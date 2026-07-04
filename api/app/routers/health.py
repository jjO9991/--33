"""
健康检查路由。

GET /health       — 基础存活探针，不依赖数据库
GET /health/ready — 就绪探针，检测数据库连通性
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session as ORMSession

from app.database import get_db

router = APIRouter(tags=["health"])

_VERSION = "0.1.0"
_SERVICE = "契合 API"


@router.get("/health")
def health() -> dict:
    """基础存活探针。"""
    return {"status": "ok", "version": _VERSION, "service": _SERVICE}


@router.get("/health/ready")
def health_ready(db: ORMSession = Depends(get_db)) -> dict:
    """就绪探针，检测数据库连通性。"""
    try:
        db.execute(text("SELECT 1"))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"status": "not_ready", "database": "disconnected"},
        )
    return {"status": "ready", "database": "connected"}
