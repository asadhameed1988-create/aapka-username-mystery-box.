extends RefCounted
## ASTROLABE RINGS (rotating symbol rings, interconnected).
## Concentric rings carry symbols. Turning one ring can drag linked rings.
## Goal: every ring shows its target symbol (index 0) under the marker.
##
## Generation: start from the SOLVED state, apply legal moves (always solvable),
## then verify with breadth-first search, which also gives the shortest solution.

const Rng = preload("res://scripts/pcg/Rng.gd")

const TYPE := "rings"
const SYMBOL_COUNT := 8
const MAX_ATTEMPTS := 40

const TIERS := {
	1: {"rings": 2, "pos": 4, "links": 0, "min_moves": 2, "max_moves": 4, "scramble": 4},
	2: {"rings": 3, "pos": 5, "links": 1, "min_moves": 3, "max_moves": 7, "scramble": 7},
	3: {"rings": 3, "pos": 6, "links": 2, "min_moves": 4, "max_moves": 10, "scramble": 12},
	4: {"rings": 4, "pos": 6, "links": 3, "min_moves": 6, "max_moves": 14, "scramble": 14},
	5: {"rings": 4, "pos": 8, "links": 4, "min_moves": 7, "max_moves": 20, "scramble": 20},
}


static func generate(seed_value: int, difficulty: int) -> Dictionary:
	var level: int = clampi(difficulty, 1, 5)
	var spec: Dictionary = {}
	for attempt in MAX_ATTEMPTS:
		var sub_seed: int = seed_value
		if attempt > 0:
			sub_seed = Rng.derive(seed_value, attempt, 31)
		spec = _build(sub_seed, level)
		spec["seed"] = seed_value
		spec["attempts"] = attempt + 1
		if bool(spec["valid"]):
			break
	return spec


static func _build(seed_value: int, level: int) -> Dictionary:
	var tier: Dictionary = TIERS[level]
	var rng: RandomNumberGenerator = Rng.make(seed_value)
	var n: int = tier["rings"]
	var m: int = tier["pos"]
	var symbols: Array = []
	for i in n:
		symbols.append(Rng.shuffled(range(SYMBOL_COUNT), rng).slice(0, m))
	var links: Array = []
	var used: Dictionary = {}
	var guard: int = 0
	while links.size() < int(tier["links"]) and guard < 60:
		guard += 1
		var a: int = rng.randi_range(0, n - 1)
		var b: int = rng.randi_range(0, n - 1)
		if a == b or used.has(a * 10 + b) or used.has(b * 10 + a):
			continue
		used[a * 10 + b] = true
		links.append([a, b, Rng.coin(rng)])
	var offsets: Array = []
	for i in n:
		offsets.append(0)
	for s in int(tier["scramble"]):
		offsets = apply_move(offsets, rng.randi_range(0, n - 1), Rng.coin(rng), links, m)
	var spec: Dictionary = {
		"type": TYPE,
		"seed": seed_value,
		"difficulty": level,
		"params": {"rings": n, "positions": m, "symbols": symbols, "links": links, "start": offsets},
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = res["ok"]
	spec["reason"] = res["reason"]
	spec["solution"] = res["solution"]
	spec["score"] = score(spec)
	spec["signature"] = (TYPE + JSON.stringify(spec["params"])).md5_text()
	return spec


## One move = turn `ring` one step in direction `dir` (+1 / -1); linked rings follow.
static func apply_move(offsets: Array, ring: int, dir: int, links: Array, m: int) -> Array:
	var out: Array = offsets.duplicate()
	out[ring] = posmod(int(out[ring]) + dir, m)
	for l in links:
		if int(l[0]) == ring:
			var target: int = int(l[1])
			out[target] = posmod(int(out[target]) + dir * int(l[2]), m)
	return out


static func is_solved(offsets: Array) -> bool:
	for o in offsets:
		if int(o) != 0:
			return false
	return true


## Breadth-first search from `start` to the solved state. Returns {"ok", "moves"}.
static func solve(params: Dictionary, start: Array) -> Dictionary:
	var n: int = int(params["rings"])
	var m: int = int(params["positions"])
	var links: Array = params.get("links", [])
	var start_code: int = _encode(start, m)
	if start_code == 0:
		return {"ok": true, "moves": []}
	var prev: Dictionary = {start_code: -1}
	var prev_move: Dictionary = {}
	var queue: Array = [start_code]
	var head: int = 0
	while head < queue.size():
		var code: int = queue[head]
		head += 1
		var offs: Array = _decode(code, n, m)
		for ring in n:
			for dir in [1, -1]:
				var nc: int = _encode(apply_move(offs, ring, dir, links, m), m)
				if prev.has(nc):
					continue
				prev[nc] = code
				prev_move[nc] = [ring, dir]
				if nc == 0:
					var moves: Array = []
					var cur: int = nc
					while cur != start_code:
						moves.push_front(prev_move[cur])
						cur = prev[cur]
					return {"ok": true, "moves": moves}
				queue.append(nc)
	return {"ok": false, "moves": []}


static func validate(spec: Dictionary) -> Dictionary:
	var p: Dictionary = spec.get("params", {})
	var level: int = clampi(int(spec.get("difficulty", 1)), 1, 5)
	var tier: Dictionary = TIERS[level]
	var n: int = int(p.get("rings", 0))
	var m: int = int(p.get("positions", 0))
	if n < 2 or n > 5 or m < 3 or m > SYMBOL_COUNT:
		return _fail("bad_size")
	var symbols: Array = p.get("symbols", [])
	var start: Array = p.get("start", [])
	if symbols.size() != n or start.size() != n:
		return _fail("bad_arrays")
	for ring in symbols:
		var ring_arr: Array = ring
		if ring_arr.size() != m:
			return _fail("bad_symbol_count")
		var seen: Dictionary = {}
		for s in ring_arr:
			var sid: int = int(s)
			if sid < 0 or sid >= SYMBOL_COUNT or seen.has(sid):
				return _fail("duplicate_symbol")
			seen[sid] = true
	for o in start:
		if int(o) < 0 or int(o) >= m:
			return _fail("bad_start")
	for l in p.get("links", []):
		var a: int = int(l[0])
		var b: int = int(l[1])
		if a < 0 or a >= n or b < 0 or b >= n or a == b or absi(int(l[2])) != 1:
			return _fail("bad_link")
	var res: Dictionary = solve(p, start)
	if not bool(res["ok"]):
		return _fail("unsolvable")
	var moves: Array = res["moves"]
	if moves.size() < int(tier["min_moves"]):
		return _fail("too_easy")
	if moves.size() > int(tier["max_moves"]):
		return _fail("too_hard")
	return {"ok": true, "reason": "", "solution": moves}


static func score(spec: Dictionary) -> float:
	var p: Dictionary = spec["params"]
	var sol: Array = spec.get("solution", [])
	var links: Array = p.get("links", [])
	return float(sol.size()) * 0.5 + float(int(p["rings"])) * 0.5 + float(links.size()) * 0.7


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "solution": []}


static func _encode(offsets: Array, m: int) -> int:
	var code: int = 0
	for i in range(offsets.size() - 1, -1, -1):
		code = code * m + int(offsets[i])
	return code


static func _decode(code: int, n: int, m: int) -> Array:
	var out: Array = []
	var c: int = code
	for i in n:
		out.append(c % m)
		c = int(c / m)
	return out
