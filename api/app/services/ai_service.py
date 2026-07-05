"""
AI 服务 —— 调用 DeepSeek API。

使用 OpenAI 兼容的 SDK 与 DeepSeek 对话。
"""

from __future__ import annotations

import json
import logging
from typing import Optional

from openai import OpenAI

from app.config import get_settings

logger = logging.getLogger("qh.ai")

HOME_CHAT_SYSTEM_PROMPT = """你是「契合」，房屋租赁合同 AI 助手。
- 友好专业回答租房/合同/法律问题，200字内
- 用户说生成/起草合同 → 引导：「请点击聊天顶部绿色「合同生成」按钮，帮您快速拟定」
- 用户说审查合同/帮我看看 → 引导：「请点击聊天顶部蓝色「合同审查」按钮，上传合同帮您分析风险」
- 始终使用中文回复"""

SYSTEM_PROMPT = """你是「契合」，一个专业的房屋租赁合同 AI 助手。

你的核心能力：
1. 与用户自然对话，收集租赁合同所需全部信息
2. 从对话中提取关键字段并在每次回复末尾输出 JSON 快照
3. 当信息齐备后提示用户可以生成合同

需要收集的全部字段（共 17 项，分 9 类）：

【双方姓名及身份证号】
- lessor_name（出租方姓名）
- lessor_id（出租方身份证号）
- lessee_name（承租方姓名）
- lessee_id（承租方身份证号）

【双方联系电话】
- lessor_phone（出租方电话）
- lessee_phone（承租方电话）

【房屋地址】
- address（房屋地址）

【房屋面积和户型】
- area（房屋面积）
- layout（户型）

【租期起止时间】
- lease_start（租期起）
- lease_end（租期止）

【租金金额】
- rent_amount（月租金）

【付款周期】
- rent_cycle（付款周期：月付/季付/半年付/年付）

【押金金额、退款条件和时间】
- deposit（押金金额）
- refund_condition（押金退款条件）
- refund_time（押金退款时间）

【水电气及物业费等】
- other_fees（水电气及物业费等其他费用）

行为准则：
- 回答自然、友好，像正常人一样聊天
- 首次对话时提示用户：「您可以根据上方的可展开信息面板填写所有信息，也可以由我一步步询问。请问您想怎么开始？」
- 在字段未收齐时，如果用户选择一步步询问，一次只问一个缺失的字段
- 用户如果闲聊（说"你好""谢谢"等），正常回应即可
- 用户提供信息后，先确认收到，再自然追问下一个未收集的字段
- 当全部 17 个字段都收集完毕后，告知用户所有信息已齐备，等待用户说"生成合同"或"生成模板"
- 注意！绝对不要从头开始问，也不要重置已收集的信息。用户可能分多次填写，每次只追问本次新出现的缺失字段即可。
- ⚠️ 重要：用户可能通过气泡面板集中提交信息，格式为「我已填写以下信息：\n- 字段名：值」。这种消息中的每一条都是有效的合同字段，必须全部确认并记录。绝不能回复"不需要收集这些信息"或类似说法。17 个字段全部需要收集，没有例外。
- 始终使用中文回复

⚠️ 每次回复末尾必须输出 JSON 字段快照，格式如下（不包含任何其他文字在 JSON 前后）：
{"field_state": {"lessor_name": "值或null", "lessor_id": "值或null", ...全部17个字段}, "all_filled": false}
注意：JSON 块必须与正文之间用换行分隔，且 JSON 单独占一段。字段值如果是字符串必须带双引号，未收集的字段值为 null（不带引号）。"""


def _build_openai_client() -> OpenAI:
    """构建 OpenAI 兼容客户端（指向 DeepSeek）。"""
    settings = get_settings()
    return OpenAI(
        api_key=settings.deepseek_api_key,
        base_url="https://api.deepseek.com",
        timeout=120.0,
    )


REVIEW_SYSTEM_PROMPT = """你是「契合」的合同审查引擎，专门分析中国房屋租赁合同条款对承租方/出租方的风险。

用户会提供一份合同文本和审查立场（tenant=承租方, landlord=出租方, neutral=中立）。
你需要逐条扫描合同条款，找出对用户不利或模糊的条款，输出 JSON。

风险类型必须至少覆盖以下类别：
- deposit_refund（押金退还条件不清）
- rent_increase（租金调价条款不明）
- lease_renewal（续租权利缺失）
- maintenance（维修责任分配不公）
- sublet（转租权利限制）
- early_termination（提前退租罚则过高）
- penalty（违约金不对等）
- fee_allocation（费用承担模糊）
- jurisdiction（争议管辖地不利）
- unfair_term（霸王条款/格式条款无效）

行为准则：
1. 只输出有实质风险的条款，无风险的合同可以返回空风险列表
2. 每条风险必须包含：risk_id, level(red/yellow/green), type, title, quote（原文引用）, plain_explanation（白话解释），suggested_revision（建议改法），needs_lawyer(boolean)
3. 法律引用 citations 为可选字段，没有确切法条依据时不编造，留空数组。**如果填写 citations，每个元素必须严格包含4个字段**：source_type（只能是 "law" / "regulation" / "interpretation" / "standard_contract" 之一）、title（法条全称+条款号，如「《民法典》第七百一十二条」）、url_or_ref（出处，无则空字符串）、verified（固定 false）。**禁止**只写字符串数组如 ["民法典712条"]，必须写完整对象。
4. highlight_range 用原文字符偏移（start/end），无法定位时设为 {"start":0,"end":0}
5. 审查摘要 summary 必须包含 total_risks, red_count, yellow_count, green_count, suggestion

输出格式（严格 JSON，不要任何额外文字）：
{
  "summary": {
    "total_risks": 3,
    "red_count": 1,
    "yellow_count": 1,
    "green_count": 1,
    "suggestion": "建议先谈押金退还和维修责任两处再签"
  },
  "risks": [
    {
      "risk_id": "risk_001",
      "level": "red",
      "type": "deposit_refund",
      "title": "押金退还条件不清",
      "quote": "合同原文中的风险句子",
      "plain_explanation": "这句话对你不利，因为…",
      "suggested_revision": "建议改为：租赁期满且房屋无异常损坏时，出租方应在3个工作日内无息退还押金。",
      "citations": [{"source_type": "law", "title": "《民法典》第七百一十二条", "url_or_ref": "", "verified": false}],
      "highlight_range": {"start": 120, "end": 168},
      "needs_lawyer": false
    }
  ]
}

**格式强约束（违反会导致解析失败）**：
- citations 必须是对象数组，禁止字符串数组如 ["《民法典》712条"]
- 每个 citation 必须含 source_type / title / url_or_ref / verified 这 4 个字段
- source_type 只能是 "law" / "regulation" / "interpretation" / "standard_contract" 之一
- 无依据时 citations 填空数组 []

注意：如果合同文本中根本没有租赁相关内容（比如用户传了一张猫的照片），返回：
{"summary":{"total_risks":0,"red_count":0,"yellow_count":0,"green_count":0,"suggestion":"未检测到有效的租赁合同内容，请确认上传文件是否正确。"},"risks":[]}"""


def review_contract(contract_text: str, user_role: str) -> dict:
    """
    调用 DeepSeek 对合同文本进行风险审查。

    Args:
        contract_text: 合同全文
        user_role: tenant / landlord / neutral

    Returns:
        parsed JSON dict（含 summary + risks）

    Raises:
        Exception: DeepSeek 调用失败
        ValueError: 模型返回内容非合法 JSON
    """
    client = _build_openai_client()
    sys_msg = (
        f"{REVIEW_SYSTEM_PROMPT}\n\n"
        f"审查立场说明： user_role={user_role}。"
        f"{' 请特别关注对承租方不利的条款。' if user_role == 'tenant' else ''}"
        f"{' 请特别关注对出租方不利的条款。' if user_role == 'landlord' else ''}"
        f"{' 请从双方平衡角度给出中立评估。' if user_role == 'neutral' else ''}"
    )
    # 合同过长时截断，避免上下文撑爆导致 DeepSeek 返回残缺 JSON
    # 阈值 4000：给 system prompt + 输出 JSON 留足余量
    if len(contract_text) > 4000:
        contract_text = (
            contract_text[:4000]
            + "\n\n[合同文本过长，已截断，仅审查前4000字。建议对完整合同分批审查。]"
        )

    user_msg = f"审查立场：{user_role}\n\n合同文本：\n{contract_text}"

    try:
        resp = client.chat.completions.create(
            model="deepseek-chat",
            messages=[
                {"role": "system", "content": sys_msg},
                {"role": "user", "content": user_msg},
            ],
            temperature=0.3,
            max_tokens=8192,
        )
        raw = resp.choices[0].message.content or ""
        # deepseek-reasoner 输出在 reasoning_content，content 可能为空
        if not raw:
            raw = getattr(resp.choices[0].message, "reasoning_content", "") or ""
    except Exception as e:
        logger.error(f"DeepSeek review 调用失败: {e}")
        raise

    text = raw.strip()
    if text.startswith("```"):
        lines = text.splitlines()
        if lines[0].strip().startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        text = "\n".join(lines).strip()

    try:
        return json.loads(text)
    except json.JSONDecodeError as e:
        logger.error(f"review_contract JSON 解析失败: {e} — 原文：{raw[:500]}")
        raise ValueError(f"模型返回非法 JSON: {e}") from e


def _chat_common(
    messages: list[dict],
    user_message: str,
    *,
    system_prompt: str,
    temperature: float = 0.7,
    max_tokens: int = 1024,
) -> tuple[str, list[dict]]:
    """
    DeepSeek 调用核心逻辑，首页聊天和合同生成共用。

    Args:
        messages: 历史消息 [{role, content}, ...]
        user_message: 用户最新输入
        system_prompt: 本次调用使用的 system prompt
        temperature: 温度
        max_tokens: 最大输出 token

    Returns:
        (ai_reply, updated_messages)
    """
    client = _build_openai_client()

    request_messages = [{"role": "system", "content": system_prompt}]
    request_messages.extend(messages)
    request_messages.append({"role": "user", "content": user_message})

    try:
        resp = client.chat.completions.create(
            model=get_settings().deepseek_model,
            messages=request_messages,
            temperature=temperature,
            max_tokens=max_tokens,
        )

        reply = resp.choices[0].message.content or "抱歉，我没有理解你的意思，能再说一遍吗？"

        # 更新消息历史
        updated_messages = list(messages)
        updated_messages.append({"role": "user", "content": user_message})
        updated_messages.append({"role": "assistant", "content": reply})

        return reply, updated_messages

    except Exception as e:
        logger.error(f"DeepSeek 调用失败: {e}")
        raise


def chat_with_ai(
    messages: list[dict],
    user_message: str,
) -> tuple[str, list[dict]]:
    """
    合同生成 / 拟定合同流的 DeepSeek 调用（带字段收集 prompt）。

    Args:
        messages: 历史消息 [{role, content}, ...]
        user_message: 用户最新输入

    Returns:
        (ai_reply, updated_messages)
    """
    return _chat_common(messages, user_message, system_prompt=SYSTEM_PROMPT)


def chat_home(
    messages: list[dict],
    user_message: str,
) -> tuple[str, list[dict]]:
    """
    首页聊天的 DeepSeek 调用（不带字段收集 prompt）。
    用户可能粘贴整份合同文本 → 进入"合同审查模式"，
    因此 max_tokens 放宽到 2048。

    Args:
        messages: 历史消息 [{role, content}, ...]
        user_message: 用户最新输入

    Returns:
        (ai_reply, updated_messages)
    """
    return _chat_common(
        messages, user_message,
        system_prompt=HOME_CHAT_SYSTEM_PROMPT,
        max_tokens=2048,
    )
