import re

from pydantic import BaseModel, EmailStr, Field, field_validator

_SPECIAL_CHAR = re.compile(r"[^A-Za-z0-9]")


class RegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)

    @field_validator("password")
    @classmethod
    def _password_must_be_strong(cls, value: str) -> str:
        """Kayak password mobile banking — wajib gede-kecil, angka, sama simbol."""
        if (
            not any(c.isupper() for c in value)
            or not any(c.islower() for c in value)
            or not any(c.isdigit() for c in value)
            or not _SPECIAL_CHAR.search(value)
        ):
            raise ValueError(
                "Password harus mengandung huruf besar, huruf kecil, angka, dan simbol "
                "(contoh: !@#$%)"
            )
        return value


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class UpdateProfileRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    email: EmailStr | None = None


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=128)


class TokenPair(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class UserOut(BaseModel):
    id: int
    name: str
    email: EmailStr

    model_config = {"from_attributes": True}


class AuthResponse(BaseModel):
    user: UserOut
    tokens: TokenPair
