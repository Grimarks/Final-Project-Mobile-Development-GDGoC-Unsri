from datetime import datetime, timezone

from sqlalchemy import ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base, UtcDateTime


class AIGenerated(Base):
    """Simpenan output AI (plan/summary/quiz) biar bisa dimunculin lagi."""

    __tablename__ = "ai_generated"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)

    source_type: Mapped[str] = mapped_column(String(20))  # material | task_set
    source_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    type: Mapped[str] = mapped_column(String(20))  # summary | quiz | plan
    content_json: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        UtcDateTime, default=lambda: datetime.now(timezone.utc)
    )
