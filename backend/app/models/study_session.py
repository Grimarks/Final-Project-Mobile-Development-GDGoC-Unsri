from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base

FEEDBACKS = ("easy", "normal", "hard")


class StudySession(Base):
    __tablename__ = "study_sessions"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    task_id: Mapped[int | None] = mapped_column(
        ForeignKey("tasks.id", ondelete="SET NULL"), nullable=True
    )

    planned_start: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    planned_end: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    actual_duration: Mapped[int | None] = mapped_column(Integer, nullable=True)  # menit
    completed: Mapped[bool] = mapped_column(Boolean, default=False)
    feedback: Mapped[str | None] = mapped_column(String(10), nullable=True)
