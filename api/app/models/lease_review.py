"""
租赁合同审查 ORM 模型。

一次"审核会话"对应一条 lease_reviews 记录，
记录立场、OCR 结果、风险卡片与法条校验状态。
"""

import uuid
from datetime import datetime, timezone
from typing import Literal, Optional

from sqlalchemy import String, Float, DateTime, Text, Index
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base

UserRole = Literal["tenant", "landlord", "neutral"]
CitationStatus = Literal["verified", "partial", "failed", "pending"]


def _uuid4_hex() -> str:
    return uuid.uuid4().hex


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class LeaseReview(Base):
    """一份租赁合同审查结果。"""

    __tablename__ = "lease_reviews"

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

    # ---- 审查配置 ----
    user_role: Mapped[UserRole] = mapped_column(
        String(20),
        nullable=False,
        comment="用户立场：tenant（承租方）/ landlord（出租方）/ neutral（中立）",
    )

    # ---- OCR / 文本抽取 ----
    extracted_text_ref: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="提取的合同文本引用（敏感数据，可为外键或存储地址）",
    )

    ocr_confidence: Mapped[Optional[float]] = mapped_column(
        Float,
        nullable=True,
        comment="OCR 置信度 0.0 ~ 1.0",
    )

    # ---- 审查结果 ----
    summary_json: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="审查摘要 JSON",
    )

    risk_items_json: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
        comment="风险卡片列表 JSON（含标题、原文、解释、建议、依据）",
    )

    citation_check_status: Mapped[Optional[CitationStatus]] = mapped_column(
        String(20),
        nullable=True,
        comment="法条校验状态：verified / partial / failed / pending",
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
        Index("ix_lease_reviews_session", "session_id"),
    )

    def __repr__(self) -> str:
        return (
            f"<LeaseReview(id={self.id!r}, session_id={self.session_id!r}, "
            f"role={self.user_role!r})>"
        )
