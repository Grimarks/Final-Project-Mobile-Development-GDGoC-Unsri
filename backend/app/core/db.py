"""Engine + session factory SQLAlchemy async."""
from collections.abc import AsyncGenerator
from datetime import datetime, timezone

from sqlalchemy import DateTime
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.types import TypeDecorator

from app.core.config import settings


class Base(DeclarativeBase):
    """Base class untuk semua model ORM."""


class UtcDateTime(TypeDecorator):
    """DateTime yg selalu UTC + ada zona waktunya, di database mana pun.

    SQLite gak punya tipe timestamp ber-zona: jam dari "...+07:00" disimpen apa
    adanya & zonanya dibuang, pas dibaca jadi naive. App di HP lalu nganggep jam
    naive itu jam lokal -> deadline geser 7 jam. Di sini semua dinormalisasi ke
    UTC pas nyimpen, dan dikasih tzinfo UTC lagi pas dibaca."""

    impl = DateTime(timezone=True)
    cache_ok = True

    def process_bind_param(self, value: datetime | None, dialect) -> datetime | None:
        if value is None:
            return None
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)  # naive dianggap udah UTC
        return value.astimezone(timezone.utc)

    def process_result_value(self, value: datetime | None, dialect) -> datetime | None:
        if value is None:
            return None
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)


engine = create_async_engine(settings.database_url, echo=False, future=True)
SessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency: satu session per request, auto-close."""
    async with SessionLocal() as session:
        yield session
