from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_user,
    hash_password,
    verify_password,
)
from app.models.user import User
from app.schemas.auth import (
    AuthResponse,
    ChangePasswordRequest,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    TokenPair,
    UpdateProfileRequest,
    UserOut,
)

router = APIRouter(prefix="/auth", tags=["auth"])


def _tokens(user: User) -> TokenPair:
    return TokenPair(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
    )


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(body: RegisterRequest, db: AsyncSession = Depends(get_db)):
    existing = (
        await db.execute(select(User).where(User.email == body.email.lower()))
    ).scalar_one_or_none()
    if existing:
        raise HTTPException(status.HTTP_409_CONFLICT, "Email sudah terdaftar")

    user = User(
        email=body.email.lower(),
        name=body.name,
        password_hash=hash_password(body.password),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return AuthResponse(user=UserOut.model_validate(user), tokens=_tokens(user))


@router.post("/login", response_model=AuthResponse)
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db)):
    user = (
        await db.execute(select(User).where(User.email == body.email.lower()))
    ).scalar_one_or_none()
    # pesan error disamain aja, biar gak ketauan email mana yg kedaftar
    if user is None or not verify_password(body.password, user.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Email atau password salah")
    return AuthResponse(user=UserOut.model_validate(user), tokens=_tokens(user))


@router.post("/refresh", response_model=TokenPair)
async def refresh(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    user_id = decode_token(body.refresh_token, "refresh")
    user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User tidak ditemukan")
    return _tokens(user)


@router.get("/me", response_model=UserOut)
async def get_me(user: User = Depends(get_current_user)):
    """Cek token tersimpan masih valid + ambil user-nya — dipake buat restore sesi
    (misal abis Face ID) tanpa isi password lagi."""
    return UserOut.model_validate(user)


@router.put("/me", response_model=UserOut)
async def update_me(
    body: UpdateProfileRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.email is not None:
        normalized = body.email.lower()
        if normalized != user.email:
            existing = (
                await db.execute(select(User).where(User.email == normalized))
            ).scalar_one_or_none()
            if existing is not None:
                raise HTTPException(status.HTTP_409_CONFLICT, "Email sudah dipakai akun lain")
            user.email = normalized
    user.name = body.name
    await db.commit()
    await db.refresh(user)
    return UserOut.model_validate(user)


@router.post("/change-password", status_code=status.HTTP_204_NO_CONTENT)
async def change_password(
    body: ChangePasswordRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not verify_password(body.current_password, user.password_hash):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Password lama salah")
    user.password_hash = hash_password(body.new_password)
    await db.commit()
