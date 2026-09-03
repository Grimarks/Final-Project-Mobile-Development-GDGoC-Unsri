from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base

TASK_TYPES = ("assignment", "exam", "quiz")
DIFFICULTIES = ("easy", "medium", "hard")
STATUSES = ("not_started", "in_progress", "done")


class Task(Base):
    __tablename__ = "tasks"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    course_id: Mapped[int | None] = mapped_column(
        ForeignKey("courses.id", ondelete="SET NULL"), nullable=True, index=True
    )

    title: Mapped[str] = mapped_column(String(200))
    type: Mapped[str] = mapped_column(String(20), default="assignment")
    due_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    difficulty: Mapped[str] = mapped_column(String(10), default="medium")
    status: Mapped[str] = mapped_column(String(20), default="not_started")
    progress_pct: Mapped[int] = mapped_column(Integer, default=0)

    user = relationship("User", back_populates="tasks")
    course = relationship("Course", back_populates="tasks")
