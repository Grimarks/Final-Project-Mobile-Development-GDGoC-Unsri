import re

from pydantic import BaseModel, Field, field_validator

HEX = re.compile(r"^#(?:[0-9a-fA-F]{6})$")


class CourseCreate(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    color: str = "#4C6FFF"

    @field_validator("color")
    @classmethod
    def check_hex(cls, v: str) -> str:
        if not HEX.match(v):
            raise ValueError("color harus hex 6 digit, mis. #4C6FFF")
        return v.upper()


class CourseUpdate(CourseCreate):
    pass


class CourseOut(BaseModel):
    id: int
    name: str
    color: str

    model_config = {"from_attributes": True}
