extends Node
## Autoload "Online": everything that talks to the backend (backend/ folder).
## The game stays fully playable when this does nothing: with no server address,
## with online play switched off, or when the network fails.
##
## After deploying the server, put its HTTPS address in DEFAULT_SERVER_URL.

const MissionGen = preload("res://scripts/pcg/MissionGenerator.gd")

const DEFAULT_SERVER_URL := ""      # example: "https://api.yourdomain.com"
const TIMEOUT := 10.0
const MAX_QUEUE := 50
const SYNC_KEYS := ["round", "rating", "chapters", "achievements", "inventory", "stats", "daily_done"]
const SYNC_EVERY_MSEC := 5 * 60 * 1000

var _flushing: bool = false
var _last_sync_msec: int = -SYNC_EVERY_MSEC


func _store() -> Dictionary:
	return GameState.data["online"]


func server_url() -> String:
	var custom: String = str(_store().get("server_url", ""))
	if custom != "":
		return custom
	return DEFAULT_SERVER_URL


func is_configured() -> bool:
	return server_url() != ""


func is_enabled() -> bool:
	return is_configured() and bool((GameState.data["settings"] as Dictionary).get("online", true))


func profile() -> Dictionary:
	return _store().get("profile", {})


func is_logged_in() -> bool:
	return str(_store().get("token", "")) != ""


# ------------------------------------------------------------------ HTTP

## One request. Returns {"ok": bool, "code": int (0 = no connection), "data": Dictionary}.
func api(method: int, path: String, body = null, with_auth: bool = true) -> Dictionary:
	var failed: Dictionary = {"ok": false, "code": 0, "data": {}}
	if not is_enabled():
		return failed
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	var token: String = str(_store().get("token", ""))
	if with_auth and token != "":
		headers.append("Authorization: Bearer " + token)
	var payload: String = ""
	if body != null:
		payload = JSON.stringify(body)
	if http.request(server_url() + path, headers, method, payload) != OK:
		http.queue_free()
		return failed
	var res: Array = await http.request_completed
	http.queue_free()
	var code: int = int(res[1])
	var data: Dictionary = {}
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var json: JSON = JSON.new()
	if text != "" and json.parse(text) == OK and typeof(json.data) == TYPE_DICTIONARY:
		data = json.data
	return {"ok": int(res[0]) == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300, "code": code, "data": data}


func ensure_login() -> bool:
	if is_logged_in():
		return true
	var r: Dictionary = await api(HTTPClient.METHOD_POST, "/v1/auth/guest", {}, false)
	if not bool(r["ok"]):
		return false
	_adopt_login(r["data"])
	return true


func _adopt_login(data: Dictionary) -> void:
	_store()["token"] = str(data.get("token", ""))
	_store()["profile"] = data.get("profile", {})
	GameState.save_game()


func _forget_login() -> void:
	_store()["token"] = ""
	_store()["profile"] = {}


## Authenticated request; logs in as a guest when needed and retries once if the token was refused.
func authed(method: int, path: String, body = null) -> Dictionary:
	if not await ensure_login():
		return {"ok": false, "code": 0, "data": {}}
	var r: Dictionary = await api(method, path, body)
	if int(r["code"]) == 401:
		_forget_login()
		if await ensure_login():
			r = await api(method, path, body)
	return r


# -------------------------------------------------------------- missions

## Accepts a server mission only if THIS game version can validate it.
func _accept(entry: Dictionary) -> Dictionary:
	var mission = entry.get("mission")
	if typeof(mission) != TYPE_DICTIONARY:
		return {}
	if int(mission.get("generator_version", 0)) > MissionGen.VERSION:
		return {}
	if not bool(MissionGen.validate_mission(mission)["ok"]):
		return {}
	mission["server_id"] = str(entry.get("id", ""))
	return mission


## Today's server mission ({} when offline or unusable; the caller then uses the local daily box).
func daily_mission() -> Dictionary:
	var cache: Dictionary = _store().get("daily", {})
	if str(cache.get("fetched_on", "")) == Missions.today_key() and typeof(cache.get("mission")) == TYPE_DICTIONARY:
		return cache["mission"]
	if not is_enabled():
		return {}
	var r: Dictionary = await authed(HTTPClient.METHOD_GET, "/v1/missions/daily")
	if not bool(r["ok"]):
		return {}
	var mission: Dictionary = _accept(r["data"])
	if mission.is_empty():
		return {}
	_store()["daily"] = {"fetched_on": Missions.today_key(), "mission": mission}
	GameState.save_game()
	return mission


## This week's server missions. Uses the cache when the network is down.
func weekly_missions() -> Array:
	var cache: Dictionary = _store().get("weekly", {})
	var cached: Array = cache.get("missions", [])
	if str(cache.get("fetched_on", "")) == Missions.today_key() and not cached.is_empty():
		return cached
	if not is_enabled():
		return cached
	var r: Dictionary = await authed(HTTPClient.METHOD_GET, "/v1/missions/weekly")
	if not bool(r["ok"]):
		return cached
	var fresh: Array = []
	for entry in r["data"].get("missions", []):
		var mission: Dictionary = _accept(entry)
		if not mission.is_empty():
			fresh.append(mission)
	if fresh.is_empty():
		return cached
	_store()["weekly"] = {"fetched_on": Missions.today_key(), "slot": str(r["data"].get("slot", "")), "missions": fresh}
	GameState.save_game()
	return fresh


# ------------------------------------------------------- results / queue

## Called by Missions.complete(). Results wait in a saved queue until the server confirms them.
func report_completion(mission: Dictionary, time_sec: float, hints: int) -> void:
	if not mission.has("server_id") or not is_configured():
		return
	var queue: Array = _store()["queue"]
	queue.append({"id": str(mission["server_id"]), "time_ms": int(time_sec * 1000.0), "hints": hints})
	while queue.size() > MAX_QUEUE:
		queue.pop_front()
	GameState.save_game()
	flush_queue()


func flush_queue() -> void:
	if _flushing or not is_enabled():
		return
	_flushing = true
	var queue: Array = _store()["queue"]
	while not queue.is_empty():
		var item: Dictionary = queue[0]
		var r: Dictionary = await authed(HTTPClient.METHOD_POST, "/v1/missions/%s/complete" % str(item["id"]),
			{"time_ms": int(item["time_ms"]), "hints": int(item["hints"])})
		var code: int = int(r["code"])
		if bool(r["ok"]):
			_store()["last_result"] = {"id": str(item["id"]), "accepted": bool(r["data"].get("accepted", false)),
				"rank": r["data"].get("rank")}
		elif code != 404 and code != 422:
			break      # no connection or server trouble: keep the result and try again later
		queue.pop_front()
		GameState.save_game()
	_flushing = false


func leaderboard(mission_id: String) -> Dictionary:
	var r: Dictionary = await authed(HTTPClient.METHOD_GET, "/v1/leaderboard/%s?limit=20" % mission_id)
	return {"ok": bool(r["ok"]), "entries": r["data"].get("entries", [])}


# ------------------------------------------------------------- progress

## Sends the save; if the server holds a save with MORE boxes opened, this device adopts it.
func sync_progress(force: bool = false) -> bool:
	if not is_enabled():
		return false
	if not force and Time.get_ticks_msec() - _last_sync_msec < SYNC_EVERY_MSEC:
		return false
	_last_sync_msec = Time.get_ticks_msec()
	var snapshot: Dictionary = {}
	for key in SYNC_KEYS:
		snapshot[key] = GameState.data[key]
	var solved: int = int(GameState.data["stats"]["solved"])
	var r: Dictionary = await authed(HTTPClient.METHOD_PUT, "/v1/progress", {"solved": solved, "data": snapshot})
	if not bool(r["ok"]):
		return false
	if str(r["data"].get("winner", "")) == "server":
		var remote = r["data"].get("data")
		if typeof(remote) == TYPE_DICTIONARY:
			for key in SYNC_KEYS:
				if remote.has(key):
					GameState.data[key] = remote[key]
			GameState.repair()
			GameState.save_game()
	return true


func fetch_config() -> void:
	var r: Dictionary = await authed(HTTPClient.METHOD_GET, "/v1/config")
	if bool(r["ok"]):
		_store()["config"] = r["data"]
		GameState.save_game()


## Background housekeeping when the main menu opens.
func on_menu_opened() -> void:
	if not is_enabled():
		return
	await flush_queue()
	if await sync_progress():
		await fetch_config()


# -------------------------------------------------------------- account

func update_account(patch: Dictionary) -> Dictionary:
	var r: Dictionary = await authed(HTTPClient.METHOD_PATCH, "/v1/account", patch)
	if bool(r["ok"]):
		_store()["profile"] = r["data"]
		GameState.save_game()
	return r


func register(email: String, password: String) -> Dictionary:
	var r: Dictionary = await authed(HTTPClient.METHOD_POST, "/v1/auth/register", {"email": email, "password": password})
	if bool(r["ok"]):
		_adopt_login(r["data"])
	return r


func login(email: String, password: String) -> Dictionary:
	var r: Dictionary = await api(HTTPClient.METHOD_POST, "/v1/auth/login", {"email": email, "password": password}, false)
	if bool(r["ok"]):
		_adopt_login(r["data"])
		await sync_progress(true)
	return r


## Deletes the server account and every server record of this player. Local progress stays on the phone.
func delete_account() -> bool:
	if not is_logged_in():
		return true
	var r: Dictionary = await api(HTTPClient.METHOD_DELETE, "/v1/account")
	if bool(r["ok"]) or int(r["code"]) == 401:
		_forget_login()
		_store()["queue"] = []
		GameState.save_game()
		return true
	return false
