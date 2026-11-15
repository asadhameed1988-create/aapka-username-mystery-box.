"""Database engine and session handling (PostgreSQL in production, SQLite for local tests)."""
from datetime import datetime, timezone

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker
from sqlalchemy.pool import StaticPool


class Base(DeclarativeBase):
    pass


_engine = None
_Session = None


def utcnow() -> datetime:
    """Naive UTC timestamp (same representation on PostgreSQL and SQLite)."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def configure(database_url: str) -> None:
    global _engine, _Session
    kwargs = {}
    if database_url.startswith("sqlite"):
        kwargs["connect_args"] = {"check_same_thread": False}
        if ":memory:" in database_url:
            kwargs["poolclass"] = StaticPool
    else:
        kwargs["pool_pre_ping"] = True
    _engine = create_engine(database_url, **kwargs)
    _Session = sessionmaker(bind=_engine, expire_on_commit=False)


def engine():
    return _engine


def init_db() -> None:
    from . import models  # noqa: F401  (registers the tables)
    Base.metadata.create_all(_engine)


def new_session():
    return _Session()


def get_db():
    db = _Session()
    try:
        yield db
    finally:
        db.close()
