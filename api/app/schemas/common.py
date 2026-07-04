"""
通用响应 Schema。

所有 API 响应统一包装为 ApiResponse / PaginatedResponse，
错误场景使用 ErrorResponse，便于前端统一处理。
"""

from typing import Generic, Optional, TypeVar

from pydantic import BaseModel, Field

T = TypeVar("T")


class ApiResponse(BaseModel, Generic[T]):
    """通用 API 响应包装。"""

    code: int = Field(0, description="业务状态码，0 表示成功")
    message: str = Field("ok", description="提示信息")
    data: Optional[T] = Field(None, description="业务数据载荷")


class ErrorResponse(BaseModel):
    """错误响应。"""

    code: int = Field(..., description="错误码，非 0")
    message: str = Field(..., description="用户可读的中文错误信息")
    detail: Optional[str] = Field(
        None,
        description="调试详情，仅开发环境返回，不得包含合同正文等敏感数据",
    )


class PaginatedResponse(BaseModel, Generic[T]):
    """分页响应。"""

    items: list[T] = Field(default_factory=list, description="当前页数据")
    total: int = Field(0, description="总记录数")
    page: int = Field(1, ge=1, description="当前页码，从 1 开始")
    page_size: int = Field(20, ge=1, le=100, description="每页条数")
