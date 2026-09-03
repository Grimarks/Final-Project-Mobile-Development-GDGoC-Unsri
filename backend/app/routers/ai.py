import json

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.db import get_db
from app.core.security import get_current_user
from app.models.ai_generated import AIGenerated
from app.models.chat_message import ChatMessage
from app.models.course import Course
from app.models.material import Material
from app.models.task import Task
from app.models.user import User
from app.routers.tasks import to_out as task_to_out
from app.schemas.ai import (
    AdjustPlanResponse,
    AdjustRequest,
    ChatMessageIn,
    ChatMessageOut,
    ChatReplyResponse,
    ConfirmTasksRequest,
    ExtractTasksResponse,
    PlanRequest,
    PlanResponse,
    QuizResponse,
    SummaryResponse,
)
from app.schemas.task import TaskOut
from app.services import chat_service, materials_service
from app.services.planning_service import AdjustFailed, adjust_plan, build_plan, plan_to_json

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/plan", response_model=PlanResponse)
async def plan_my_day(
    body: PlanRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Fitur utama: susun jadwal hari ini dari task yg masih kebuka."""
    tasks = list(
        (
            await db.execute(
                select(Task).options(selectinload(Task.course)).where(Task.user_id == user.id)
            )
        ).scalars().all()
    )
    plan = await build_plan(tasks, body)

    db.add(
        AIGenerated(
            user_id=user.id,
            source_type="task_set",
            source_id=None,
            type="plan",
            content_json=plan_to_json(plan),
        )
    )
    await db.commit()
    return plan


async def _get_active_plan_row(user: User, db: AsyncSession) -> AIGenerated:
    row = (
        await db.execute(
            select(AIGenerated)
            .where(AIGenerated.user_id == user.id, AIGenerated.type == "plan")
            .order_by(AIGenerated.id.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if row is None:
        raise HTTPException(
            status.HTTP_404_NOT_FOUND,
            "Belum ada plan aktif — generate plan dulu sebelum menyesuaikannya",
        )
    return row


@router.post("/plan/adjust", response_model=AdjustPlanResponse)
async def adjust_active_plan(
    body: AdjustRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Ubah plan AKTIF (baris ai_generated type='plan' terakhir punya user) sesuai instruksi."""
    row = await _get_active_plan_row(user, db)
    old_plan = PlanResponse.model_validate(json.loads(row.content_json))

    try:
        new_plan = await adjust_plan(old_plan, body.instruction)
    except AdjustFailed as exc:
        # Groq gagal/hasilnya ancur: jangan pura2 berhasil, balikin plan lama +
        # error-nya, jangan disimpen ke ai_generated
        return AdjustPlanResponse(
            generated_by=old_plan.generated_by,
            available_hours=old_plan.available_hours,
            open_task_count=old_plan.open_task_count,
            blocks=old_plan.blocks,
            adjusted=False,
            error=f"Gagal menyesuaikan plan, jadwal lama tetap dipakai: {exc}",
        )

    db.add(
        AIGenerated(
            user_id=user.id,
            source_type="task_set",
            source_id=None,
            type="plan",
            content_json=plan_to_json(new_plan),
        )
    )
    await db.commit()
    return AdjustPlanResponse(**new_plan.model_dump(), adjusted=True, error=None)


@router.post("/plan/from-chat", response_model=PlanResponse)
async def plan_from_chat(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Susun plan dari histori chat sejauh ini, pake ulang build_plan()."""
    history = list(
        (
            await db.execute(
                select(ChatMessage).where(ChatMessage.user_id == user.id).order_by(ChatMessage.id)
            )
        )
        .scalars()
        .all()
    )
    preference = chat_service.history_to_preference(history) if history else None

    tasks = list(
        (
            await db.execute(
                select(Task).options(selectinload(Task.course)).where(Task.user_id == user.id)
            )
        )
        .scalars()
        .all()
    )
    plan = await build_plan(tasks, PlanRequest(preference=preference))

    db.add(
        AIGenerated(
            user_id=user.id,
            source_type="task_set",
            source_id=None,
            type="plan",
            content_json=plan_to_json(plan),
        )
    )
    await db.commit()
    return plan


@router.post("/chat/extract-tasks", response_model=ExtractTasksResponse)
async def extract_chat_tasks(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Usul course/task baru dari histori chat — belom kesimpen sampe dikonfirmasi user."""
    history = list(
        (
            await db.execute(
                select(ChatMessage).where(ChatMessage.user_id == user.id).order_by(ChatMessage.id)
            )
        )
        .scalars()
        .all()
    )
    candidates = await chat_service.extract_tasks(history)

    existing = list(
        (
            await db.execute(
                select(Task).options(selectinload(Task.course)).where(Task.user_id == user.id)
            )
        )
        .scalars()
        .all()
    )
    existing_keys = {
        ((t.course.name if t.course else "").lower(), t.title.lower()) for t in existing
    }
    fresh = [c for c in candidates if (c.course.lower(), c.title.lower()) not in existing_keys]
    return ExtractTasksResponse(tasks=fresh)


@router.post("/chat/confirm-tasks", response_model=list[TaskOut])
async def confirm_chat_tasks(
    body: ConfirmTasksRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Simpen task (+ course kalo belom ada) yg udah dikonfirmasi user dari review chat."""
    courses = list(
        (await db.execute(select(Course).where(Course.user_id == user.id))).scalars().all()
    )
    course_by_name = {c.name.lower(): c for c in courses}

    created: list[Task] = []
    for candidate in body.tasks:
        course = course_by_name.get(candidate.course.lower())
        if course is None:
            course = Course(user_id=user.id, name=candidate.course)
            db.add(course)
            course_by_name[candidate.course.lower()] = course

        task = Task(
            user_id=user.id,
            course=course,
            title=candidate.title,
            type=candidate.type,
            difficulty=candidate.difficulty,
            due_date=candidate.due_date,
        )
        db.add(task)
        created.append(task)

    await db.commit()
    created_ids = [t.id for t in created]

    rows = (
        await db.execute(
            select(Task)
            .options(selectinload(Task.course))
            .where(Task.id.in_(created_ids))
            .order_by(Task.id)
        )
    ).scalars().all()
    return [task_to_out(t) for t in rows]


@router.post("/chat/message", response_model=ChatReplyResponse)
async def send_chat_message(
    body: ChatMessageIn,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    db.add(ChatMessage(user_id=user.id, role="user", content=body.message))
    await db.commit()

    history = list(
        (
            await db.execute(
                select(ChatMessage).where(ChatMessage.user_id == user.id).order_by(ChatMessage.id)
            )
        )
        .scalars()
        .all()
    )
    reply, generated_by = await chat_service.reply_to(history)

    db.add(ChatMessage(user_id=user.id, role="assistant", content=reply))
    await db.commit()

    return ChatReplyResponse(reply=reply, generated_by=generated_by)


@router.get("/chat/history", response_model=list[ChatMessageOut])
async def get_chat_history(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    rows = (
        await db.execute(
            select(ChatMessage).where(ChatMessage.user_id == user.id).order_by(ChatMessage.id)
        )
    ).scalars().all()
    return list(rows)


@router.delete("/chat/history", status_code=status.HTTP_204_NO_CONTENT)
async def clear_chat_history(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await db.execute(delete(ChatMessage).where(ChatMessage.user_id == user.id))
    await db.commit()


async def _get_material(material_id: int, user: User, db: AsyncSession) -> Material:
    material = (
        await db.execute(
            select(Material).where(Material.id == material_id, Material.user_id == user.id)
        )
    ).scalar_one_or_none()
    if material is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Materi tidak ditemukan")
    return material


@router.post("/materials/{material_id}/summarize", response_model=SummaryResponse)
async def summarize_material(
    material_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    material = await _get_material(material_id, user, db)
    result = await materials_service.summarize(material.id, material.extracted_text)
    db.add(
        AIGenerated(
            user_id=user.id,
            source_type="material",
            source_id=material.id,
            type="summary",
            content_json=json.dumps(result.model_dump(), ensure_ascii=False),
        )
    )
    await db.commit()
    return result


@router.post("/materials/{material_id}/quiz", response_model=QuizResponse)
async def quiz_material(
    material_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    material = await _get_material(material_id, user, db)
    result = await materials_service.make_quiz(material.id, material.extracted_text)
    db.add(
        AIGenerated(
            user_id=user.id,
            source_type="material",
            source_id=material.id,
            type="quiz",
            content_json=json.dumps(result.model_dump(), ensure_ascii=False),
        )
    )
    await db.commit()
    return result
