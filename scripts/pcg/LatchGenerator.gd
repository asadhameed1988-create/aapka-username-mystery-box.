extends RefCounted
## SEALED LATCHES (hidden dependency order).
## Each latch is blocked by other latches (engraved on it as small symbols).
## The dependency graph is built from a hidden opening order, so it is always
## acyclic; it is then verified with a topological sort (Kahn's algorithm).

const Rng = preload("res://scripts/pcg/Rng.gd")

const TYPE := "latch"
const SYMBOL_COUNT := 8
const MAX_ATTEMPTS := 20
const MAX_BLOCKERS := 2

const TIERS := {
	1: {"count": 3, "depth": 2, "extra": 0, "reset": false},
	2: {"count": 4, "depth": 3, "extra": 1, "reset": false},
	3: {"count": 5, "depth": 3, "extra": 2, "reset": true},
	4: {"count": 6, "depth": 4, "extra": 3, "reset": true},
	5: {"count": 8, "depth": 5, "extra": 5, "reset": true},
}


static func generate(seed_value: int, difficulty: int) -> Dictionary:
	var level: int = clampi(difficulty, 1, 5)
	var spec: Dictionary = {}
	for attempt in MAX_ATTEMPTS:
		var sub_seed: int = seed_value
		if attempt > 0:
			sub_seed = Rng.derive(seed_value, attempt, 41)
		spec = _build(sub_seed, level)
		spec["seed"] = seed_value
		spec["attempts"] = attempt + 1
		if bool(spec["valid"]):
			break
	return spec


static func _build(seed_value: int, level: int) -> Dictionary:
	var tier: Dictionary = TIERS[level]
	var rng: RandomNumberGenerator = Rng.make(seed_value)
	var n: int = tier["count"]
	var depth: int = tier["depth"]
	var order: Array = Rng.shuffled(range(n), rng)
	var deps: Array = []
	for i in n:
		deps.append([])
	# Guaranteed chain of the required depth.
	for k in range(1, depth):
		(deps[int(order[k])] as Array).append(int(order[k - 1]))
	# Extra edges, always from an earlier latch to a later one (keeps it acyclic).
	var added: int = 0
	var guard: int = 0
	while added < int(tier["extra"]) and guard < 80:
		guard += 1
		var ib: int = rng.randi_range(1, n - 1)
		var ia: int = rng.randi_range(0, ib - 1)
		var a: int = int(order[ia])
		var b: int = int(order[ib])
		var list: Array = deps[b]
		if list.has(a) or list.size() >= MAX_BLOCKERS:
			continue
		list.append(a)
		added += 1
	var spec: Dictionary = {
		"type": TYPE,
		"seed": seed_value,
		"difficulty": level,
		"params": {
			"count": n,
			"symbols": Rng.shuffled(range(SYMBOL_COUNT), rng).slice(0, n),
			"deps": deps,
			"reset_on_error": bool(tier["reset"]),
		},
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = res["ok"]
	spec["reason"] = res["reason"]
	spec["solution"] = res["solution"]
	spec["score"] = score(spec)
	spec["signature"] = (TYPE + JSON.stringify(spec["params"])).md5_text()
	return spec


## Topological sort. Returns {"ok", "order", "depth"}.
static func solve(params: Dictionary) -> Dictionary:
	var n: int = int(params["count"])
	var deps: Array = params["deps"]
	var opened: Dictionary = {}
	var level_of: Dictionary = {}
	var order: Array = []
	var max_depth: int = 0
	var progress: bool = true
	while progress:
		progress = false
		for i in n:
			if opened.has(i):
				continue
			var ready: bool = true
			var lvl: int = 1
			for d in deps[i]:
				var di: int = int(d)
				if not opened.has(di):
					ready = false
					break
				lvl = maxi(lvl, int(level_of[di]) + 1)
			if ready:
				opened[i] = true
				level_of[i] = lvl
				max_depth = maxi(max_depth, lvl)
				order.append(i)
				progress = true
	return {"ok": order.size() == n, "order": order, "depth": max_depth}


static func validate(spec: Dictionary) -> Dictionary:
	var p: Dictionary = spec.get("params", {})
	var level: int = clampi(int(spec.get("difficulty", 1)), 1, 5)
	var tier: Dictionary = TIERS[level]
	var n: int = int(p.get("count", 0))
	if n < 2 or n > SYMBOL_COUNT:
		return _fail("bad_size")
	var deps: Array = p.get("deps", [])
	var symbols: Array = p.get("symbols", [])
	if deps.size() != n or symbols.size() != n:
		return _fail("bad_arrays")
	var seen: Dictionary = {}
	for s in symbols:
		var sid: int = int(s)
		if sid < 0 or sid >= SYMBOL_COUNT or seen.has(sid):
			return _fail("duplicate_symbol")
		seen[sid] = true
	var edges: int = 0
	for i in n:
		var list: Array = deps[i]
		if list.size() > MAX_BLOCKERS:
			return _fail("too_many_blockers")
		for d in list:
			if int(d) < 0 or int(d) >= n or int(d) == i:
				return _fail("bad_dependency")
			edges += 1
	if edges == 0:
		return _fail("trivial")
	var res: Dictionary = solve(p)
	if not bool(res["ok"]):
		return _fail("cycle_unsolvable")
	if int(res["depth"]) < int(tier["depth"]):
		return _fail("too_easy")
	return {"ok": true, "reason": "", "solution": res["order"]}


static func score(spec: Dictionary) -> float:
	var p: Dictionary = spec["params"]
	var edges: int = 0
	for list in p["deps"]:
		edges += (list as Array).size()
	var bonus: float = 0.0
	if bool(p.get("reset_on_error", false)):
		bonus = 1.0
	return float(int(p["count"])) * 0.4 + float(edges) * 0.4 + bonus


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "solution": []}
