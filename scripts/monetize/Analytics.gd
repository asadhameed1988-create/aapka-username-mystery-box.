extends Node
## Autoload "Analytics": a few anonymous usage events sent to OUR OWN server
## (backend /v1/events), never to third parties. Off when online play or the
## "usage statistics" setting is off; events wait in the save file while offline.

const FLUSH_SECONDS := 30.0
const BATCH := 20
const MAX_STORED := 200
const PERF_AFTER_SECONDS := 60.0

var _timer: float = 0.0
var _sending: bool = false
var _fps_sum: float = 0.0
var _fps_min: float = 9999.0
var _fps_samples: int = 0
var _perf_clock: float = 0.0
var _perf_sent: bool = false


func _ready() -> void:
	track.call_deferred("session_start", {"version": str(ProjectSettings.get_setting("application/config/version", "dev"))})


func allowed() -> bool:
	return Online.is_enabled() and bool((GameState.data["settings"] as Dictionary).get("analytics", true))


func track(event_name: String, props: Dictionary = {}) -> void:
	if not allowed():
		return
	var queue: Array = GameState.data["online"]["events"]
	queue.append({"name": event_name, "props": props, "at": int(Time.get_unix_time_from_system())})
	while queue.size() > MAX_STORED:
		queue.pop_front()
	if queue.size() >= BATCH:
		flush()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= FLUSH_SECONDS:
		_timer = 0.0
		flush()
	# One technical-performance sample per session (average and lowest frame rate).
	if not _perf_sent:
		_perf_clock += delta
		if _perf_clock >= 1.0:
			var fps: float = Engine.get_frames_per_second()
			_fps_sum += fps
			_fps_min = minf(_fps_min, fps)
			_fps_samples += 1
			_perf_clock = 0.0
			if float(_fps_samples) >= PERF_AFTER_SECONDS:
				_perf_sent = true
				track("perf", {"fps_avg": int(_fps_sum / float(_fps_samples)), "fps_min": int(_fps_min),
					"quality": str(GameState.data["settings"].get("quality", "high"))})


func flush() -> void:
	var queue: Array = GameState.data["online"]["events"]
	if _sending or queue.is_empty() or not allowed():
		return
	_sending = true
	var batch: Array = queue.slice(0, BATCH)
	var r: Dictionary = await Online.authed(HTTPClient.METHOD_POST, "/v1/events", {"events": batch})
	if bool(r["ok"]) or int(r["code"]) == 422:
		for i in batch.size():
			if not queue.is_empty():
				queue.pop_front()
		GameState.save_game()
	_sending = false
