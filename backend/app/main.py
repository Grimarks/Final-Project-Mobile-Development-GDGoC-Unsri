"""Entry point FastAPI-nya CampusFlow."""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import DEFAULT_JWT_SECRET, settings
from app.core.db import Base, engine
from app.models import *  # noqa: F401,F403  (biar model ke-registrasi ke metadata)
from app.routers import ai, auth, courses, materials, study_sessions, tasks

logging.basicConfig(level=logging.INFO)

@asynccontextmanager
async def lifespan(_: FastAPI):
    """Dev/SQLite doang: bikin tabel otomatis. Kalo produksi pake `alembic upgrade head`."""
    if not settings.is_sqlite and settings.jwt_secret == DEFAULT_JWT_SECRET:
        # secret default = siapa aja bisa bikin token login akun orang
        raise RuntimeError("JWT_SECRET wajib diisi string acak sebelum jalan di server")
    if settings.is_sqlite:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    yield


app = FastAPI(
    lifespan=lifespan,
    title=settings.app_name,
    version="1.0.0",
    description="REST API untuk CampusFlow — AI academic life manager.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[o.strip() for o in settings.cors_origins.split(",")],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(courses.router)
app.include_router(tasks.router)
app.include_router(study_sessions.router)
app.include_router(materials.router)
app.include_router(ai.router)


@app.get("/health", tags=["meta"])
async def health() -> dict[str, object]:
    return {"status": "ok", "ai_provider": "groq" if settings.groq_enabled else "heuristic"}
