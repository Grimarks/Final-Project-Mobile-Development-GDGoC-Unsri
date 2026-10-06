"""Config deploy: URL database dari Render/Railway dinormalisasi ke driver async."""
from app.core.config import Settings


def test_render_postgres_url_gets_async_driver():
    for raw in ("postgres://u:p@host:5432/db", "postgresql://u:p@host:5432/db"):
        settings = Settings(database_url=raw)
        assert settings.database_url == "postgresql+asyncpg://u:p@host:5432/db"
        assert not settings.is_sqlite


def test_explicit_driver_and_sqlite_untouched():
    assert (
        Settings(database_url="postgresql+asyncpg://u:p@h/db").database_url
        == "postgresql+asyncpg://u:p@h/db"
    )
    assert Settings(database_url="sqlite+aiosqlite:///./x.db").is_sqlite
