"""Urusan password (bcrypt) sama JWT (access + refresh)."""
from datetime import datetime, timedelta, timezone
from typing import Any, Literal

import bcrypt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.db import get_db
from app.models.user import User

bearer_scheme = HTTPBearer(auto_error=False)

TokenType = Literal["access", "refresh"]


def hash_password(plain: str) -> str:
    """Bcrypt, salt auto tiap kali hash."""
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))
    except ValueError:
        return False  # hash-nya rusak/formatnya aneh


def _create_token(subject: str, token_type: TokenType, expires: timedelta) -> str:
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": subject,
        "type": token_type,
        "iat": int(now.timestamp()),
        "exp": int((now + expires).timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_access_token(user_id: int) -> str:
    return _create_token(
        str(user_id), "access", timedelta(minutes=settings.jwt_access_expire_minutes)
    )


def create_refresh_token(user_id: int) -> str:
    return _create_token(
        str(user_id), "refresh", timedelta(days=settings.jwt_refresh_expire_days)
    )


def decode_token(token: str, expected_type: TokenType) -> int:
    """Cek signature + expiry + tipe token, balikin user id."""
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token tidak valid atau sudah kedaluwarsa",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(
            token, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
    except JWTError as exc:  # salah/expired/rusak, pokoknya gak valid
        raise credentials_error from exc

    if payload.get("type") != expected_type:
        raise credentials_error
    subject = payload.get("sub")
    if subject is None:
        raise credentials_error
    try:
        return int(subject)
    except (TypeError, ValueError) as exc:
        raise credentials_error from exc


async def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Dependency buat route yang butuh login — header Authorization: Bearer <token>."""
    if creds is None or creds.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Butuh header Authorization: Bearer <token>",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id = decode_token(creds.credentials, "access")
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="User tidak ditemukan"
        )
    return user
