"""Config app, ambil dari env / file .env."""
from functools import lru_cache
from zoneinfo import ZoneInfo

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "CampusFlow API"
    database_url: str = "sqlite+aiosqlite:///./campusflow.db"

    jwt_secret: str = "dev-secret-change-me"
    jwt_algorithm: str = "HS256"
    jwt_access_expire_minutes: int = 30
    jwt_refresh_expire_days: int = 7

    groq_api_key: str | None = None
    groq_model: str = "openai/gpt-oss-120b"
    # model yg bisa baca gambar, buat Snap & Go (foto pengumuman tugas)
    groq_vision_model: str = "qwen/qwen3.8-27b"
    # speech-to-text buat input suara (v3 biasa lebih akurat buat bahasa Indonesia
    # drpd turbo — "bab" gak jadi "BAP")
    groq_whisper_model: str = "whisper-large-v3"
    groq_base_url: str = "https://api.groq.com/openai/v1"

    cors_origins: str = "*"

    # zona waktu mahasiswa — buat ngartiin tanggal polos dari AI ("besok", "2026-10-07")
    app_timezone: str = "Asia/Jakarta"

    @property
    def groq_enabled(self) -> bool:
        return bool(self.groq_api_key)

    @property
    def tz(self) -> ZoneInfo:
        return ZoneInfo(self.app_timezone)


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
