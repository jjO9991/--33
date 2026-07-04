"""
SQLAlchemy 2.0 DeclarativeBase 基类。

所有 ORM 模型统一继承 ``Base``，由 ``database.py`` 中的 metadata 管理建表与迁移。
"""

from __future__ import annotations

from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    """所有 ORM 模型的统一基类。"""
