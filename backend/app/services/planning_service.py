"""Otak fitur "Plan My Day". Dua jalur: build_plan (Groq, ada fallback) sama
build_plan_heuristic (murni skor prioritas, gak butuh AI)."""
from __future__ import annotations

import json
import re
from datetime import datetime, timezone

from app.models.chat_message import ChatMessage
from app.models.task import Task
from app.schemas.ai import PlanBlock, PlanRequest, PlanResponse
from app.services.chat_service import parse_time_window, to_24h
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


BREAK_MINUTES = 10  # jeda antar blok
MIN_BLOCK_MINUTES = 20  # sisa waktu di bawah ini gak usah dipaksa jadi blok
DEFAULT_COLOR = "#4C6FFF"


def fmt_minutes(total: int) -> str:
    """Menit dari 00:00 -> "HH:MM"."""
    return f"{total // 60:02d}:{total % 60:02d}"


def parse_hhmm(value: object) -> int | None:
    """ "10:00" / "10.00" / "9:5" -> menit dari 00:00. Gak valid -> None."""
    if not isinstance(value, str):
        return None
    m = re.fullmatch(r"\s*(\d{1,2})[:.](\d{1,2})\s*", value)
    if not m:
        return None
    h, mnt = int(m.group(1)), int(m.group(2))
    if h > 24 or mnt > 59 or (h == 24 and mnt):
        return None
    return h * 60 + mnt


def plan_window(req: PlanRequest) -> tuple[int, int]:
    """Rentang waktu luang (menit dari 00:00), gak boleh lewat tengah malem."""
    start = req.start_hour * 60 + req.start_minute
    end = min(start + round(req.available_hours * 60), 24 * 60)
    return start, end


def _course_name(task: Task) -> str | None:
    return task.course.name if task.course else None


def _course_color(task: Task) -> str:
    return task.course.color if task.course else DEFAULT_COLOR


def layout_blocks(
    items: list[tuple[Task, int, str | None]], start: int, end: int
) -> list[PlanBlock]:
    """Susun blok berurutan mulai `start`, jeda BREAK_MINUTES, gak pernah lewat `end`.
    Jam-nya SELALU diitung di sini, bukan dipercaya dari LLM — LLM cuma milih task,
    urutan, sama durasinya. Makanya jadwal pasti di dalem jam luang & gak numpuk."""
    blocks: list[PlanBlock] = []
    cursor = start
    for task, minutes, reason in items:
        remaining = end - cursor
        if remaining < MIN_BLOCK_MINUTES:
            break
        minutes = max(MIN_BLOCK_MINUTES, min(minutes, remaining))
        blocks.append(
            PlanBlock(
                task_id=task.id,
                title=task.title,
                course=_course_name(task),
                color=_course_color(task),
                start_time=fmt_minutes(cursor),
                end_time=fmt_minutes(cursor + minutes),
                duration_minutes=minutes,
                reason=reason,
            )
        )
        cursor += minutes + BREAK_MINUTES
    return blocks


def _response(
    generated_by: str, req: PlanRequest, open_count: int, blocks: list[PlanBlock]
) -> PlanResponse:
    start, end = plan_window(req)
    return PlanResponse(
        generated_by=generated_by,
        available_hours=round((end - start) / 60, 2),
        open_task_count=open_count,
        blocks=blocks,
        start_time=fmt_minutes(start),
        end_time=fmt_minutes(end),
    )


def build_plan_heuristic(tasks: list[Task], req: PlanRequest) -> PlanResponse:
    """Jadwal manual: task terpenting duluan, durasi dari tingkat kesulitan."""
    ranked = rank_tasks(tasks)
    start, end = plan_window(req)
    items = [
        (t, BASE_MINUTES[t.difficulty], f"prioritas {priority_label(priority_score(t))}")
        for t in ranked
    ]
    return _response("heuristic", req, len(ranked), layout_blocks(items, start, end))


SYSTEM_PROMPT = (
    "Kamu adalah asisten perencana belajar. Kamu HANYA membalas dengan JSON valid, "
    "tanpa penjelasan tambahan dan tanpa markdown fence. "
    'Format: {"blocks": [{"task_id": int, "duration_minutes": int, "reason": str}]}. '
    "Urutan blocks = urutan dikerjakan. Jam mulai/selesai TIDAK perlu kamu tulis, "
    "sistem yang menyusunnya di dalam waktu luang mahasiswa. Aturan: "
    "(1) task_id WAJIB salah satu id dari daftar task, jangan mengarang task baru; "
    "(2) satu task maksimal satu blok; "
    "(3) total duration_minutes ditambah jeda 10 menit antar blok TIDAK BOLEH melebihi "
    "total menit waktu luang; "
    "(4) kalau percakapan/preferensi mahasiswa menyebut mata kuliah atau tugas tertentu, "
    "jadwalkan task itu lebih dulu dan boleh abaikan task yang tidak relevan; "
    "(5) kalau tidak ada preferensi khusus, dahulukan skor prioritas tertinggi; "
    "(6) reason singkat dalam bahasa Indonesia."
)

MAX_CONTEXT_CHARS = 4000


def build_prompt(tasks: list[Task], req: PlanRequest, context: str | None = None) -> str:
    ranked = rank_tasks(tasks)
    start, end = plan_window(req)
    lines = []
    for t in ranked:
        days = days_until_due(t)
        due = "tanpa deadline" if days is None else f"{days:.1f} hari lagi"
        lines.append(
            f"- id={t.id} | {t.title} | mata kuliah={_course_name(t) or '-'} "
            f"| tipe={t.type} | kesulitan={t.difficulty} | progres={t.progress_pct}% "
            f"| deadline={due} | skor_prioritas={priority_score(t)}"
        )
    task_list = "\n".join(lines) if lines else "(tidak ada task terbuka)"
    parts = [
        f"Waktu luang hari ini: {fmt_minutes(start)}-{fmt_minutes(end)} "
        f"(total {end - start} menit).",
        f"Preferensi mahasiswa: {req.preference or 'tidak ada preferensi khusus'}",
    ]
    if context:
        # yg terbaru paling penting, jadi kalo kepanjangan potong dari DEPAN
        parts.append(f"Percakapan dengan mahasiswa:\n{context[-MAX_CONTEXT_CHARS:]}")
    parts.append(f"Daftar task terbuka:\n{task_list}")
    parts.append("Pilih task dan durasinya untuk jadwal belajar hari ini.")
    return "\n\n".join(parts)


def _llm_items(raw: object, ranked: list[Task]) -> list[tuple[Task, int, str | None]]:
    """Ambil (task, menit, alasan) dari JSON LLM. Task_id ngarang / dobel dibuang."""
    blocks_raw = raw.get("blocks") if isinstance(raw, dict) else raw
    if not isinstance(blocks_raw, list):
        raise ValueError("field 'blocks' tidak ada / bukan list")
    by_id = {t.id: t for t in ranked}
    items: list[tuple[Task, int, str | None]] = []
    used: set[int] = set()
    for item in blocks_raw:
        if not isinstance(item, dict):
            continue
        try:
            task_id = int(item.get("task_id"))
        except (TypeError, ValueError):
            continue
        task = by_id.get(task_id)
        if task is None or task_id in used:
            continue
        try:
            minutes = int(item.get("duration_minutes") or BASE_MINUTES[task.difficulty])
        except (TypeError, ValueError):
            minutes = BASE_MINUTES[task.difficulty]
        reason = item.get("reason")
        items.append((task, minutes, str(reason) if reason else None))
        used.add(task_id)
    return items


async def build_plan(
    tasks: list[Task], req: PlanRequest, context: str | None = None
) -> PlanResponse:
    """Coba Groq dulu, kalo gak ada / hasilnya ancur baru jatoh ke heuristik.
    `context` = isi percakapan chat (opsional), dikirim utuh ke LLM."""
    ranked = rank_tasks(tasks)
    if not ranked:
        return _response("heuristic", req, 0, [])

    try:
        raw = await complete_json(SYSTEM_PROMPT, build_prompt(tasks, req, context))
        items = _llm_items(raw, ranked)
        start, end = plan_window(req)
        blocks = layout_blocks(items, start, end)
        if not blocks:
            raise ValueError("LLM tidak memilih task yang valid")
        return _response("groq", req, len(ranked), blocks)
    except (GroqUnavailable, ValueError, TypeError, AttributeError):
        return build_plan_heuristic(tasks, req)


def plan_to_json(plan: PlanResponse) -> str:
    # plan_id itu id baris-nya sendiri, gak usah ikut disimpen di dalem kontennya
    return json.dumps(plan.model_dump(exclude={"plan_id"}), ensure_ascii=False)


class AdjustFailed(RuntimeError):
    """Groq gagal / hasilnya ancur pas nyesuain plan — router balik ke plan lama."""


ADJUST_SYSTEM_PROMPT = (
    "Kamu adalah asisten perencana belajar. Kamu akan diberi jadwal (blocks) yang sudah ada, "
    "waktu luang mahasiswa, daftar task miliknya, dan instruksi baru untuk mengubah jadwal. "
    "Kamu HANYA membalas dengan JSON valid, tanpa penjelasan tambahan dan tanpa markdown "
    'fence. Format: {"start_time": "HH:MM", "end_time": "HH:MM", "blocks": [{"task_id": '
    'int atau null, "title": str, "course": str atau null, "start_time": "HH:MM", '
    '"end_time": "HH:MM", "reason": str}]}. '
    "start_time/end_time di luar blocks = waktu luang mahasiswa; pertahankan yang lama "
    "kecuali instruksi menyebut waktu luang baru. Aturan: (1) SEMUA blok harus berada di "
    "dalam waktu luang itu dan tidak boleh saling bertumpuk; (2) untuk task yang ada di "
    "daftar, pakai task_id-nya; (3) task_id null HANYA untuk kegiatan baru yang diminta "
    "mahasiswa secara eksplisit dan tidak ada di daftar — isi title dan course-nya dengan "
    "jelas; (4) kembalikan SEMUA blok (yang lama + yang baru), jangan menghapus blok yang "
    "tidak disinggung instruksi — kalau waktunya tidak cukup, perpendek blok lain; "
    "(5) reason singkat dalam bahasa Indonesia."
)


def _window_of(plan: PlanResponse) -> tuple[int, int] | None:
    start, end = parse_hhmm(plan.start_time), parse_hhmm(plan.end_time)
    if start is not None and end is not None and end > start:
        return start, end
    # plan lama belom nyimpen jendela waktunya, kira2 dari bloknya aja
    times = [
        (parse_hhmm(b.start_time), parse_hhmm(b.end_time)) for b in plan.blocks
    ]
    times = [(a, b) for a, b in times if a is not None and b is not None]
    if not times:
        return None
    return min(a for a, _ in times), max(b for _, b in times)


def build_adjust_prompt(
    old_plan: PlanResponse, instruction: str, tasks: list[Task] | None = None
) -> str:
    lines = [
        f"- task_id={b.task_id} | {b.title} | mata kuliah={b.course or '-'} "
        f"| {b.start_time}-{b.end_time} ({b.duration_minutes} menit) | alasan={b.reason or '-'}"
        for b in old_plan.blocks
    ]
    blocks_text = "\n".join(lines) if lines else "(tidak ada blok)"
    window = _window_of(old_plan)
    window_text = (
        f"{fmt_minutes(window[0])}-{fmt_minutes(window[1])}" if window else "belum diketahui"
    )
    task_lines = [
        f"- id={t.id} | {t.title} | mata kuliah={_course_name(t) or '-'} | kesulitan={t.difficulty}"
        for t in rank_tasks(tasks or [])
    ]
    tasks_text = "\n".join(task_lines) if task_lines else "(tidak ada task terbuka)"
    return (
        f"Waktu luang mahasiswa: {window_text}\n\n"
        f"Jadwal saat ini:\n{blocks_text}\n\n"
        f"Daftar task terbuka milik mahasiswa:\n{tasks_text}\n\n"
        f"Instruksi perubahan dari mahasiswa: {instruction}\n\n"
        "Susun ulang jadwal sesuai instruksi tersebut."
    )


_REMOVAL_RE = re.compile(
    r"\b(hapus|buang|hilangkan|hilangin|skip|batal|batalkan|ganti|gantikan|cuma|hanya|"
    r"kurangi|remove|delete|drop|only)\b",
    re.IGNORECASE,
)


_BOUND = r"(?:jam|pukul)\s*(\d{1,2})(?:[.:](\d{2}))?\s*(pagi|siang|sore|malam)?"
_UNTIL_RE = re.compile(rf"(?:sampai|sampe|hingga|until|s/d)\s*{_BOUND}", re.IGNORECASE)
_SINCE_RE = re.compile(rf"(?:mulai|dari|start|from)\s*{_BOUND}", re.IGNORECASE)


def _clock(m: re.Match) -> int:
    return to_24h(int(m.group(1)), m.group(3)) * 60 + int(m.group(2) or 0)


def _instruction_window(
    instruction: str, old_window: tuple[int, int] | None, llm_window: tuple[int, int] | None
) -> tuple[int, int] | None:
    """Jam luang abis adjust. Diputusin kode, bukan LLM: cuma berubah kalo instruksinya
    beneran nyebut jam (dulu LLM suka iseng melarin jendelanya sendiri)."""
    parsed = parse_time_window([ChatMessage(role="user", content=instruction)])
    if parsed.start_minutes is not None and parsed.end_minutes is not None:
        return parsed.start_minutes, parsed.end_minutes
    # batas sebelah doang: "cuma bisa sampai jam 12" / "mulai jam 11 aja"
    base = old_window or llm_window
    until = _UNTIL_RE.search(instruction)
    since = _SINCE_RE.search(instruction)
    if base and (until or since):
        start, end = base
        if since:
            start = _clock(since)
        if until:
            end = _clock(until)
            if end <= start and end < 12 * 60:
                end += 12 * 60  # "sampai jam 1" siang
        if 0 <= start < end <= 24 * 60:
            return start, end
    if parsed.hours is not None:
        wanted = round(parsed.hours * 60)
        if llm_window and abs((llm_window[1] - llm_window[0]) - wanted) <= 15:
            return llm_window
        start = old_window[0] if old_window else (llm_window[0] if llm_window else None)
        return (start, min(start + wanted, 24 * 60)) if start is not None else None
    if old_window:
        return old_window
    return llm_window


def _normalize_adjusted(
    raw: object, old_plan: PlanResponse, tasks: list[Task], instruction: str = ""
) -> tuple[list[PlanBlock], tuple[int, int] | None]:
    """Validasi hasil adjust dari LLM: jam valid, task_id beneran punya user,
    gak numpuk, dan tetep di dalem waktu luang."""
    if not isinstance(raw, dict):
        raise ValueError("respons bukan objek JSON")
    blocks_raw = raw.get("blocks")
    if not isinstance(blocks_raw, list) or not blocks_raw:
        raise ValueError("field 'blocks' tidak ada / bukan list / kosong")

    by_id = {t.id: t for t in tasks}
    by_title = {t.title.strip().lower(): t for t in tasks}
    old_colors = {b.task_id: b.color for b in old_plan.blocks if b.task_id is not None}

    parsed: list[tuple[int, int, PlanBlock]] = []
    for item in blocks_raw:
        if not isinstance(item, dict):
            continue
        start, end = parse_hhmm(item.get("start_time")), parse_hhmm(item.get("end_time"))
        if start is None or end is None or end <= start:
            continue
        try:
            task_id = int(item["task_id"]) if item.get("task_id") is not None else None
        except (TypeError, ValueError):
            task_id = None
        title = str(item.get("title") or "").strip()
        task = by_id.get(task_id) if task_id is not None else None
        if task is None and title:
            task = by_title.get(title.lower())  # LLM lupa id-nya tapi judulnya sama
        if task is not None:
            block = PlanBlock(
                task_id=task.id,
                title=task.title,
                course=_course_name(task),
                color=_course_color(task),
                start_time="",
                end_time="",
                duration_minutes=end - start,
                reason=item.get("reason"),
            )
        elif title:
            # kegiatan baru yg diminta user — task-nya dibikin pas plan di-accept
            course = item.get("course")
            block = PlanBlock(
                task_id=None,
                title=title[:200],
                course=str(course)[:150] if course else None,
                color=old_colors.get(task_id, DEFAULT_COLOR),
                start_time="",
                end_time="",
                duration_minutes=end - start,
                reason=item.get("reason"),
            )
        else:
            continue
        parsed.append((start, end, block))

    if not parsed:
        raise ValueError("tidak ada blok valid dari LLM")

    window_start = parse_hhmm(raw.get("start_time"))
    window_end = parse_hhmm(raw.get("end_time"))
    llm_window = (
        (window_start, window_end)
        if window_start is not None and window_end is not None and window_end > window_start
        else None
    )
    window = _instruction_window(instruction, _window_of(old_plan), llm_window)

    parsed.sort(key=lambda p: p[0])

    # LLM kadang ngilangin blok lama diem2. kalo user gak minta hapus apa2,
    # balikin blok yg ilang ke belakang (kalo gak muat nanti kepotong sendiri)
    if not _REMOVAL_RE.search(instruction):
        kept_ids = {b.task_id for _, _, b in parsed if b.task_id is not None}
        kept_titles = {b.title.lower() for _, _, b in parsed}
        cursor_end = parsed[-1][1]
        for old in old_plan.blocks:
            if old.task_id in kept_ids or old.title.lower() in kept_titles:
                continue
            start = cursor_end + BREAK_MINUTES
            parsed.append((start, start + old.duration_minutes, old.model_copy()))
            cursor_end = start + old.duration_minutes
    cursor = None
    out_of_window = False
    placed: list[tuple[int, int, PlanBlock]] = []
    for start, end, block in parsed:
        duration = end - start
        if cursor is not None and start < cursor:  # numpuk -> geser ke abis blok sebelumnya
            start = cursor
            end = start + duration
        if window and (start < window[0] or end > window[1]):
            out_of_window = True
        placed.append((start, end, block))
        cursor = end

    if out_of_window and window:
        # ada yg keluar jendela: susun ulang berurutan di dalem jendela, durasi dijaga
        placed = []
        cursor = window[0]
        for _, _, block in parsed:
            duration = block.duration_minutes
            remaining = window[1] - cursor
            if remaining < MIN_BLOCK_MINUTES:
                break
            duration = min(duration, remaining)
            placed.append((cursor, cursor + duration, block))
            cursor += duration + BREAK_MINUTES

    blocks = []
    for start, end, block in placed:
        block.start_time = fmt_minutes(start)
        block.end_time = fmt_minutes(end)
        block.duration_minutes = end - start
        blocks.append(block)
    if not blocks:
        raise ValueError("tidak ada blok yang muat di waktu luang")
    return blocks, window


async def adjust_plan(
    old_plan: PlanResponse, instruction: str, tasks: list[Task] | None = None
) -> PlanResponse:
    """Kirim plan lama + instruksi ke Groq, validasi hasilnya. Gagal -> AdjustFailed,
    biar router yg mutusin mau fallback ke plan lama apa gimana."""
    open_tasks = rank_tasks(tasks or [])
    try:
        raw = await complete_json(
            ADJUST_SYSTEM_PROMPT, build_adjust_prompt(old_plan, instruction, open_tasks)
        )
        blocks, window = _normalize_adjusted(raw, old_plan, open_tasks, instruction)
        return PlanResponse(
            generated_by="groq",
            available_hours=round((window[1] - window[0]) / 60, 2)
            if window
            else old_plan.available_hours,
            open_task_count=len(open_tasks),
            blocks=blocks,
            start_time=fmt_minutes(window[0]) if window else None,
            end_time=fmt_minutes(window[1]) if window else None,
        )
    except (GroqUnavailable, ValueError, TypeError, AttributeError, KeyError) as exc:
        raise AdjustFailed(str(exc)) from exc
