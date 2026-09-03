"""Test AI mengurus course/task dari chat (POST /ai/chat/extract-tasks, /ai/chat/confirm-tasks)."""
import pytest
from sqlalchemy import select

from app.models.course import Course
from app.models.task import Task
from app.services.chat_service import extract_tasks


@pytest.mark.asyncio
async def test_extract_tasks_empty_when_no_history():
    assert await extract_tasks([]) == []


@pytest.mark.asyncio
async def test_extract_tasks_endpoint_empty_when_groq_unavailable(auth_client):
    """GROQ_API_KEY kosong saat test -> extract_tasks() heuristik: selalu list kosong,

    bukan error ke user (lihat conftest.py: GROQ_API_KEY dipaksa kosong).
    """
    await auth_client.post("/ai/chat/message", json={"message": "Aku ada tugas CS 301"})
    resp = await auth_client.post("/ai/chat/extract-tasks")
    assert resp.status_code == 200, resp.text
    assert resp.json() == {"tasks": []}


@pytest.mark.asyncio
async def test_extract_tasks_requires_auth(client):
    assert (await client.post("/ai/chat/extract-tasks")).status_code == 401


@pytest.mark.asyncio
async def test_confirm_tasks_creates_course_and_task(auth_client, db_session):
    resp = await auth_client.post(
        "/ai/chat/confirm-tasks",
        json={
            "tasks": [
                {
                    "course": "CS 301",
                    "title": "Problem Set 4",
                    "type": "assignment",
                    "difficulty": "hard",
                    "due_date": None,
                }
            ]
        },
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert len(body) == 1
    assert body[0]["title"] == "Problem Set 4"
    assert body[0]["course_name"] == "CS 301"
    assert body[0]["difficulty"] == "hard"
    assert body[0]["status"] == "not_started"

    courses = (await db_session.execute(select(Course))).scalars().all()
    tasks = (await db_session.execute(select(Task))).scalars().all()
    assert len(courses) == 1
    assert len(tasks) == 1

    # Task ini juga harus muncul di Tasks tab biasa (bukan cuma dipakai plan sekali pakai).
    list_resp = await auth_client.get("/tasks")
    assert any(t["title"] == "Problem Set 4" for t in list_resp.json())


@pytest.mark.asyncio
async def test_confirm_tasks_reuses_existing_course_case_insensitive(auth_client, db_session):
    await auth_client.post("/courses", json={"name": "CS 301", "color": "#4C6FFF"})

    resp = await auth_client.post(
        "/ai/chat/confirm-tasks",
        json={"tasks": [{"course": "cs 301", "title": "Chapter 7"}]},
    )
    assert resp.status_code == 200, resp.text

    courses = (await db_session.execute(select(Course))).scalars().all()
    assert len(courses) == 1  # tidak membuat course duplikat


@pytest.mark.asyncio
async def test_confirm_tasks_requires_auth(client):
    resp = await client.post(
        "/ai/chat/confirm-tasks", json={"tasks": [{"course": "X", "title": "Y"}]}
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_confirm_tasks_rejects_empty_list(auth_client):
    resp = await auth_client.post("/ai/chat/confirm-tasks", json={"tasks": []})
    assert resp.status_code == 422
