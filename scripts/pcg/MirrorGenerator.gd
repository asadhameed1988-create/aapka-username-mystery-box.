extends RefCounted
## LIGHT REFLECTION: a beam enters from the left; tapping a mirror flips it
## between "/" and "\". Goal: the beam must pass through the crystal.
## A solved mirror layout is built first and the crystal is placed on its beam;
## some mirrors are then flipped. The validator simulates every mirror
## combination to find the fewest flips.

const Rng = preload("res://scripts/pcg/Rng.gd")

const TYPE := "mirrors"
const MAX_ATTEMPTS := 40
const DX := [1, 0, -1, 0]   # 0 = east, 1 = south, 2 = west, 3 = north
const DY := [0, 1, 0, -1]
const REFLECT := [[3, 2, 1, 0], [1, 0, 3, 2]]   # [orientation][incoming direction]

const TIERS := {
	1: {"w": 4, "h": 4, "mirrors": 3, "bounces": 1, "flips": 1},
	2: {"w": 5, "h": 5, "mirrors": 4, "bounces": 2, "flips": 2},
	3: {"w": 5, "h": 5, "mirrors": 6, "bounces": 2, "flips": 2},
	4: {"w": 6, "h": 6, "mirrors": 8, "bounces": 3, "flips": 3},
	5: {"w": 6, "h": 6, "mirrors": 9, "bounces": 4, "flips": 3},
}


static func generate(seed_value: int, difficulty: int) -> Dictionary:
	var level: int = clampi(difficulty, 1, 5)
	var spec: Dictionary = {}
	for attempt in MAX_ATTEMPTS:
		var sub_seed: int = seed_value
		if attempt > 0:
			sub_seed = Rng.derive(seed_value, attempt, 83)
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
	var entry_row: int = rng.randi_range(0, h - 1)
	# Lay the solved beam path first: travel, place a mirror, turn, repeat.
	var x: int = 0
	var y: int = entry_row
	var dir: int = 0
	var used: Dictionary = {entry_row * w: true}
	var mirror_cells: Array = []
	var orients: Array = []
	var target: int = -1
	var ok: bool = true
	for leg in int(tier["bounces"]) + 1:
		var room: int = _room(x, y, dir, w, h)
		if room < 1:
			ok = false
			break
		var steps: int = rng.randi_range(1, room)
		for s in steps:
			x += int(DX[dir])
			y += int(DY[dir])
			if s < steps - 1:
				if mirror_cells.has(y * w + x):
					ok = false
				used[y * w + x] = true
		var cell: int = y * w + x
		if not ok or used.has(cell):
			ok = false
			break
		used[cell] = true
		if leg == int(tier["bounces"]):
			target = cell
			break
		var orient: int = rng.randi_range(0, 1)
		if _room(x, y, int(REFLECT[orient][dir]), w, h) < 1:
			orient = 1 - orient
		mirror_cells.append(cell)
		orients.append(orient)
		dir = int(REFLECT[orient][dir])
	if not ok:
		target = -1
	var on_path: int = mirror_cells.size()
	# Decoy mirrors off the beam.
	for c in Rng.shuffled(range(w * h), rng):
		if mirror_cells.size() >= int(tier["mirrors"]):
			break
		if not used.has(int(c)):
			mirror_cells.append(int(c))
			orients.append(rng.randi_range(0, 1))
	# Flip some of the mirrors on the beam to hide the solution.
	var flip_order: Array = Rng.shuffled(range(on_path), rng)
	for i in mini(int(tier["flips"]), flip_order.size()):
		var idx: int = int(flip_order[i])
		orients[idx] = 1 - int(orients[idx])
	var mirrors: Array = []
	for i in mirror_cells.size():
		mirrors.append([mirror_cells[i], orients[i]])
	var spec: Dictionary = {
		"type": TYPE,
		"seed": seed_value,
		"difficulty": level,
		"params": {"w": w, "h": h, "entry_row": entry_row, "mirrors": mirrors, "target": target},
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = res["ok"]
	spec["reason"] = res["reason"]
	spec["solution"] = res["solution"]
	spec["score"] = score(spec)
	spec["signature"] = (TYPE + JSON.stringify(spec["params"])).md5_text()
	return spec


## Free cells ahead of (x, y) in direction `dir` before the grid edge.
static func _room(x: int, y: int, dir: int, w: int, h: int) -> int:
	if dir == 0:
		return w - 1 - x
	if dir == 1:
		return h - 1 - y
	if dir == 2:
		return x
	return y


## Cells the beam passes through, in order, for the given mirror orientations.
static func beam_cells(w: int, h: int, entry_row: int, mirror_cells: Array, orients: Array) -> Array:
	var lookup: Dictionary = {}
	for i in mirror_cells.size():
		lookup[int(mirror_cells[i])] = int(orients[i])
	var out: Array = []
	var x: int = 0
	var y: int = entry_row
	var dir: int = 0
	var guard: int = w * h * 4
	while x >= 0 and x < w and y >= 0 and y < h and guard > 0:
		guard -= 1
		var cell: int = y * w + x
		out.append(cell)
		if lookup.has(cell):
			dir = int(REFLECT[int(lookup[cell])][dir])
		x += int(DX[dir])
		y += int(DY[dir])
	return out


## Splits the stored mirror list into {"cells", "orients"}.
static func unpack(params: Dictionary) -> Dictionary:
	var cells: Array = []
	var orients: Array = []
	for m in params["mirrors"]:
		cells.append(int(m[0]))
		orients.append(int(m[1]))
	return {"cells": cells, "orients": orients}


static func hits_target(params: Dictionary, orients: Array) -> bool:
	var cells: Array = unpack(params)["cells"]
	var beam: Array = beam_cells(int(params["w"]), int(params["h"]), int(params["entry_row"]), cells, orients)
	return beam.has(int(params["target"]))


## Tries every mirror combination; returns {"ok", "flips"} with the fewest flips from `orients`.
static func solve(params: Dictionary, orients: Array) -> Dictionary:
	var cells: Array = unpack(params)["cells"]
	var n: int = cells.size()
	var w: int = int(params["w"])
	var h: int = int(params["h"])
	var entry_row: int = int(params["entry_row"])
	var target: int = int(params["target"])
	var best: int = -1
	var best_count: int = n + 1
	for mask in 1 << n:
		var count: int = 0
		for i in n:
			if (mask >> i) & 1 == 1:
				count += 1
		if count >= best_count:
			continue
		var trial: Array = []
		for i in n:
			trial.append(int(orients[i]) ^ ((mask >> i) & 1))
		if beam_cells(w, h, entry_row, cells, trial).has(target):
			best = mask
			best_count = count
	if best < 0:
		return {"ok": false, "flips": []}
	var flips: Array = []
	for i in n:
		if (best >> i) & 1 == 1:
			flips.append(i)
	return {"ok": true, "flips": flips}


static func validate(spec: Dictionary) -> Dictionary:
	var p: Dictionary = spec.get("params", {})
	var level: int = clampi(int(spec.get("difficulty", 1)), 1, 5)
	var tier: Dictionary = TIERS[level]
	var w: int = int(p.get("w", 0))
	var h: int = int(p.get("h", 0))
	var mirrors: Array = p.get("mirrors", [])
	var target: int = int(p.get("target", -1))
	var entry_row: int = int(p.get("entry_row", -1))
	if w < 3 or h < 3 or w > 8 or h > 8 or mirrors.is_empty() or mirrors.size() > 10:
		return _fail("bad_size")
	if entry_row < 0 or entry_row >= h:
		return _fail("bad_entry")
	if target < 0 or target >= w * h:
		return _fail("no_target")
	var seen: Dictionary = {}
	for m in mirrors:
		var cell: int = int(m[0])
		if cell < 0 or cell >= w * h or seen.has(cell) or cell == target or (int(m[1]) != 0 and int(m[1]) != 1):
			return _fail("bad_mirror")
		seen[cell] = true
	var orients: Array = unpack(p)["orients"]
	if hits_target(p, orients):
		return _fail("already_solved")
	var res: Dictionary = solve(p, orients)
	if not bool(res["ok"]):
		return _fail("unsolvable")
	var flips: Array = res["flips"]
	if flips.size() < int(tier["flips"]):
		return _fail("too_easy")
	return {"ok": true, "reason": "", "solution": flips}


static func score(spec: Dictionary) -> float:
	var p: Dictionary = spec["params"]
	var sol: Array = spec.get("solution", [])
	return float((p["mirrors"] as Array).size()) * 0.5 + float(sol.size()) * 0.8


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "solution": []}
