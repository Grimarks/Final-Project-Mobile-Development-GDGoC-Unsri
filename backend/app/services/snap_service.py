"""Snap & Go: foto pengumuman tugas / papan tulis / screenshot grup WA (atau teks
yg di-paste) -> usulan task. Sama kayak extract dari chat, hasilnya cuma USULAN —
baru kesimpen pas user konfirmasi lewat /ai/chat/confirm-tasks."""
from __future__ import annotations

import base64
from datetime import datetime, timezone
from typing import Any

from app.core.config import settings
from app.schemas.ai import TaskCandidate
from app.services.groq_service import complete_json

SNAP_SYSTEM_PROMPT = (
    "Kamu membaca pengumuman akademik untuk mahasiswa: foto papan tulis, slide, "
    "screenshot chat grup kelas (WhatsApp/Line), atau teks yang di-paste. Tugasmu: "
    "ekstrak SEMUA tugas, kuis, ujian, atau deadline akademik yang disebut. "
    "JANGAN mengarang tugas yang tidak tertulis. Kamu HANYA membalas dengan JSON valid, "
    'tanpa markdown. Format: {"tasks": [{"course": str, "title": str, '
    '"type": "assignment"|"exam"|"quiz", "difficulty": "easy"|"medium"|"hard", '
    '"due_date": "YYYY-MM-DD" atau "YYYY-MM-DDTHH:MM" atau null}]}. '
    "Aturan: (1) course = nama mata kuliah; kalau mirip salah satu mata kuliah milik "
    "mahasiswa yang diberikan, pakai nama PERSIS dari daftar itu; kalau tidak disebut "
    'sama sekali, isi "Lainnya"; (2) title singkat & jelas, maksimal 8 kata, bahasa '
    "sesuai sumber; (3) UTS/UAS/ujian -> exam, kuis -> quiz, selain itu assignment; "
    "(4) difficulty perkiraan dari beban tugasnya, default medium; (5) tanggal relatif "
    '("besok", "Jumat depan") diubah ke tanggal pasti berdasarkan tanggal hari ini yang '
    "diberikan; kalau jam deadline disebut, sertakan jamnya (waktu lokal mahasiswa); "
    'kalau tidak ada tanggal, null. Kalau tidak ada tugas sama sekali, balas {"tasks": []}.'
)


def detect_image_mime(data: bytes) -> str | None:
    """Cek format dari isi file (magic bytes), bukan dari nama/header yg bisa ngibul."""
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return None


def build_snap_content(
    *,
    image: bytes | None,
    image_mime: str | None,
    text: str | None,
    course_names: list[str],
) -> list[dict[str, Any]]:
    today = datetime.now(settings.tz).strftime("%Y-%m-%d (%A)")
    courses = ", ".join(course_names) if course_names else "(belum ada)"
    intro = f"Hari ini: {today}.\nMata kuliah milik mahasiswa: {courses}."
    if text:
        intro += f"\n\nTeks pengumuman:\n{text}"
    intro += "\n\nEkstrak daftar tugasnya."
    parts: list[dict[str, Any]] = [{"type": "text", "text": intro}]
    if image is not None and image_mime is not None:
        b64 = base64.b64encode(image).decode("ascii")
        parts.append({"type": "image_url", "image_url": {"url": f"data:{image_mime};base64,{b64}"}})
    return parts


def _with_local_tz(item: Any) -> Any:
    """ "2026-10-10T14:00" tanpa zona = jam lokal mahasiswa (WIB), bukan UTC."""
    if not isinstance(item, dict):
        return item
    due = item.get("due_date")
    if isinstance(due, str) and "T" in due:
        try:
            parsed = datetime.fromisoformat(due.strip())
        except ValueError:
            return {**item, "due_date": None}
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=settings.tz)
        return {**item, "due_date": parsed.astimezone(timezone.utc).isoformat()}
    return item


async def extract_from_snap(
    *,
    image: bytes | None,
    image_mime: str | None,
    text: str | None,
    course_names: list[str],
) -> list[TaskCandidate]:
    """Lempar GroqUnavailable kalo AI-nya gak bisa dipanggil — beda sama extract dari
    chat, fitur ini gak ada gunanya tanpa AI, jadi user mesti dikasih tau."""
    raw = await complete_json(
        SNAP_SYSTEM_PROMPT,
        build_snap_content(
            image=image, image_mime=image_mime, text=text, course_names=course_names
        ),
        temperature=0.0,
        model=settings.groq_vision_model if image is not None else None,
    )
    items = raw.get("tasks") if isinstance(raw, dict) else raw
    if not isinstance(items, list):
        return []
    candidates: list[TaskCandidate] = []
    for item in items:
        try:
            candidates.append(TaskCandidate.model_validate(_with_local_tz(item)))
        except (ValueError, TypeError):
            continue  # skip yg gak valid aja
    return candidates[:20]
