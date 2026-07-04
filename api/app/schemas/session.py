"""
会话相关 Schema。

提供给 sessions router 的入参与回参。
"""

from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field

SessionType = Literal["draft", "review"]
SessionStatus = Literal["processing", "completed", "failed"]


class SessionCreateRequest(BaseModel):
    """POST /api/v1/sessions 请求体。"""

    device_id: str = Field(..., description="设备指纹，用于匿名用户追踪")
    type: SessionType = Field(..., description="会话类型：draft（拟定）/ review（审核）")


class SessionResponse(BaseModel):
    """会话回参。"""

    model_config = ConfigDict(from_attributes=True)

    id: str
    device_id: str
    type: str
    status: str
    error_message: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class SessionStatusUpdateRequest(BaseModel):
    """PATCH /api/v1/sessions/{id} 请求体。"""

    status: SessionStatus = Field(
        ...,
        description="会话状态：processing / completed / failed",
    )
    error_message: Optional[str] = Field(
        None,
        description="失败时的错误信息",
    )
