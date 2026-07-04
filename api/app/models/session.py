"""
会话 ORM 模型。

记录一次"拟定合同"或"审核合同"的完整会话生命周期，
用于历史列表、状态追踪与错误回溯。
"""

import uuid
from datetime import datetime, timezone
from typing import Literal, Optional

from sqlalchemy import String, Text, DateTime, Index
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base

SessionType = Literal["draft", "review"]
SessionStatus = Literal["created", "processing", "completed", "failed"]


def _uuid4_hex() -> str:
    return uuid.uuid4().hex


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Session(Base):
    """一次合同拟定 / 审核会话。"""

    __tablename__ = "sessions"

    # ---- 主键 ----
    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=_uuid4_hex,
    )

    # ---- 归属 ----
    user_id: Mapped[Optional[str]] = mapped_column(
        String(36),
        nullable=True,
        index=True,
        comment="用户 ID，可为空（匿名会话）",
    )

    device_id: Mapped[str] = mapped_column(
        String(256),
        nullable=False,
        index=True,
        comment="设备指纹，用于匿名用户追踪",
    )

    # ---- 业务属性 ----
    type: Mapped[SessionType] = mapped_column(
        String(20),
        nullable=False,
        comment="会话类型：draft（拟定）/ review（审核）",
    )

    status: Mapped[SessionStatus] = mapped_column(
        String(20),
        nullable=False,
        default="created",
        index=True,
        comment="会话状态：created / processing / completed / failed",
    )

    error_message: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="失败时的错误信息",
    )

    # ---- 时间戳 ----
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=_utcnow,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=_utcnow,
        onupdate=_utcnow,
        comment="每次写入自动刷新",
    )

    # ---- 索引 ----
    __table_args__ = (
        Index("ix_sessions_user_created", "user_id", "created_at"),
        Index("ix_sessions_device_created", "device_id", "created_at"),
    )

    def __repr__(self) -> str:
        return (
            f"<Session(id={self.id!r}, type={self.type!r}, "
            f"status={self.status!r})>"
        )
