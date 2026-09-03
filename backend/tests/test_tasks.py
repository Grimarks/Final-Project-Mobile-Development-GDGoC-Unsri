import pytest

pytestmark = pytest.mark.asyncio


async def _make_course(client, name="CS 301 — Algorithms", color="#4C6FFF"):
    resp = await client.post("/courses", json={"name": name, "color": color})
    assert resp.status_code == 201, resp.text
    return resp.json()


async def test_course_crud(auth_client):
    course = await _make_course(auth_client)
    assert course["color"] == "#4C6FFF"

    listed = await auth_client.get("/courses")
    assert len(listed.json()) == 1

    updated = await auth_client.put(
        f"/courses/{course['id']}", json={"name": "CS 301", "color": "#FF8A3D"}
    )
    assert updated.json()["color"] == "#FF8A3D"

    assert (await auth_client.delete(f"/courses/{course['id']}")).status_code == 204
    assert (await auth_client.get("/courses")).json() == []


async def test_invalid_hex_color_rejected(auth_client):
    resp = await auth_client.post("/courses", json={"name": "X", "color": "biru"})
    assert resp.status_code == 422


async def test_create_task_and_priority_label(auth_client):
    course = await _make_course(auth_client)
    resp = await auth_client.post(
        "/tasks",
        json={
            "title": "Problem Set 4",
            "course_id": course["id"],
            "type": "exam",
            "difficulty": "hard",
            "due_date": "2020-01-01T00:00:00Z",  # sudah lewat -> paling mendesak
        },
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["priority"] == "high"
    assert body["course_name"] == course["name"]
    assert body["course_color"] == "#4C6FFF"


async def test_task_filter_by_status(auth_client):
    await auth_client.post("/tasks", json={"title": "A", "status": "done"})
    await auth_client.post("/tasks", json={"title": "B", "status": "not_started"})
    resp = await auth_client.get("/tasks", params={"status": "done"})
    assert [t["title"] for t in resp.json()] == ["A"]


async def test_marking_done_sets_progress_100(auth_client):
    created = (await auth_client.post("/tasks", json={"title": "A"})).json()
    resp = await auth_client.put(f"/tasks/{created['id']}", json={"status": "done"})
    assert resp.json()["progress_pct"] == 100


async def test_cannot_touch_other_users_task(auth_client, client):
    mine = (await auth_client.post("/tasks", json={"title": "Rahasia"})).json()

    other = await client.post(
        "/auth/register",
        json={"name": "Lain", "email": "lain@unsri.ac.id", "password": "Password123!"},
    )
    token = other.json()["tokens"]["access_token"]
    resp = await client.get(
        f"/tasks/{mine['id']}", headers={"Authorization": f"Bearer {token}"}
    )
    # route GET /tasks/{id} tidak ada -> pastikan lewat update saja
    resp = await client.put(
        f"/tasks/{mine['id']}",
        json={"title": "diubah"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 404


async def test_task_with_foreign_course_rejected(auth_client):
    resp = await auth_client.post("/tasks", json={"title": "A", "course_id": 999})
    assert resp.status_code == 404
