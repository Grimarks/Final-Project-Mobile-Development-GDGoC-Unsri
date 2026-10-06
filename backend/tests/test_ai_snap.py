"""Snap & Go: foto/teks pengumuman -> usulan task. Groq di-fake lewat monkeypatch,
GROQ_API_KEY kosong saat test jadi jalur aslinya 503."""
import pytest

from app.services import snap_service


_PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64


def _fake_llm(tasks, calls=None):
    async def fake(system_prompt, user_content, **kwargs):
        if calls is not None:
            calls.append((user_content, kwargs))
        return {"tasks": tasks}

    return fake


def test_detect_image_mime():
    assert snap_service.detect_image_mime(b"\xff\xd8\xff\xe0rest") == "image/jpeg"
    assert snap_service.detect_image_mime(_PNG) == "image/png"
    assert snap_service.detect_image_mime(b"RIFF\x00\x00\x00\x00WEBPVP8 ") == "image/webp"
    assert snap_service.detect_image_mime(b"%PDF-1.4") is None


@pytest.mark.asyncio
async def test_snap_requires_auth(client):
    resp = await client.post("/ai/snap/extract", data={"text": "tugas"})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_snap_rejects_empty_request(auth_client):
    resp = await auth_client.post("/ai/snap/extract", data={"text": "   "})
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_snap_rejects_non_image_file(auth_client):
    resp = await auth_client.post(
        "/ai/snap/extract", files={"image": ("x.jpg", b"%PDF-1.4 bukan gambar", "image/jpeg")}
    )
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_snap_rejects_oversized_image(auth_client):
    big = _PNG + b"\x00" * (3 * 1024 * 1024)
    resp = await auth_client.post(
        "/ai/snap/extract", files={"image": ("big.png", big, "image/png")}
    )
    assert resp.status_code == 413


@pytest.mark.asyncio
async def test_snap_without_groq_returns_503(auth_client):
    resp = await auth_client.post("/ai/snap/extract", data={"text": "Kuis fisika besok"})
    assert resp.status_code == 503


@pytest.mark.asyncio
async def test_snap_image_uses_vision_model_and_course_names(auth_client, monkeypatch):
    await auth_client.post("/courses", json={"name": "Kalkulus II", "color": "#4C6FFF"})
    calls = []
    monkeypatch.setattr(
        snap_service,
        "complete_json",
        _fake_llm(
            [{"course": "Kalkulus II", "title": "Latihan bab 4", "due_date": "2026-10-10"}],
            calls,
        ),
    )

    resp = await auth_client.post(
        "/ai/snap/extract", files={"image": ("snap.png", _PNG, "image/png")}
    )
    assert resp.status_code == 200, resp.text
    tasks = resp.json()["tasks"]
    assert [t["title"] for t in tasks] == ["Latihan bab 4"]
    # tanggal polos = akhir hari WIB
    assert tasks[0]["due_date"].startswith("2026-10-10T16:59")

    content, kwargs = calls[0]
    assert kwargs["model"] == snap_service.settings.groq_vision_model
    assert content[1]["image_url"]["url"].startswith("data:image/png;base64,")
    assert "Kalkulus II" in content[0]["text"]


@pytest.mark.asyncio
async def test_snap_text_with_local_time_and_skips_existing(auth_client, monkeypatch):
    course = (await auth_client.post("/courses", json={"name": "Fisika"})).json()
    await auth_client.post("/tasks", json={"title": "Kuis bab 2", "course_id": course["id"]})
    calls = []
    monkeypatch.setattr(
        snap_service,
        "complete_json",
        _fake_llm(
            [
                {"course": "Fisika", "title": "Kuis bab 2", "type": "quiz"},
                {"course": "Fisika", "title": "Laporan praktikum", "due_date": "2026-10-10T14:00"},
                {"course": "", "title": "invalid tanpa course"},
            ],
            calls,
        ),
    )

    resp = await auth_client.post(
        "/ai/snap/extract", data={"text": "Laporan praktikum fisika kumpul Sabtu jam 2 siang"}
    )
    assert resp.status_code == 200, resp.text
    tasks = resp.json()["tasks"]
    # yg udah ada sebagai task terbuka & yg invalid dibuang
    assert [t["title"] for t in tasks] == ["Laporan praktikum"]
    # jam 14:00 WIB = 07:00 UTC
    assert tasks[0]["due_date"].startswith("2026-10-10T07:00")
    # teks doang -> model teks biasa, bukan vision
    assert calls[0][1]["model"] is None
