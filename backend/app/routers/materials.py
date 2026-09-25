from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.security import get_current_user
from app.models.material import Material
from app.models.user import User
from app.schemas.material import MaterialOut
from app.services.materials_service import extract_pdf_text

router = APIRouter(prefix="/materials", tags=["materials"])

UPLOAD_DIR = Path("uploads")
MAX_BYTES = 10 * 1024 * 1024  # 10 MB


def _to_out(m: Material) -> MaterialOut:
    return MaterialOut(
        id=m.id,
        filename=m.filename,
        course_id=m.course_id,
        uploaded_at=m.uploaded_at,
        text_length=len(m.extracted_text or ""),
        preview=(m.extracted_text or "")[:300],
    )


@router.post("/upload", response_model=MaterialOut, status_code=status.HTTP_201_CREATED)
async def upload_material(
    file: UploadFile = File(...),
    course_id: int | None = Form(default=None),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not (file.filename or "").lower().endswith(".pdf"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Hanya menerima file PDF")

    data = await file.read()
    if len(data) > MAX_BYTES:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "File maksimal 10 MB")

    UPLOAD_DIR.mkdir(exist_ok=True)
    # jangan pernah pake nama file dari user langsung jadi path, bahaya path traversal
    safe_name = Path(file.filename).name
    dest = UPLOAD_DIR / f"u{user.id}_{safe_name}"
    dest.write_bytes(data)

    try:
        text = extract_pdf_text(data)
    except Exception:  # noqa: BLE001
        text = ""

    material = Material(
        user_id=user.id,
        course_id=course_id,
        filename=safe_name,
        file_url=str(dest),
        extracted_text=text,
    )
    db.add(material)
    await db.commit()
    await db.refresh(material)
    return _to_out(material)


@router.get("", response_model=list[MaterialOut])
async def list_materials(
    user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)
):
    rows = (
        await db.execute(
            select(Material).where(Material.user_id == user.id).order_by(Material.id.desc())
        )
    ).scalars().all()
    return [_to_out(m) for m in rows]


@router.get("/{material_id}", response_model=MaterialOut)
async def get_material(
    material_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    m = (
        await db.execute(
            select(Material).where(Material.id == material_id, Material.user_id == user.id)
        )
    ).scalar_one_or_none()
    if m is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Materi tidak ditemukan")
    return _to_out(m)


@router.delete("/{material_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_material(
    material_id: int,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    m = (
        await db.execute(
            select(Material).where(Material.id == material_id, Material.user_id == user.id)
        )
    ).scalar_one_or_none()
    if m is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Materi tidak ditemukan")

    file_url = m.file_url
    await db.delete(m)
    await db.commit()

    # upload nama file sama nimpa path yg sama, jadi file fisiknya baru dihapus
    # kalo udah gak ada materi lain yg nunjuk ke situ
    still_used = (
        await db.execute(select(func.count()).where(Material.file_url == file_url))
    ).scalar_one()
    if not still_used:
        Path(file_url).unlink(missing_ok=True)
