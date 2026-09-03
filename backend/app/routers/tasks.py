from datetime import datetime, time, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.db import get_db
from app.core.security import get_current_user
from app.models.course import Course
from app.models.task import Task
from app.models.user import User
from app.schemas.task import TaskCreate, TaskOut, TaskUpdate
from app.services.planning_service import priority_label, priority_score

router = APIRouter(prefix="/tasks", tags=["tasks"])


def to_out(task: Task) -> TaskOut:
    """Model DB -> response, sekalian itung label prioritasnya."""
    score = priority_score(task)
    return TaskOut(
        id=task.id,
        title=task.title,
        course_id=task.course_id,
        course_name=task.course.name if task.course else None,
        course_color=task.course.color if task.course else None,
        type=task.type,
        due_date=task.due_date,
        difficulty=task.difficulty,
        status=task.status,
        progress_pct=task.progress_pct,
        priority=priority_label(score),
    )


async def _load_tasks(db: AsyncSession, user_id: int) -> list[Task]:
    rows = (
        await db.execute(
            select(Task)
            .options(selectinload(Task.course))
            .where(Task.user_id == user_id)
            .order_by(Task.id)
        )
    ).scalars().all()
    return list(rows)


async def _get_owned(task_id: int, user: User, db: AsyncSession) -> Task:
    task = (
        await db.execute(
            select(Task)
            .options(selectinload(Task.course))
            .where(Task.id == task_id, Task.user_id == user.id)
        )
    ).scalar_one_or_none()
    if task is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Task tidak ditemukan")
    return task


async def _check_course(course_id: int | None, user: User, db: AsyncSession) -> None:
    if course_id is None:
        return
    owned = (
        await db.execute(
            select(Course.id).where(Course.id == course_id, Course.user_id == user.id)
        )
    ).scalar_one_or_none()
    if owned is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Course tidak ditemukan")


@router.get("", response_model=list[TaskOut])
async def list_tasks(
    status_filter: str | None = Query(default=None, alias="status"),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    tasks = await _load_tasks(db, user.id)
    if status_filter:
        tasks = [t for t in tasks if t.status == status_filter]
    return [to_out(t) for t in tasks]


@router.get("/today", response_model=list[TaskOut])
async def tasks_today(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    """Task yg belom kelar & deadline-nya hari ini atau udah lewat."""
    tasks = await _load_tasks(db, user.id)
    end_of_day = datetime.combine(datetime.now(timezone.utc).date(), time.max, timezone.utc)
    result = []
    for t in tasks:
        if t.status == "done" or t.due_date is None:
            continue
        due = t.due_date if t.due_date.tzinfo else t.due_date.replace(tzinfo=timezone.utc)
        if due <= end_of_day:
            result.append(t)
    result.sort(key=priority_score, reverse=True)
    return [to_out(t) for t in result]


@router.post("", response_model=TaskOut, status_code=status.HTTP_201_CREATED)
async def create_task(
    body: TaskCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await _check_course(body.course_id, user, db)
    task = Task(user_id=user.id, **body.model_dump())
    db.add(task)
    await db.commit()
    return to_out(await _get_owned(task.id, user, db))


@router.put("/{task_id}", response_model=TaskOut)
async def update_task(
    task_id: int,
    body: TaskUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    task = await _get_owned(task_id, user, db)
    patch = body.model_dump(exclude_unset=True)
    if "course_id" in patch:
        await _check_course(patch["course_id"], user, db)
    for field, value in patch.items():
        setattr(task, field, value)
    if task.status == "done":
        task.progress_pct = 100
    await db.commit()
    return to_out(await _get_owned(task_id, user, db))


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_task(
    task_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    task = await _get_owned(task_id, user, db)
    await db.delete(task)
    await db.commit()
