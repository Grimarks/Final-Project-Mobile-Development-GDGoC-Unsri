"""Test upload materi + AI summary/quiz (jalur heuristik, GROQ_API_KEY kosong saat test)."""
import pytest

pytestmark = pytest.mark.asyncio

# PDF minimal tanpa teks (tanpa content stream) — cukup untuk test upload/list/get;
# extract_pdf_text() atas file ini menghasilkan string kosong, sama seperti PDF hasil scan.
_MINIMAL_PDF = (
    b"%PDF-1.4\n"
    b"1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\n"
    b"2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj\n"
    b"3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]>>endobj\n"
    b"xref\n0 4\n0000000000 65535 f \n"
    b"trailer<</Size 4/Root 1 0 R>>\n"
    b"startxref\n0\n%%EOF"
)


async def test_upload_rejects_non_pdf(auth_client):
    resp = await auth_client.post(
        "/materials/upload", files={"file": ("notes.txt", b"hello", "text/plain")}
    )
    assert resp.status_code == 400


async def test_upload_pdf_succeeds(auth_client):
    resp = await auth_client.post(
        "/materials/upload", files={"file": ("notes.pdf", _MINIMAL_PDF, "application/pdf")}
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["filename"] == "notes.pdf"
    assert body["course_id"] is None


async def test_upload_with_course_id(auth_client):
    course = (
        await auth_client.post("/courses", json={"name": "CS 301", "color": "#4C6FFF"})
    ).json()
    resp = await auth_client.post(
        "/materials/upload",
        data={"course_id": str(course["id"])},
        files={"file": ("notes.pdf", _MINIMAL_PDF, "application/pdf")},
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["course_id"] == course["id"]


async def test_upload_rejects_oversized_file(auth_client):
    too_big = b"%PDF-1.4\n" + b"0" * (10 * 1024 * 1024 + 1)
    resp = await auth_client.post(
        "/materials/upload", files={"file": ("big.pdf", too_big, "application/pdf")}
    )
    assert resp.status_code == 413


async def test_list_materials_only_own(auth_client, client):
    await auth_client.post(
        "/materials/upload", files={"file": ("mine.pdf", _MINIMAL_PDF, "application/pdf")}
    )
    other = await client.post(
        "/auth/register",
        json={"name": "Other", "email": "other-mat@unsri.ac.id", "password": "Password123!"},
    )
    other_token = other.json()["tokens"]["access_token"]
    await client.post(
        "/materials/upload",
        files={"file": ("theirs.pdf", _MINIMAL_PDF, "application/pdf")},
        headers={"Authorization": f"Bearer {other_token}"},
    )

    resp = await auth_client.get("/materials")
    assert resp.status_code == 200
    filenames = [m["filename"] for m in resp.json()]
    assert "mine.pdf" in filenames
    assert "theirs.pdf" not in filenames


async def test_get_material_not_found_for_other_user(auth_client, client):
    upload = await auth_client.post(
        "/materials/upload", files={"file": ("mine.pdf", _MINIMAL_PDF, "application/pdf")}
    )
    material_id = upload.json()["id"]

    other = await client.post(
        "/auth/register",
        json={"name": "Other", "email": "other-get@unsri.ac.id", "password": "Password123!"},
    )
    resp = await client.get(
        f"/materials/{material_id}",
        headers={"Authorization": f"Bearer {other.json()['tokens']['access_token']}"},
    )
    assert resp.status_code == 404


async def test_get_material_not_found_for_bad_id(auth_client):
    assert (await auth_client.get("/materials/999999")).status_code == 404


async def test_summarize_material_with_no_extractable_text(auth_client, db_session):
    from sqlalchemy import select

    from app.models.ai_generated import AIGenerated

    upload = await auth_client.post(
        "/materials/upload", files={"file": ("scanned.pdf", _MINIMAL_PDF, "application/pdf")}
    )
    material_id = upload.json()["id"]

    resp = await auth_client.post(f"/ai/materials/{material_id}/summarize")
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["generated_by"] == "heuristic"
    assert body["key_points"] == []

    rows = (await db_session.execute(select(AIGenerated))).scalars().all()
    assert len(rows) == 1
    assert rows[0].type == "summary"
    assert rows[0].source_id == material_id


async def test_quiz_material_heuristic_fallback(auth_client):
    upload = await auth_client.post(
        "/materials/upload", files={"file": ("scanned.pdf", _MINIMAL_PDF, "application/pdf")}
    )
    material_id = upload.json()["id"]

    resp = await auth_client.post(f"/ai/materials/{material_id}/quiz")
    assert resp.status_code == 200, resp.text
    assert resp.json()["generated_by"] == "heuristic"


async def test_summarize_requires_owned_material(auth_client, client):
    other = await client.post(
        "/auth/register",
        json={"name": "Other", "email": "other-sum@unsri.ac.id", "password": "Password123!"},
    )
    other_token = other.json()["tokens"]["access_token"]
    upload = await client.post(
        "/materials/upload",
        files={"file": ("theirs.pdf", _MINIMAL_PDF, "application/pdf")},
        headers={"Authorization": f"Bearer {other_token}"},
    )
    material_id = upload.json()["id"]

    resp = await auth_client.post(f"/ai/materials/{material_id}/summarize")
    assert resp.status_code == 404


async def test_materials_require_auth(client):
    assert (await client.get("/materials")).status_code == 401
    assert (await client.post("/ai/materials/1/summarize")).status_code == 401
