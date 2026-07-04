"""
契合 API — FastAPI 启动入口。
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.database import engine
from app.middleware.logging import add_logging_middleware
from app.models import Base
from app.routers import files, health, sessions

settings = get_settings()

logging.basicConfig(
    level=getattr(logging, settings.log_level.upper(), logging.INFO),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("qh.api")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """启动时确保目录 + 数据库表就绪。"""
    # 创建必要目录
    Path(settings.upload_dir).mkdir(parents=True, exist_ok=True)
    Path("./data").mkdir(parents=True, exist_ok=True)

    # 自动建表（MVP 阶段，生产环境请改用 Alembic）
    Base.metadata.create_all(bind=engine)
    logger.info("契合 API 启动完成")
    yield
    logger.info("契合 API 已关闭")


def create_app() -> FastAPI:
    app = FastAPI(
        title="契合 API",
        description="租赁合同 AI 辅助工具 — 后端 API",
        version="0.1.0",
        docs_url="/docs",
        lifespan=lifespan,
    )

    # CORS — 开发阶段允许所有来源，生产须收窄
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # 请求日志
    add_logging_middleware(app)

    # 路由
    app.include_router(health.router)
    app.include_router(sessions.router)
    app.include_router(files.router)

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
