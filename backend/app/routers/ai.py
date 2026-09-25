import json
from datetime import date, datetime

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
    RandomPlanRequest,
    QuizResponse,
    SummaryResponse,
)
from app.schemas.task import TaskOut
from app.services import chat_service, materials_service
from app.services.planning_service import (
    AdjustFailed,
    adjust_plan,
    build_plan,
    build_random_plan,
    plan_to_json,
)

router = APIRouter(prefix="/ai", tags=["ai"])


async def _user_tasks(user: User, db: AsyncSession) -> list[Task]:
    return list(
        (
            await db.execute(
                select(Task).options(selectinload(Task.course)).where(Task.user_id == user.id)
            )
        )
        .scalars()
        .all()
    )


async def _save_plan(plan: PlanResponse, user: User, db: AsyncSession) -> PlanResponse:
    """Arsipin plan ke ai_generated, balikin plan + plan_id-nya."""
    row = AIGenerated(
        user_id=user.id,
        source_type="task_set",
        source_id=None,
        type="plan",
        content_json=plan_to_json(plan),
    )
    db.add(row)
    await db.commit()
    plan.plan_id = row.id
    return plan


def _row_to_plan(row: AIGenerated) -> PlanResponse:
    plan = PlanResponse.model_validate(json.loads(row.content_json))
    plan.plan_id = row.id
    return plan


@router.post("/plan", response_model=PlanResponse)
async def plan_my_day(
    body: PlanRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Fitur utama: susun jadwal hari ini dari task yg masih kebuka."""
    plan = await build_plan(await _user_tasks(user, db), body)
    return await _save_plan(plan, user, db)


@router.post("/plan/random", response_model=PlanResponse)
async def random_plan(
    body: RandomPlanRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Opsi "random plan": cuma butuh jam luang, sisanya (course, jam, kegiatan) diacak."""
    courses = list(
        (await db.execute(select(Course).where(Course.user_id == user.id))).scalars().all()
    )
    return await _save_plan(build_random_plan(courses, body.available_hours), user, db)


@router.get("/plan/active", response_model=PlanResponse | None)
async def active_plan(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Plan terakhir (yg bakal diubah sama Adjust), biar user liat dulu apa yg mau diubah."""
    try:
        return _row_to_plan(await _get_active_plan_row(user, db))
    except HTTPException:
        return None


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
    old_plan = _row_to_plan(row)

    try:
        new_plan = await adjust_plan(old_plan, body.instruction, await _user_tasks(user, db))
    except AdjustFailed as exc:
        # Groq gagal/hasilnya ancur: jangan pura2 berhasil, balikin plan lama +
        # error-nya, jangan disimpen ke ai_generated
        return AdjustPlanResponse(
            **old_plan.model_dump(),
            adjusted=False,
            error=f"Gagal menyesuaikan plan, jadwal lama tetap dipakai: {exc}",
        )

    new_plan = await _save_plan(new_plan, user, db)
    return AdjustPlanResponse(**new_plan.model_dump(), adjusted=True, error=None)


@router.post("/plan/{plan_id}/accept", response_model=PlanResponse)
async def accept_plan(
    plan_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Terima plan: tiap blok WAJIB nyambung ke task beneran. Blok kegiatan baru
    (task_id null, biasanya dari Adjust) dibikinin task + course-nya di sini."""
    row = (
        await db.execute(
            select(AIGenerated).where(
                AIGenerated.id == plan_id,
                AIGenerated.user_id == user.id,
                AIGenerated.type == "plan",
            )
        )
    ).scalar_one_or_none()
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Plan tidak ditemukan")
    plan = _row_to_plan(row)
    if not plan.blocks:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Plan kosong, tidak ada yang diterima")

    tasks = await _user_tasks(user, db)
    task_by_id = {t.id: t for t in tasks}
    open_by_key = {
        ((t.course.name.lower() if t.course else ""), t.title.lower()): t
        for t in tasks
        if t.status != "done"
    }
    courses = list(
        (await db.execute(select(Course).where(Course.user_id == user.id))).scalars().all()
    )
    course_by_name = {c.name.lower(): c for c in courses}

    for block in plan.blocks:
        task = task_by_id.get(block.task_id) if block.task_id is not None else None
        if task is None:
            key = ((block.course or "").lower(), block.title.lower())
            task = open_by_key.get(key)
        if task is None:
            course = None
            if block.course:
                course = course_by_name.get(block.course.lower())
                if course is None:
                    course = Course(user_id=user.id, name=block.course, color=block.color)
                    db.add(course)
                    course_by_name[block.course.lower()] = course
            task = Task(user_id=user.id, course=course, title=block.title[:200])
            db.add(task)
            await db.flush()
            open_by_key[key] = task
        block.task_id = task.id
        block.title = task.title
        if task.course is not None:
            block.course = task.course.name
            block.color = task.course.color

    plan.accepted = True
    plan.plan_date = date.today().isoformat()
    plan.accepted_at = datetime.now().isoformat()
    row.content_json = plan_to_json(plan)
    await db.commit()
    return plan


@router.get("/plan/today", response_model=PlanResponse | None)
async def todays_plan(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Plan yg udah di-accept buat hari ini (paling baru), buat ditampilin di Home."""
    rows = (
        await db.execute(
            select(AIGenerated)
            .where(AIGenerated.user_id == user.id, AIGenerated.type == "plan")
            .order_by(AIGenerated.id.desc())
            .limit(30)
        )
    ).scalars().all()
    today = date.today().isoformat()
    accepted = [
        plan
        for plan in map(_row_to_plan, rows)
        if plan.accepted and plan.plan_date == today
    ]
    # yg paling terakhir di-ACCEPT (bukan yg id-nya paling gede)
    return max(accepted, key=lambda p: p.accepted_at or "", default=None)


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
    req = PlanRequest()
    window = chat_service.parse_time_window(history)
    if window.start_minutes is not None and window.end_minutes is not None:
        req = PlanRequest(
            start_hour=window.start_minutes // 60,
            start_minute=window.start_minutes % 60,
            available_hours=min(max((window.end_minutes - window.start_minutes) / 60, 0.5), 16),
        )
    elif window.hours is not None:
        req = PlanRequest(available_hours=window.hours)

    context = chat_service.history_to_context(history) if history else None
    plan = await build_plan(await _user_tasks(user, db), req, context)
    return await _save_plan(plan, user, db)


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
    # yg udah done boleh diusulin lagi (mau latihan lagi), cuma yg masih kebuka yg di-skip
    existing_keys = {
        ((t.course.name if t.course else "").lower(), t.title.lower())
        for t in existing
        if t.status != "done"
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
