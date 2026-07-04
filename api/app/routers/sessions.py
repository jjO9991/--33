"""
会话路由。

POST   /api/v1/sessions               — 创建会话
GET    /api/v1/sessions/{session_id}   — 查询会话
PATCH  /api/v1/sessions/{session_id}/status — 更新会话状态
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session as ORMSession

from app.database import get_db
from app.schemas import (
    ApiResponse,
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
