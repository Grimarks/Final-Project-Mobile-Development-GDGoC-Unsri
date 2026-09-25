"""Jadwal harus ngikut jam luang user & nyambung ke task beneran (bug: chat bilang
10.00-13.00 tapi plan jam 09.00, blok hasil adjust gak jadi task pas di-accept)."""
import json

import pytest
from sqlalchemy import select

from app.models.ai_generated import AIGenerated
from app.models.chat_message import ChatMessage
from app.models.course import Course
from app.models.task import Task
from app.schemas.ai import PlanRequest, PlanResponse
from app.services import planning_service
from app.services.chat_service import parse_time_window
from app.services.planning_service import (
    adjust_plan,
    build_plan,
    build_plan_heuristic,
    parse_hhmm,
)


def _msg(text: str, role: str = "user") -> ChatMessage:
    return ChatMessage(role=role, content=text)


def _task(id: int, title: str = "T", difficulty: str = "hard") -> Task:
    return Task(
        id=id, user_id=1, title=title, type="assignment", difficulty=difficulty,
        status="not_started", progress_pct=0, due_date=None,
    )


# ------------------------------ parse jam luang ------------------------------ #
@pytest.mark.parametrize(
    "text, start, end",
    [
        ("aku setiap hari punya kebebasan selama 3 jam, jam 10.00 - 13.00", "10:00", "13:00"),
        ("jam 1 siang sampai 3 sore", "13:00", "15:00"),
        ("pukul 19.00-21.30", "19:00", "21:30"),
        ("jam 10 sampai 1", "10:00", "13:00"),
    ],
)
def test_parse_time_window(text, start, end):
    w = parse_time_window([_msg(text)])
    assert (w.start_minutes, w.end_minutes) == (parse_hhmm(start), parse_hhmm(end))


def test_parse_time_window_ignores_non_time_ranges_and_ai_messages():
    w = parse_time_window([_msg("ada 3 - 4 soal"), _msg("jam 08.00 - 09.00", role="assistant")])
    assert w.start_minutes is None


def test_parse_time_window_latest_mention_wins():
    w = parse_time_window([_msg("jam 08.00 - 09.00"), _msg("eh ralat, jam 14.00 - 16.00")])
    assert w.start_minutes == parse_hhmm("14:00")


def test_parse_hours_only():
    assert parse_time_window([_msg("aku cuma punya 2 jam")]).hours == 2.0


# ---------------------------- jadwal di dalam jendela ------------------------ #
def _assert_inside(plan: PlanResponse, start: str, end: str):
    lo, hi = parse_hhmm(start), parse_hhmm(end)
    prev_end = lo
    for b in plan.blocks:
        s, e = parse_hhmm(b.start_time), parse_hhmm(b.end_time)
        assert lo <= s < e <= hi, b
        assert s >= prev_end, "blok numpuk"
        assert b.duration_minutes == e - s
        prev_end = e


def test_heuristic_never_runs_past_window_including_breaks():
    tasks = [_task(i) for i in range(1, 6)]
    plan = build_plan_heuristic(tasks, PlanRequest(start_hour=10, available_hours=3))
    assert plan.start_time == "10:00" and plan.end_time == "13:00"
    _assert_inside(plan, "10:00", "13:00")


@pytest.mark.asyncio
async def test_llm_times_are_ignored_and_invented_tasks_dropped(monkeypatch):
    async def fake(system, prompt, **kw):
        assert "10:00-13:00" in prompt
        return {"blocks": [
            {"task_id": 999, "duration_minutes": 60, "reason": "ngarang"},
            {"task_id": 2, "duration_minutes": 60, "start_time": "09:00", "reason": "x"},
            {"task_id": 2, "duration_minutes": 60, "reason": "dobel"},
            {"task_id": 1, "duration_minutes": 500, "reason": "kepanjangan"},
        ]}

    monkeypatch.setattr(planning_service, "complete_json", fake)
    plan = await build_plan(
        [_task(1, "A"), _task(2, "B")], PlanRequest(start_hour=10, available_hours=3)
    )
    assert plan.generated_by == "groq"
    assert [b.task_id for b in plan.blocks] == [2, 1]
    assert plan.blocks[0].start_time == "10:00"
    _assert_inside(plan, "10:00", "13:00")


@pytest.mark.asyncio
async def test_adjust_keeps_blocks_in_window_and_allows_new_activity(monkeypatch):
    old = PlanResponse(
        generated_by="groq", available_hours=3, open_task_count=0, blocks=[],
        start_time="10:00", end_time="13:00",
    )

    async def fake(system, prompt, **kw):
        assert "Waktu luang mahasiswa: 10:00-13:00" in prompt
        return {"blocks": [{
            "task_id": None, "title": "Latihan soal", "course": "Matematika Dasar",
            "start_time": "09:00", "end_time": "10:00", "reason": "diminta",
        }]}

    monkeypatch.setattr(planning_service, "complete_json", fake)
    plan = await adjust_plan(old, "tambahin matematika dasar", [])
    assert plan.blocks[0].task_id is None
    assert plan.blocks[0].course == "Matematika Dasar"
    _assert_inside(plan, "10:00", "13:00")


# ------------------------------- endpoint -------------------------------------- #
@pytest.mark.asyncio
async def test_plan_from_chat_uses_time_window_from_chat(auth_client):
    await auth_client.post("/tasks", json={"title": "Latihan soal"})
    await auth_client.post(
        "/ai/chat/message", json={"message": "aku luang jam 10.00 - 13.00"}
    )
    resp = await auth_client.post("/ai/plan/from-chat")
    body = resp.json()
    assert body["start_time"] == "10:00" and body["end_time"] == "13:00"
    assert body["blocks"][0]["start_time"] == "10:00"
    assert body["plan_id"]


async def _seed_plan(db_session, user_id: int, blocks: list[dict]) -> int:
    row = AIGenerated(
        user_id=user_id, source_type="task_set", source_id=None, type="plan",
        content_json=json.dumps({
            "generated_by": "groq", "available_hours": 3, "open_task_count": 0,
            "blocks": blocks, "start_time": "10:00", "end_time": "13:00",
        }),
    )
    db_session.add(row)
    await db_session.commit()
    return row.id


@pytest.mark.asyncio
async def test_accept_creates_missing_tasks_and_shows_as_today(auth_client, db_session):
    me = (await auth_client.get("/auth/me")).json()
    existing = (await auth_client.post("/tasks", json={"title": "Baca bab 1"})).json()
    plan_id = await _seed_plan(db_session, me["id"], [
        {"task_id": existing["id"], "title": "Baca bab 1", "start_time": "10:00",
         "end_time": "11:00", "duration_minutes": 60},
        {"task_id": None, "title": "Latihan soal", "course": "Matematika Dasar",
         "start_time": "11:10", "end_time": "12:10", "duration_minutes": 60},
    ])
    assert (await auth_client.get("/ai/plan/today")).json() is None

    resp = await auth_client.post(f"/ai/plan/{plan_id}/accept")
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["accepted"] is True
    assert all(b["task_id"] for b in body["blocks"])
    assert body["blocks"][0]["task_id"] == existing["id"]

    new_task = (
        await db_session.execute(select(Task).where(Task.id == body["blocks"][1]["task_id"]))
    ).scalar_one()
    course = (await db_session.execute(select(Course).where(Course.id == new_task.course_id))).scalar_one()
    assert (new_task.title, course.name) == ("Latihan soal", "Matematika Dasar")

    today = (await auth_client.get("/ai/plan/today")).json()
    assert today["plan_id"] == plan_id

    # accept ulang gak bikin task dobel
    await auth_client.post(f"/ai/plan/{plan_id}/accept")
    tasks = (await auth_client.get("/tasks")).json()
    assert len(tasks) == 2


@pytest.mark.asyncio
async def test_accept_other_users_plan_is_404(auth_client, db_session):
    plan_id = await _seed_plan(db_session, 9999, [
        {"task_id": None, "title": "X", "start_time": "10:00", "end_time": "11:00",
         "duration_minutes": 60},
    ])
    assert (await auth_client.post(f"/ai/plan/{plan_id}/accept")).status_code == 404


@pytest.mark.asyncio
async def test_adjust_restores_dropped_blocks_and_keeps_window(monkeypatch):
    """LLM ngilangin blok lama + melarin jendela sendiri -> dibalikin sama kode."""
    old = PlanResponse(
        generated_by="groq", available_hours=3, open_task_count=2,
        start_time="10:00", end_time="13:00",
        blocks=[
            {"task_id": 1, "title": "A", "start_time": "10:00", "end_time": "11:00",
             "duration_minutes": 60},
            {"task_id": 2, "title": "B", "start_time": "11:10", "end_time": "12:00",
             "duration_minutes": 50},
        ],
    )

    async def fake(system, prompt, **kw):
        return {"start_time": "10:00", "end_time": "14:00", "blocks": [
            {"task_id": 1, "title": "A", "start_time": "10:00", "end_time": "11:00"},
            {"task_id": None, "title": "Baca Fisika", "course": "Fisika",
             "start_time": "11:00", "end_time": "11:30"},
        ]}

    monkeypatch.setattr(planning_service, "complete_json", fake)
    plan = await adjust_plan(old, "tambahkan 30 menit baca Fisika", [_task(1, "A"), _task(2, "B")])
    assert plan.end_time == "13:00"
    assert [b.title for b in plan.blocks] == ["A", "Baca Fisika", "B"]
    _assert_inside(plan, "10:00", "13:00")


@pytest.mark.asyncio
async def test_adjust_window_changes_when_instruction_names_new_time(monkeypatch):
    old = PlanResponse(
        generated_by="groq", available_hours=3, open_task_count=1,
        start_time="10:00", end_time="13:00",
        blocks=[{"task_id": 1, "title": "A", "start_time": "10:00", "end_time": "11:00",
                 "duration_minutes": 60}],
    )

    async def fake(system, prompt, **kw):
        return {"blocks": [{"task_id": 1, "title": "A", "start_time": "15:00", "end_time": "16:00"}]}

    monkeypatch.setattr(planning_service, "complete_json", fake)
    plan = await adjust_plan(old, "pindah ke jam 15.00 - 17.00", [_task(1, "A")])
    assert (plan.start_time, plan.end_time) == ("15:00", "17:00")
    assert plan.blocks[0].start_time == "15:00"


@pytest.mark.parametrize(
    "instruction, window",
    [
        ("aku cuma bisa sampai jam 12", ("10:00", "12:00")),
        ("mulai jam 11 aja", ("11:00", "13:00")),
        ("tambahin fisika", ("10:00", "13:00")),
    ],
)
def test_instruction_window_one_sided_bounds(instruction, window):
    from app.services.planning_service import _instruction_window

    got = _instruction_window(instruction, (600, 780), (600, 840))
    assert got == (parse_hhmm(window[0]), parse_hhmm(window[1]))


def _old_plan_10_to_13() -> PlanResponse:
    return PlanResponse(
        generated_by="random", available_hours=3, open_task_count=0,
        start_time="10:00", end_time="13:00",
        blocks=[
            {"task_id": None, "title": "Latihan soal Fisika", "course": "Fisika",
             "color": "#2BB673", "start_time": "10:00", "end_time": "11:00", "duration_minutes": 60},
            {"task_id": None, "title": "Baca materi Kimia", "course": "Kimia",
             "start_time": "11:10", "end_time": "12:00", "duration_minutes": 50},
        ],
    )


@pytest.mark.asyncio
async def test_adjust_shift_by_hours_moves_window_instead_of_shrinking(monkeypatch):
    async def fake(system, prompt, **kw):
        return {"start_time": "11:00", "end_time": "14:00", "blocks": [
            {"task_id": None, "title": "Latihan soal Fisika", "course": "Fisika",
             "start_time": "11:00", "end_time": "12:00"},
            {"task_id": None, "title": "Baca materi Kimia", "course": "Kimia",
             "start_time": "12:10", "end_time": "13:00"},
        ]}

    monkeypatch.setattr(planning_service, "complete_json", fake)
    plan = await adjust_plan(_old_plan_10_to_13(), "geser semua 1 jam lebih lambat", [])
    assert (plan.start_time, plan.end_time) == ("11:00", "14:00")
    assert [b.start_time for b in plan.blocks] == ["11:00", "12:10"]
    assert plan.blocks[0].color == "#2BB673"  # warna course blok random tetep


@pytest.mark.asyncio
async def test_adjust_move_to_period_is_enforced(monkeypatch):
    async def fake(system, prompt, **kw):  # LLM "lupa" mindahin ke sore
        return [
            {"task_id": None, "title": "Latihan soal Fisika", "course": "Fisika",
             "start_time": "11:00", "end_time": "12:00"},
            {"task_id": None, "title": "Baca materi Kimia", "course": "Kimia",
             "start_time": "12:10", "end_time": "13:00"},
        ]

    monkeypatch.setattr(planning_service, "complete_json", fake)
    plan = await adjust_plan(_old_plan_10_to_13(), "pindahkan ke sore", [])
    assert plan.blocks[0].start_time == "15:00"
    _assert_inside(plan, plan.start_time, plan.end_time)


@pytest.mark.asyncio
async def test_adjust_break_is_a_gap_not_a_block(monkeypatch):
    async def fake(system, prompt, **kw):
        return {"blocks": [
            {"task_id": None, "title": "Latihan soal Fisika", "start_time": "10:00", "end_time": "11:00"},
            {"task_id": None, "title": "Istirahat", "start_time": "11:00", "end_time": "11:15"},
            {"task_id": None, "title": "Baca materi Kimia", "start_time": "11:15", "end_time": "12:05"},
        ]}

    monkeypatch.setattr(planning_service, "complete_json", fake)
    plan = await adjust_plan(_old_plan_10_to_13(), "tambahkan istirahat 15 menit", [])
    assert [b.title for b in plan.blocks] == ["Latihan soal Fisika", "Baca materi Kimia"]
    assert plan.blocks[1].start_time == "11:15"


# ------------------------------- random plan ----------------------------------- #
def test_random_plan_ignores_tasks_and_randomizes_everything():
    import random as _random

    from app.services.planning_service import RANDOM_ACTIVITIES, build_random_plan

    courses = [Course(id=1, name="Matematika Dasar", color="#FF8A3D"),
               Course(id=2, name="Fisika", color="#2BB673")]
    starts, titles = set(), set()
    for seed in range(40):
        plan = build_random_plan(courses, 3, _random.Random(seed))
        assert plan.generated_by == "random"
        assert (parse_hhmm(plan.end_time) - parse_hhmm(plan.start_time)) == 180
        _assert_inside(plan, plan.start_time, plan.end_time)
        for b in plan.blocks:
            assert b.task_id is None and b.course in {"Matematika Dasar", "Fisika"}
            assert any(b.title.startswith(a) for a, _, _ in RANDOM_ACTIVITIES)
            titles.add(b.title)
        starts.add(plan.start_time)
    assert len(starts) > 5 and len(titles) > 5  # beneran acak


@pytest.mark.asyncio
async def test_random_endpoint_uses_courses_not_existing_tasks(auth_client):
    await auth_client.post("/courses", json={"name": "Fisika", "color": "#2BB673"})
    await auth_client.post("/tasks", json={"title": "Latihan soal"})  # gak boleh kepake
    body = (await auth_client.post("/ai/plan/random", json={"available_hours": 2})).json()
    assert body["generated_by"] == "random" and body["plan_id"]
    assert all(b["course"] == "Fisika" and b["task_id"] is None for b in body["blocks"])

    active = (await auth_client.get("/ai/plan/active")).json()
    assert active["plan_id"] == body["plan_id"]

    accepted = (await auth_client.post(f"/ai/plan/{body['plan_id']}/accept")).json()
    assert all(b["task_id"] for b in accepted["blocks"])


@pytest.mark.asyncio
async def test_active_plan_none_when_nothing_generated(auth_client):
    assert (await auth_client.get("/ai/plan/active")).json() is None
