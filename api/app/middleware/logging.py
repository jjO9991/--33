"""
请求日志中间件。

- 生成 X-Request-ID，注入响应头
- 记录 method / path / status / duration
- /health 路由降为 debug 级别
- 严禁记录 body、Authorization、Cookie 等敏感信息
"""

from __future__ import annotations

import logging
import time
import uuid

from fastapi import FastAPI, Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

logger = logging.getLogger("qh.api")

_HEALTH_PREFIXES = ("/health", "/health/ready")


class _LoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = uuid.uuid4().hex
        method = request.method
        path = request.url.path

        start = time.perf_counter()
        response = await call_next(request)
        duration_ms = round((time.perf_counter() - start) * 1000, 2)

        response.headers["X-Request-ID"] = request_id

        if path.startswith(_HEALTH_PREFIXES):
            logger.debug("[%s] %s %s → %s (%sms)", request_id, method, path, response.status_code, duration_ms)
        else:
            logger.info("[%s] %s %s → %s (%sms)", request_id, method, path, response.status_code, duration_ms)

        return response


def add_logging_middleware(app: FastAPI) -> None:
    """注册请求日志中间件。"""
    app.add_middleware(_LoggingMiddleware)
