"""Test POST /ai/plan/adjust (jalur fallback, GROQ_API_KEY kosong saat test)."""
import pytest
from sqlalchemy import select

from app.models.ai_generated import AIGenerated


@pytest.mark.asyncio
async def test_adjust_without_active_plan_returns_404(auth_client):
    resp = await auth_client.post("/ai/plan/adjust", json={"instruction": "geser ke sore"})
    assert resp.status_code == 404
    assert "plan aktif" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_adjust_falls_back_to_old_plan_when_groq_unavailable(auth_client, db_session):
    await auth_client.post("/tasks", json={"title": "Problem Set 4", "difficulty": "hard"})
    plan_resp = await auth_client.post("/ai/plan", json={"available_hours": 3, "start_hour": 9})
    assert plan_resp.status_code == 200
    old_blocks = plan_resp.json()["blocks"]

    resp = await auth_client.post("/ai/plan/adjust", json={"instruction": "cuma 1 jam sekarang"})
    assert resp.status_code == 200, resp.text
    body = resp.json()

    # GROQ_API_KEY kosong saat test -> adjust gagal, plan lama dikembalikan apa adanya.
    assert body["adjusted"] is False
    assert body["error"]
    assert body["blocks"] == old_blocks

    # Fallback tidak boleh menyimpan baris ai_generated baru; hanya baris /ai/plan awal.
    rows = (await db_session.execute(select(AIGenerated))).scalars().all()
    assert len(rows) == 1


@pytest.mark.asyncio
async def test_adjust_uses_latest_plan_row(auth_client, db_session):
    """Adjust harus mengambil baris ai_generated type='plan' TERAKHIR, histori lama tidak terhapus."""
    await auth_client.post("/tasks", json={"title": "Chapter 7"})
    await auth_client.post("/ai/plan", json={"available_hours": 2})
    await auth_client.post("/ai/plan", json={"available_hours": 4})  # plan kedua jadi "aktif"

    resp = await auth_client.post("/ai/plan/adjust", json={"instruction": "tambahkan jeda"})
    assert resp.status_code == 200, resp.text

    rows = (await db_session.execute(select(AIGenerated))).scalars().all()
    # 2 plan awal masih ada (tidak terhapus) + fallback tidak menambah baris baru saat gagal.
    assert len(rows) == 2
    assert all(r.type == "plan" for r in rows)


@pytest.mark.asyncio
async def test_adjust_requires_auth(client):
    resp = await client.post("/ai/plan/adjust", json={"instruction": "x"})
    assert resp.status_code == 401
