"""
会话路由。

POST   /api/v1/sessions               — 创建会话
GET    /api/v1/sessions/{session_id}   — 查询会话
PATCH  /api/v1/sessions/{session_id}/status — 更新会话状态
"""

from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session as ORMSession

from app.database import get_db
from app.routers.chat import FIELD_LABELS
from app.schemas import (
    ApiResponse,
    DraftDetailResponse,
    SessionCreateRequest,
    SessionResponse,
    SessionStatusUpdateRequest,
)
from app.services import session_service

router = APIRouter(prefix="/api/v1/sessions", tags=["sessions"])


@router.post("", response_model=ApiResponse[SessionResponse])
def create_session(
    payload: SessionCreateRequest,
    db: ORMSession = Depends(get_db),
) -> ApiResponse[SessionResponse]:
    """创建一条新会话。"""
    session_obj = session_service.create_session(
        db=db,
        device_id=payload.device_id,
        session_type=payload.type,
    )
    return ApiResponse(data=SessionResponse.model_validate(session_obj))


@router.get("", response_model=ApiResponse[list[SessionResponse]])
def list_sessions(
    device_id: str = Query(..., description="设备 ID"),
    type: str | None = Query(None, description="会话类型：draft / review"),
    limit: int = Query(50, description="每页条数"),
    offset: int = Query(0, description="偏移量"),
    db: ORMSession = Depends(get_db),
) -> ApiResponse[list[SessionResponse]]:
    """按设备列出历史会话。"""
    sessions = session_service.list_sessions_by_device(
        db, device_id=device_id, session_type=type, limit=limit, offset=offset,
    )
    return ApiResponse(data=[SessionResponse.model_validate(s) for s in sessions])


@router.get("/{session_id}", response_model=ApiResponse[SessionResponse])
def get_session(
    session_id: str,
    db: ORMSession = Depends(get_db),
) -> ApiResponse[SessionResponse]:
    """按 ID 查询会话。"""
    session_obj = session_service.get_session(db, session_id)
    if session_obj is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在",
        )
    return ApiResponse(data=SessionResponse.model_validate(session_obj))


@router.delete("/{session_id}", response_model=ApiResponse[dict])
def delete_session(
    session_id: str,
    db: ORMSession = Depends(get_db),
) -> ApiResponse[dict]:
    """删除会话及其关联草稿。"""
    session_obj = session_service.get_session(db, session_id)
    if session_obj is None:
        raise HTTPException(status_code=404, detail="会话不存在")
    session_service.delete_session(db, session_id)
    return ApiResponse(data={"deleted": True})


@router.get("/{session_id}/draft", response_model=ApiResponse[DraftDetailResponse])
def get_draft_detail(
    session_id: str,
    db: ORMSession = Depends(get_db),
) -> ApiResponse[DraftDetailResponse]:
    """获取某次拟定合同会话的草稿详情（字段 + 聊天记录）。"""
    session_obj = session_service.get_session(db, session_id)
    if session_obj is None:
        raise HTTPException(status_code=404, detail="会话不存在")
    draft = session_service.get_draft_by_session(db, session_id)
    if draft is None:
        raise HTTPException(status_code=404, detail="草稿不存在")
    # 补齐全部字段：未填的 key 设为 None
    saved_fields: dict = json.loads(draft.fields_json or "{}")
    full_fields: dict[str, str | None] = {}
    for key in FIELD_LABELS:
        full_fields[key] = saved_fields.get(key)

    return ApiResponse(data=DraftDetailResponse(
        fields=full_fields,
        missing_fields=json.loads(draft.missing_fields_json or "[]"),
        chat_history=json.loads(draft.chat_history_json or "[]"),
        completeness=draft.completeness_score or 0.0,
    ))


@router.patch("/{session_id}/status", response_model=ApiResponse[SessionResponse])
def update_session_status(
    session_id: str,
    payload: SessionStatusUpdateRequest,
    db: ORMSession = Depends(get_db),
) -> ApiResponse[SessionResponse]:
    """更新会话状态。"""
    session_obj = session_service.update_session_status(
        db=db,
        session_id=session_id,
        new_status=payload.status,
        error_message=payload.error_message,
    )
    return ApiResponse(data=SessionResponse.model_validate(session_obj))
