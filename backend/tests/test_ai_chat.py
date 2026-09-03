"""Test chat multi-turn AI Planner (jalur heuristik, GROQ_API_KEY kosong saat test)."""
import pytest
from sqlalchemy import select

from app.models.chat_message import ChatMessage
from app.services.chat_service import _MAX_REPLY_CHARS, _clip


def test_clip_leaves_short_reply_untouched():
    assert _clip("Oke, dicatat!") == "Oke, dicatat!"


def test_clip_truncates_long_reply_at_word_boundary():
    # Jaring pengaman kalau Groq mengabaikan instruksi dan menulis draf jadwal panjang.
    long_reply = "Berikut contoh blok waktu. " * 40
    clipped = _clip(long_reply)

    assert len(clipped) <= _MAX_REPLY_CHARS + 1  # +1 untuk karakter "…"
    assert clipped.endswith("…")
    assert not clipped[:-1].endswith(" ")


@pytest.mark.asyncio
async def test_chat_message_is_stored_and_replied(auth_client, db_session):
    resp = await auth_client.post("/ai/chat/message", json={"message": "Aku punya 2 jam luang"})
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["reply"]
    assert body["generated_by"] == "heuristic"  # GROQ_API_KEY kosong saat test

    rows = (await db_session.execute(select(ChatMessage))).scalars().all()
    assert len(rows) == 2  # pesan user + balasan asisten
    assert rows[0].role == "user"
    assert rows[0].content == "Aku punya 2 jam luang"
    assert rows[1].role == "assistant"
    assert rows[1].content == body["reply"]


@pytest.mark.asyncio
async def test_chat_history_ordered(auth_client):
    await auth_client.post("/ai/chat/message", json={"message": "Halo"})
    await auth_client.post("/ai/chat/message", json={"message": "Aku ada tugas CS 301"})

    resp = await auth_client.get("/ai/chat/history")
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert len(body) == 4  # 2 pesan user + 2 balasan asisten
    assert body[0]["role"] == "user"
    assert body[0]["content"] == "Halo"
    assert body[2]["content"] == "Aku ada tugas CS 301"
    # urut waktu naik
    timestamps = [m["created_at"] for m in body]
    assert timestamps == sorted(timestamps)


@pytest.mark.asyncio
async def test_chat_history_empty_by_default(auth_client):
    resp = await auth_client.get("/ai/chat/history")
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.asyncio
async def test_delete_chat_history_clears_all(auth_client, db_session):
    await auth_client.post("/ai/chat/message", json={"message": "Halo"})

    resp = await auth_client.delete("/ai/chat/history")
    assert resp.status_code == 204

    rows = (await db_session.execute(select(ChatMessage))).scalars().all()
    assert rows == []

    resp = await auth_client.get("/ai/chat/history")
    assert resp.json() == []


@pytest.mark.asyncio
async def test_chat_requires_auth(client):
    assert (await client.post("/ai/chat/message", json={"message": "hi"})).status_code == 401
    assert (await client.get("/ai/chat/history")).status_code == 401
    assert (await client.delete("/ai/chat/history")).status_code == 401


@pytest.mark.asyncio
async def test_plan_from_chat_uses_heuristic_and_archives(auth_client, db_session):
    from sqlalchemy import select as sa_select

    from app.models.ai_generated import AIGenerated

    await auth_client.post("/ai/chat/message", json={"message": "Aku cuma punya 1 jam"})
    await auth_client.post("/tasks", json={"title": "Baca modul"})

    resp = await auth_client.post("/ai/plan/from-chat")
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["generated_by"] == "heuristic"
    assert body["open_task_count"] == 1

    rows = (await db_session.execute(sa_select(AIGenerated))).scalars().all()
    assert len(rows) == 1
    assert rows[0].type == "plan"
