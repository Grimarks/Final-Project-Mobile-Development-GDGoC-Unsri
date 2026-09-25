import pytest

pytestmark = pytest.mark.asyncio


async def test_session_lifecycle(auth_client):
    task = (await auth_client.post("/tasks", json={"title": "Problem Set 4"})).json()

    created = await auth_client.post("/study-sessions", json={"task_id": task["id"]})
    assert created.status_code == 201
    session_id = created.json()["id"]
    assert created.json()["completed"] is False

    done = await auth_client.patch(
        f"/study-sessions/{session_id}/complete",
        json={"feedback": "hard", "actual_duration": 25},
    )
    assert done.status_code == 200
    assert done.json()["completed"] is True
    assert done.json()["feedback"] == "hard"
    assert done.json()["actual_duration"] == 25


async def test_invalid_feedback_rejected(auth_client):
    created = (await auth_client.post("/study-sessions", json={})).json()
    resp = await auth_client.patch(
        f"/study-sessions/{created['id']}/complete", json={"feedback": "susah-banget"}
    )
    assert resp.status_code == 422


async def test_complete_unknown_session(auth_client):
    resp = await auth_client.patch("/study-sessions/999/complete", json={"feedback": "easy"})
    assert resp.status_code == 404


async def test_session_rejects_other_users_task(auth_client, client):
    other = await client.post(
        "/auth/register",
        json={"name": "Other", "email": "other-sess@unsri.ac.id", "password": "Password123!"},
    )
    token = other.json()["tokens"]["access_token"]
    theirs = await client.post(
        "/tasks", json={"title": "Punya orang"}, headers={"Authorization": f"Bearer {token}"}
    )
    resp = await auth_client.post("/study-sessions", json={"task_id": theirs.json()["id"]})
    assert resp.status_code == 404
