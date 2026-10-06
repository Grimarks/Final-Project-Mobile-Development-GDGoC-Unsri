import re
from datetime import date, datetime, time, timezone
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

from app.core.config import settings

_DATE_ONLY = re.compile(r"\d{4}-\d{2}-\d{2}")


class PlanRequest(BaseModel):
    available_hours: float = Field(default=3.5, ge=0.5, le=16)
    start_hour: int = Field(default=9, ge=0, le=23)
    start_minute: int = Field(default=0, ge=0, le=59)
    preference: str | None = Field(default=None, max_length=300)


class RandomPlanRequest(BaseModel):
    available_hours: float = Field(default=2, ge=0.5, le=16)


class PlanBlock(BaseModel):
    """Satu blok jadwal — ini yg divalidasi dari respons LLM."""

    task_id: int | None = None
    title: str
    course: str | None = None
    color: str = "#4C6FFF"
    start_time: str  # "09:00"
    end_time: str  # "10:30"
    duration_minutes: int = Field(ge=5, le=480)
    reason: str | None = None


class PlanResponse(BaseModel):
    # "random" = opsi random plan, diacak kode (bukan dari task yg udah ada)
    generated_by: Literal["groq", "heuristic", "random"]
    available_hours: float
    open_task_count: int
    blocks: list[PlanBlock]
    # rentang waktu luang yg dipake nyusun jadwal ("10:00"-"13:00"). plan lama
    # di DB belom punya field ini, makanya boleh None
    start_time: str | None = None
    end_time: str | None = None
    # id baris ai_generated-nya, biar accept nembak plan yg lagi diliat user
    plan_id: int | None = None
    accepted: bool = False
    plan_date: str | None = None  # YYYY-MM-DD, diisi pas di-accept
    accepted_at: str | None = None  # ISO datetime, buat nentuin plan hari ini yg terbaru


class SummaryResponse(BaseModel):
    generated_by: Literal["groq", "heuristic"]
    material_id: int
    summary: str
    key_points: list[str]


class QuizQuestion(BaseModel):
    question: str
    options: list[str] = Field(min_length=2, max_length=5)
    correct_index: int = Field(ge=0, le=4)
    explanation: str | None = None

    @model_validator(mode="after")
    def _correct_index_in_options(self) -> "QuizQuestion":
        # LLM kadang ngasih index 4 padahal opsinya cuma 4 -> gak ada jawaban yg bener
        if self.correct_index >= len(self.options):
            raise ValueError("correct_index di luar jumlah opsi")
        return self


class QuizResponse(BaseModel):
    generated_by: Literal["groq", "heuristic"]
    material_id: int
    questions: list[QuizQuestion]


class ChatMessageIn(BaseModel):
    message: str = Field(min_length=1, max_length=2000)


class ChatMessageOut(BaseModel):
    role: Literal["user", "assistant"]
    content: str
    created_at: datetime

    model_config = {"from_attributes": True}


class ChatReplyResponse(BaseModel):
    reply: str
    generated_by: Literal["groq", "heuristic"]


class AdjustRequest(BaseModel):
    instruction: str = Field(min_length=1, max_length=500)


class AdjustPlanResponse(PlanResponse):
    """PlanResponse + status adjust. Kalo `adjusted` False, `blocks` itu plan LAMA."""

    adjusted: bool
    error: str | None = None


class TaskCandidate(BaseModel):
    """Task/course usulan AI dari chat — belom tersimpen sampe dikonfirmasi user."""

    course: str = Field(min_length=1, max_length=150)
    title: str = Field(min_length=1, max_length=200)
    type: Literal["assignment", "exam", "quiz"] = "assignment"
    difficulty: Literal["easy", "medium", "hard"] = "medium"
    due_date: datetime | None = None

    @field_validator("due_date", mode="before")
    @classmethod
    def _date_only_is_end_of_local_day(cls, value: object) -> object:
        # AI ngasih "YYYY-MM-DD" polos. kalo dibiarin jadi 00:00 UTC = jam 7 pagi WIB,
        # task-nya udah "overdue" dari pagi. deadline tanggal doang = akhir hari itu
        if isinstance(value, str) and _DATE_ONLY.fullmatch(value.strip()):
            day = date.fromisoformat(value.strip())
            local = datetime.combine(day, time(23, 59), tzinfo=settings.tz)
            return local.astimezone(timezone.utc)
        return value


class ExtractTasksResponse(BaseModel):
    tasks: list[TaskCandidate]


class SnapVoiceResponse(ExtractTasksResponse):
    """Input suara: transkrip Whisper-nya ikut dibalikin biar user liat AI dengernya apa."""

    transcript: str


class ConfirmTasksRequest(BaseModel):
    tasks: list[TaskCandidate] = Field(min_length=1, max_length=20)
