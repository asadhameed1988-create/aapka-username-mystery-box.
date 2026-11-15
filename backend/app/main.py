"""Application factory. Run with:  uvicorn app.main:app --host 0.0.0.0 --port 8000"""
import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import admin, api, db, generator, services
from .config import Settings, load_settings

log = logging.getLogger("mystery_box")


async def _worker_loop(interval_seconds: int = 1800) -> None:
    """Optional in-process schedule (BACKGROUND_WORKER=1). A cron job calling app.worker is the alternative."""
    while True:
        try:
            session = db.new_session()
            try:
                await asyncio.to_thread(services.run_once, session)
            finally:
                session.close()
        except Exception:      # never let the schedule die; errors are visible in the log
            log.exception("scheduled generation failed")
        await asyncio.sleep(interval_seconds)


def create_app(settings: Settings = None) -> FastAPI:
    settings = settings or load_settings()
    db.configure(settings.database_url)
    db.init_db()
    if generator.get_generator() is None:
        generator.set_generator(generator.GodotGenerator(settings.godot_bin, settings.game_project_dir))

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        task = asyncio.create_task(_worker_loop()) if settings.background_worker else None
        yield
        if task is not None:
            task.cancel()

    app = FastAPI(title="Mystery Box API", version="1.0", lifespan=lifespan, docs_url=None, redoc_url=None)
    app.state.settings = settings
    app.state.rate = {}
    if settings.cors_origins:
        app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins, allow_methods=["*"], allow_headers=["*"])
    app.include_router(api.router)
    app.include_router(admin.router)

    @app.get("/health")
    def health():
        return {"ok": True}

    return app


def _default_app():
    return create_app()


def __getattr__(name):
    # `uvicorn app.main:app` builds the app lazily, so importing this module in tests has no side effects.
    if name == "app":
        global _app
        try:
            return _app
        except NameError:
            _app = _default_app()
            return _app
    raise AttributeError(name)
