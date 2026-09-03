"""Otak fitur "Plan My Day". Dua jalur: build_plan (Groq, ada fallback) sama
build_plan_heuristic (murni skor prioritas, gak butuh AI)."""
from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone

from app.models.task import Task
from app.schemas.ai import PlanBlock, PlanRequest, PlanResponse
from app.services.groq_service import GroqUnavailable, complete_json

DIFFICULTY_WEIGHT = {"easy": 1.0, "medium": 1.6, "hard": 2.4}
TYPE_WEIGHT = {"quiz": 1.0, "assignment": 1.2, "exam": 1.8}

# estimasi durasi ngerjain per task (menit), sebelum dipotong jam yg available
BASE_MINUTES = {"easy": 30, "medium": 60, "hard": 90}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def days_until_due(task: Task, now: datetime | None = None) -> float | None:
    """Sisa hari ke deadline. None kalo gak ada due date."""
    if task.due_date is None:
        return None
    now = now or _now()
    due = task.due_date
    if due.tzinfo is None:  # sqlite nyimpen datetime naive
        due = due.replace(tzinfo=timezone.utc)
    return (due - now).total_seconds() / 86400


def priority_score(task: Task, now: datetime | None = None) -> float:
    """Skor 0-100, makin deket deadline + makin susah + makin berat tipenya = makin gede.
    Sengaja dibikin manual/deterministik (bukan AI) biar gampang dites."""
    if task.status == "done":
        return 0.0

    days = days_until_due(task, now)
    if days is None:
        urgency = 0.35  # gaada deadline, prioritas menengah-bawah aja
    elif days <= 0:
        urgency = 1.0  # udah lewat / hari ini
    else:
        # 1 hari -> 0.83, 3 hari -> 0.63, 7 hari -> 0.42
        urgency = 1.0 / (1.0 + days / 5.0)

    weight = DIFFICULTY_WEIGHT[task.difficulty] * TYPE_WEIGHT[task.type]
    progress_left = 1.0 - (task.progress_pct / 100.0)

    raw = urgency * weight * (0.4 + 0.6 * progress_left)
    # nilai max teoritis = 1.0 * 2.4 * 1.8 * 1.0 = 4.32
    return round(min(raw / 4.32, 1.0) * 100, 2)


def priority_label(score: float) -> str:
    if score >= 55:
        return "high"
    if score >= 25:
        return "medium"
    return "low"


def rank_tasks(tasks: list[Task], now: datetime | None = None) -> list[Task]:
    """Urutin task terbuka, yg paling mendesak duluan."""
    open_tasks = [t for t in tasks if t.status != "done"]
    return sorted(open_tasks, key=lambda t: priority_score(t, now), reverse=True)


def _fmt(dt: datetime) -> str:
    return dt.strftime("%H:%M")


def build_plan_heuristic(tasks: list[Task], req: PlanRequest) -> PlanResponse:
    """Jadwal manual: task terpenting duluan, blok 25-90 menit, jeda 15 menit."""
    ranked = rank_tasks(tasks)
    budget = int(req.available_hours * 60)
    cursor = datetime(2000, 1, 1, req.start_hour, 0)  # tanggalnya dummy, cuma jamnya yg dipake
    blocks: list[PlanBlock] = []

    for task in ranked:
        if budget < 25:
            break
        minutes = min(BASE_MINUTES[task.difficulty], budget)
        end = cursor + timedelta(minutes=minutes)
        blocks.append(
            PlanBlock(
                task_id=task.id,
                title=task.title,
                course=task.course.name if task.course else None,
                color=task.course.color if task.course else "#4C6FFF",
                start_time=_fmt(cursor),
                end_time=_fmt(end),
                duration_minutes=minutes,
                reason=f"prioritas {priority_label(priority_score(task))}",
            )
        )
        budget -= minutes
        cursor = end + timedelta(minutes=15)  # istirahat antar sesi

    return PlanResponse(
        generated_by="heuristic",
        available_hours=req.available_hours,
        open_task_count=len(ranked),
        blocks=blocks,
    )


SYSTEM_PROMPT = (
    "Kamu adalah asisten perencana belajar. Kamu HANYA membalas dengan JSON valid, "
    "tanpa penjelasan tambahan dan tanpa markdown fence. "
    'Format: {"blocks": [{"task_id": int, "title": str, "course": str, '
    '"start_time": "HH:MM", "end_time": "HH:MM", "duration_minutes": int, "reason": str}]}. '
    "Aturan: total duration_minutes tidak boleh melebihi jam yang tersedia; "
    "beri jeda 10-15 menit antar blok; dahulukan task dengan skor prioritas tinggi; "
    "satu task maksimal satu blok."
)


def build_prompt(tasks: list[Task], req: PlanRequest) -> str:
    ranked = rank_tasks(tasks)
    lines = []
    for t in ranked:
        days = days_until_due(t)
        due = "tanpa deadline" if days is None else f"{days:.1f} hari lagi"
        lines.append(
            f"- id={t.id} | {t.title} | mata kuliah={t.course.name if t.course else '-'} "
            f"| tipe={t.type} | kesulitan={t.difficulty} | progres={t.progress_pct}% "
            f"| deadline={due} | skor_prioritas={priority_score(t)}"
        )
    task_list = "\n".join(lines) if lines else "(tidak ada task terbuka)"
    pref = req.preference or "tidak ada preferensi khusus"
    return (
        f"Jam belajar tersedia hari ini: {req.available_hours} jam, "
        f"mulai pukul {req.start_hour:02d}:00.\n"
        f"Preferensi mahasiswa: {pref}\n\n"
        f"Daftar task terbuka:\n{task_list}\n\n"
        "Susun jadwal belajar hari ini."
    )


async def build_plan(tasks: list[Task], req: PlanRequest) -> PlanResponse:
    """Coba Groq dulu, kalo gak ada / hasilnya ancur baru jatoh ke heuristik."""
    ranked = rank_tasks(tasks)
    if not ranked:
        return PlanResponse(
            generated_by="heuristic",
            available_hours=req.available_hours,
            open_task_count=0,
            blocks=[],
        )

    try:
        raw = await complete_json(SYSTEM_PROMPT, build_prompt(tasks, req))
        blocks_raw = raw.get("blocks") if isinstance(raw, dict) else raw
        if not isinstance(blocks_raw, list):
            raise ValueError("field 'blocks' tidak ada / bukan list")

        color_by_id = {
            t.id: (t.course.color if t.course else "#4C6FFF") for t in ranked
        }
        blocks: list[PlanBlock] = []
        for item in blocks_raw:
            block = PlanBlock.model_validate(item)  # validasi dulu, jangan percaya mentahan
            block.color = color_by_id.get(block.task_id, "#4C6FFF")
            blocks.append(block)

        if not blocks:
            raise ValueError("LLM mengembalikan daftar blok kosong")

        return PlanResponse(
            generated_by="groq",
            available_hours=req.available_hours,
            open_task_count=len(ranked),
            blocks=blocks,
        )
    except (GroqUnavailable, ValueError, TypeError, AttributeError):
        return build_plan_heuristic(tasks, req)


def plan_to_json(plan: PlanResponse) -> str:
    return json.dumps(plan.model_dump(), ensure_ascii=False)


class AdjustFailed(RuntimeError):
    """Groq gagal / hasilnya ancur pas nyesuain plan — router balik ke plan lama."""


ADJUST_SYSTEM_PROMPT = (
    "Kamu adalah asisten perencana belajar. Kamu akan diberi jadwal (blocks) yang sudah ada "
    "dan instruksi baru dari mahasiswa untuk mengubahnya. Kamu HANYA membalas dengan JSON "
    "valid, tanpa penjelasan tambahan dan tanpa markdown fence. "
    'Format: {"blocks": [{"task_id": int atau null, "title": str, "course": str, '
    '"start_time": "HH:MM", "end_time": "HH:MM", "duration_minutes": int, "reason": str}]}. '
    "Pertahankan task_id, title, dan course dari blok asli sebisa mungkin kecuali instruksi "
    "eksplisit memintamu mengubahnya. Ikuti instruksi mahasiswa seakurat mungkin."
)


def build_adjust_prompt(old_plan: PlanResponse, instruction: str) -> str:
    lines = [
        f"- task_id={b.task_id} | {b.title} | mata kuliah={b.course or '-'} "
        f"| {b.start_time}-{b.end_time} ({b.duration_minutes} menit) | alasan={b.reason or '-'}"
        for b in old_plan.blocks
    ]
    blocks_text = "\n".join(lines) if lines else "(tidak ada blok)"
    return (
        f"Jadwal saat ini:\n{blocks_text}\n\n"
        f"Instruksi perubahan dari mahasiswa: {instruction}\n\n"
        "Susun ulang jadwal sesuai instruksi tersebut."
    )


async def adjust_plan(old_plan: PlanResponse, instruction: str) -> PlanResponse:
    """Kirim plan lama + instruksi ke Groq, validasi kayak build_plan(). Gagal -> AdjustFailed,
    biar router yg mutusin mau fallback ke plan lama apa gimana."""
    try:
        raw = await complete_json(ADJUST_SYSTEM_PROMPT, build_adjust_prompt(old_plan, instruction))
        blocks_raw = raw.get("blocks") if isinstance(raw, dict) else raw
        if not isinstance(blocks_raw, list) or not blocks_raw:
            raise ValueError("field 'blocks' tidak ada / bukan list / kosong")

        color_by_id = {b.task_id: b.color for b in old_plan.blocks if b.task_id is not None}
        blocks: list[PlanBlock] = []
        for item in blocks_raw:
            block = PlanBlock.model_validate(item)  # validasi dulu, jangan percaya mentahan
            if block.task_id is not None and block.task_id in color_by_id:
                block.color = color_by_id[block.task_id]
            blocks.append(block)

        return PlanResponse(
            generated_by="groq",
            available_hours=old_plan.available_hours,
            open_task_count=old_plan.open_task_count,
            blocks=blocks,
        )
    except (GroqUnavailable, ValueError, TypeError, AttributeError) as exc:
        raise AdjustFailed(str(exc)) from exc
