"""Input suara: rekaman -> Whisper (di-fake) -> ekstraksi task (di-fake)."""
import pytest

from app.routers import ai as ai_router
from app.services import snap_service

# header MP4/M4A minimal: 4 byte ukuran box + "ftyp"
_M4A = b"\x00\x00\x00\x20ftypM4A " + b"\x00" * 64


def test_detect_audio_ext():
    assert snap_service.detect_audio_ext(_M4A) == "m4a"
    assert snap_service.detect_audio_ext(b"OggS\x00rest") == "ogg"
    assert snap_service.detect_audio_ext(b"RIFF\x00\x00\x00\x00WAVEfmt ") == "wav"
    assert snap_service.detect_audio_ext(b"ID3\x04rest") == "mp3"
    assert snap_service.detect_audio_ext(b"\x1a\x45\xdf\xa3rest") == "webm"
    assert snap_service.detect_audio_ext(b"%PDF-1.4") is None


@pytest.mark.asyncio
async def test_voice_requires_auth(client):
    resp = await client.post("/ai/snap/voice", files={"audio": ("v.m4a", _M4A, "audio/m4a")})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_voice_rejects_unknown_format(auth_client):
    resp = await auth_client.post(
        "/ai/snap/voice", files={"audio": ("v.m4a", b"bukan audio", "audio/m4a")}
    )
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_voice_without_groq_returns_503(auth_client):
    resp = await auth_client.post("/ai/snap/voice", files={"audio": ("v.m4a", _M4A, "audio/m4a")})
    assert resp.status_code == 503


@pytest.mark.asyncio
async def test_voice_transcribes_then_extracts(auth_client, monkeypatch):
    calls = {}

    async def fake_transcribe(audio, filename):
        calls["filename"] = filename
        return "Besok ada kuis basis data bab normalisasi"

    async def fake_llm(system_prompt, user_content, **kwargs):
        calls["text"] = user_content[0]["text"]
        calls["model"] = kwargs["model"]
        return {"tasks": [{"course": "Basis Data", "title": "Kuis normalisasi", "type": "quiz"}]}

    monkeypatch.setattr(ai_router, "transcribe", fake_transcribe)
    monkeypatch.setattr(snap_service, "complete_json", fake_llm)

    resp = await auth_client.post("/ai/snap/voice", files={"audio": ("v.bin", _M4A, "audio/m4a")})
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["transcript"] == "Besok ada kuis basis data bab normalisasi"
    assert [t["title"] for t in body["tasks"]] == ["Kuis normalisasi"]
    # ekstensi dari isi file, bukan nama file kiriman
    assert calls["filename"] == "voice.m4a"
    assert "kuis basis data" in calls["text"]
    assert calls["model"] is None  # teks -> model teks biasa


@pytest.mark.asyncio
async def test_voice_silence_returns_empty(auth_client, monkeypatch):
    async def fake_transcribe(audio, filename):
        return ""

    monkeypatch.setattr(ai_router, "transcribe", fake_transcribe)
    resp = await auth_client.post("/ai/snap/voice", files={"audio": ("v.m4a", _M4A, "audio/m4a")})
    assert resp.status_code == 200
    assert resp.json() == {"tasks": [], "transcript": ""}
