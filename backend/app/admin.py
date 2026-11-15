"""Owner dashboard (/admin). Plain server-rendered pages behind HTTP Basic auth. Use only over HTTPS."""
import html
import json
import secrets
from datetime import timedelta

from fastapi import APIRouter, Depends, Form, HTTPException, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from . import security, services
from .db import get_db, utcnow
from .models import Completion, Event, GenerationLog, Mission, Player

router = APIRouter(prefix="/admin")
basic = HTTPBasic()


def admin_user(request: Request, creds: HTTPBasicCredentials = Depends(basic)) -> str:
    settings = request.app.state.settings
    if not settings.admin_password:
        raise HTTPException(status_code=503, detail="admin_disabled")
    ok_user = secrets.compare_digest(creds.username.encode(), settings.admin_user.encode())
    ok_pass = secrets.compare_digest(creds.password.encode(), settings.admin_password.encode())
    if not (ok_user and ok_pass):
        raise HTTPException(status_code=401, detail="bad_admin_login", headers={"WWW-Authenticate": "Basic"})
    return creds.username


def _csrf(request: Request, user: str) -> str:
    return security.csrf_token(request.app.state.settings.secret_key, user)


def _check_csrf(request: Request, user: str, token: str) -> None:
    if not secrets.compare_digest(token, _csrf(request, user)):
        raise HTTPException(status_code=403, detail="bad_csrf_token")


def _page(title: str, body: str) -> HTMLResponse:
    nav = " | ".join('<a href="/admin%s">%s</a>' % (href, label) for href, label in (
        ("", "Overview"), ("/analytics", "Analytics"), ("/missions", "Missions"), ("/config", "Config"), ("/logs", "Generation log")))
    doc = ("<!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
           "<title>%s</title><style>body{font-family:system-ui,sans-serif;margin:1.2rem;background:#12202b;color:#f3e9d2}"
           "a{color:#d9b25f}table{border-collapse:collapse;width:100%%}td,th{border:1px solid #35505f;padding:.35rem .5rem;"
           "text-align:left;font-size:.9rem}pre{white-space:pre-wrap;word-break:break-all;background:#0c161d;padding:.6rem}"
           "input,button,select{font-size:1rem;padding:.3rem}</style></head><body><p>%s</p><h1>%s</h1>%s</body></html>")
    return HTMLResponse(doc % (html.escape(title), nav, html.escape(title), body))


def _table(headers: list, rows: list) -> str:
    head = "".join("<th>%s</th>" % html.escape(str(h)) for h in headers)
    body = "".join("<tr>%s</tr>" % "".join("<td>%s</td>" % c for c in row) for row in rows)
    return "<table><tr>%s</tr>%s</table>" % (head, body)


@router.get("", response_class=HTMLResponse)
def overview(request: Request, user: str = Depends(admin_user), db: Session = Depends(get_db)):
    now = utcnow()
    count = lambda q: db.scalar(q) or 0   # noqa: E731
    total = count(select(func.count()).select_from(Player))
    day = count(select(func.count()).select_from(Player).where(Player.last_seen >= now - timedelta(days=1)))
    week = count(select(func.count()).select_from(Player).where(Player.last_seen >= now - timedelta(days=7)))
    registered = count(select(func.count()).select_from(Player).where(Player.is_guest.is_(False)))
    done = count(select(func.count()).select_from(Completion))
    rejected = count(select(func.count()).select_from(Completion).where(Completion.accepted.is_(False)))
    rows = [["Total players", total], ["Registered accounts", registered], ["Active in 24 hours", day],
            ["Active in 7 days", week], ["Completions recorded", done], ["Completions rejected", rejected]]
    body = _table(["Metric", "Value"], rows)
    by = db.execute(select(Mission.kind, Mission.status, Mission.difficulty, func.count())
                    .group_by(Mission.kind, Mission.status, Mission.difficulty)
                    .order_by(Mission.kind, Mission.status, Mission.difficulty)).all()
    body += "<h2>Missions</h2>" + _table(["Kind", "Status", "Difficulty", "Count"], [list(r) for r in by])
    stats = db.execute(select(Mission.difficulty, func.count(Completion.id), func.avg(Completion.time_ms), func.avg(Completion.hints))
                       .join(Completion, Completion.mission_id == Mission.id).where(Completion.accepted.is_(True))
                       .group_by(Mission.difficulty).order_by(Mission.difficulty)).all()
    body += "<h2>Difficulty statistics</h2>" + _table(
        ["Difficulty", "Accepted completions", "Average time (s)", "Average hints"],
        [[d, n, "%.1f" % ((t or 0) / 1000.0), "%.2f" % (h or 0)] for d, n, t, h in stats])
    body += ("<h2>Run generation now</h2><form method='post' action='/admin/generate'>"
             "<input type='hidden' name='csrf' value='%s'><button>Generate</button></form>" % _csrf(request, user))
    return _page("Mystery Box admin", body)


@router.get("/missions", response_class=HTMLResponse)
def missions(request: Request, kind: str = "", status: str = "", user: str = Depends(admin_user), db: Session = Depends(get_db)):
    q = select(Mission)
    if kind in ("daily", "weekly", "pool"):
        q = q.where(Mission.kind == kind)
    if status in ("active", "disabled"):
        q = q.where(Mission.status == status)
    rows = []
    for m in db.scalars(q.order_by(Mission.created_at.desc()).limit(200)):
        plays = db.scalar(select(func.count()).select_from(Completion).where(Completion.mission_id == m.id)) or 0
        rows.append(['<a href="/admin/missions/%s">%s</a>' % (html.escape(m.id), html.escape(m.id)), m.kind,
                     html.escape(m.slot), m.difficulty, m.status, plays, m.created_at.strftime("%Y-%m-%d %H:%M")])
    links = " ".join('<a href="/admin/missions?kind=%s">%s</a>' % (k, k) for k in ("daily", "weekly", "pool"))
    return _page("Missions", "<p>Filter: %s <a href='/admin/missions?status=disabled'>disabled</a></p>" % links
                 + _table(["Id", "Kind", "Slot", "Difficulty", "Status", "Completions", "Created (UTC)"], rows))


@router.get("/missions/{mission_id}", response_class=HTMLResponse)
def mission_detail(mission_id: str, request: Request, user: str = Depends(admin_user), db: Session = Depends(get_db)):
    m = db.get(Mission, mission_id)
    if m is None:
        raise HTTPException(status_code=404, detail="unknown_mission")
    action = "disabled" if m.status == "active" else "active"
    label = "Disable this mission" if m.status == "active" else "Enable this mission"
    body = ("<p>Kind %s, slot %s, difficulty %d, status <b>%s</b>, seed %d, generator v%d</p>"
            "<form method='post' action='/admin/missions/%s/status'><input type='hidden' name='csrf' value='%s'>"
            "<input type='hidden' name='status' value='%s'><button>%s</button></form><pre>%s</pre>") % (
        m.kind, html.escape(m.slot), m.difficulty, m.status, m.seed, m.generator_version, html.escape(m.id),
        _csrf(request, user), action, label, html.escape(json.dumps(json.loads(m.payload), indent=2)))
    return _page("Mission " + m.id, body)


@router.post("/missions/{mission_id}/status")
def mission_status(mission_id: str, request: Request, status: str = Form(...), csrf: str = Form(...),
                   user: str = Depends(admin_user), db: Session = Depends(get_db)):
    _check_csrf(request, user, csrf)
    if not services.set_mission_status(db, mission_id, status):
        raise HTTPException(status_code=404, detail="unknown_mission")
    return RedirectResponse("/admin/missions/" + mission_id, status_code=303)


@router.get("/config", response_class=HTMLResponse)
def config_page(request: Request, user: str = Depends(admin_user), db: Session = Depends(get_db)):
    cfg = services.get_config(db)
    rows = "".join("<tr><td>%s</td><td><input name='%s' value='%s'></td></tr>" % (
        html.escape(k), html.escape(k), html.escape(json.dumps(v))) for k, v in cfg.items())
    body = ("<form method='post' action='/admin/config'><input type='hidden' name='csrf' value='%s'>"
            "<table><tr><th>Key</th><th>Value (JSON)</th></tr>%s</table><p><button>Save</button></p></form>") % (
        _csrf(request, user), rows)
    return _page("Config", body)


@router.post("/config")
async def config_save(request: Request, user: str = Depends(admin_user), db: Session = Depends(get_db)):
    form = await request.form()
    _check_csrf(request, user, str(form.get("csrf", "")))
    for key in services.DEFAULT_CONFIG:
        if key in form:
            try:
                services.set_config(db, key, json.loads(str(form[key])))
            except (ValueError, TypeError):
                raise HTTPException(status_code=422, detail="bad_value_for_" + key)
    return RedirectResponse("/admin/config", status_code=303)


@router.get("/logs", response_class=HTMLResponse)
def logs(user: str = Depends(admin_user), db: Session = Depends(get_db)):
    rows = [[g.created_at.strftime("%Y-%m-%d %H:%M:%S"), g.kind, g.requested, g.produced, g.failed, html.escape(g.message)]
            for g in db.scalars(select(GenerationLog).order_by(GenerationLog.id.desc()).limit(200))]
    return _page("Generation log", _table(["Time (UTC)", "Kind", "Requested", "Produced", "Failed", "Message"], rows))


@router.get("/analytics", response_class=HTMLResponse)
def analytics(user: str = Depends(admin_user), db: Session = Depends(get_db)):
    """Engagement, retention, ad impressions, purchases and frame rate for the last 14 days."""
    today = utcnow().date()
    days = [(today - timedelta(days=i)).isoformat() for i in range(14)]
    counts = {}
    for day, name, n in db.execute(select(Event.day, Event.name, func.count()).where(Event.day >= days[-1])
                                   .group_by(Event.day, Event.name)).all():
        counts[(day, name)] = n
    kinds = {}
    for day, props in db.execute(select(Event.day, Event.props).where(Event.day >= days[-1], Event.name == "ad_impression")).all():
        try:
            kind = str(json.loads(props).get("kind", "?"))
        except ValueError:
            kind = "?"
        kinds[(day, kind)] = kinds.get((day, kind), 0) + 1
    active = dict(db.execute(select(Event.day, func.count(func.distinct(Event.player_id))).where(Event.day >= days[-1])
                             .group_by(Event.day)).all())
    rows = []
    for day in days:
        next_day = (today.fromisoformat(day) + timedelta(days=1)).isoformat()
        cohort = [p for (p,) in db.execute(select(Player.id).where(func.date(Player.created_at) == day)).all()]
        returned = 0
        if cohort:
            returned = db.scalar(select(func.count(func.distinct(Event.player_id))).where(
                Event.day == next_day, Event.player_id.in_(cohort))) or 0
        retention = "%d%% (%d of %d)" % (round(100.0 * returned / len(cohort)), returned, len(cohort)) if cohort else "-"
        rows.append([day, active.get(day, 0), counts.get((day, "session_start"), 0), counts.get((day, "box_complete"), 0),
                     kinds.get((day, "interstitial"), 0), kinds.get((day, "rewarded"), 0), counts.get((day, "ad_reward"), 0),
                     counts.get((day, "purchase"), 0), retention])
    body = _table(["Day (UTC)", "Active players", "Sessions", "Boxes opened", "Interstitial ads", "Rewarded ads",
                   "Rewards given", "Purchases", "New players back next day"], rows)
    fps = []
    for (props,) in db.execute(select(Event.props).where(Event.name == "perf").order_by(Event.id.desc()).limit(500)).all():
        try:
            sample = json.loads(props)
        except ValueError:
            continue
        if "fps_avg" in sample:
            fps.append(sample)
    if fps:
        avg = sum(float(f.get("fps_avg", 0)) for f in fps) / len(fps)
        low = sum(1 for f in fps if float(f.get("fps_min", 60)) < 30)
        body += "<h2>Technical performance</h2><p>Last %d sessions: average %.0f FPS; %d sessions dropped below 30 FPS.</p>" % (
            len(fps), avg, low)
    body += ("<p>Ad REVENUE is not known to this server: read it in the AdMob console. "
             "Purchases here are counts reported by the game, not verified receipts.</p>")
    return _page("Analytics", body)


@router.post("/generate")
def generate_now(request: Request, csrf: str = Form(...), user: str = Depends(admin_user), db: Session = Depends(get_db)):
    _check_csrf(request, user, csrf)
    services.run_once(db)
    return RedirectResponse("/admin/logs", status_code=303)
