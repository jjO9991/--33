"""
合同审查路由。

POST /api/v1/reviews/analyze — 提交合同文本进行 AI 风险审查
"""

from __future__ import annotations

import json
import logging
import os
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as ORMSession

from app.database import get_db
from app.models import File, LeaseReview, Session
from app.schemas import (
    ApiResponse,
    ReviewAnalyzeRequest,
    ReviewAnalyzeResponse,
    ReviewSummary,
    RiskCard,
)
from app.services.ai_service import review_contract

logger = logging.getLogger("qh.api.reviews")

router = APIRouter(prefix="/api/v1/reviews", tags=["reviews"])


# ---- 内部辅助 ----

def _load_contract_text(payload: ReviewAnalyzeRequest, db: ORMSession) -> str:
    """
    从 text 或 file_id 中读取合同文本。

    - 优先使用 payload.text
    - 否则根据 file_id 读 SQLite 文件记录，仅 .txt 可直接读取；
      其它类型（pdf / docx / image）在 MVP 阶段直接返回有好的错误提示，
      待 OCR 接入后可平滑扩展。
    """
    if payload.text:
        return payload.text

    file_obj = db.query(File).filter(File.id == payload.file_id).first()
    if file_obj is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="file_id 对应的文件不存在",
        )

    if file_obj.type != "txt":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"暂不支持 {file_obj.type} 类型的审查，请粘贴合同文本或上传 .txt 文件",
        )

    upload_dir = os.path.dirname(file_obj.storage_key)
    # storage_key 形如 "{prefix}/{sha256}.{ext}"
    file_path = Path(upload_dir) / file_obj.storage_key
    if not file_path.is_file():
        # 再退回项目根下的 uploads 目录
        fallback = Path("uploads") / file_obj.storage_key
        file_path = fallback if fallback.is_file() else file_path

    try:
        return file_path.read_text(encoding="utf-8")
    except Exception as exc:
        logger.error(f"读取合同文件失败: {file_obj.storage_key} — {exc}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="合同文件读取失败，请稍后重试",
        ) from exc


def _parse_ai_reply(raw: str) -> tuple[ReviewSummary, list[RiskCard]]:
    """
    将 DeepSeek 回复解析为 (summary, risks)。

    - 允许回复被 ```json ... ``` 包裹
    - JSON 结构校验失败时抛 ValueError，由调用方返回 failed
    """
    text = raw.strip()
    if text.startswith("```"):
        # 去掉首尾 ```json / ``` 包裹
        lines = text.splitlines()
        if lines[0].strip().startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        text = "\n".join(lines).strip()

    data = json.loads(text)

    # 兜底标准化 citations：DeepSeek 偶尔不按格式输出，补全必填字段避免解析失败
    for risk in data.get("risks", []):
        normalized = []
        for c in risk.get("citations", []):
            if isinstance(c, str):
                c = {"title": c}
            c.setdefault("source_type", "law")
            c.setdefault("title", "相关法规")
            c.setdefault("url_or_ref", "")
            c.setdefault("verified", False)
            normalized.append(c)
        risk["citations"] = normalized

    summary = ReviewSummary(**data["summary"])
    risks = [RiskCard(**item) for item in data.get("risks", [])]
    return summary, risks


# ---- 路由 ----

@router.post("/analyze", response_model=ApiResponse[ReviewAnalyzeResponse])
def analyze_review(
    payload: ReviewAnalyzeRequest,
    db: ORMSession = Depends(get_db),
) -> ApiResponse[ReviewAnalyzeResponse]:
    """
    提交合同文本进行 AI 审查。

    流程：校验 session → 读取合同文本 → 写 LeaseReview 占位 → 调 DeepSeek →
          解析 JSON → 落库 → 返回。
    """
    # 1. 校验 session 存在且为 review 类型
    session_obj: Session | None = db.query(Session).filter(
        Session.id == payload.session_id,
    ).first()
    if session_obj is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在",
        )
    if session_obj.type != "review":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该会话不是审查会话（type != review），请使用 type=review 的会话",
        )

    # 2. 读取合同文本
    contract_text = _load_contract_text(payload, db)
    if not contract_text.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="合同文本为空，无法审查",
        )

    # 3. 创建或更新 LeaseReview 占位（无结果时也可查到痕迹）
    review = db.query(LeaseReview).filter(
        LeaseReview.session_id == payload.session_id,
    ).first()
    if review is None:
        review = LeaseReview(
            session_id=payload.session_id,
            user_role=payload.user_role,
            extracted_text_ref=contract_text[:200] + ("…" if len(contract_text) > 200 else ""),
        )
        db.add(review)
    else:
        review.user_role = payload.user_role
        review.extracted_text_ref = contract_text[:200] + (
            "…" if len(contract_text) > 200 else ""
        )

    # 4. 调 AI
    try:
        ai_result = review_contract(
            contract_text=contract_text,
            user_role=payload.user_role,
        )
    except Exception as exc:
        logger.error(f"审查 AI 调用失败: {exc}")
        review.summary_json = json.dumps({
            "total_risks": 0, "red_count": 0, "yellow_count": 0, "green_count": 0,
            "suggestion": "审查服务暂时不可用，请稍后重试",
        }, ensure_ascii=False)
        review.risk_items_json = "[]"
        db.commit()
        return ApiResponse(
            data=ReviewAnalyzeResponse(
                session_id=payload.session_id,
                status="failed",
                summary=ReviewSummary(
                    total_risks=0, red_count=0, yellow_count=0, green_count=0,
                    suggestion="审查服务暂时不可用，请稍后重试",
                ),
                risks=[],
            ))
    # 5. 解析
    try:
        summary, risks = _parse_ai_reply(json.dumps(ai_result, ensure_ascii=False))
    except (ValueError, KeyError, json.JSONDecodeError) as exc:
        logger.warning(f"审查结果解析失败: {exc}")
        review.summary_json = json.dumps({
            "total_risks": 0, "red_count": 0, "yellow_count": 0, "green_count": 0,
            "suggestion": "审查结果解析异常，请重试",
        }, ensure_ascii=False)
        review.risk_items_json = "[]"
        db.commit()
        return ApiResponse(
            data=ReviewAnalyzeResponse(
                session_id=payload.session_id,
                status="failed",
                summary=ReviewSummary(
                    total_risks=0, red_count=0, yellow_count=0, green_count=0,
                    suggestion="审查结果解析异常，请重试",
                ),
                risks=[],
            ))

    # 6. 落库
    review.summary_json = summary.model_dump_json()
    review.risk_items_json = json.dumps(
        [r.model_dump() for r in risks], ensure_ascii=False,
    )
    db.commit()
    db.refresh(review)

    # 7. 非合同内容判定：无风险且 AI 提示"未检测到"，把状态改为 empty
    #    让前端分流渲染，不把猫图/垃圾文本显示成"审查完成"
    final_status = "completed"
    if summary.total_risks == 0 and "未检测到" in summary.suggestion:
        final_status = "empty"

    return ApiResponse(
        data=ReviewAnalyzeResponse(
            session_id=payload.session_id,
            status=final_status,
            summary=summary,
            risks=risks,
        ),
    )
