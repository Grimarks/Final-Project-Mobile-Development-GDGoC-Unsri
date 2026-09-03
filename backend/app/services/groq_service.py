"""Wrapper tipis buat Groq API (OpenAI-compatible). Inget: JANGAN PERNAH percaya
JSON dari LLM mentah-mentah — divalidasi lagi pake Pydantic di pemanggilnya.
Kalo GROQ_API_KEY kosong / API-nya down, pemanggil jatoh ke heuristik lokal."""
from __future__ import annotations

import json
import logging
from typing import Any

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)


class GroqUnavailable(RuntimeError):
    """Dilempar kalo Groq belom dikonfig atau gagal dipanggil."""


def _extract_json(raw: str) -> Any:
    """Ambil JSON dari teks model, tahan banting kalo dibungkus ```json fence."""
    text = raw.strip()
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    text = text.strip()
    start = min(
        (i for i in (text.find("{"), text.find("[")) if i != -1),
        default=-1,
    )
    if start > 0:
        text = text[start:]
    return json.loads(text)


async def complete_json(
    system_prompt: str,
    user_prompt: str,
    *,
    max_tokens: int = 1600,
    temperature: float = 0.3,
    retries: int = 2,
) -> Any:
    """Panggil Groq, balikin hasilnya yg udah diparse jadi objek Python."""
    if not settings.groq_enabled:
        raise GroqUnavailable("GROQ_API_KEY belum diisi")

    payload = {
        "model": settings.groq_model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": temperature,
        "max_tokens": max_tokens,
        "response_format": {"type": "json_object"},
    }
    headers = {"Authorization": f"Bearer {settings.groq_api_key}"}

    last_error: Exception | None = None
    async with httpx.AsyncClient(timeout=45.0) as client:
        for attempt in range(retries + 1):
            try:
                resp = await client.post(
                    f"{settings.groq_base_url}/chat/completions",
                    json=payload,
                    headers=headers,
                )
                resp.raise_for_status()
                content = resp.json()["choices"][0]["message"]["content"]
                return _extract_json(content)
            except (httpx.HTTPError, KeyError, ValueError, json.JSONDecodeError) as exc:
                last_error = exc
                logger.warning("Groq gagal (percobaan %s): %s", attempt + 1, exc)

    raise GroqUnavailable(f"Groq gagal setelah {retries + 1} percobaan: {last_error}")


async def complete_text(
    messages: list[dict[str, str]],
    *,
    max_tokens: int = 400,
    temperature: float = 0.6,
    retries: int = 2,
) -> str:
    """Kayak `complete_json` tapi buat chat multi-turn — kirim `messages` apa adanya
    (system prompt + histori) trus balikin teks biasa, gak diparsing JSON."""
    if not settings.groq_enabled:
        raise GroqUnavailable("GROQ_API_KEY belum diisi")

    payload = {
        "model": settings.groq_model,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
    }
    headers = {"Authorization": f"Bearer {settings.groq_api_key}"}

    last_error: Exception | None = None
    async with httpx.AsyncClient(timeout=45.0) as client:
        for attempt in range(retries + 1):
            try:
                resp = await client.post(
                    f"{settings.groq_base_url}/chat/completions",
                    json=payload,
                    headers=headers,
                )
                resp.raise_for_status()
                return resp.json()["choices"][0]["message"]["content"].strip()
            except (httpx.HTTPError, KeyError, ValueError) as exc:
                last_error = exc
                logger.warning("Groq gagal (percobaan %s): %s", attempt + 1, exc)

    raise GroqUnavailable(f"Groq gagal setelah {retries + 1} percobaan: {last_error}")
