from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

Feedback = Literal["easy", "normal", "hard"]


class StudySessionCreate(BaseModel):
    task_id: int | None = None
    planned_start: datetime | None = None
    planned_end: datetime | None = None


class StudySessionComplete(BaseModel):
    feedback: Feedback
    actual_duration: int | None = Field(default=None, ge=0, le=600)


class StudySessionOut(BaseModel):
    id: int
    task_id: int | None
    planned_start: datetime | None
    planned_end: datetime | None
    actual_duration: int | None
    completed: bool
    feedback: Feedback | None

    model_config = {"from_attributes": True}
