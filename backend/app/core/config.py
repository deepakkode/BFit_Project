from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "BFit API"
    api_v1_prefix: str = "/api/v1"
    environment: str = "development"
    database_url: str = "postgresql+psycopg://postgres:postgres@localhost:5432/bfit"
    secret_key: str = "development-only-change-me"
    access_token_expire_minutes: int = 30
    activity_model: str = "auto"
    ml_artifact_path: str = "../ml/artifacts/random_forest.joblib"
    deepconv_lstm_artifact_path: str = "../ml/artifacts/deepconv_lstm.pt"
    cors_origins: str = "http://localhost:8081,http://localhost:19006"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    @property
    def allowed_origins(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    settings = Settings()
    if settings.environment == "production" and settings.secret_key == "development-only-change-me":
        raise ValueError("SECRET_KEY must be configured in production")
    return settings


settings = get_settings()