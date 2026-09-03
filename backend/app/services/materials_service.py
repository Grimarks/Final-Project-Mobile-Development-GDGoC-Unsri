"""Ekstrak teks PDF + bikin ringkasan & kuis lewat Groq (ada fallback-nya)."""
from __future__ import annotations

import io
import re

from pypdf import PdfReader

from app.schemas.ai import QuizQuestion, QuizResponse, SummaryResponse
from app.services.groq_service import GroqUnavailable, complete_json

MAX_CHARS_TO_LLM = 12_000  # potong biar gak kelebihan context window


def extract_pdf_text(data: bytes) -> str:
    """Ambil teks dari semua halaman PDF. Kalo PDF-nya hasil scan, ya kosong."""
    reader = PdfReader(io.BytesIO(data))
    pages = []
    for page in reader.pages:
        try:
            pages.append(page.extract_text() or "")
        except Exception:  # noqa: BLE001 - halaman rusak jangan sampe gagalin upload
            pages.append("")
    text = "\n".join(pages)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def _sentences(text: str) -> list[str]:
    return [s.strip() for s in re.split(r"(?<=[.!?])\s+", text) if len(s.strip()) > 40]


SUMMARY_SYSTEM = (
    "Kamu meringkas materi kuliah. Balas HANYA JSON valid: "
    '{"summary": str, "key_points": [str, ...]}. '
    "Ringkasan maksimal 6 kalimat, key_points 3-6 butir, gunakan bahasa materi aslinya."
)

QUIZ_SYSTEM = (
    "Kamu membuat kuis pilihan ganda dari materi kuliah. Balas HANYA JSON valid: "
    '{"questions": [{"question": str, "options": [str, str, str, str], '
    '"correct_index": int, "explanation": str}]}. '
    "Buat 5 soal, 4 opsi tiap soal, correct_index adalah indeks 0-3."
)


async def summarize(material_id: int, text: str) -> SummaryResponse:
    if not text.strip():
        return SummaryResponse(
            generated_by="heuristic",
            material_id=material_id,
            summary="Tidak ada teks yang bisa diekstrak dari file ini (kemungkinan PDF hasil scan).",
            key_points=[],
        )

    try:
        raw = await complete_json(SUMMARY_SYSTEM, text[:MAX_CHARS_TO_LLM])
        return SummaryResponse(
            generated_by="groq",
            material_id=material_id,
            summary=str(raw["summary"]),
            key_points=[str(p) for p in raw.get("key_points", [])][:6],
        )
    except (GroqUnavailable, KeyError, TypeError, ValueError):
        sents = _sentences(text)
        return SummaryResponse(
            generated_by="heuristic",
            material_id=material_id,
            summary=" ".join(sents[:4]) or text[:400],
            key_points=[s[:120] for s in sents[4:9]],
        )


async def make_quiz(material_id: int, text: str) -> QuizResponse:
    try:
        raw = await complete_json(QUIZ_SYSTEM, text[:MAX_CHARS_TO_LLM], temperature=0.5)
        questions = [QuizQuestion.model_validate(q) for q in raw["questions"]][:10]
        if not questions:
            raise ValueError("kuis kosong")
        return QuizResponse(
            generated_by="groq", material_id=material_id, questions=questions
        )
    except (GroqUnavailable, KeyError, TypeError, ValueError):
        # fallback ecek-ecek: bikin soal dari kalimat-kalimat pertama materinya
        sents = _sentences(text)[:3]
        questions = [
            QuizQuestion(
                question=f"Konsep apa yang dibahas pada bagian: “{s[:90]}…”?",
                options=["Konsep utama materi", "Tidak dibahas", "Hanya contoh soal", "Daftar pustaka"],
                correct_index=0,
                explanation="Kuis otomatis tidak tersedia (GROQ_API_KEY belum diisi).",
            )
            for s in sents
        ]
        return QuizResponse(
            generated_by="heuristic", material_id=material_id, questions=questions
        )
