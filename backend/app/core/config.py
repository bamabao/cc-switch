from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    app_name: str = "爸妈宝"
    debug: bool = True

    # Database
    database_url: str = "sqlite:///./bamabao.db"

    # JWT
    secret_key: str = "change-me-in-production-bamabao-secret"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7  # 7 days

    # File storage (MinIO or local fallback)
    storage_backend: str = "local"  # local | minio
    upload_dir: str = "./uploads"

    # Alert
    alert_timeout_minutes: int = 30  # 未确认用药 -> 推送子女

    # Reward
    reward_per_dose: int = 10
    reward_streak_7: int = 50
    reward_streak_30: int = 200

    class Config:
        env_file = ".env"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
