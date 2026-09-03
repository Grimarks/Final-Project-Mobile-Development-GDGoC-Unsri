import pytest

pytestmark = pytest.mark.asyncio


async def test_register_returns_token_pair(client):
    resp = await client.post(
        "/auth/register",
        json={"name": "Rel", "email": "a@unsri.ac.id", "password": "Password123!"},
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["user"]["email"] == "a@unsri.ac.id"
    assert body["tokens"]["access_token"]
    assert body["tokens"]["refresh_token"]


async def test_password_is_not_stored_in_plaintext(client, db_session):
    from sqlalchemy import select

    from app.models.user import User

    await client.post(
        "/auth/register",
        json={"name": "Rel", "email": "b@unsri.ac.id", "password": "Password123!"},
    )
    user = (await db_session.execute(select(User))).scalars().first()
    assert user.password_hash != "Password123!"
    assert user.password_hash.startswith("$2")  # penanda hash bcrypt


async def test_duplicate_email_rejected(client):
    payload = {"name": "Rel", "email": "c@unsri.ac.id", "password": "Password123!"}
    await client.post("/auth/register", json=payload)
    resp = await client.post("/auth/register", json=payload)
    assert resp.status_code == 409


async def test_login_wrong_password(client):
    await client.post(
        "/auth/register",
        json={"name": "Rel", "email": "d@unsri.ac.id", "password": "Password123!"},
    )
    resp = await client.post(
        "/auth/login", json={"email": "d@unsri.ac.id", "password": "salahsalah"}
    )
    assert resp.status_code == 401


async def test_refresh_token_issues_new_access_token(client):
    reg = await client.post(
        "/auth/register",
        json={"name": "Rel", "email": "e@unsri.ac.id", "password": "Password123!"},
    )
    refresh = reg.json()["tokens"]["refresh_token"]
    resp = await client.post("/auth/refresh", json={"refresh_token": refresh})
    assert resp.status_code == 200
    assert resp.json()["access_token"]


async def test_access_token_cannot_be_used_as_refresh(client):
    reg = await client.post(
        "/auth/register",
        json={"name": "Rel", "email": "f@unsri.ac.id", "password": "Password123!"},
    )
    access = reg.json()["tokens"]["access_token"]
    resp = await client.post("/auth/refresh", json={"refresh_token": access})
    assert resp.status_code == 401


async def test_protected_route_requires_token(client):
    assert (await client.get("/tasks")).status_code == 401


async def test_get_me_returns_current_user(client):
    reg = await client.post(
        "/auth/register",
        json={"name": "Rel", "email": "me@unsri.ac.id", "password": "Password123!"},
    )
    access = reg.json()["tokens"]["access_token"]
    resp = await client.get("/auth/me", headers={"Authorization": f"Bearer {access}"})
    assert resp.status_code == 200
    assert resp.json()["email"] == "me@unsri.ac.id"


async def test_get_me_requires_auth(client):
    assert (await client.get("/auth/me")).status_code == 401


async def test_update_profile_changes_name(client):
    reg = await client.post(
        "/auth/register",
        json={"name": "Rel", "email": "g@unsri.ac.id", "password": "Password123!"},
    )
    access = reg.json()["tokens"]["access_token"]
    resp = await client.put(
        "/auth/me",
        json={"name": "Rel Darrell"},
        headers={"Authorization": f"Bearer {access}"},
    )
    assert resp.status_code == 200
    assert resp.json()["name"] == "Rel Darrell"


async def test_update_profile_changes_email(client):
    reg = await client.post(
        "/auth/register",
        json={"name": "Rel", "email": "g2@unsri.ac.id", "password": "Password123!"},
    )
    access = reg.json()["tokens"]["access_token"]
    resp = await client.put(
        "/auth/me",
        json={"name": "Rel", "email": "g2-new@unsri.ac.id"},
        headers={"Authorization": f"Bearer {access}"},
    )
    assert resp.status_code == 200
    assert resp.json()["email"] == "g2-new@unsri.ac.id"

    # Bisa login dengan email baru, tidak lagi dengan email lama.
    old = await client.post(
        "/auth/login", json={"email": "g2@unsri.ac.id", "password": "Password123!"}
    )
    assert old.status_code == 401
    new = await client.post(
        "/auth/login", json={"email": "g2-new@unsri.ac.id", "password": "Password123!"}
    )
    assert new.status_code == 200


async def test_update_profile_email_conflict_rejected(client):
    await client.post(
        "/auth/register",
        json={"name": "Taken", "email": "taken@unsri.ac.id", "password": "Password123!"},
    )
    reg = await client.post(
        "/auth/register",
        json={"name": "Rel", "email": "g3@unsri.ac.id", "password": "Password123!"},
    )
    access = reg.json()["tokens"]["access_token"]
    resp = await client.put(
        "/auth/me",
        json={"name": "Rel", "email": "taken@unsri.ac.id"},
        headers={"Authorization": f"Bearer {access}"},
    )
    assert resp.status_code == 409


async def test_register_rejects_weak_password(client):
    resp = await client.post(
        "/auth/register",
        json={"name": "Rel", "email": "weak@unsri.ac.id", "password": "password123"},
    )
    assert resp.status_code == 422


async def test_register_rejects_password_without_special_char(client):
    resp = await client.post(
        "/auth/register",
        json={"name": "Rel", "email": "weak2@unsri.ac.id", "password": "Password123"},
    )
    assert resp.status_code == 422


async def test_register_accepts_strong_password(client):
    resp = await client.post(
        "/auth/register",
        json={"name": "Rel", "email": "strong@unsri.ac.id", "password": "Str0ng!Pass"},
    )
    assert resp.status_code == 201


async def test_change_password_with_wrong_current_password_rejected(client):
    reg = await client.post(
        "/auth/register",
        json={"name": "Rel", "email": "h@unsri.ac.id", "password": "Password123!"},
    )
    access = reg.json()["tokens"]["access_token"]
    resp = await client.post(
        "/auth/change-password",
        json={"current_password": "salahsalah", "new_password": "newpassword123"},
        headers={"Authorization": f"Bearer {access}"},
    )
    assert resp.status_code == 400


async def test_change_password_then_login_with_new_password(client):
    reg = await client.post(
        "/auth/register",
        json={"name": "Rel", "email": "i@unsri.ac.id", "password": "Password123!"},
    )
    access = reg.json()["tokens"]["access_token"]
    resp = await client.post(
        "/auth/change-password",
        json={"current_password": "Password123!", "new_password": "newpassword123"},
        headers={"Authorization": f"Bearer {access}"},
    )
    assert resp.status_code == 204

    old_login = await client.post(
        "/auth/login", json={"email": "i@unsri.ac.id", "password": "Password123!"}
    )
    assert old_login.status_code == 401

    new_login = await client.post(
        "/auth/login", json={"email": "i@unsri.ac.id", "password": "newpassword123"}
    )
    assert new_login.status_code == 200
