from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


class Course(Base):
    __tablename__ = "courses"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(150))
    # hex color dari design token, mis. #4C6FFF
    color: Mapped[str] = mapped_column(String(9), default="#4C6FFF")

    user = relationship("User", back_populates="courses")
    tasks = relationship("Task", back_populates="course", cascade="all, delete-orphan")
