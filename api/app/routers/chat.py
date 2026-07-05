"""
聊天路由。

POST /api/v1/sessions/{session_id}/chat  — 发送消息并获取 AI 回复（基于 DeepSeek）
"""

from __future__ import annotations

import json
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as ORMSession

from app.database import get_db
from app.models import Session, LeaseDraft
from app.schemas import ApiResponse
from app.schemas.chat import ChatRequest, ChatResponse, FieldInfo
from app.services.ai_service import chat_home, chat_with_ai

logger = logging.getLogger("qh.chat")

router = APIRouter(prefix="/api/v1/sessions", tags=["chat"])

FIELD_DEFINITIONS: list[dict[str, str]] = [
    # ① 双方姓名及身份证号
    {"key": "lessor_name", "label": "出租方姓名"},
    {"key": "lessor_id", "label": "出租方身份证号"},
    {"key": "lessee_name", "label": "承租方姓名"},
    {"key": "lessee_id", "label": "承租方身份证号"},
    # ② 双方联系电话
    {"key": "lessor_phone", "label": "出租方电话"},
    {"key": "lessee_phone", "label": "承租方电话"},
    # ③ 房屋地址
    {"key": "address", "label": "房屋地址"},
    # ④ 房屋面积和户型
    {"key": "area", "label": "房屋面积"},
    {"key": "layout", "label": "户型"},
    # ⑤ 租期起止时间
    {"key": "lease_start", "label": "租期起"},
    {"key": "lease_end", "label": "租期止"},
    # ⑥ 租金金额
    {"key": "rent_amount", "label": "月租金"},
    # ⑦ 付款周期
    {"key": "rent_cycle", "label": "付款周期"},
    # ⑧ 押金金额、退款条件和时间
    {"key": "deposit", "label": "押金金额"},
    {"key": "refund_condition", "label": "押金退款条件"},
    {"key": "refund_time", "label": "押金退款时间"},
    # ⑨ 水电气及物业费等
    {"key": "other_fees", "label": "水电气及物业费"},
]

FIELD_LABELS = {f["key"]: f["label"] for f in FIELD_DEFINITIONS}
FIELD_KEYS_BY_LABEL: dict[str, str] = {f["label"]: f["key"] for f in FIELD_DEFINITIONS}


@router.post("/{session_id}/chat", response_model=ApiResponse[ChatResponse])
def chat(
    session_id: str,
    payload: ChatRequest,
    db: ORMSession = Depends(get_db),
) -> ApiResponse[ChatResponse]:
    """发送一条消息，DeepSeek AI 回复。"""

    # 1. 查找会话
    session_obj = db.query(Session).filter(Session.id == session_id).first()
    if session_obj is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在",
        )

    # 首页聊天：session type=chat → 纯聊天，不收集字段
    if session_obj.type == "chat":
        return _chat_home(session_id, session_obj, payload.message, db)

    # 2. 查找或创建 LeaseDraft
    draft = db.query(LeaseDraft).filter(LeaseDraft.session_id == session_id).first()
    if draft is None:
        draft = LeaseDraft(
            session_id=session_id,
            fields_json="{}",
            missing_fields_json=json.dumps([f["key"] for f in FIELD_DEFINITIONS]),
            chat_history_json="[]",
            completeness_score=0.0,
        )
        db.add(draft)
        db.commit()
        db.refresh(draft)

    # 3. 加载已有字段和聊天历史
    current_fields: dict[str, Optional[str]] = json.loads(draft.fields_json or "{}")
    chat_history: list[dict] = json.loads(draft.chat_history_json or "[]")

    # 4. 先从用户消息中提取字段（正则提取，直接写的内容）
    current_fields = _extract_fields_from_reply(payload.message, current_fields)

    # 5. 构建带字段上下文的增强消息
    filled_count = sum(1 for f in FIELD_DEFINITIONS if current_fields.get(f["key"]))
    total_count = len(FIELD_DEFINITIONS)

    field_context_lines = ["当前已收集的合同信息："]
    filled_fields = [f for f in FIELD_DEFINITIONS if current_fields.get(f["key"])]
    if filled_fields:
        for f in filled_fields:
            field_context_lines.append(f"- {f['label']}：{current_fields[f['key']]}")
    else:
        field_context_lines.append("（尚未收集任何信息）")
    field_context_lines.append(f"还需收集 {total_count - filled_count}/{total_count} 项。")
    field_context_lines.append("请根据已有信息自然回应，不要重复询问已收集的字段。")
    field_context = "\n".join(field_context_lines)

    enriched_message = f"{payload.message}\n\n[系统参考：{field_context}]"

    # 6. 调用 DeepSeek
    try:
        reply, updated_history = chat_with_ai(chat_history, enriched_message)
    except Exception as e:
        logger.error(f"AI 调用失败: {e}")
        return ApiResponse(
            code=500,
            message=f"AI 服务暂时不可用：{str(e)}",
            data=ChatResponse(
                reply="抱歉，AI 服务暂时不可用，请稍后再试。",
                fields=_build_field_list(current_fields),
                completeness=_calc_completeness(current_fields),
            ),
        )

    # 7. 从 AI 回复中提取字段 — 优先解析 JSON 快照，降级到正则
    current_fields = _extract_fields_from_ai_reply(reply, current_fields)

    # 8. 保存到数据库（★ 关键修复：存库前剥离 JSON 快照）
    clean_reply = _strip_field_json(reply)
    updated_history[-1]["content"] = clean_reply

    missing_keys = [f["key"] for f in FIELD_DEFINITIONS if current_fields.get(f["key"]) is None]
    draft.fields_json = json.dumps(current_fields)
    draft.missing_fields_json = json.dumps(missing_keys)
    draft.completeness_score = _calc_completeness(current_fields)
    draft.chat_history_json = json.dumps(updated_history)

    # 自动生成会话标题（仅首次）
    if session_obj.title == "新建会话":
        _auto_name_session(session_obj, payload.message)

    db.commit()

    # 9. 返回（已干净的正文）
    return ApiResponse(data=ChatResponse(
        reply=clean_reply,
        fields=_build_field_list(current_fields),
        completeness=_calc_completeness(current_fields),
    ))


def _build_field_list(fields: dict[str, Optional[str]]) -> list[FieldInfo]:
    return [
        FieldInfo(
            key=k,
            label=FIELD_LABELS.get(k, k),
            value=fields.get(k),
            is_missing=fields.get(k) is None,
        )
        for k in FIELD_LABELS
    ]


def _calc_completeness(fields: dict[str, Optional[str]]) -> float:
    filled = sum(1 for f in FIELD_DEFINITIONS if fields.get(f["key"]))
    return round(filled / len(FIELD_DEFINITIONS), 2)


def _extract_fields_from_ai_reply(
    reply: str,
    current: dict[str, Optional[str]],
) -> dict[str, Optional[str]]:
    """
    从 AI 回复中提取字段值。

    策略：
    1. 优先解析 AI 按要求附加的 JSON 快照（最准确）
    2. 次优：解析结构化行格式 "- 标签：值"（来自气泡提交）
    3. 降级到正则提取（兜底）
    """
    import json as _json
    import re

    fields = dict(current)

    # ---- 策略 1：解析 JSON 快照 ----
    json_fields = _parse_field_json(reply)
    if json_fields is not None:
        for key, value in json_fields.items():
            if key in FIELD_LABELS and value is not None:
                fields[key] = str(value)

    # ---- 策略 2：结构化行格式解析（"- 标签：值"） ----
    fields = _extract_structured_lines(reply, fields)

    # ---- 策略 3：正则降级提取（作为补充） ----
    fields = _regex_extract(reply, fields)

    return fields


def _extract_structured_lines(
    text: str,
    fields: dict[str, Optional[str]],
) -> dict[str, Optional[str]]:
    """
    解析结构化行格式：
      - 出租方姓名：张三
      - 出租方身份证：110101...
    将中文标签映射回 field key。

    ⚠️ 结构化行格式是用户明确填写的内容，比正则猜测更可信，
       因此直接覆盖已有值（不检查 is None）。
    """
    import re
    for line in text.splitlines():
        line = line.strip()
        # 匹配 "- 标签：值" 或 "- 标签：值"
        m = re.match(r'^[-•*]\s*(.+?)[：:]\s*(.+)$', line)
        if m:
            label = m.group(1).strip()
            value = m.group(2).strip()
            if not value or value == "（未填写）":
                continue
            # 通过中文标签反查字段 key
            if label in FIELD_KEYS_BY_LABEL:
                key = FIELD_KEYS_BY_LABEL[label]
                fields[key] = value
            # 也尝试模糊匹配：标签包含关系
            else:
                for ch_label, ch_key in FIELD_KEYS_BY_LABEL.items():
                    if ch_label in label or label in ch_label:
                        fields[ch_key] = value
                        break
    return fields


def _parse_field_json(text: str) -> dict[str, Optional[str]] | None:
    """
    从 AI 回复末尾解析 JSON 字段快照。
    格式：{"field_state": {"key": "value"或null, ...}, "all_filled": bool}
    """
    import json as _json
    import re

    # 找最后一个包含 "field_state" 的 JSON 块
    json_pattern = re.compile(r'\{[^{}]*"field_state"[^{}]*\{[^{}]*\}[^{}]*\}', re.DOTALL)
    for m in json_pattern.finditer(text):
        try:
            data = _json.loads(m.group())
            fs = data.get("field_state", {})
            if isinstance(fs, dict):
                return {k: v for k, v in fs.items()}
        except (_json.JSONDecodeError, TypeError):
            continue
    return None


def _strip_field_json(text: str) -> str:
    """
    移除 AI 回复末尾的 JSON 字段快照，只保留正文。
    """
    import re
    # 移除最后一个 JSON 块
    return re.sub(r'\s*\{[^{}]*"field_state"[^{}]*\{[^{}]*\}[^{}]*\}\s*$', '', text).strip()


def _auto_name_session(session_obj, user_message: str):
    """从用户第一条有效消息自动生成会话标题。"""
    import re
    # 去掉系统参考后缀
    text = re.sub(r'\n\n\[系统参考：.*$', '', user_message).strip()
    # 取第一行有效内容，截取前 20 个字
    title = text.split('\n')[0].strip()[:20]
    if title:
        session_obj.title = title


def _extract_fields_from_reply(
    text: str,
    current: dict[str, Optional[str]],
) -> dict[str, Optional[str]]:
    """提取字段（用于用户消息）：结构化行精确解析 → 正则兜底补充。"""
    fields = dict(current)
    fields = _extract_structured_lines(text, fields)
    fields = _regex_extract(text, fields)
    return fields


def _regex_extract(
    text: str,
    fields: dict[str, Optional[str]],
) -> dict[str, Optional[str]]:
    """从文本中用正则提取字段值。"""
    import re

    question_words = re.compile(r'[哪谁吗呢什么怎么是否有没有]')

    # 姓名类
    name_patterns = {
        "lessor_name": [r'(?:出租方|甲方|出租人)[：:是为\s]*([^。，？！!.\n\d]{2,10})'],
        "lessee_name": [r'(?:承租方|乙方|承租人)[：:是为\s]*([^。，？！!.\n\d]{2,10})'],
    }
    for key, regexes in name_patterns.items():
        if fields.get(key) is not None:
            continue
        for p in regexes:
            m = re.search(p, text)
            if m:
                val = m.group(1).strip()
                if len(val) >= 2 and not question_words.search(val):
                    fields[key] = val
                    break

    # 电话
    phone_p = re.compile(r'(?:电话|手机|联系电话|联系方式)[：:是为\s]*(\d{11})')
    for match in phone_p.finditer(text):
        val = match.group(1)
        if fields.get("lessor_phone") is None:
            fields["lessor_phone"] = val
        elif fields.get("lessee_phone") is None:
            fields["lessee_phone"] = val
        # 如果两个都填了，skip

    # 身份证
    id_p = re.compile(r'(?:身份证|身份证号|身份证号码)[：:是为\s]*(\d{17}[\dXx])')
    for match in id_p.finditer(text):
        val = match.group(1)
        if fields.get("lessor_id") is None:
            fields["lessor_id"] = val
        elif fields.get("lessee_id") is None:
            fields["lessee_id"] = val

    # 地址
    if fields.get("address") is None:
        addr_p = re.compile(r'(?:地址|房屋地址|租赁地址)[：:是为\s]*([^。，？！!.\n]{3,40})')
        m = addr_p.search(text)
        if m:
            val = m.group(1).strip()
            if len(val) >= 3 and not question_words.search(val):
                fields["address"] = val

    # 面积
    if fields.get("area") is None:
        area_p = re.compile(r'(\d+(?:\.\d+)?)\s*(?:平方[米]?|㎡|m²)')
        m = area_p.search(text)
        if m:
            fields["area"] = m.group(1) + "㎡"

    # 户型
    if fields.get("layout") is None:
        layout_p = re.compile(r'(\d)\s*(?:室|房)\s*(\d)\s*(?:厅|听)')
        m = layout_p.search(text)
        if m:
            fields["layout"] = f"{m.group(1)}室{m.group(2)}厅"

    # 月租金
    if fields.get("rent_amount") is None:
        rent_p = re.compile(r'(?:月租金|租金|房租)[：:是为\s]*(\d+(?:\.\d+)?)\s*(?:元|块)')
        m = rent_p.search(text)
        if m:
            fields["rent_amount"] = m.group(1) + "元"

    # 付款周期
    if fields.get("rent_cycle") is None:
        cycle_p = re.compile(r'(月付|季付|半年付|年付|每月|每季|每半年|每年)')
        m = cycle_p.search(text)
        if m:
            val = m.group(1)
            mapping = {"每月": "月付", "每季": "季付", "每半年": "半年付", "每年": "年付"}
            fields["rent_cycle"] = mapping.get(val, val)

    # 押金金额
    if fields.get("deposit") is None:
        dep_p = re.compile(r'押金[：:是为\s]*(\d+(?:\.\d+)?)\s*(?:元|块)')
        m = dep_p.search(text)
        if m:
            fields["deposit"] = m.group(1) + "元"

    # 退款条件
    if fields.get("refund_condition") is None:
        cond_p = re.compile(r'(?:退款条件|退还条件|退押金条件)[：:是为\s]*([^。，？！!.\n]{3,30})')
        m = cond_p.search(text)
        if m:
            val = m.group(1).strip()
            if not question_words.search(val):
                fields["refund_condition"] = val

    # 退款时间
    if fields.get("refund_time") is None:
        time_p = re.compile(r'(?:退款时间|退还时间|[退押金]{2,4})(?:[后内]|时间)[：:是为\s]*([^。，？！!.\n]{2,20})')
        m = time_p.search(text)
        if m:
            val = m.group(1).strip()
            if not question_words.search(val):
                fields["refund_time"] = val

    # 其他费用
    if fields.get("other_fees") is None:
        fee_p = re.compile(r'(?:水电气|物业费|其他费用|水电费|杂费)[：:是为\s]*([^。，？！!.\n]{3,40})')
        m = fee_p.search(text)
        if m:
            val = m.group(1).strip()
            if not question_words.search(val):
                fields["other_fees"] = val

    # 日期提取（租期起/止）
    if fields.get("lease_start") is None or fields.get("lease_end") is None:
        date_pattern = re.compile(
            r'(\d{4}\s*年\s*\d{1,2}\s*月\s*\d{1,2}\s*日'
            r'|\d{4}[-/]\d{1,2}[-/]\d{1,2}'
            r'|\d{1,2}\s*月\s*\d{1,2}\s*号?)',
        )
        dates = date_pattern.findall(text)
        if dates:
            if fields.get("lease_start") is None:
                fields["lease_start"] = dates[0].strip()
            if len(dates) > 1 and fields.get("lease_end") is None:
                fields["lease_end"] = dates[1].strip()

    return fields


def _chat_home(session_id: str, session_obj, message: str, db):
    """首页纯聊天，存历史但不做字段收集"""
    from app.models import LeaseDraft

    # 用 LeaseDraft 存聊天历史（复用 chat_history_json，字段相关不管）
    draft = db.query(LeaseDraft).filter(LeaseDraft.session_id == session_id).first()
    if draft is None:
        draft = LeaseDraft(
            session_id=session_id,
            fields_json="{}",
            missing_fields_json="[]",
            chat_history_json="[]",
            completeness_score=1.0,
        )
        db.add(draft)
        db.commit()
        db.refresh(draft)

    chat_history = json.loads(draft.chat_history_json or "[]")

    try:
        reply, updated_history = chat_home(chat_history, message)
    except Exception as e:
        logger.error(f"首页 AI 调用失败: {e}")
        return ApiResponse(
            code=500,
            message="AI 服务暂时不可用",
            data=ChatResponse(
                reply="抱歉，AI 服务暂时不可用，请稍后再试。",
                fields=[],
                completeness=1.0,
            ),
        )

    draft.chat_history_json = json.dumps(updated_history)
    if session_obj.title == "新建会话":
        session_obj.title = message[:20]
    db.commit()

    return ApiResponse(data=ChatResponse(
        reply=reply,
        fields=[],
        completeness=1.0,
    ))
