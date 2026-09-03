from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

TaskType = Literal["assignment", "exam", "quiz"]
Difficulty = Literal["easy", "medium", "hard"]
Status = Literal["not_started", "in_progress", "done"]


class TaskCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    course_id: int | None = None
    type: TaskType = "assignment"
    due_date: datetime | None = None
    difficulty: Difficulty = "medium"
    status: Status = "not_started"
    progress_pct: int = Field(default=0, ge=0, le=100)


class TaskUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    course_id: int | None = None
    type: TaskType | None = None
    due_date: datetime | None = None
    difficulty: Difficulty | None = None
    status: Status | None = None
    progress_pct: int | None = Field(default=None, ge=0, le=100)


class TaskOut(BaseModel):
    id: int
    title: str
    course_id: int | None
    course_name: str | None = None
    course_color: str | None = None
    type: TaskType
    due_date: datetime | None
    difficulty: Difficulty
    status: Status
    progress_pct: int
    priority: Literal["low", "medium", "high"]

    model_config = {"from_attributes": True}
