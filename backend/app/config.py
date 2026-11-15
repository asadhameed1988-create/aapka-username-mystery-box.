"""Settings come from environment variables (see .env.example). Secrets are never stored in code."""
import os
from dataclasses import dataclass, field

DEV_SECRET = "dev-only-change-me"


@dataclass
class Settings:
    database_url: str = "sqlite:///./mystery_box.db"
    secret_key: str = DEV_SECRET
    admin_user: str = "admin"
    admin_password: str = ""          # empty = admin dashboard disabled
    godot_bin: str = "godot"
    game_project_dir: str = ".."
    cors_origins: list = field(default_factory=list)
    background_worker: bool = False
    environment: str = "development"


def load_settings() -> Settings:
    s = Settings(
        database_url=os.getenv("DATABASE_URL", "sqlite:///./mystery_box.db"),
        secret_key=os.getenv("SECRET_KEY", DEV_SECRET),
        admin_user=os.getenv("ADMIN_USER", "admin"),
        admin_password=os.getenv("ADMIN_PASSWORD", ""),
        godot_bin=os.getenv("GODOT_BIN", "godot"),
        game_project_dir=os.getenv("GAME_PROJECT_DIR", ".."),
        cors_origins=[o.strip() for o in os.getenv("CORS_ORIGINS", "").split(",") if o.strip()],
        background_worker=os.getenv("BACKGROUND_WORKER", "0") == "1",
        environment=os.getenv("ENVIRONMENT", "development"),
    )
    if s.environment == "production" and (s.secret_key == DEV_SECRET or len(s.secret_key) < 32):
        raise RuntimeError("SECRET_KEY must be set to a long random value in production")
    return s
