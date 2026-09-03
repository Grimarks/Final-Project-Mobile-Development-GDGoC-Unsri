from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.db import Base


class Material(Base):
    __tablename__ = "materials"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    course_id: Mapped[int | None] = mapped_column(
        ForeignKey("courses.id", ondelete="SET NULL"), nullable=True
    )

    filename: Mapped[str] = mapped_column(String(255))
    file_url: Mapped[str] = mapped_column(String(500))
    extracted_text: Mapped[str] = mapped_column(Text, default="")
    uploaded_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
