from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    app_env: str = "development"
    log_level: str = "INFO"

    database_url: str = "sqlite:///./data/qh.db"
    upload_dir: str = "./uploads"
    max_upload_size_mb: int = 20

    anthropic_api_key: str = ""
    anthropic_model: str = "claude-sonnet-4-20250514"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
