extends RefCounted
## MECHANICAL MAZE (with key-and-compartment on harder levels).
## A pin must travel through the maze to the exit; on harder levels it must
## pick up the key first. Carved with a backtracking spanning tree, then
## verified with BFS (start -> key -> exit) and by replaying the solution.

const Rng = preload("res://scripts/pcg/Rng.gd")
const Grid = preload("res://scripts/pcg/GridTree.gd")

const TYPE := "maze"
const MAX_ATTEMPTS := 30

const TIERS := {
	1: {"w": 4, "h": 4, "key": false, "min": 6, "loops": 0},
	2: {"w": 5, "h": 5, "key": false, "min": 8, "loops": 0},
	3: {"w": 5, "h": 6, "key": true, "min": 12, "loops": 0},
	4: {"w": 6, "h": 7, "key": true, "min": 16, "loops": 2},
	5: {"w": 7, "h": 8, "key": true, "min": 22, "loops": 3},
}


static func generate(seed_value: int, difficulty: int) -> Dictionary:
	var level: int = clampi(difficulty, 1, 5)
	var spec: Dictionary = {}
	for attempt in MAX_ATTEMPTS:
		var sub_seed: int = seed_value
		if attempt > 0:
			sub_seed = Rng.derive(seed_value, attempt, 59)
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
	var cells: Array = Grid.carve(w, h, rng)
	# A few extra openings create loops (more than one route) on hard levels.
	var opened: int = 0
	var guard: int = 0
	while opened < int(tier["loops"]) and guard < 60:
		guard += 1
		var cell: int = rng.randi_range(0, w * h - 1)
		var dir: int = int(Rng.pick(Grid.DIRS, rng))
		var nxt: int = Grid.step(cell, dir, w, h)
		if nxt < 0 or (int(cells[cell]) & dir) != 0:
			continue
		cells[cell] = int(cells[cell]) | dir
		cells[nxt] = int(cells[nxt]) | Grid.opposite(dir)
		opened += 1
	var start: int = 0
	var from_start: Array = Grid.bfs(cells, w, h, start)["dist"]
	var exit_cell: int = 0
	for i in w * h:
		if int(from_start[i]) > int(from_start[exit_cell]):
			exit_cell = i
	var key_cell: int = -1
	if bool(tier["key"]):
		var from_exit: Array = Grid.bfs(cells, w, h, exit_cell)["dist"]
		var best: int = -1
		for i in w * h:
			if i == start or i == exit_cell:
				continue
			var total: int = int(from_start[i]) + int(from_exit[i])
			if total > best:
				best = total
				key_cell = i
	var spec: Dictionary = {
		"type": TYPE,
		"seed": seed_value,
		"difficulty": level,
		"params": {"w": w, "h": h, "cells": cells, "start": start, "exit": exit_cell, "key": key_cell},
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = res["ok"]
	spec["reason"] = res["reason"]
	spec["solution"] = res["solution"]
	spec["score"] = score(spec)
	spec["signature"] = (TYPE + JSON.stringify(spec["params"])).md5_text()
	return spec


## Shortest route as a list of directions (through the key when there is one).
static func solve(params: Dictionary, from: int, has_key: bool) -> Array:
	var w: int = int(params["w"])
	var h: int = int(params["h"])
	var cells: Array = params["cells"]
	var key_cell: int = int(params["key"])
	var exit_cell: int = int(params["exit"])
	if key_cell >= 0 and not has_key:
		var first: Array = Grid.path(cells, w, h, from, key_cell)
		first.append_array(Grid.path(cells, w, h, key_cell, exit_cell))
		return first
	return Grid.path(cells, w, h, from, exit_cell)


static func validate(spec: Dictionary) -> Dictionary:
	var p: Dictionary = spec.get("params", {})
	var level: int = clampi(int(spec.get("difficulty", 1)), 1, 5)
	var tier: Dictionary = TIERS[level]
	var w: int = int(p.get("w", 0))
	var h: int = int(p.get("h", 0))
	var cells: Array = p.get("cells", [])
	if w < 2 or h < 2 or w > 10 or h > 10 or cells.size() != w * h:
		return _fail("bad_size")
	for c in cells:
		if int(c) < 1 or int(c) > 15:
			return _fail("bad_cell")
	if not Grid.is_consistent(cells, w, h):
		return _fail("broken_walls")
	var start: int = int(p.get("start", -1))
	var exit_cell: int = int(p.get("exit", -1))
	var key_cell: int = int(p.get("key", -1))
	if start < 0 or start >= w * h or exit_cell < 0 or exit_cell >= w * h or start == exit_cell:
		return _fail("bad_endpoints")
	if key_cell >= w * h or key_cell == start or key_cell == exit_cell:
		return _fail("bad_key")
	var dist: Array = Grid.bfs(cells, w, h, start)["dist"]
	if int(dist[exit_cell]) < 0:
		return _fail("unsolvable")
	if key_cell >= 0 and int(dist[key_cell]) < 0:
		return _fail("key_unreachable")
	var route: Array = solve(p, start, false)
	# Replay the route to prove it really ends on the exit with the key collected.
	var pos: int = start
	var got_key: bool = key_cell < 0
	for dir in route:
		if (int(cells[pos]) & int(dir)) == 0:
			return _fail("route_hits_wall")
		pos = Grid.step(pos, int(dir), w, h)
		if pos == key_cell:
			got_key = true
	if pos != exit_cell or not got_key:
		return _fail("route_incomplete")
	if route.size() < int(tier["min"]):
		return _fail("too_easy")
	return {"ok": true, "reason": "", "solution": route}


static func score(spec: Dictionary) -> float:
	var p: Dictionary = spec["params"]
	var sol: Array = spec.get("solution", [])
	var bonus: float = 0.0
	if int(p["key"]) >= 0:
		bonus = 1.5
	return float(sol.size()) * 0.15 + float(int(p["w"]) * int(p["h"])) * 0.05 + bonus


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "solution": []}
