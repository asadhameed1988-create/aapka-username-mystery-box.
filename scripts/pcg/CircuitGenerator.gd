extends RefCounted
## CIRCUIT CONNECTION: rotate the channel tiles until every tile is joined to
## the source and no channel ends at a wall or a closed side.
## The solved network is a random spanning tree; tiles are then rotated.
## The validator re-applies the stored rotations and checks the win condition.

const Rng = preload("res://scripts/pcg/Rng.gd")
const Grid = preload("res://scripts/pcg/GridTree.gd")

const TYPE := "circuit"
const MAX_ATTEMPTS := 30

const TIERS := {
	1: {"w": 3, "h": 3, "min_wrong": 4},
	2: {"w": 3, "h": 4, "min_wrong": 6},
	3: {"w": 4, "h": 4, "min_wrong": 8},
	4: {"w": 4, "h": 5, "min_wrong": 11},
	5: {"w": 5, "h": 5, "min_wrong": 14},
}


static func generate(seed_value: int, difficulty: int) -> Dictionary:
	var level: int = clampi(difficulty, 1, 5)
	var spec: Dictionary = {}
	for attempt in MAX_ATTEMPTS:
		var sub_seed: int = seed_value
		if attempt > 0:
			sub_seed = Rng.derive(seed_value, attempt, 61)
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
	var solved: Array = Grid.carve(w, h, rng)
	var tiles: Array = []
	var solution: Array = []
	for i in w * h:
		var turns: int = rng.randi_range(0, 3)
		tiles.append(Grid.rotate_mask(int(solved[i]), turns))
		solution.append((4 - turns) % 4)
	var spec: Dictionary = {
		"type": TYPE,
		"seed": seed_value,
		"difficulty": level,
		"params": {"w": w, "h": h, "tiles": tiles, "source": rng.randi_range(0, w * h - 1)},
		"solution": solution,
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = res["ok"]
	spec["reason"] = res["reason"]
	spec["score"] = score(spec)
	spec["signature"] = (TYPE + JSON.stringify(spec["params"])).md5_text()
	return spec


## Win condition: all channels matched and every tile reachable from the source.
static func is_network_complete(tiles: Array, w: int, h: int, source: int) -> bool:
	if not Grid.is_consistent(tiles, w, h):
		return false
	for d in Grid.bfs(tiles, w, h, source)["dist"]:
		if int(d) < 0:
			return false
	return true


## Tiles after applying the stored solution rotations.
static func solved_tiles(spec: Dictionary) -> Array:
	var tiles: Array = spec["params"]["tiles"]
	var sol: Array = spec["solution"]
	var out: Array = []
	for i in tiles.size():
		out.append(Grid.rotate_mask(int(tiles[i]), int(sol[i])))
	return out


static func validate(spec: Dictionary) -> Dictionary:
	var p: Dictionary = spec.get("params", {})
	var level: int = clampi(int(spec.get("difficulty", 1)), 1, 5)
	var tier: Dictionary = TIERS[level]
	var w: int = int(p.get("w", 0))
	var h: int = int(p.get("h", 0))
	var tiles: Array = p.get("tiles", [])
	var sol: Array = spec.get("solution", [])
	if w < 2 or h < 2 or w > 8 or h > 8 or tiles.size() != w * h or sol.size() != w * h:
		return _fail("bad_size")
	var source: int = int(p.get("source", -1))
	if source < 0 or source >= w * h:
		return _fail("bad_source")
	for t in tiles:
		if int(t) < 1 or int(t) > 15:
			return _fail("bad_tile")
	if is_network_complete(tiles, w, h, source):
		return _fail("already_solved")
	var target: Array = solved_tiles(spec)
	if not is_network_complete(target, w, h, source):
		return _fail("solution_not_connected")
	var wrong: int = 0
	for i in tiles.size():
		if int(tiles[i]) != int(target[i]):
			wrong += 1
	if wrong < int(tier["min_wrong"]):
		return _fail("too_easy")
	return {"ok": true, "reason": "", "solution": sol}


static func score(spec: Dictionary) -> float:
	var p: Dictionary = spec["params"]
	return float(int(p["w"]) * int(p["h"])) * 0.25


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "solution": []}
