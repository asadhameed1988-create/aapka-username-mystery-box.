extends RefCounted
## LANTERN SWITCHES (hidden switches): every switch flips its own lantern and
## some hidden others. Goal: all lanterns lit.
## Built from the all-lit state by pressing switches, then verified with BFS
## over every lantern state (at most 2^9 = 512), which gives the fewest presses.

const Rng = preload("res://scripts/pcg/Rng.gd")

const TYPE := "lights"
const MAX_ATTEMPTS := 40

const TIERS := {
	1: {"count": 3, "links": 1, "min": 2, "presses": 2},
	2: {"count": 4, "links": 1, "min": 2, "presses": 3},
	3: {"count": 5, "links": 1, "min": 3, "presses": 3},
	4: {"count": 6, "links": 2, "min": 3, "presses": 4},
	5: {"count": 9, "links": 2, "min": 4, "presses": 5},
}


static func generate(seed_value: int, difficulty: int) -> Dictionary:
	var level: int = clampi(difficulty, 1, 5)
	var spec: Dictionary = {}
	for attempt in MAX_ATTEMPTS:
		var sub_seed: int = seed_value
		if attempt > 0:
			sub_seed = Rng.derive(seed_value, attempt, 53)
		spec = _build(sub_seed, level)
		spec["seed"] = seed_value
		spec["attempts"] = attempt + 1
		if bool(spec["valid"]):
			break
	return spec


static func _build(seed_value: int, level: int) -> Dictionary:
	var tier: Dictionary = TIERS[level]
	var rng: RandomNumberGenerator = Rng.make(seed_value)
	var n: int = int(tier["count"])
	var toggles: Array = []
	for i in n:
		var list: Array = [i]
		var others: Array = Rng.shuffled(range(n), rng)
		for o in others:
			if list.size() > int(tier["links"]):
				break
			if int(o) != i:
				list.append(int(o))
		toggles.append(list)
	var mask: int = (1 << n) - 1
	var pressed: Array = Rng.shuffled(range(n), rng).slice(0, int(tier["presses"]))
	for sw in pressed:
		mask = mask ^ _mask(toggles[int(sw)])
	var start: Array = []
	for i in n:
		start.append((mask >> i) & 1)
	var spec: Dictionary = {
		"type": TYPE,
		"seed": seed_value,
		"difficulty": level,
		"params": {"count": n, "toggles": toggles, "start": start},
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = res["ok"]
	spec["reason"] = res["reason"]
	spec["solution"] = res["solution"]
	spec["score"] = score(spec)
	spec["signature"] = (TYPE + JSON.stringify(spec["params"])).md5_text()
	return spec


static func _mask(list: Array) -> int:
	var m: int = 0
	for i in list:
		m = m | (1 << int(i))
	return m


static func state_mask(state: Array) -> int:
	var m: int = 0
	for i in state.size():
		if int(state[i]) != 0:
			m = m | (1 << i)
	return m


## Flips the lanterns of one switch. Returns the new state array.
static func press(state: Array, toggles: Array, index: int) -> Array:
	var out: Array = state.duplicate()
	for i in toggles[index]:
		out[int(i)] = 1 - int(out[int(i)])
	return out


static func is_solved(state: Array) -> bool:
	for v in state:
		if int(v) == 0:
			return false
	return true


## BFS to the all-lit state. Returns {"ok", "presses"} (fewest switch presses).
static func solve(params: Dictionary, state: Array) -> Dictionary:
	var n: int = int(params["count"])
	var masks: Array = []
	for list in params["toggles"]:
		masks.append(_mask(list))
	var goal: int = (1 << n) - 1
	var start: int = state_mask(state)
	if start == goal:
		return {"ok": true, "presses": []}
	var prev: Dictionary = {start: -1}
	var via: Dictionary = {}
	var queue: Array = [start]
	var head: int = 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		for i in n:
			var nxt: int = cur ^ int(masks[i])
			if prev.has(nxt):
				continue
			prev[nxt] = cur
			via[nxt] = i
			if nxt == goal:
				var presses: Array = []
				var walk: int = nxt
				while walk != start:
					presses.push_front(via[walk])
					walk = prev[walk]
				return {"ok": true, "presses": presses}
			queue.append(nxt)
	return {"ok": false, "presses": []}


static func validate(spec: Dictionary) -> Dictionary:
	var p: Dictionary = spec.get("params", {})
	var level: int = clampi(int(spec.get("difficulty", 1)), 1, 5)
	var tier: Dictionary = TIERS[level]
	var n: int = int(p.get("count", 0))
	if n < 2 or n > 9:
		return _fail("bad_size")
	var toggles: Array = p.get("toggles", [])
	var start: Array = p.get("start", [])
	if toggles.size() != n or start.size() != n:
		return _fail("bad_arrays")
	for i in n:
		var list: Array = toggles[i]
		if list.is_empty() or int(list[0]) != i:
			return _fail("bad_toggle")
		var seen: Dictionary = {}
		for t in list:
			if int(t) < 0 or int(t) >= n or seen.has(int(t)):
				return _fail("bad_toggle")
			seen[int(t)] = true
	for v in start:
		if int(v) != 0 and int(v) != 1:
			return _fail("bad_start")
	var res: Dictionary = solve(p, start)
	if not bool(res["ok"]):
		return _fail("unsolvable")
	var presses: Array = res["presses"]
	if presses.size() < int(tier["min"]):
		return _fail("too_easy")
	return {"ok": true, "reason": "", "solution": presses}


static func score(spec: Dictionary) -> float:
	var p: Dictionary = spec["params"]
	var sol: Array = spec.get("solution", [])
	return float(int(p["count"])) * 0.4 + float(sol.size()) * 0.8


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "solution": []}
