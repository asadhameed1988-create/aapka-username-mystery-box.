extends RefCounted
## SLIDING MECHANICAL LOCK: numbered plates slide into the single empty slot
## until they read 1, 2, 3 ... in order with the empty slot last.
## Scrambled from the solved board with legal slides (always solvable), then
## verified with BFS, which also gives the fewest slides.

const Rng = preload("res://scripts/pcg/Rng.gd")

const TYPE := "slider"
const MAX_ATTEMPTS := 40

const TIERS := {
	1: {"w": 3, "h": 2, "min": 3, "max": 10, "scramble": 8},
	2: {"w": 3, "h": 2, "min": 6, "max": 14, "scramble": 16},
	3: {"w": 3, "h": 2, "min": 11, "max": 21, "scramble": 40},
	4: {"w": 4, "h": 2, "min": 12, "max": 20, "scramble": 40},
	5: {"w": 4, "h": 2, "min": 18, "max": 36, "scramble": 80},
}


static func generate(seed_value: int, difficulty: int) -> Dictionary:
	var level: int = clampi(difficulty, 1, 5)
	var spec: Dictionary = {}
	for attempt in MAX_ATTEMPTS:
		var sub_seed: int = seed_value
		if attempt > 0:
			sub_seed = Rng.derive(seed_value, attempt, 67)
		spec = _build(sub_seed, level)
		spec["seed"] = seed_value
		spec["attempts"] = attempt + 1
		if bool(spec["valid"]):
			break
	return spec


static func _build(seed_value: int, level: int) -> Dictionary:
	var tier: Dictionary = TIERS[level]
	var rng: RandomNumberGenerator = Rng.make(seed_value)
	var w: int = int(tier["w"])
	var h: int = int(tier["h"])
	var board: Array = goal(w * h)
	var last_blank: int = -1
	for s in int(tier["scramble"]):
		var blank: int = board.find(0)
		var options: Array = []
		for cell in neighbours(blank, w, h):
			if int(cell) != last_blank:
				options.append(int(cell))
		var pick_cell: int = int(Rng.pick(options, rng))
		board = slide(board, pick_cell)
		last_blank = blank
	var spec: Dictionary = {
		"type": TYPE,
		"seed": seed_value,
		"difficulty": level,
		"params": {"w": w, "h": h, "start": board},
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = res["ok"]
	spec["reason"] = res["reason"]
	spec["solution"] = res["solution"]
	spec["score"] = score(spec)
	spec["signature"] = (TYPE + JSON.stringify(spec["params"])).md5_text()
	return spec


static func goal(count: int) -> Array:
	var out: Array = []
	for i in range(1, count):
		out.append(i)
	out.append(0)
	return out


static func neighbours(cell: int, w: int, h: int) -> Array:
	var out: Array = []
	var x: int = cell % w
	var y: int = int(cell / w)
	if x > 0:
		out.append(cell - 1)
	if x < w - 1:
		out.append(cell + 1)
	if y > 0:
		out.append(cell - w)
	if y < h - 1:
		out.append(cell + w)
	return out


## Moves the plate at `cell` into the empty slot (caller checks adjacency).
static func slide(board: Array, cell: int) -> Array:
	var out: Array = board.duplicate()
	var blank: int = out.find(0)
	out[blank] = out[cell]
	out[cell] = 0
	return out


static func is_solved(board: Array) -> bool:
	var n: int = board.size()
	for i in n - 1:
		if int(board[i]) != i + 1:
			return false
	return int(board[n - 1]) == 0


static func _encode(board: Array) -> int:
	var code: int = 0
	var n: int = board.size()
	for i in range(n - 1, -1, -1):
		code = code * n + int(board[i])
	return code


static func _decode(code: int, n: int) -> Array:
	var out: Array = []
	var c: int = code
	for i in n:
		out.append(c % n)
		c = int(c / n)
	return out


## BFS to the ordered board. Returns {"ok", "moves"}; each move is the cell to tap.
static func solve(w: int, h: int, start: Array) -> Dictionary:
	var n: int = w * h
	var board: Array = []
	for v in start:
		board.append(int(v))
	var goal_code: int = _encode(goal(n))
	var start_code: int = _encode(board)
	if start_code == goal_code:
		return {"ok": true, "moves": []}
	var prev: Dictionary = {start_code: -1}
	var via: Dictionary = {}
	var queue: Array = [start_code]
	var head: int = 0
	while head < queue.size():
		var code: int = queue[head]
		head += 1
		var cur: Array = _decode(code, n)
		for cell in neighbours(cur.find(0), w, h):
			var nc: int = _encode(slide(cur, int(cell)))
			if prev.has(nc):
				continue
			prev[nc] = code
			via[nc] = int(cell)
			if nc == goal_code:
				var moves: Array = []
				var walk: int = nc
				while walk != start_code:
					moves.push_front(via[walk])
					walk = prev[walk]
				return {"ok": true, "moves": moves}
			queue.append(nc)
	return {"ok": false, "moves": []}


static func validate(spec: Dictionary) -> Dictionary:
	var p: Dictionary = spec.get("params", {})
	var level: int = clampi(int(spec.get("difficulty", 1)), 1, 5)
	var tier: Dictionary = TIERS[level]
	var w: int = int(p.get("w", 0))
	var h: int = int(p.get("h", 0))
	var start: Array = p.get("start", [])
	if w < 2 or h < 2 or w * h > 8 or start.size() != w * h:
		return _fail("bad_size")
	var seen: Dictionary = {}
	for v in start:
		var plate: int = int(v)
		if plate < 0 or plate >= w * h or seen.has(plate):
			return _fail("bad_board")
		seen[plate] = true
	var res: Dictionary = solve(w, h, start)
	if not bool(res["ok"]):
		return _fail("unsolvable")
	var moves: Array = res["moves"]
	if moves.size() < int(tier["min"]):
		return _fail("too_easy")
	if moves.size() > int(tier["max"]):
		return _fail("too_hard")
	return {"ok": true, "reason": "", "solution": moves}


static func score(spec: Dictionary) -> float:
	var sol: Array = spec.get("solution", [])
	return float(sol.size()) * 0.25


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "solution": []}
