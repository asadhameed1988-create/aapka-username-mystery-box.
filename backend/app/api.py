"""Public game API (prefix /v1). The game talks only to these endpoints."""
import json
import re
import time
from typing import Optional

import jwt
from fastapi import APIRouter, Depends, Header, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session
import uuid

from . import security, services
from .db import get_db, utcnow
from .models import Completion, Event, Mission, Player, Progress

router = APIRouter(prefix="/v1")
EMAIL_RE = re.compile(r"^[^@\s]{1,64}@[^@\s]{1,180}\.[^@\s]{2,}$")
NAME_RE = re.compile(r"^[\w \-]{2,24}$", re.UNICODE)
MAX_PROGRESS_BYTES = 200_000


# ------------------------------------------------------------- helpers

def _rate_limit(request: Request, bucket: str, limit: int, window: int = 60) -> None:
    """Small in-memory limiter (per process) against password guessing and account spam."""
    store = request.app.state.rate
    ip = request.client.host if request.client else "?"
    now = time.time()
    key = (bucket, ip)
    hits = [t for t in store.get(key, []) if now - t < window]
    if len(hits) >= limit:
        raise HTTPException(status_code=429, detail="too_many_requests")
    hits.append(now)
    store[key] = hits


def current_player(request: Request, authorization: str = Header(default=""), db: Session = Depends(get_db)) -> Player:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="missing_token")
    try:
        payload = security.read_token(request.app.state.settings.secret_key, authorization[7:])
    except jwt.PyJWTError:
        raise HTTPException(status_code=401, detail="bad_token")
    player = db.get(Player, str(payload.get("sub", "")))
    if player is None or int(payload.get("ver", 0)) != player.token_version:
        raise HTTPException(status_code=401, detail="bad_token")
    now = utcnow()
    if (now - player.last_seen).total_seconds() > 300:
        player.last_seen = now
        db.commit()
    return player


def _token(request: Request, player: Player) -> str:
    return security.make_token(request.app.state.settings.secret_key, player.id, player.token_version)


def _mission_out(m: Mission) -> dict:
    return {"id": m.id, "kind": m.kind, "slot": m.slot, "difficulty": m.difficulty, "mission": json.loads(m.payload)}


def _profile(player: Player) -> dict:
    return {"player_id": player.id, "is_guest": player.is_guest, "display_name": services.display_name(player),
            "email": player.email, "show_on_leaderboard": player.show_on_leaderboard}


# ------------------------------------------------------------- schemas

class RegisterIn(BaseModel):
    email: str = Field(max_length=254)
    password: str = Field(min_length=8, max_length=128)
    display_name: Optional[str] = Field(default=None, max_length=24)


class LoginIn(BaseModel):
    email: str = Field(max_length=254)
    password: str = Field(max_length=128)


class CompleteIn(BaseModel):
    time_ms: int = Field(ge=0)
    hints: int = Field(ge=0)


class ProgressIn(BaseModel):
    solved: int = Field(ge=0, le=10_000_000)
    data: dict


class AccountPatch(BaseModel):
    display_name: Optional[str] = Field(default=None, max_length=24)
    show_on_leaderboard: Optional[bool] = None


# ---------------------------------------------------------------- auth

@router.post("/auth/guest")
def auth_guest(request: Request, db: Session = Depends(get_db)):
    _rate_limit(request, "guest", 30)
    player = Player(id=str(uuid.uuid4()))
    db.add(player)
    db.commit()
    return {"token": _token(request, player), "profile": _profile(player)}


@router.post("/auth/register")
def auth_register(body: RegisterIn, request: Request, player: Player = Depends(current_player), db: Session = Depends(get_db)):
    """Turns the current guest into a registered account (progress is kept)."""
    _rate_limit(request, "register", 10)
    email = body.email.strip().lower()
    if not EMAIL_RE.match(email):
        raise HTTPException(status_code=422, detail="bad_email")
    taken = db.scalar(select(Player).where(Player.email == email, Player.id != player.id))
    if taken is not None:
        raise HTTPException(status_code=409, detail="email_in_use")
    if body.display_name is not None:
        name = body.display_name.strip()
        if not NAME_RE.match(name):
            raise HTTPException(status_code=422, detail="bad_display_name")
        player.display_name = name
    player.email = email
    player.password_hash = security.hash_password(body.password)
    player.is_guest = False
    db.commit()
    return {"token": _token(request, player), "profile": _profile(player)}


@router.post("/auth/login")
def auth_login(body: LoginIn, request: Request, db: Session = Depends(get_db)):
    _rate_limit(request, "login", 10)
    player = db.scalar(select(Player).where(Player.email == body.email.strip().lower()))
    if player is None or not player.password_hash or not security.verify_password(body.password, player.password_hash):
        raise HTTPException(status_code=401, detail="bad_credentials")
    return {"token": _token(request, player), "profile": _profile(player)}


# ------------------------------------------------------------- account

@router.get("/account")
def account_get(player: Player = Depends(current_player)):
    return _profile(player)


@router.patch("/account")
def account_patch(body: AccountPatch, player: Player = Depends(current_player), db: Session = Depends(get_db)):
    if body.display_name is not None:
        name = body.display_name.strip()
        if not NAME_RE.match(name):
            raise HTTPException(status_code=422, detail="bad_display_name")
        player.display_name = name
    if body.show_on_leaderboard is not None:
        player.show_on_leaderboard = body.show_on_leaderboard
    db.commit()
    return _profile(player)


@router.delete("/account")
def account_delete(player: Player = Depends(current_player), db: Session = Depends(get_db)):
    """Permanently removes the player and everything stored about them."""
    db.execute(delete(Completion).where(Completion.player_id == player.id))
    db.execute(delete(Progress).where(Progress.player_id == player.id))
    db.execute(delete(Event).where(Event.player_id == player.id))
    db.execute(delete(Player).where(Player.id == player.id))
    db.commit()
    return {"deleted": True}


# ------------------------------------------------------- config/missions

@router.get("/config")
def config_get(db: Session = Depends(get_db)):
    cfg = services.get_config(db)
    public = ("content_version", "min_generator_version", "ads_enabled", "interstitial_every_n_boxes",
              "sponsor_text", "sponsor_url")
    return {k: cfg[k] for k in public}


@router.get("/missions/daily")
def missions_daily(player: Player = Depends(current_player), db: Session = Depends(get_db)):
    mission = services.ensure_daily(db)
    if mission is None:
        # The game then falls back to its local date-seeded daily box.
        raise HTTPException(status_code=503, detail="no_mission_use_local")
    return _mission_out(mission)


@router.get("/missions/weekly")
def missions_weekly(player: Player = Depends(current_player), db: Session = Depends(get_db)):
    return {"slot": services.week_slot(), "missions": [_mission_out(m) for m in services.ensure_weekly(db)]}


@router.get("/missions/pool")
def missions_pool(difficulty: int = 1, limit: int = 5, player: Player = Depends(current_player), db: Session = Depends(get_db)):
    difficulty = max(1, min(difficulty, 5))
    limit = max(1, min(limit, 10))
    done = select(Completion.mission_id).where(Completion.player_id == player.id)
    q = (select(Mission).where(Mission.kind == "pool", Mission.status == "active", Mission.difficulty == difficulty,
                               Mission.id.not_in(done)).order_by(Mission.created_at, Mission.id).limit(limit))
    return {"missions": [_mission_out(m) for m in db.scalars(q)]}


@router.post("/missions/{mission_id}/complete")
def missions_complete(mission_id: str, body: CompleteIn, player: Player = Depends(current_player), db: Session = Depends(get_db)):
    mission = db.get(Mission, mission_id)
    if mission is None:
        raise HTTPException(status_code=404, detail="unknown_mission")
    row = services.record_completion(db, player, mission, body.time_ms, body.hints)
    rank = None
    if row.accepted:
        better = db.scalar(select(func.count()).select_from(Completion).where(
            Completion.mission_id == mission.id, Completion.accepted.is_(True), Completion.time_ms < row.time_ms)) or 0
        rank = better + 1
    return {"accepted": row.accepted, "reason": row.reject_reason, "time_ms": row.time_ms, "rank": rank}


@router.get("/leaderboard/{mission_id}")
def leaderboard_get(mission_id: str, limit: int = 20, player: Player = Depends(current_player), db: Session = Depends(get_db)):
    if db.get(Mission, mission_id) is None:
        raise HTTPException(status_code=404, detail="unknown_mission")
    entries = services.leaderboard(db, mission_id, limit)
    for e in entries:
        e["me"] = e.pop("player_id") == player.id      # internal ids are never sent to other players
    return {"mission_id": mission_id, "entries": entries}


# ----------------------------------------------------------- analytics

ALLOWED_EVENTS = {"session_start", "box_complete", "ad_impression", "ad_reward", "purchase", "perf"}


class EventIn(BaseModel):
    name: str = Field(max_length=32)
    props: dict = Field(default_factory=dict)


class EventsIn(BaseModel):
    events: list[EventIn] = Field(max_length=50)


@router.post("/events")
def events_post(body: EventsIn, player: Player = Depends(current_player), db: Session = Depends(get_db)):
    """Anonymous usage events. Unknown names and oversized payloads are dropped, not stored."""
    day = utcnow().date().isoformat()
    stored = 0
    for e in body.events:
        if e.name not in ALLOWED_EVENTS:
            continue
        raw = json.dumps(e.props)
        if len(raw) > 600:
            raw = "{}"
        db.add(Event(player_id=player.id, name=e.name, day=day, props=raw))
        stored += 1
    db.commit()
    return {"stored": stored}


# ------------------------------------------------------------ progress

@router.get("/progress")
def progress_get(player: Player = Depends(current_player), db: Session = Depends(get_db)):
    row = db.get(Progress, player.id)
    if row is None:
        return {"solved": 0, "data": {}, "updated_at": None}
    return {"solved": row.solved, "data": json.loads(row.data), "updated_at": row.updated_at.isoformat()}


@router.put("/progress")
def progress_put(body: ProgressIn, player: Player = Depends(current_player), db: Session = Depends(get_db)):
    """Conflict rule: the save with MORE boxes solved wins; the loser is told to adopt the winner."""
    raw = json.dumps(body.data)
    if len(raw.encode()) > MAX_PROGRESS_BYTES:
        raise HTTPException(status_code=413, detail="progress_too_large")
    row = db.get(Progress, player.id)
    if row is None:
        row = Progress(player_id=player.id, solved=body.solved, data=raw)
        db.add(row)
        db.commit()
        return {"winner": "client", "solved": row.solved}
    if body.solved >= row.solved:
        row.solved = body.solved
        row.data = raw
        row.updated_at = utcnow()
        db.commit()
        return {"winner": "client", "solved": row.solved}
    return {"winner": "server", "solved": row.solved, "data": json.loads(row.data)}
