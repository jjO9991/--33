"""
会话 CRUD 服务。

所有函数接收 ``db: Session`` 作为第一个参数，便于调用方控制事务边界。
"""

from __future__ import annotations

from fastapi import HTTPException, status
from sqlalchemy.orm import Session as ORMSession

from app.models import Session


def create_session(db: ORMSession, device_id: str, session_type: str) -> Session:
    """创建一条新会话并入库。"""

    session_obj = Session(
        device_id=device_id,
        type=session_type,
        status="created",
    )
    db.add(session_obj)
    db.commit()
    db.refresh(session_obj)
    return session_obj


def get_session(db: ORMSession, session_id: str) -> Session | None:
    """按 ID 查询会话，不存在返回 None。"""

    return db.query(Session).filter(Session.id == session_id).first()


def update_session_status(
    db: ORMSession,
    session_id: str,
    new_status: str,
    error_message: str | None = None,
) -> Session:
    """更新会话状态，找不到时抛 404。"""

    session_obj = get_session(db, session_id)
    if session_obj is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在",
        )

    session_obj.status = new_status
    if error_message is not None:
        session_obj.error_message = error_message

    db.commit()
    db.refresh(session_obj)
    return session_obj
