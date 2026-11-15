from sqlalchemy import select

from app import db, services
from app.models import GenerationLog, Mission
from conftest import guest

ADMIN = ("owner", "owner-pass")


def test_health_and_auth_required(client):
    assert client.get("/health").json() == {"ok": True}
    assert client.get("/v1/missions/daily").status_code == 401
    assert client.get("/v1/missions/daily", headers={"Authorization": "Bearer nonsense"}).status_code == 401


def test_daily_mission_is_generated_once_and_stable(client, gen):
    a, b = guest(client), guest(client)
    first = client.get("/v1/missions/daily", headers=a).json()
    second = client.get("/v1/missions/daily", headers=b).json()
    assert first["id"] == second["id"]
    assert first["kind"] == "daily" and first["difficulty"] == 3
    assert first["mission"]["stages"] and first["mission"]["valid"] is True
    assert gen.calls == 1


def test_completion_leaderboard_and_cheat_checks(client):
    a, b, c = guest(client), guest(client), guest(client)
    mission_id = client.get("/v1/missions/daily", headers=a).json()["id"]
    url = "/v1/missions/%s/complete" % mission_id
    assert client.post(url, json={"time_ms": 90_000, "hints": 0}, headers=a).json()["accepted"] is True
    fast = client.post(url, json={"time_ms": 60_000, "hints": 1}, headers=b).json()
    assert fast["accepted"] is True and fast["rank"] == 1
    # Impossible time is stored but rejected, and never shown.
    cheat = client.post(url, json={"time_ms": 200, "hints": 0}, headers=c).json()
    assert cheat["accepted"] is False and cheat["reason"] == "too_fast"
    # A replay cannot overwrite the first result.
    again = client.post(url, json={"time_ms": 10_000, "hints": 0}, headers=a).json()
    assert again["time_ms"] == 90_000
    board = client.get("/v1/leaderboard/" + mission_id, headers=a).json()["entries"]
    assert [e["time_ms"] for e in board] == [60_000, 90_000]
    assert board[1]["me"] is True and board[0]["me"] is False
    assert "player_id" not in board[0] and board[0]["name"].startswith("Guest-")
    assert client.post("/v1/missions/nope/complete", json={"time_ms": 5000, "hints": 0}, headers=a).status_code == 404
    assert client.post(url, json={"time_ms": -1, "hints": 0}, headers=a).status_code == 422


def test_leaderboard_privacy_opt_out(client):
    a, b = guest(client), guest(client)
    mission_id = client.get("/v1/missions/daily", headers=a).json()["id"]
    for h, t in ((a, 50_000), (b, 70_000)):
        client.post("/v1/missions/%s/complete" % mission_id, json={"time_ms": t, "hints": 0}, headers=h)
    assert client.patch("/v1/account", json={"show_on_leaderboard": False}, headers=a).json()["show_on_leaderboard"] is False
    board = client.get("/v1/leaderboard/" + mission_id, headers=b).json()["entries"]
    assert [e["time_ms"] for e in board] == [70_000]


def test_register_login_and_account_delete(client):
    a = guest(client)
    r = client.post("/v1/auth/register", json={"email": "Player@Example.com", "password": "correct horse", "display_name": "Asad"}, headers=a)
    assert r.status_code == 200 and r.json()["profile"]["is_guest"] is False
    assert client.post("/v1/auth/register", json={"email": "player@example.com", "password": "another pass"}, headers=guest(client)).status_code == 409
    assert client.post("/v1/auth/register", json={"email": "not-an-email", "password": "long enough"}, headers=guest(client)).status_code == 422
    assert client.post("/v1/auth/login", json={"email": "player@example.com", "password": "wrong"}).status_code == 401
    token = client.post("/v1/auth/login", json={"email": "player@example.com", "password": "correct horse"}).json()["token"]
    h = {"Authorization": "Bearer " + token}
    assert client.get("/v1/account", headers=h).json()["display_name"] == "Asad"
    assert client.patch("/v1/account", json={"display_name": "<script>"}, headers=h).status_code == 422
    assert client.delete("/v1/account", headers=h).json() == {"deleted": True}
    assert client.get("/v1/account", headers=h).status_code == 401
    assert client.post("/v1/auth/login", json={"email": "player@example.com", "password": "correct horse"}).status_code == 401


def test_progress_sync_keeps_the_save_with_more_boxes(client):
    a = guest(client)
    assert client.get("/v1/progress", headers=a).json()["solved"] == 0
    assert client.put("/v1/progress", json={"solved": 12, "data": {"round": 12}}, headers=a).json()["winner"] == "client"
    older = client.put("/v1/progress", json={"solved": 4, "data": {"round": 4}}, headers=a).json()
    assert older["winner"] == "server" and older["data"] == {"round": 12}
    assert client.put("/v1/progress", json={"solved": 20, "data": {"round": 20}}, headers=a).json()["solved"] == 20
    assert client.get("/v1/progress", headers=a).json()["data"] == {"round": 20}
    assert client.put("/v1/progress", json={"solved": 21, "data": {"x": "y" * 300_000}}, headers=a).status_code == 413


def test_weekly_pool_and_generation_limits(client, gen):
    a = guest(client)
    weekly = client.get("/v1/missions/weekly", headers=a).json()
    assert len(weekly["missions"]) == 5 and len({m["id"] for m in weekly["missions"]}) == 5
    session = db.new_session()
    try:
        services.set_config(session, "pool_target_per_difficulty", 4)
        services.set_config(session, "max_generate_per_run", 10)
        summary = services.run_once(session)
        assert summary["pool"] == 10                       # capped by the per-run budget
        summary = services.run_once(session)
        assert summary["pool"] == 10                       # second pass finishes the 20
        assert services.run_once(session)["pool"] == 0     # nothing left to do
        assert session.scalar(select(Mission).where(Mission.slot == services.today_slot(), Mission.kind == "daily")) is not None
    finally:
        session.close()
    pool = client.get("/v1/missions/pool?difficulty=2&limit=3", headers=a).json()["missions"]
    assert len(pool) == 3 and all(m["difficulty"] == 2 for m in pool)
    client.post("/v1/missions/%s/complete" % pool[0]["id"], json={"time_ms": 80_000, "hints": 0}, headers=a)
    after = client.get("/v1/missions/pool?difficulty=2&limit=3", headers=a).json()["missions"]
    assert pool[0]["id"] not in [m["id"] for m in after]


def test_generator_failure_is_logged_and_client_told_to_use_local(client, gen):
    gen.fail = True
    r = client.get("/v1/missions/daily", headers=guest(client))
    assert r.status_code == 503 and r.json()["detail"] == "no_mission_use_local"
    session = db.new_session()
    try:
        log = session.scalars(select(GenerationLog)).all()
        assert log and log[-1].produced == 0 and "simulated failure" in log[-1].message
    finally:
        session.close()


def test_admin_requires_login_and_can_replace_a_broken_daily(client):
    assert client.get("/admin").status_code == 401
    assert client.get("/admin", auth=("owner", "wrong")).status_code == 401
    a = guest(client)
    first = client.get("/v1/missions/daily", headers=a).json()["id"]
    page = client.get("/admin", auth=ADMIN)
    assert page.status_code == 200 and "Total players" in page.text
    detail = client.get("/admin/missions/" + first, auth=ADMIN)
    assert detail.status_code == 200
    csrf = detail.text.split("name='csrf' value='")[1].split("'")[0]
    assert client.post("/admin/missions/%s/status" % first, data={"status": "disabled", "csrf": "wrong"}, auth=ADMIN).status_code == 403
    r = client.post("/admin/missions/%s/status" % first, data={"status": "disabled", "csrf": csrf}, auth=ADMIN, follow_redirects=False)
    assert r.status_code == 303
    second = client.get("/v1/missions/daily", headers=a).json()["id"]
    assert second != first                                   # a replacement was generated automatically
    late = client.post("/v1/missions/%s/complete" % first, json={"time_ms": 90_000, "hints": 0}, headers=a).json()
    assert late["accepted"] is False and late["reason"] == "mission_not_active"
    for path in ("/admin/missions", "/admin/config", "/admin/logs"):
        assert client.get(path, auth=ADMIN).status_code == 200
    assert client.post("/admin/config", data={"csrf": csrf, "daily_difficulty": "5"}, auth=ADMIN, follow_redirects=False).status_code == 303
    assert client.get("/v1/config", headers=a).json()["content_version"] == 1


def test_usage_events_and_admin_analytics(client):
    a, b = guest(client), guest(client)
    events = [{"name": "session_start", "props": {"version": "0.8.0"}},
              {"name": "box_complete", "props": {"mode": "endless", "difficulty": 2, "seconds": 70, "hints": 0}},
              {"name": "ad_impression", "props": {"kind": "interstitial"}},
              {"name": "ad_impression", "props": {"kind": "rewarded"}},
              {"name": "ad_reward", "props": {"hints": 3}},
              {"name": "purchase", "props": {"product": "remove_ads"}},
              {"name": "perf", "props": {"fps_avg": 58, "fps_min": 41, "quality": "high"}},
              {"name": "something_else", "props": {}},
              {"name": "perf", "props": {"junk": "x" * 2000}}]
    assert client.post("/v1/events", json={"events": events}, headers=a).json() == {"stored": 8}
    assert client.post("/v1/events", json={"events": [{"name": "session_start"}]}, headers=b).json() == {"stored": 1}
    assert client.post("/v1/events", json={"events": [{"name": "perf"}] * 51}, headers=a).status_code == 422
    assert client.post("/v1/events", json={"events": events}).status_code == 401
    page = client.get("/admin/analytics", auth=ADMIN)
    assert page.status_code == 200
    today_row = page.text.split("<tr>")[2]
    cells = [c.split("</td>")[0] for c in today_row.split("<td>")[1:]]
    assert cells[1:8] == ["2", "2", "1", "1", "1", "1", "1"]      # active, sessions, boxes, interstitial, rewarded, rewards, purchases
    assert "Last 1 sessions: average 58 FPS; 0 sessions dropped below 30 FPS" in page.text
    cfg = client.get("/v1/config", headers=a).json()
    assert cfg["sponsor_text"] == "" and "sponsor_url" in cfg
    assert client.delete("/v1/account", headers=a).json() == {"deleted": True}
    session = db.new_session()
    try:
        from app.models import Event
        assert len(session.scalars(select(Event)).all()) == 1          # only player b's event is left
    finally:
        session.close()
