"""Database tables."""
from datetime import datetime
from typing import Optional

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base, utcnow


class Player(Base):
    __tablename__ = "players"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    last_seen: Mapped[datetime] = mapped_column(DateTime, default=utcnow, index=True)
    is_guest: Mapped[bool] = mapped_column(Boolean, default=True)
    email: Mapped[Optional[str]] = mapped_column(String(254), unique=True, nullable=True)
    password_hash: Mapped[Optional[str]] = mapped_column(String(200), nullable=True)
    display_name: Mapped[str] = mapped_column(String(24), default="")
    show_on_leaderboard: Mapped[bool] = mapped_column(Boolean, default=True)
    token_version: Mapped[int] = mapped_column(Integer, default=1)


class Mission(Base):
    __tablename__ = "missions"
    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    kind: Mapped[str] = mapped_column(String(12), index=True)        # daily | weekly | pool
    slot: Mapped[str] = mapped_column(String(16), default="", index=True)  # 2026-11-12 | 2026-W46 | ""
    difficulty: Mapped[int] = mapped_column(Integer, index=True)
    seed: Mapped[int] = mapped_column(BigInteger)
    generator_version: Mapped[int] = mapped_column(Integer, default=0)
    signature: Mapped[str] = mapped_column(String(64), index=True)
    status: Mapped[str] = mapped_column(String(12), default="active", index=True)  # active | disabled
    min_seconds: Mapped[int] = mapped_column(Integer, default=3)
    payload: Mapped[str] = mapped_column(Text)                        # full mission JSON
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class Completion(Base):
    __tablename__ = "completions"
    __table_args__ = (UniqueConstraint("player_id", "mission_id", name="uq_completion_player_mission"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), index=True)
    mission_id: Mapped[str] = mapped_column(ForeignKey("missions.id", ondelete="CASCADE"), index=True)
    time_ms: Mapped[int] = mapped_column(Integer)
    hints: Mapped[int] = mapped_column(Integer, default=0)
    accepted: Mapped[bool] = mapped_column(Boolean, default=True)
    reject_reason: Mapped[str] = mapped_column(String(40), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class Progress(Base):
    __tablename__ = "progress"
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), primary_key=True)
    solved: Mapped[int] = mapped_column(Integer, default=0)
    data: Mapped[str] = mapped_column(Text, default="{}")
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class Event(Base):
    """Anonymous usage event (sessions, boxes, ad impressions, purchases, frame rate)."""
    __tablename__ = "events"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(32), index=True)
    day: Mapped[str] = mapped_column(String(10), index=True)          # server date, YYYY-MM-DD
    props: Mapped[str] = mapped_column(Text, default="{}")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)


class ConfigEntry(Base):
    __tablename__ = "config"
    key: Mapped[str] = mapped_column(String(48), primary_key=True)
    value: Mapped[str] = mapped_column(Text)                          # JSON value


class GenerationLog(Base):
    __tablename__ = "generation_log"
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow, index=True)
    kind: Mapped[str] = mapped_column(String(12))
    requested: Mapped[int] = mapped_column(Integer, default=0)
    produced: Mapped[int] = mapped_column(Integer, default=0)
    failed: Mapped[int] = mapped_column(Integer, default=0)
    message: Mapped[str] = mapped_column(Text, default="")
