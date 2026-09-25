"""Chat multi-turn AI Planner. Ini cuma buat gali preferensi user (jam luang, mood,
gaya belajar) — bukan tempat AI ngarang-ngarang task, itu urusannya build_plan()."""
from __future__ import annotations

import re
from dataclasses import dataclass
from datetime import datetime, timezone

from app.models.chat_message import ChatMessage
from app.schemas.ai import TaskCandidate
from app.services.groq_service import GroqUnavailable, complete_json, complete_text

SYSTEM_PROMPT = (
    "Kamu adalah asisten perencana belajar yang ramah untuk aplikasi CampusFlow. "
    "Tugasmu di percakapan ini menggali informasi dari mahasiswa SEBELUM jadwal dibuat, "
    "dalam urutan prioritas ini: (1) PALING PENTING — mata kuliah/course apa yang mau "
    "dikerjakan DAN tugas konkretnya apa (misal: latihan soal, baca bab 3, bikin ringkasan "
    "materi); tanpa ini AI generate plan tidak akan punya apa pun untuk dijadwalkan, jadi "
    "tanyakan ini LEBIH DULU kalau belum disebutkan mahasiswa secara eksplisit; (2) berapa "
    "jam luang yang dia punya hari ini; (3) prioritas, mood, dan preferensi belajarnya. "
    "JANGAN mengarang atau mengasumsikan mata kuliah/tugas yang tidak disebutkan mahasiswa "
    "sendiri. JANGAN PERNAH menyusun, mencontohkan, atau menulis draf jadwal/blok "
    "waktu/tabel/daftar bernomor di sini — penyusunan jadwal sungguhan terjadi di fitur "
    "terpisah setelah mahasiswa menekan tombol \"Generate plan\", bukan tugasmu di "
    "percakapan ini. Tulis teks polos tanpa markdown (tanpa tanda bintang). Balas SANGAT singkat (maksimal 2 kalimat pendek), hangat, dan ajukan "
    "satu pertanyaan lanjutan yang relevan bila informasinya belum cukup — utamakan "
    "menanyakan mata kuliah & tugas konkret dulu kalau itu yang belum jelas. Kalau "
    "informasinya sudah cukup, cukup bilang begitu dan arahkan mahasiswa menekan tombol "
    '"Generate plan from this chat" — jangan menyusun jadwalnya sendiri di sini.'
)

# jaga-jaga kalo Groq ngeyel gak nurut prompt & nulis draf jadwal panjang
_MAX_REPLY_CHARS = 420

# fallback pas Groq mati/gagal — jangan sampe user liat error mentah
_HEURISTIC_REPLIES = [
    "Oke, dicatat! Berapa jam luang yang kamu punya hari ini, dan mau mulai jam berapa?",
    "Baik. Ada tugas yang paling bikin kepikiran sekarang? Itu bisa jadi prioritas utama.",
    "Siap. Kalau informasinya sudah cukup, tekan \"Generate plan from this chat\" ya.",
]


def _heuristic_reply(user_turn_index: int) -> str:
    return _HEURISTIC_REPLIES[user_turn_index % len(_HEURISTIC_REPLIES)]


def _to_groq_messages(history: list[ChatMessage]) -> list[dict[str, str]]:
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    messages.extend({"role": m.role, "content": m.content} for m in history)
    return messages


def _clip(text: str) -> str:
    if len(text) <= _MAX_REPLY_CHARS:
        return text
    return text[:_MAX_REPLY_CHARS].rsplit(" ", 1)[0].rstrip(".,;:—-") + "…"


async def reply_to(history: list[ChatMessage]) -> tuple[str, str]:
    """`history` udah termasuk pesan user terbaru, urut waktu. Balikin (reply, generated_by)."""
    try:
        # jatah longgar krn token reasoning ikut diitung, panjang balasan tetep dijaga _clip()
        text = await complete_text(_to_groq_messages(history), max_tokens=1024)
        if not text:
            raise ValueError("Groq mengembalikan balasan kosong")
        return _clip(text), "groq"
    except (GroqUnavailable, ValueError):
        user_turns = sum(1 for m in history if m.role == "user")
        return _heuristic_reply(user_turns - 1), "heuristic"


# extract course/task dari chat, buat opsi "Talk to me" (AI ngurus semuanya)
EXTRACT_SYSTEM_PROMPT = (
    "Kamu membaca percakapan antara mahasiswa dan asisten perencana belajar. Tugasmu: "
    "ekstrak daftar kegiatan belajar/tugas akademik yang ingin dikerjakan mahasiswa. "
    "Setiap mata kuliah yang mahasiswa bilang mau dipelajari/dikerjakan DIHITUNG sebagai "
    "tugas, walaupun kegiatannya umum. Contoh: \"aku mau belajar Matematika Dasar, "
    "latihan saja\" -> {\"course\": \"Matematika Dasar\", \"title\": \"Latihan soal "
    "Matematika Dasar\"}; \"besok kuis Fisika bab 2\" -> {\"course\": \"Fisika\", "
    "\"title\": \"Belajar kuis bab 2\", \"type\": \"quiz\"}. JANGAN mengarang mata kuliah "
    "yang tidak disebut mahasiswa, dan jangan ambil contoh yang hanya disebut AI. "
    "Kamu HANYA membalas dengan JSON valid, tanpa penjelasan tambahan dan tanpa markdown "
    'fence. Format: {"tasks": [{"course": str, "title": str, '
    '"type": "assignment"|"exam"|"quiz", "difficulty": "easy"|"medium"|"hard", '
    '"due_date": "YYYY-MM-DD" atau null}]}. '
    "Nama course pakai kapitalisasi rapi (Title Case). title singkat & jelas, maksimal "
    "8 kata. Kalau tanggal disebut relatif (\"besok\", \"minggu depan\"), ubah ke "
    "YYYY-MM-DD berdasarkan tanggal hari ini yang diberikan di bawah; kalau tidak disebut, "
    'null. Kalau mahasiswa sama sekali tidak menyebut mata kuliah apa pun, balas '
    '{"tasks": []}.'
)


def build_extract_prompt(history: list[ChatMessage]) -> str:
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    lines = [f"{'Mahasiswa' if m.role == 'user' else 'AI'}: {m.content}" for m in history]
    conversation = "\n".join(lines) if lines else "(percakapan kosong)"
    return f"Hari ini: {today}\n\nPercakapan:\n{conversation}\n\nEkstrak daftar tugasnya."


async def extract_tasks(history: list[ChatMessage]) -> list[TaskCandidate]:
    """Usul task/course dari histori chat. Gagal -> list kosong aja, jangan error ke
    user — ini best-effort, bukan jalur kritis kayak build_plan."""
    if not history:
        return []
    try:
        # LLM kadang iseng bales kosong padahal jelas2 ada matkul yg disebut,
        # jadi kalo kosong coba sekali lagi
        for _ in range(2):
            raw = await complete_json(
                EXTRACT_SYSTEM_PROMPT, build_extract_prompt(history), temperature=0.0
            )
            items = raw.get("tasks") if isinstance(raw, dict) else raw
            if not isinstance(items, list):
                continue
            candidates: list[TaskCandidate] = []
            for item in items:
                try:
                    candidates.append(TaskCandidate.model_validate(item))
                except (ValueError, TypeError):
                    continue  # skip yg gak valid aja, jangan gagalin semuanya
            if candidates:
                return candidates
        return []
    except (GroqUnavailable, ValueError, TypeError, AttributeError):
        return []


def history_to_context(history: list[ChatMessage]) -> str:
    """Seluruh percakapan sebagai teks, buat konteks build_plan (gak dipotong 300
    karakter kayak preference — dulu info jam luang di akhir chat malah kebuang)."""
    return "\n".join(
        f"{'Mahasiswa' if m.role == 'user' else 'AI'}: {m.content}" for m in history
    )


@dataclass
class TimeWindow:
    start_minutes: int | None = None  # menit dari 00:00
    end_minutes: int | None = None
    hours: float | None = None


_PERIOD = r"(pagi|siang|sore|malam)"
_CLOCK = r"(\d{1,2})(?:[.:](\d{2}))?"
_RANGE_RE = re.compile(
    rf"(jam|pukul)?\s*{_CLOCK}\s*{_PERIOD}?\s*"
    r"(?:-|–|—|s/d|sd|sampai|sampe|hingga|ke|to|until)\s*"
    rf"(?:jam|pukul)?\s*{_CLOCK}\s*{_PERIOD}?",
    re.IGNORECASE,
)
_HOURS_RE = re.compile(r"(?<![:.\d])(\d{1,2}(?:[.,]\d)?)\s*jam\b", re.IGNORECASE)


def to_24h(hour: int, period: str | None) -> int:
    period = (period or "").lower()
    if period == "siang" and hour <= 6:
        return hour + 12  # jam 1 siang = 13
    if period in ("sore", "malam") and 1 <= hour < 12:
        return hour + 12
    return hour


def parse_time_window(history: list[ChatMessage]) -> TimeWindow:
    """Cari jam luang dari pesan user, deterministik (gak nebak pake AI).
    "jam 10.00 - 13.00", "10-13", "jam 1 siang sampai 3 sore", "punya 3 jam".
    Kalo disebut berkali-kali, yg PALING BARU yg dipake."""
    window = TimeWindow()
    for msg in history:
        if msg.role != "user":
            continue
        text = msg.content
        for m in _RANGE_RE.finditer(text):
            prefix, h1, m1, p1, h2, m2, p2 = m.groups()
            # "3 - 4 soal" jangan ke-parse jadi jam: wajib ada penanda waktu
            if not (prefix or m1 or m2 or p1 or p2):
                continue
            start_h, end_h = to_24h(int(h1), p1 or p2), to_24h(int(h2), p2)
            if start_h > 24 or end_h > 24:
                continue
            start = start_h * 60 + int(m1 or 0)
            end = end_h * 60 + int(m2 or 0)
            if end <= start and end_h < 12 and not p2:
                end += 12 * 60  # "10 - 1" maksudnya 10:00-13:00
            if end <= start or end > 24 * 60:
                continue
            window.start_minutes, window.end_minutes = start, end
            window.hours = None
        for m in _HOURS_RE.finditer(_RANGE_RE.sub(" ", text)):
            hours = float(m.group(1).replace(",", "."))
            if 0.5 <= hours <= 16:
                window.hours = hours
    return window
