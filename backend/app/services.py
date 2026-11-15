"""Mission scheduling, storage, completion records and leaderboards."""
import hashlib
import json
from datetime import date, timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from . import generator
from .db import utcnow
from .models import Completion, ConfigEntry, GenerationLog, Mission, Player

DEFAULT_CONFIG = {
    "content_version": 1,
    "min_generator_version": 4,
    "daily_difficulty": 3,
    "weekly_difficulty": 4,
    "weekly_count": 5,
    "pool_target_per_difficulty": 20,
    "max_generate_per_run": 60,     # hard cap so a bad setting cannot overload the server
    "ads_enabled": True,
    "interstitial_every_n_boxes": 4,
    "sponsor_text": "",             # optional sponsor line on the main menu
    "sponsor_url": "",
}
MAX_TIME_MS = 6 * 3600 * 1000
REQUIRED_KEYS = ("id", "seed", "difficulty", "stages", "signature", "valid")


# ----------------------------------------------------------------- config

def get_config(db: Session) -> dict:
    cfg = dict(DEFAULT_CONFIG)
    for row in db.scalars(select(ConfigEntry)):
        try:
            cfg[row.key] = json.loads(row.value)
        except ValueError:
            pass
    return cfg


def set_config(db: Session, key: str, value) -> None:
    if key not in DEFAULT_CONFIG:
        raise KeyError(key)
    default = DEFAULT_CONFIG[key]
    if isinstance(default, bool):
        value = bool(value)
    elif isinstance(default, int):
        value = int(value)
    elif isinstance(default, str):
        value = str(value)[:200]
    row = db.get(ConfigEntry, key)
    if row is None:
        db.add(ConfigEntry(key=key, value=json.dumps(value)))
    else:
        row.value = json.dumps(value)
    db.commit()


# ------------------------------------------------------------------ seeds

def seed_for(label: str, attempt: int) -> int:
    digest = hashlib.sha256(("mystery-box:%s:%d" % (label, attempt)).encode()).digest()
    return int.from_bytes(digest[:4], "big") & 0x7FFFFFFF


def today_slot() -> str:
    return utcnow().date().isoformat()


def week_slot(day: date = None) -> str:
    day = day or utcnow().date()
    iso = day.isocalendar()
    return "%d-W%02d" % (iso[0], iso[1])


# ---------------------------------------------------------------- storage

def min_seconds_for(mission: dict) -> int:
    """Fastest time a person could plausibly need (used to reject impossible leaderboard times)."""
    total = 0
    for stage in mission.get("stages", []):
        steps = stage.get("solution", [])
        total += max(2, len(steps) if isinstance(steps, list) else 2)
    return max(3, total)


def check_mission(mission) -> str:
    """Returns "" when the generator output is usable, else the reason."""
    if not isinstance(mission, dict):
        return "not_a_dictionary"
    for key in REQUIRED_KEYS:
        if key not in mission:
            return "missing_" + key
    if not mission.get("valid") or not mission.get("server_check", {}).get("ok", False):
        return "generator_marked_invalid"
    if not isinstance(mission["stages"], list) or not mission["stages"]:
        return "no_stages"
    return ""


def _generate_and_store(db: Session, kind: str, slot: str, difficulty: int, count: int, label: str) -> int:
    """Generates until `count` missions are stored (bounded retries). Returns how many were stored."""
    gen = generator.get_generator()
    stored = 0
    failed = 0
    message = ""
    if gen is None:
        message = "no generator configured"
    else:
        attempt = db.scalar(select(func.count()).select_from(Mission).where(Mission.kind == kind, Mission.slot == slot)) or 0
        tries = 0
        while stored < count and tries < 3:
            tries += 1
            need = count - stored
            seeds = [seed_for("%s:%s:%d" % (label, slot, difficulty), attempt + i) for i in range(need)]
            attempt += need
            try:
                missions = gen.generate(seeds, difficulty)
            except generator.GeneratorError as e:
                message = str(e)[:500]
                failed += need
                break
            for mission in missions:
                reason = check_mission(mission)
                if reason:
                    failed += 1
                    message = reason
                    continue
                mission_id = "%s-%s-%s" % (kind, slot or "p", mission["id"])
                duplicate = db.scalar(select(func.count()).select_from(Mission).where(
                    (Mission.id == mission_id) | ((Mission.signature == mission["signature"]) & (Mission.kind == kind))))
                if duplicate:
                    failed += 1
                    message = "duplicate"
                    continue
                mission["id"] = mission_id
                db.add(Mission(id=mission_id, kind=kind, slot=slot, difficulty=int(mission["difficulty"]),
                               seed=int(mission["seed"]), generator_version=int(mission.get("generator_version", 0)),
                               signature=str(mission["signature"]), min_seconds=min_seconds_for(mission),
                               payload=json.dumps(mission)))
                db.flush()
                stored += 1
    db.add(GenerationLog(kind=kind, requested=count, produced=stored, failed=failed, message=message))
    db.commit()
    return stored


def active_missions(db: Session, kind: str, slot: str = None, difficulty: int = None, limit: int = 50) -> list:
    q = select(Mission).where(Mission.kind == kind, Mission.status == "active")
    if slot is not None:
        q = q.where(Mission.slot == slot)
    if difficulty is not None:
        q = q.where(Mission.difficulty == difficulty)
    return list(db.scalars(q.order_by(Mission.created_at, Mission.id).limit(limit)))


def ensure_daily(db: Session, slot: str = None) -> Mission:
    """Returns the active daily mission, generating one (or a replacement) if needed."""
    slot = slot or today_slot()
    found = active_missions(db, "daily", slot, limit=1)
    if found:
        return found[0]
    cfg = get_config(db)
    _generate_and_store(db, "daily", slot, int(cfg["daily_difficulty"]), 1, "daily")
    found = active_missions(db, "daily", slot, limit=1)
    return found[0] if found else None


def ensure_weekly(db: Session, slot: str = None) -> list:
    slot = slot or week_slot()
    cfg = get_config(db)
    want = max(1, min(int(cfg["weekly_count"]), 20))
    have = active_missions(db, "weekly", slot, limit=want)
    if len(have) < want:
        _generate_and_store(db, "weekly", slot, int(cfg["weekly_difficulty"]), want - len(have), "weekly")
        have = active_missions(db, "weekly", slot, limit=want)
    return have


def top_up_pool(db: Session, budget: int) -> int:
    """Keeps a pre-validated pool per difficulty. Returns missions added (never more than `budget`)."""
    cfg = get_config(db)
    target = max(0, min(int(cfg["pool_target_per_difficulty"]), 200))
    added = 0
    for difficulty in range(1, 6):
        have = db.scalar(select(func.count()).select_from(Mission).where(
            Mission.kind == "pool", Mission.status == "active", Mission.difficulty == difficulty)) or 0
        need = min(target - have, budget - added)
        if need > 0:
            added += _generate_and_store(db, "pool", "", difficulty, need, "pool")
        if added >= budget:
            break
    return added


def run_once(db: Session) -> dict:
    """One scheduled pass: today's + tomorrow's daily, this week's set, then the pool."""
    cfg = get_config(db)
    budget = max(1, min(int(cfg["max_generate_per_run"]), 500))
    today = utcnow().date()
    summary = {"daily": 0, "weekly": 0, "pool": 0}
    for day in (today, today + timedelta(days=1)):
        if ensure_daily(db, day.isoformat()) is not None:
            summary["daily"] += 1
    summary["weekly"] = len(ensure_weekly(db, week_slot(today)))
    summary["pool"] = top_up_pool(db, budget)
    return summary


def set_mission_status(db: Session, mission_id: str, status: str) -> bool:
    mission = db.get(Mission, mission_id)
    if mission is None or status not in ("active", "disabled"):
        return False
    mission.status = status
    db.commit()
    return True


# ------------------------------------------------- completions/leaderboard

def record_completion(db: Session, player: Player, mission: Mission, time_ms: int, hints: int) -> Completion:
    existing = db.scalar(select(Completion).where(Completion.player_id == player.id, Completion.mission_id == mission.id))
    if existing is not None:
        return existing          # first result stands; replays never overwrite it
    reason = ""
    if mission.status != "active":
        reason = "mission_not_active"
    elif time_ms < mission.min_seconds * 1000:
        reason = "too_fast"
    elif time_ms > MAX_TIME_MS:
        reason = "too_slow"
    elif hints < 0 or hints > 50:
        reason = "bad_hints"
    row = Completion(player_id=player.id, mission_id=mission.id, time_ms=int(time_ms), hints=int(hints),
                     accepted=(reason == ""), reject_reason=reason)
    db.add(row)
    db.commit()
    return row


def display_name(player: Player) -> str:
    return player.display_name or ("Guest-" + player.id[:4].upper())


def leaderboard(db: Session, mission_id: str, limit: int = 20) -> list:
    q = (select(Completion, Player).join(Player, Player.id == Completion.player_id)
         .where(Completion.mission_id == mission_id, Completion.accepted.is_(True), Player.show_on_leaderboard.is_(True))
         .order_by(Completion.time_ms, Completion.hints, Completion.created_at).limit(max(1, min(limit, 100))))
    out = []
    for rank, (completion, player) in enumerate(db.execute(q).all(), start=1):
        out.append({"rank": rank, "name": display_name(player), "time_ms": completion.time_ms,
                    "hints": completion.hints, "player_id": player.id})
    return out
