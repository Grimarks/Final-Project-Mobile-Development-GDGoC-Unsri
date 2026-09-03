"""Fixture pytest: DB SQLite in-memory per test + client HTTP async yang sudah login."""
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")
os.environ.setdefault("JWT_SECRET", "test-secret")
os.environ.setdefault("GROQ_API_KEY", "")  # paksa jalur heuristik saat test

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.core.db import Base, get_db
from app.main import app


@pytest_asyncio.fixture
async def db_session():
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    maker = async_sessionmaker(engine, expire_on_commit=False)
    async with maker() as session:
        yield session
    await engine.dispose()


@pytest_asyncio.fixture
async def client(db_session):
    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def auth_client(client):
    """Client yang sudah terdaftar + membawa header Authorization."""
    resp = await client.post(
        "/auth/register",
        json={"name": "Rel", "email": "rel@unsri.ac.id", "password": "Password123!"},
    )
    assert resp.status_code == 201, resp.text
    token = resp.json()["tokens"]["access_token"]
    client.headers["Authorization"] = f"Bearer {token}"
    return client


@pytest.fixture
def anyio_backend():
    return "asyncio"
