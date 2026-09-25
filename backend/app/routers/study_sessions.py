from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import get_current_user
from app.models.study_session import StudySession
from app.models.task import Task
from app.models.user import User
from app.schemas.study_session import (
    StudySessionComplete,
    StudySessionCreate,
    StudySessionOut,
)

router = APIRouter(prefix="/study-sessions", tags=["study-sessions"])


@router.get("", response_model=list[StudySessionOut])
async def list_sessions(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    rows = (
        await db.execute(
            select(StudySession)
            .where(StudySession.user_id == user.id)
            .order_by(StudySession.id.desc())
        )
    ).scalars().all()
    return list(rows)


@router.post("", response_model=StudySessionOut, status_code=status.HTTP_201_CREATED)
async def create_session(
    body: StudySessionCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.task_id is not None:
        # jangan sampe sesi nempel ke task punya user lain
        owned = (
            await db.execute(
                select(Task.id).where(Task.id == body.task_id, Task.user_id == user.id)
            )
        ).scalar_one_or_none()
        if owned is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Task tidak ditemukan")
    session = StudySession(user_id=user.id, **body.model_dump())
    db.add(session)
    await db.commit()
    await db.refresh(session)
    return session


@router.patch("/{session_id}/complete", response_model=StudySessionOut)
async def complete_session(
    session_id: int,
    body: StudySessionComplete,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Tutup sesi pomodoro + simpen feedback-nya (easy/normal/hard) — ini yang
    dibaca planner buat nyesuain estimasi durasi ke kebiasaan belajar user."""
    session = (
        await db.execute(
            select(StudySession).where(
                StudySession.id == session_id, StudySession.user_id == user.id
            )
        )
    ).scalar_one_or_none()
    if session is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Sesi tidak ditemukan")

    session.completed = True
    session.feedback = body.feedback
    if body.actual_duration is not None:
        session.actual_duration = body.actual_duration
    await db.commit()
    await db.refresh(session)
    return session
