"""
聊天 Schema。

POST /api/v1/sessions/{session_id}/chat 的入参与回参。
"""

from typing import Optional

from pydantic import BaseModel, Field


class ChatRequest(BaseModel):
    """发送消息请求体。"""

    message: str = Field(..., min_length=1, max_length=2000, description="用户输入的消息")


class FieldInfo(BaseModel):
    """字段状态。"""

    key: str
    label: str
    value: Optional[str] = None
    is_missing: bool = True


class ChatResponse(BaseModel):
    """聊天回复。"""

    reply: str = Field(..., description="AI 的回复内容")
    fields: list[FieldInfo] = Field(..., description="当前所有字段状态")
    completeness: float = Field(..., description="完整度 0.0 ~ 1.0")
