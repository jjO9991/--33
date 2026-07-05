"""
合同审查相关 Schema。

提供给 reviews router 的入参与回参，
与 lease_reviews 模型 + review_items_json / summary_json 结构对齐。
"""

from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict, Field, model_validator

RiskLevel = Literal["red", "yellow", "green"]
UserRole = Literal["tenant", "landlord", "neutral"]
SourceType = Literal["law", "regulation", "judicial_interpretation", "standard_contract"]


# ---- 子结构 ----

class Citation(BaseModel):
    """法条 / 司法解释 / 规范合同引用。"""

    source_type: SourceType = Field(
        ...,
        description="引用来源类型：law 法律 / regulation 行政法规 / judicial_interpretation 司法解释 / standard_contract 规范合同",
    )
    title: str = Field(..., description="引用标题，如「民法典 第 710 条」")
    url_or_ref: str = Field(..., description="原文链接或文献出处")
    verified: bool = Field(False, description="是否已通过法条校验")


class HighlightRange(BaseModel):
    """风险条款在原文中的定位。"""

    start: int = Field(..., ge=0, description="起始字符偏移（含）")
    end: int = Field(..., ge=0, description="结束字符偏移（不含）")


class RiskCard(BaseModel):
    """一条风险卡片。"""

    risk_id: str = Field(..., description="风险唯一 ID")
    level: RiskLevel = Field(..., description="风险等级：red / yellow / green")
    type: str = Field(
        ...,
        description="风险类型编码",
        examples=["deposit_refund", "rent_increase", "lease_renewal", "maintenance"],
    )
    title: str = Field(..., description="风险标题")
    quote: str = Field(..., description="合同原文引用")
    plain_explanation: str = Field(..., description="白话解释，普通用户也能读懂")
    suggested_revision: str = Field(..., description="建议改法")
    citations: list[Citation] = Field(default_factory=list, description="相关法条引用")
    highlight_range: HighlightRange = Field(..., description="风险条款在原文中的定位")
    needs_lawyer: bool = Field(
        False,
        description="是否超出 AI 能力、需要执业律师介入",
    )


class ReviewSummary(BaseModel):
    """审查结果统计摘要。"""

    total_risks: int = Field(..., ge=0, description="总风险数")
    red_count: int = Field(..., ge=0, description="红色（严重）风险数")
    yellow_count: int = Field(..., ge=0, description="黄色（注意）风险数")
    green_count: int = Field(..., ge=0, description="绿色（提示）风险数")
    suggestion: str = Field(
        ...,
        description="给用户的整体建议，如「建议先谈 3 处再签」",
    )


# ---- 请求 / 回参 ----

class ReviewAnalyzeRequest(BaseModel):
    """POST /api/v1/reviews/analyze 请求体。"""

    session_id: str = Field(..., description="所属会话 ID")
    user_role: UserRole = Field(
        ...,
        description="用户立场：tenant（承租方）/ landlord（出租方）/ neutral（中立）",
    )
    file_id: Optional[str] = Field(None, description="文件 ID（来源为上传时提供）")
    text: Optional[str] = Field(None, description="粘贴的合同文本（来源为粘贴时提供）")

    @model_validator(mode="after")
    def _check_source(self) -> "ReviewAnalyzeRequest":
        if self.file_id is None and not self.text:
            raise ValueError("file_id 和 text 至少提供一个")
        return self


class ReviewAnalyzeResponse(BaseModel):
    """审查分析回参。"""

    model_config = ConfigDict(from_attributes=True)

    session_id: str = Field(..., description="所属会话 ID")
    status: str = Field(..., description="审查状态：created / processing / completed / failed")
    summary: ReviewSummary = Field(..., description="审查摘要统计")
    risks: list[RiskCard] = Field(default_factory=list, description="风险卡片列表")
