"""
租赁合同拟定草稿 ORM 模型。

一次"拟定会话"对应一条 lease_drafts 记录，
随着多轮对话逐步填充字段、提升完整度，最终生成合同正文。
"""

import uuid
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import String, Integer, Float, DateTime, Text, Index
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


def _uuid4_hex() -> str:
    return uuid.uuid4().hex


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class LeaseDraft(Base):
    """一份进行中的租赁合同拟定草稿。"""

    __tablename__ = "lease_drafts"

    # ---- 主键 ----
    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=_uuid4_hex,
    )

    # ---- 归属 ----
    session_id: Mapped[str] = mapped_column(
        String(36),
        nullable=False,
        index=True,
        comment="所属会话 ID",
    )

    # ---- 拟定内容 ----
    fields_json: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="已收集的租赁字段 JSON（出租方、地址、租期、租金等）",
    )

    missing_fields_json: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="缺失字段列表 JSON，用于前端高亮提示",
    )

    chat_history_json: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        default=None,
        comment="对话历史 JSON 数组，格式 [{role, content}]",
    )

    completeness_score: Mapped[Optional[float]] = mapped_column(
        Float,
        nullable=True,
        comment="字段完整度 0.0 ~ 1.0",
    )

    contract_text: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="生成的完整合同文本（敏感数据）",
    )

    template_version: Mapped[Optional[str]] = mapped_column(
        String(20),
        nullable=True,
        comment="使用的合同模板版本号",
    )

    # ---- 乐观锁 ----
    version: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        default=1,
        comment="版本号，每次更新 +1，用于乐观并发控制",
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
        Index("ix_lease_drafts_session", "session_id"),
    )

    def __repr__(self) -> str:
        return (
            f"<LeaseDraft(id={self.id!r}, session_id={self.session_id!r}, "
            f"completeness={self.completeness_score!r})>"
        )
