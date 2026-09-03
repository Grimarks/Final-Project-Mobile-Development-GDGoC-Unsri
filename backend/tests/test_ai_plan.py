"""Test logika prioritas + endpoint /ai/plan (jalur heuristik, tanpa memanggil Groq)."""
from datetime import datetime, timedelta, timezone

import pytest

from app.models.course import Course
from app.models.task import Task
from app.schemas.ai import PlanRequest
from app.services.planning_service import (
    build_plan_heuristic,
    priority_label,
    priority_score,
    rank_tasks,
)


def _task(**kw) -> Task:
    now = datetime.now(timezone.utc)
    defaults = dict(
        id=1,
        user_id=1,
        title="T",
        type="assignment",
        difficulty="medium",
        status="not_started",
        progress_pct=0,
        due_date=now + timedelta(days=3),
    )
    defaults.update(kw)
    return Task(**defaults)


# --------------------------- unit: skor prioritas --------------------------- #
def test_done_task_scores_zero():
    assert priority_score(_task(status="done")) == 0.0


def test_closer_deadline_scores_higher():
    soon = priority_score(_task(due_date=datetime.now(timezone.utc) + timedelta(hours=2)))
    later = priority_score(_task(due_date=datetime.now(timezone.utc) + timedelta(days=10)))
    assert soon > later


def test_harder_task_scores_higher_at_same_deadline():
    due = datetime.now(timezone.utc) + timedelta(days=2)
    assert priority_score(_task(difficulty="hard", due_date=due)) > priority_score(
        _task(difficulty="easy", due_date=due)
    )


def test_exam_outranks_quiz():
    due = datetime.now(timezone.utc) + timedelta(days=2)
    assert priority_score(_task(type="exam", due_date=due)) > priority_score(
        _task(type="quiz", due_date=due)
    )


def test_progress_reduces_score():
    due = datetime.now(timezone.utc) + timedelta(days=2)
    assert priority_score(_task(progress_pct=90, due_date=due)) < priority_score(
        _task(progress_pct=0, due_date=due)
    )


def test_task_without_due_date_still_scored():
    assert 0 < priority_score(_task(due_date=None)) < 100


def test_score_is_bounded():
    overdue = _task(
        type="exam", difficulty="hard", due_date=datetime.now(timezone.utc) - timedelta(days=5)
    )
    assert 0 <= priority_score(overdue) <= 100


def test_priority_labels():
    assert priority_label(80) == "high"
    assert priority_label(30) == "medium"
    assert priority_label(5) == "low"


def test_rank_tasks_excludes_done_and_sorts():
    urgent = _task(id=1, difficulty="hard", due_date=datetime.now(timezone.utc))
    relaxed = _task(id=2, difficulty="easy", due_date=datetime.now(timezone.utc) + timedelta(days=14))
    finished = _task(id=3, status="done")
    ranked = rank_tasks([relaxed, finished, urgent])
    assert [t.id for t in ranked] == [1, 2]


# --------------------------- unit: penyusun jadwal -------------------------- #
def test_heuristic_plan_respects_time_budget():
    tasks = [_task(id=i, difficulty="hard") for i in range(1, 6)]
    plan = build_plan_heuristic(tasks, PlanRequest(available_hours=2.0, start_hour=9))
    assert sum(b.duration_minutes for b in plan.blocks) <= 120
    assert plan.generated_by == "heuristic"


def test_heuristic_plan_starts_at_requested_hour():
    plan = build_plan_heuristic([_task()], PlanRequest(available_hours=3, start_hour=13))
    assert plan.blocks[0].start_time == "13:00"


def test_heuristic_plan_inherits_course_color():
    course = Course(id=1, user_id=1, name="MATH 210", color="#FF8A3D")
    task = _task()
    task.course = course
    plan = build_plan_heuristic([task], PlanRequest())
    assert plan.blocks[0].color == "#FF8A3D"


def test_no_open_tasks_gives_empty_plan():
    plan = build_plan_heuristic([_task(status="done")], PlanRequest())
    assert plan.blocks == []


# --------------------------- integrasi: endpoint ---------------------------- #
@pytest.mark.asyncio
async def test_plan_endpoint_end_to_end(auth_client):
    course = (await auth_client.post("/courses", json={"name": "CS 301", "color": "#4C6FFF"})).json()
    for title, diff in [("Problem Set 4", "hard"), ("Chapter 7", "medium")]:
        await auth_client.post(
            "/tasks",
            json={"title": title, "course_id": course["id"], "difficulty": diff},
        )

    resp = await auth_client.post("/ai/plan", json={"available_hours": 3.5, "start_hour": 9})
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["open_task_count"] == 2
    assert body["generated_by"] == "heuristic"  # GROQ_API_KEY kosong saat test
    assert len(body["blocks"]) == 2
    assert body["blocks"][0]["start_time"] == "09:00"


@pytest.mark.asyncio
async def test_plan_requires_auth(client):
    assert (await client.post("/ai/plan", json={})).status_code == 401


@pytest.mark.asyncio
async def test_plan_is_archived(auth_client, db_session):
    from sqlalchemy import select

    from app.models.ai_generated import AIGenerated

    await auth_client.post("/tasks", json={"title": "A"})
    await auth_client.post("/ai/plan", json={"available_hours": 2})
    rows = (await db_session.execute(select(AIGenerated))).scalars().all()
    assert len(rows) == 1
    assert rows[0].type == "plan"
