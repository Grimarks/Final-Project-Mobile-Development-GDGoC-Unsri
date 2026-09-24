"""Chat multi-turn AI Planner. Ini cuma buat gali preferensi user (jam luang, mood,
gaya belajar) — bukan tempat AI ngarang-ngarang task, itu urusannya build_plan()."""
from __future__ import annotations

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
    "ekstrak daftar tugas akademik KONKRET yang disebutkan mahasiswa secara eksplisit — "
    "JANGAN mengarang tugas yang tidak disebutkan di percakapan. Kamu HANYA membalas "
    "dengan JSON valid, tanpa penjelasan tambahan dan tanpa markdown fence. "
    'Format: {"tasks": [{"course": str, "title": str, '
    '"type": "assignment"|"exam"|"quiz", "difficulty": "easy"|"medium"|"hard", '
    '"due_date": "YYYY-MM-DD" atau null}]}. '
    "Field \"course\" wajib diisi (perkirakan dari konteks kalau mata kuliahnya tidak "
    "eksplisit disebut, jangan dikosongkan). Kalau tanggal disebut relatif "
    '("besok", "minggu depan"), ubah ke YYYY-MM-DD berdasarkan tanggal hari ini yang '
    'diberikan di bawah. Kalau mahasiswa tidak menyebutkan tugas/mata kuliah konkret '
    'apa pun, balas {"tasks": []} — jangan memaksakan hasil.'
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
        raw = await complete_json(EXTRACT_SYSTEM_PROMPT, build_extract_prompt(history))
        items = raw.get("tasks") if isinstance(raw, dict) else raw
        if not isinstance(items, list):
            return []
        candidates: list[TaskCandidate] = []
        for item in items:
            try:
                candidates.append(TaskCandidate.model_validate(item))
            except (ValueError, TypeError):
                continue  # skip yg gak valid aja, jangan gagalin semuanya
        return candidates
    except (GroqUnavailable, ValueError, TypeError, AttributeError):
        return []


def history_to_preference(history: list[ChatMessage]) -> str:
    """Ringkes histori chat jadi teks preference buat `PlanRequest.preference`."""
    lines = [f"{'Mahasiswa' if m.role == 'user' else 'AI'}: {m.content}" for m in history]
    summary = " | ".join(lines)
    max_len = 290  # PlanRequest.preference max_length=300
    if len(summary) > max_len:
        summary = summary[: max_len - 1].rstrip() + "…"
    return summary
