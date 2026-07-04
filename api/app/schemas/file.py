"""
文件相关 Schema。

提供给 files router 的入参与回参。
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field


# ---- POST /api/v1/sessions/{session_id}/files ----

class FileUploadResponse(BaseModel):
    """文件上传成功回参。"""

    file_id: str = Field(..., description="文件 ID")
    original_name: Optional[str] = Field(None, description="原始文件名")
    sha256: str = Field(..., description="SHA-256 哈希")
    size_bytes: int = Field(..., description="文件大小（字节）")
    mime_type: Optional[str] = Field(None, description="MIME 类型")


# ---- GET /api/v1/sessions/{session_id}/files ----

class FileResponse(BaseModel):
    """文件详情回参。"""

    model_config = ConfigDict(from_attributes=True)

    id: str
    session_id: str
    type: str
    original_name: Optional[str]
    sha256: str
    size_bytes: int
    mime_type: Optional[str]
    created_at: datetime


# ---- 上传失败时的错误 ----

class FileUploadError(BaseModel):
    """文件上传错误信息。"""

    code: int = Field(..., description="错误码，如 40001")
    message: str = Field(
        ...,
        description="用户可读的中文错误信息，前端可直接展示",
        examples=[
            "文件过大，最大支持 20MB",
            "不支持的文件类型，仅支持 PDF/DOCX/TXT/图片",
            "文件内容检测不通过，请确认上传的是合同文件",
        ],
    )
