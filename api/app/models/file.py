"""
文件 ORM 模型。

记录用户上传或系统生成的文件元信息，
storage_key 指向本地磁盘或对象存储的实际位置。
"""

import uuid
from datetime import datetime, timezone
from typing import Literal, Optional

from sqlalchemy import String, Integer, DateTime, Index
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base

FileType = Literal[
    "image", "pdf", "docx", "txt",
    "export_pdf", "export_docx",
]


def _uuid4_hex() -> str:
    return uuid.uuid4().hex


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class File(Base):
    """上传或生成的文件元信息。"""

    __tablename__ = "files"

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

    session_id: Mapped[str] = mapped_column(
        String(36),
        nullable=False,
        index=True,
        comment="所属会话 ID",
    )

    # ---- 业务属性 ----
    type: Mapped[FileType] = mapped_column(
        String(20),
        nullable=False,
        index=True,
        comment="文件类型：image / pdf / docx / txt / export_pdf / export_docx",
    )

    storage_key: Mapped[str] = mapped_column(
        String(512),
        nullable=False,
        comment="本地文件路径或对象存储 key",
    )

    original_name: Mapped[Optional[str]] = mapped_column(
        String(256),
        nullable=True,
        comment="上传时的原始文件名",
    )

    sha256: Mapped[str] = mapped_column(
        String(64),
        nullable=False,
        comment="文件 SHA-256 哈希，用于去重与完整性校验",
    )

    size_bytes: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        comment="文件大小（字节）",
    )

    mime_type: Mapped[Optional[str]] = mapped_column(
        String(128),
        nullable=True,
        comment="MIME 类型，如 image/png、application/pdf",
    )

    retention_until: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="文件保留截止时间，到期可由清理任务删除",
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
        Index("ix_files_session_created", "session_id", "created_at"),
        Index("ix_files_sha256", "sha256"),
    )

    def __repr__(self) -> str:
        return (
            f"<File(id={self.id!r}, type={self.type!r}, "
            f"session_id={self.session_id!r})>"
        )
