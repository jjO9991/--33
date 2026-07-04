"""
文件路由。

POST /api/v1/files/upload — 上传文件并入库
GET  /api/v1/files/{file_id} — 查询文件详情
"""

from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session as ORMSession

from app.config import get_settings
from app.database import get_db
from app.models import File
from app.schemas import ApiResponse, FileResponse, FileUploadResponse
from app.services import file_service

router = APIRouter(prefix="/api/v1/files", tags=["files"])


@router.post("/upload", response_model=ApiResponse[FileUploadResponse])
def upload_file(
    file: UploadFile = File(),
    session_id: Optional[str] = None,
    db: ORMSession = Depends(get_db),
) -> ApiResponse[FileUploadResponse]:
    """上传文件，校验后落盘并入库。"""
    settings = get_settings()

    try:
        storage_key, sha256_hex, size_bytes = file_service.save_upload(
            file=file,
            upload_dir=settings.upload_dir,
            max_size_mb=settings.max_upload_size_mb,
        )
    except ValueError as exc:
        return ApiResponse(
            code=40001,
            message=str(exc),
            data=None,
        )

    # 推断文件类型
    filename = file.filename or ""
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    file_type = {
        "pdf": "pdf", "doc": "docx", "docx": "docx", "txt": "txt",
        "jpg": "image", "jpeg": "image", "png": "image", "heic": "image",
    }.get(ext, "txt")

    file_obj = File(
        session_id=session_id or "",
        type=file_type,
        storage_key=storage_key,
        original_name=file.filename,
        sha256=sha256_hex,
        size_bytes=size_bytes,
        mime_type=file.content_type,
    )
    db.add(file_obj)
    db.commit()
    db.refresh(file_obj)

    return ApiResponse(
        data=FileUploadResponse(
            file_id=file_obj.id,
            original_name=file_obj.original_name,
            sha256=file_obj.sha256,
            size_bytes=file_obj.size_bytes,
            mime_type=file_obj.mime_type,
        )
    )


@router.get("/{file_id}", response_model=ApiResponse[FileResponse])
def get_file(
    file_id: str,
    db: ORMSession = Depends(get_db),
) -> ApiResponse[FileResponse]:
    """按 ID 查询文件详情。"""
    file_obj = db.query(File).filter(File.id == file_id).first()
    if file_obj is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="文件不存在",
        )
    return ApiResponse(data=FileResponse.model_validate(file_obj))
