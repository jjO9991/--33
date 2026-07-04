"""
文件上传工具函数。

负责扩展名 / MIME / 大小校验，以及 SHA-256 计算与落盘。
"""

import hashlib
from pathlib import Path

from fastapi import UploadFile

# ---- 白名单 ----

ALLOWED_EXTENSIONS: set[str] = {
    "pdf", "doc", "docx", "txt",
    "jpg", "jpeg", "png", "heic",
}

ALLOWED_MIMETYPES: set[str] = {
    "application/pdf",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "text/plain",
    "image/jpeg",
    "image/png",
    "image/heic",
}


# ---- 校验 ----

def validate_upload(file: UploadFile, max_size_mb: int) -> None:
    """校验扩展名、Content-Type、文件大小，不合法时抛出 ValueError。"""

    # 扩展名
    filename = file.filename or ""
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    if ext not in ALLOWED_EXTENSIONS:
        raise ValueError(
            "不支持的文件类型，仅支持 PDF/DOCX/TXT/图片"
        )

    # Content-Type
    if file.content_type and file.content_type not in ALLOWED_MIMETYPES:
        raise ValueError(
            "不支持的文件类型，仅支持 PDF/DOCX/TXT/图片"
        )


# ---- 落盘 ----

def save_upload(
    file: UploadFile,
    upload_dir: str,
    max_size_mb: int,
) -> tuple[str, str, int]:
    """
    读取 → 校验 → 算 SHA-256 → 落盘。

    Returns:
        (storage_key, sha256_hex, size_bytes)
    """
    # 先读内容到内存（MVP 阶段文件大小可控）
    content = file.file.read()

    # 大小校验（以实际内容为准）
    size_bytes = len(content)
    max_bytes = max_size_mb * 1024 * 1024
    if size_bytes > max_bytes:
        raise ValueError(f"文件过大，最大支持 {max_size_mb}MB")

    # 校验扩展名 / MIME
    validate_upload(file, max_size_mb)

    # SHA-256
    sha256_hex = hashlib.sha256(content).hexdigest()

    # 落盘：upload_dir / {sha256前2位} / {sha256}.{ext}
    filename = file.filename or ""
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else "bin"
    dest_dir = Path(upload_dir) / sha256_hex[:2]
    dest_dir.mkdir(parents=True, exist_ok=True)
    storage_key = f"{sha256_hex[:2]}/{sha256_hex}.{ext}"
    dest_dir.joinpath(f"{sha256_hex}.{ext}").write_bytes(content)

    return storage_key, sha256_hex, size_bytes
