extends RefCounted
## DIAL COMBINATION LOCK (inspired by al-Jazari's dial lock, 1206 CE).
## A secret code is chosen FIRST, then true clues are added until exactly one
## code satisfies them all (constraint satisfaction by exhaustive enumeration).

const Rng = preload("res://scripts/pcg/Rng.gd")

const TYPE := "combo"
const MAX_ATTEMPTS := 20

const TIERS := {
	1: {"digits": 3, "base": 6, "max_exact": 1, "minimize": false},
	2: {"digits": 3, "base": 10, "max_exact": 1, "minimize": true},
	3: {"digits": 4, "base": 8, "max_exact": 0, "minimize": true},
	4: {"digits": 4, "base": 10, "max_exact": 0, "minimize": false},
	5: {"digits": 5, "base": 7, "max_exact": 0, "minimize": false},
}


static func generate(seed_value: int, difficulty: int) -> Dictionary:
	var level: int = clampi(difficulty, 1, 5)
	var spec: Dictionary = {}
	for attempt in MAX_ATTEMPTS:
		var sub_seed: int = seed_value
		if attempt > 0:
			sub_seed = Rng.derive(seed_value, attempt, 37)
		spec = _build(sub_seed, level)
		spec["seed"] = seed_value
		spec["attempts"] = attempt + 1
		if bool(spec["valid"]):
			break
	return spec


static func _build(seed_value: int, level: int) -> Dictionary:
	var tier: Dictionary = TIERS[level]
	var rng: RandomNumberGenerator = Rng.make(seed_value)
	var digits: int = tier["digits"]
	var base: int = tier["base"]
	var code: Array = []
	for i in digits:
		code.append(rng.randi_range(0, base - 1))

	# Pool of TRUE statements about the code.
	var pool: Array = [{"k": "sum", "v": _sum(code)}]
	for i in digits:
		pool.append({"k": "parity", "i": i, "v": int(code[i]) % 2})
	for i in digits:
		for j in range(i + 1, digits):
			pool.append(_pair_clue(code, i, j, rng.randi_range(0, 2)))
	pool = Rng.shuffled(pool, rng)

	var ordered: Array = []
	var exact_left: int = int(tier["max_exact"])
	for i in Rng.shuffled(range(digits), rng):
		if exact_left > 0:
			ordered.append({"k": "exact", "i": i, "v": code[i]})
			exact_left -= 1
	ordered.append_array(pool)
	# Safety net: these difference clues plus the sum always force a unique code.
	for k in range(1, digits):
		ordered.append({"k": "diff", "i": 0, "j": k, "v": int(code[0]) - int(code[k])})

	var space: int = _ipow(base, digits)
	var cands: Array = range(space)
	var clues: Array = []
	for clue in ordered:
		if cands.size() <= 1:
			break
		var kept: Array = []
		for c in cands:
			if check_clue(clue, _digits(c, digits, base)):
				kept.append(c)
		if kept.size() < cands.size():
			clues.append(clue)
			cands = kept

	if bool(tier["minimize"]):
		var idx: int = clues.size() - 1
		while idx >= 0 and clues.size() > 2:
			var trial: Array = clues.duplicate()
			trial.remove_at(idx)
			if count_solutions(trial, digits, base, 2) == 1:
				clues = trial
			idx -= 1

	var spec: Dictionary = {
		"type": TYPE,
		"seed": seed_value,
		"difficulty": level,
		"params": {"digits": digits, "base": base, "clues": clues},
		"solution": code,
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = res["ok"]
	spec["reason"] = res["reason"]
	spec["score"] = score(spec)
	spec["signature"] = (TYPE + JSON.stringify(spec["params"])).md5_text()
	return spec


static func _pair_clue(code: Array, i: int, j: int, kind: int) -> Dictionary:
	var a: int = int(code[i])
	var b: int = int(code[j])
	if kind == 0 and a != b:
		if a > b:
			return {"k": "gt", "i": i, "j": j}
		return {"k": "gt", "i": j, "j": i}
	if kind == 2:
		return {"k": "sum2", "i": i, "j": j, "v": a + b}
	return {"k": "diff", "i": i, "j": j, "v": a - b}


static func check_clue(clue: Dictionary, digs: Array) -> bool:
	var k: String = str(clue.get("k", ""))
	if k == "sum":
		return _sum(digs) == int(clue.get("v", 0))
	var i: int = int(clue.get("i", 0))
	if i < 0 or i >= digs.size():
		return false
	if k == "parity":
		return int(digs[i]) % 2 == int(clue.get("v", 0))
	if k == "exact":
		return int(digs[i]) == int(clue.get("v", 0))
	var j: int = int(clue.get("j", 0))
	if j < 0 or j >= digs.size():
		return false
	if k == "gt":
		return int(digs[i]) > int(digs[j])
	if k == "diff":
		return int(digs[i]) - int(digs[j]) == int(clue.get("v", 0))
	if k == "sum2":
		return int(digs[i]) + int(digs[j]) == int(clue.get("v", 0))
	return false


static func check_all(clues: Array, digs: Array) -> bool:
	for clue in clues:
		if not check_clue(clue, digs):
			return false
	return true


## Counts codes that satisfy every clue; stops early once `limit` is reached.
static func count_solutions(clues: Array, digits: int, base: int, limit: int) -> int:
	var found: int = 0
	var space: int = _ipow(base, digits)
	for c in space:
		if check_all(clues, _digits(c, digits, base)):
			found += 1
			if found >= limit:
				return found
	return found


static func validate(spec: Dictionary) -> Dictionary:
	var p: Dictionary = spec.get("params", {})
	var level: int = clampi(int(spec.get("difficulty", 1)), 1, 5)
	var tier: Dictionary = TIERS[level]
	var digits: int = int(p.get("digits", 0))
	var base: int = int(p.get("base", 0))
	if digits < 2 or digits > 5 or base < 2 or base > 10:
		return _fail("bad_size")
	var clues: Array = p.get("clues", [])
	var solution: Array = spec.get("solution", [])
	if solution.size() != digits or clues.is_empty():
		return _fail("bad_arrays")
	var exact: int = 0
	for clue in clues:
		if str(clue.get("k", "")) == "exact":
			exact += 1
	if exact > int(tier["max_exact"]):
		return _fail("too_easy")
	for d in solution:
		if int(d) < 0 or int(d) >= base:
			return _fail("bad_solution")
	if not check_all(clues, solution):
		return _fail("contradictory_clues")
	if count_solutions(clues, digits, base, 2) != 1:
		return _fail("not_unique")
	return {"ok": true, "reason": "", "solution": solution}


static func score(spec: Dictionary) -> float:
	var p: Dictionary = spec["params"]
	var space: float = float(_ipow(int(p["base"]), int(p["digits"])))
	var clues: Array = p["clues"]
	return log(space) / log(10.0) * 2.0 + float(clues.size()) * 0.3


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "solution": []}


static func _sum(digs: Array) -> int:
	var total: int = 0
	for d in digs:
		total += int(d)
	return total


static func _ipow(base: int, exp: int) -> int:
	var out: int = 1
	for i in exp:
		out *= base
	return out


static func _digits(code: int, digits: int, base: int) -> Array:
	var out: Array = []
	var c: int = code
	for i in digits:
		out.append(c % base)
		c = int(c / base)
	return out
