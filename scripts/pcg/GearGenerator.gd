extends RefCounted
## GEAR ALIGNMENT: a row of gears with different tooth counts. Each crank turns
## its own gear one tooth and drags the meshed neighbour(s) the other way.
## Goal: every gear's marker tooth at the top.
## Scrambled from the aligned state with legal crank turns, then verified with BFS.

const Rng = preload("res://scripts/pcg/Rng.gd")

const TYPE := "gears"
const MAX_ATTEMPTS := 40

const TIERS := {
	1: {"gears": 2, "teeth": [4, 5], "cranks": 2, "min": 2, "max": 6, "scramble": 5, "long": false},
	2: {"gears": 3, "teeth": [4, 5, 6], "cranks": 2, "min": 3, "max": 9, "scramble": 8, "long": false},
	3: {"gears": 3, "teeth": [4, 5, 6], "cranks": 3, "min": 4, "max": 11, "scramble": 10, "long": true},
	4: {"gears": 4, "teeth": [4, 5, 6], "cranks": 3, "min": 5, "max": 15, "scramble": 14, "long": true},
	5: {"gears": 4, "teeth": [5, 6, 8], "cranks": 4, "min": 6, "max": 20, "scramble": 18, "long": true},
}


static func generate(seed_value: int, difficulty: int) -> Dictionary:
	var level: int = clampi(difficulty, 1, 5)
	var spec: Dictionary = {}
	for attempt in MAX_ATTEMPTS:
		var sub_seed: int = seed_value
		if attempt > 0:
			sub_seed = Rng.derive(seed_value, attempt, 71)
		spec = _build(sub_seed, level)
		spec["seed"] = seed_value
		spec["attempts"] = attempt + 1
		if bool(spec["valid"]):
			break
	return spec


static func _build(seed_value: int, level: int) -> Dictionary:
	var tier: Dictionary = TIERS[level]
	var rng: RandomNumberGenerator = Rng.make(seed_value)
	var n: int = int(tier["gears"])
	var teeth: Array = []
	for i in n:
		teeth.append(int(Rng.pick(tier["teeth"], rng)))
	var cranks: Array = []
	var hosts: Array = Rng.shuffled(range(n), rng).slice(0, int(tier["cranks"]))
	for host in hosts:
		var a: int = int(host)
		var side: int = Rng.coin(rng)
		if a + side < 0 or a + side >= n:
			side = -side
		var effect: Array = [[a, 1], [a + side, -1]]
		var far: int = a + side * 2
		if bool(tier["long"]) and far >= 0 and far < n and rng.randi_range(0, 1) == 0:
			effect.append([far, 1])
		cranks.append(effect)
	var offsets: Array = []
	for i in n:
		offsets.append(0)
	for s in int(tier["scramble"]):
		offsets = turn(offsets, teeth, cranks[rng.randi_range(0, cranks.size() - 1)], Rng.coin(rng))
	var spec: Dictionary = {
		"type": TYPE,
		"seed": seed_value,
		"difficulty": level,
		"params": {"teeth": teeth, "cranks": cranks, "start": offsets},
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = res["ok"]
	spec["reason"] = res["reason"]
	spec["solution"] = res["solution"]
	spec["score"] = score(spec)
	spec["signature"] = (TYPE + JSON.stringify(spec["params"])).md5_text()
	return spec


## Turns one crank one click (dir = +1 / -1).
static func turn(offsets: Array, teeth: Array, effect: Array, dir: int) -> Array:
	var out: Array = offsets.duplicate()
	for part in effect:
		var g: int = int(part[0])
		out[g] = posmod(int(out[g]) + dir * int(part[1]), int(teeth[g]))
	return out


static func is_solved(offsets: Array) -> bool:
	for o in offsets:
		if int(o) != 0:
			return false
	return true


static func _encode(offsets: Array, teeth: Array) -> int:
	var code: int = 0
	for i in range(offsets.size() - 1, -1, -1):
		code = code * int(teeth[i]) + int(offsets[i])
	return code


static func _decode(code: int, teeth: Array) -> Array:
	var out: Array = []
	var c: int = code
	for i in teeth.size():
		var t: int = int(teeth[i])
		out.append(c % t)
		c = int(c / t)
	return out


## BFS to the aligned state. Returns {"ok", "moves"}; each move is [crank, dir].
static func solve(params: Dictionary, start: Array) -> Dictionary:
	var teeth: Array = params["teeth"]
	var cranks: Array = params["cranks"]
	var start_code: int = _encode(start, teeth)
	if start_code == 0:
		return {"ok": true, "moves": []}
	var prev: Dictionary = {start_code: -1}
	var via: Dictionary = {}
	var queue: Array = [start_code]
	var head: int = 0
	while head < queue.size():
		var code: int = queue[head]
		head += 1
		var offs: Array = _decode(code, teeth)
		for c in cranks.size():
			for dir in [1, -1]:
				var nc: int = _encode(turn(offs, teeth, cranks[c], int(dir)), teeth)
				if prev.has(nc):
					continue
				prev[nc] = code
				via[nc] = [c, int(dir)]
				if nc == 0:
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
	var teeth: Array = p.get("teeth", [])
	var cranks: Array = p.get("cranks", [])
	var start: Array = p.get("start", [])
	var n: int = teeth.size()
	if n < 2 or n > 5 or start.size() != n or cranks.is_empty() or cranks.size() > 5:
		return _fail("bad_size")
	for i in n:
		if int(teeth[i]) < 3 or int(teeth[i]) > 10 or int(start[i]) < 0 or int(start[i]) >= int(teeth[i]):
			return _fail("bad_gear")
	for effect in cranks:
		var seen: Dictionary = {}
		for part in effect:
			var g: int = int(part[0])
			if g < 0 or g >= n or seen.has(g) or absi(int(part[1])) != 1:
				return _fail("bad_crank")
			seen[g] = true
	var res: Dictionary = solve(p, start)
	if not bool(res["ok"]):
		return _fail("unsolvable")
	var moves: Array = res["moves"]
	if moves.size() < int(tier["min"]):
		return _fail("too_easy")
	if moves.size() > int(tier["max"]):
		return _fail("too_hard")
	return {"ok": true, "reason": "", "solution": moves}


static func score(spec: Dictionary) -> float:
	var p: Dictionary = spec["params"]
	var sol: Array = spec.get("solution", [])
	return float(sol.size()) * 0.5 + float((p["teeth"] as Array).size()) * 0.6


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "solution": []}
