from datetime import datetime

from pydantic import BaseModel


class MaterialOut(BaseModel):
    id: int
    filename: str
    course_id: int | None
    uploaded_at: datetime
    text_length: int
    preview: str
