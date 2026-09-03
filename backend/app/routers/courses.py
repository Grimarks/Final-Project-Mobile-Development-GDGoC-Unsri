from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import get_current_user
from app.models.course import Course
from app.models.user import User
from app.schemas.course import CourseCreate, CourseOut, CourseUpdate

router = APIRouter(prefix="/courses", tags=["courses"])


async def _get_owned(course_id: int, user: User, db: AsyncSession) -> Course:
    course = (
        await db.execute(
            select(Course).where(Course.id == course_id, Course.user_id == user.id)
        )
    ).scalar_one_or_none()
    if course is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Course tidak ditemukan")
    return course


@router.get("", response_model=list[CourseOut])
async def list_courses(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    rows = (
        await db.execute(select(Course).where(Course.user_id == user.id).order_by(Course.id))
    ).scalars().all()
    return list(rows)


@router.post("", response_model=CourseOut, status_code=status.HTTP_201_CREATED)
async def create_course(
    body: CourseCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    course = Course(user_id=user.id, name=body.name, color=body.color)
    db.add(course)
    await db.commit()
    await db.refresh(course)
    return course


@router.put("/{course_id}", response_model=CourseOut)
async def update_course(
    course_id: int,
    body: CourseUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    course = await _get_owned(course_id, user, db)
    course.name = body.name
    course.color = body.color
    await db.commit()
    await db.refresh(course)
    return course


@router.delete("/{course_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_course(
    course_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    course = await _get_owned(course_id, user, db)
    await db.delete(course)
    await db.commit()
