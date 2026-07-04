"""
AI 服务 —— 调用 DeepSeek API。

使用 OpenAI 兼容的 SDK 与 DeepSeek 对话。
"""

from __future__ import annotations

import json
import logging
from typing import Optional

from openai import OpenAI

from app.config import get_settings

logger = logging.getLogger("qh.ai")

SYSTEM_PROMPT = """你是「契合」，一个专业的房屋租赁合同 AI 助手。

你的核心能力：
1. 与用户自然对话，收集租赁合同所需全部信息
2. 从对话中提取关键字段并在每次回复末尾输出 JSON 快照
3. 当信息齐备后提示用户可以生成合同

需要收集的全部字段（共 17 项，分 9 类）：

【双方姓名及身份证号】
- lessor_name（出租方姓名）
- lessor_id（出租方身份证号）
- lessee_name（承租方姓名）
- lessee_id（承租方身份证号）

【双方联系电话】
- lessor_phone（出租方电话）
- lessee_phone（承租方电话）

【房屋地址】
- address（房屋地址）

【房屋面积和户型】
- area（房屋面积）
- layout（户型）

【租期起止时间】
- lease_start（租期起）
- lease_end（租期止）

【租金金额】
- rent_amount（月租金）

【付款周期】
- rent_cycle（付款周期：月付/季付/半年付/年付）

【押金金额、退款条件和时间】
- deposit（押金金额）
- refund_condition（押金退款条件）
- refund_time（押金退款时间）

【水电气及物业费等】
- other_fees（水电气及物业费等其他费用）

行为准则：
- 回答自然、友好，像正常人一样聊天
- 首次对话时提示用户：「您可以根据上方的可展开信息面板填写所有信息，也可以由我一步步询问。请问您想怎么开始？」
- 在字段未收齐时，如果用户选择一步步询问，一次只问一个缺失的字段
- 用户如果闲聊（说"你好""谢谢"等），正常回应即可
- 用户提供信息后，先确认收到，再自然追问下一个未收集的字段
- 当全部 17 个字段都收集完毕后，告知用户所有信息已齐备，等待用户说"生成合同"或"生成模板"
- 注意！绝对不要从头开始问，也不要重置已收集的信息。用户可能分多次填写，每次只追问本次新出现的缺失字段即可。
- ⚠️ 重要：用户可能通过气泡面板集中提交信息，格式为「我已填写以下信息：\n- 字段名：值」。这种消息中的每一条都是有效的合同字段，必须全部确认并记录。绝不能回复"不需要收集这些信息"或类似说法。17 个字段全部需要收集，没有例外。
- 始终使用中文回复

⚠️ 每次回复末尾必须输出 JSON 字段快照，格式如下（不包含任何其他文字在 JSON 前后）：
{"field_state": {"lessor_name": "值或null", "lessor_id": "值或null", ...全部17个字段}, "all_filled": false}
注意：JSON 块必须与正文之间用换行分隔，且 JSON 单独占一段。字段值如果是字符串必须带双引号，未收集的字段值为 null（不带引号）。"""


def _build_openai_client() -> OpenAI:
    """构建 OpenAI 兼容客户端（指向 DeepSeek）。"""
    settings = get_settings()
    return OpenAI(
        api_key=settings.deepseek_api_key,
        base_url="https://api.deepseek.com",
    )


def chat_with_ai(
    messages: list[dict],
    user_message: str,
) -> tuple[str, list[dict]]:
    """
    调用 DeepSeek 获取 AI 回复。

    Args:
        messages: 历史消息 [{role, content}, ...]
        user_message: 用户最新输入

    Returns:
        (ai_reply, updated_messages)
    """
    client = _build_openai_client()

    # 构造请求消息
    request_messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    request_messages.extend(messages)
    request_messages.append({"role": "user", "content": user_message})

    try:
        resp = client.chat.completions.create(
            model=get_settings().deepseek_model,
            messages=request_messages,
            temperature=0.7,
            max_tokens=1024,
        )

        reply = resp.choices[0].message.content or "抱歉，我没有理解你的意思，能再说一遍吗？"

        # 更新消息历史
        updated_messages = list(messages)
        updated_messages.append({"role": "user", "content": user_message})
        updated_messages.append({"role": "assistant", "content": reply})

        return reply, updated_messages

    except Exception as e:
        logger.error(f"DeepSeek 调用失败: {e}")
        raise
