extends RefCounted
## SYMBOL DECODING: every symbol hides a different number. Small equations
## between symbols are the clues; the player dials the number of each symbol.
## Values are chosen first, true clues are added until one assignment is left,
## and the validator re-counts all assignments.

const Rng = preload("res://scripts/pcg/Rng.gd")

const TYPE := "cipher"
const SYMBOL_COUNT := 8
const MAX_ATTEMPTS := 20

const TIERS := {
	1: {"symbols": 3, "range": 5, "given": 1},
	2: {"symbols": 3, "range": 9, "given": 1},
	3: {"symbols": 4, "range": 8, "given": 1},
	4: {"symbols": 4, "range": 9, "given": 0},
	5: {"symbols": 5, "range": 7, "given": 0},
}


static func generate(seed_value: int, difficulty: int) -> Dictionary:
	var level: int = clampi(difficulty, 1, 5)
	var spec: Dictionary = {}
	for attempt in MAX_ATTEMPTS:
		var sub_seed: int = seed_value
		if attempt > 0:
			sub_seed = Rng.derive(seed_value, attempt, 79)
		spec = _build(sub_seed, level)
		spec["seed"] = seed_value
		spec["attempts"] = attempt + 1
		if bool(spec["valid"]):
			break
	return spec


static func _build(seed_value: int, level: int) -> Dictionary:
	var tier: Dictionary = TIERS[level]
	var rng: RandomNumberGenerator = Rng.make(seed_value)
	var count: int = int(tier["symbols"])
	var top: int = int(tier["range"])
	var values: Array = Rng.shuffled(range(1, top + 1), rng).slice(0, count)
	var symbols: Array = Rng.shuffled(range(SYMBOL_COUNT), rng).slice(0, count)
	var total: int = 0
	for v in values:
		total += int(v)

	var pool: Array = [{"k": "sum", "v": total}]
	for i in count:
		for j in range(i + 1, count):
			if rng.randi_range(0, 1) == 0:
				pool.append({"k": "sum2", "i": i, "j": j, "v": int(values[i]) + int(values[j])})
			else:
				pool.append(_diff_clue(values, i, j))
	pool = Rng.shuffled(pool, rng)
	var ordered: Array = []
	if int(tier["given"]) > 0:
		var gi: int = rng.randi_range(0, count - 1)
		ordered.append({"k": "given", "i": gi, "v": int(values[gi])})
	ordered.append_array(pool)
	# Safety net: these differences plus the total always pin every value.
	for k in range(1, count):
		ordered.append(_diff_clue(values, 0, k))
	ordered.append({"k": "sum", "v": total})

	var cands: Array = all_assignments(count, top)
	var clues: Array = []
	for clue in ordered:
		if cands.size() <= 1:
			break
		var kept: Array = []
		for cand in cands:
			if check_clue(clue, cand):
				kept.append(cand)
		if kept.size() < cands.size():
			clues.append(clue)
			cands = kept

	var spec: Dictionary = {
		"type": TYPE,
		"seed": seed_value,
		"difficulty": level,
		"params": {"symbols": symbols, "range": top, "clues": clues},
		"solution": values,
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = res["ok"]
	spec["reason"] = res["reason"]
	spec["score"] = score(spec)
	spec["signature"] = (TYPE + JSON.stringify(spec["params"])).md5_text()
	return spec


static func _diff_clue(values: Array, i: int, j: int) -> Dictionary:
	if int(values[i]) > int(values[j]):
		return {"k": "diff", "i": i, "j": j, "v": int(values[i]) - int(values[j])}
	return {"k": "diff", "i": j, "j": i, "v": int(values[j]) - int(values[i])}


## Every way to give `count` symbols different numbers from 1..top.
static func all_assignments(count: int, top: int) -> Array:
	var out: Array = []
	var total: int = 1
	for i in count:
		total *= top
	for code in total:
		var vals: Array = []
		var c: int = code
		var ok: bool = true
		for i in count:
			var v: int = c % top + 1
			c = int(c / top)
			if vals.has(v):
				ok = false
				break
			vals.append(v)
		if ok:
			out.append(vals)
	return out


static func check_clue(clue: Dictionary, vals: Array) -> bool:
	var k: String = str(clue.get("k", ""))
	if k == "sum":
		var total: int = 0
		for v in vals:
			total += int(v)
		return total == int(clue.get("v", 0))
	var i: int = int(clue.get("i", 0))
	if i < 0 or i >= vals.size():
		return false
	if k == "given":
		return int(vals[i]) == int(clue.get("v", 0))
	var j: int = int(clue.get("j", 0))
	if j < 0 or j >= vals.size():
		return false
	if k == "sum2":
		return int(vals[i]) + int(vals[j]) == int(clue.get("v", 0))
	if k == "diff":
		return int(vals[i]) - int(vals[j]) == int(clue.get("v", 0))
	return false


static func check_all(clues: Array, vals: Array) -> bool:
	for clue in clues:
		if not check_clue(clue, vals):
			return false
	return true


static func validate(spec: Dictionary) -> Dictionary:
	var p: Dictionary = spec.get("params", {})
	var level: int = clampi(int(spec.get("difficulty", 1)), 1, 5)
	var tier: Dictionary = TIERS[level]
	var symbols: Array = p.get("symbols", [])
	var top: int = int(p.get("range", 0))
	var clues: Array = p.get("clues", [])
	var solution: Array = spec.get("solution", [])
	var count: int = symbols.size()
	if count < 2 or count > 5 or top < count or top > 9 or solution.size() != count or clues.is_empty():
		return _fail("bad_size")
	var seen_sym: Dictionary = {}
	for s in symbols:
		if int(s) < 0 or int(s) >= SYMBOL_COUNT or seen_sym.has(int(s)):
			return _fail("bad_symbol")
		seen_sym[int(s)] = true
	var seen_val: Dictionary = {}
	for v in solution:
		if int(v) < 1 or int(v) > top or seen_val.has(int(v)):
			return _fail("bad_solution")
		seen_val[int(v)] = true
	var given: int = 0
	for clue in clues:
		if str(clue.get("k", "")) == "given":
			given += 1
	if given > int(tier["given"]):
		return _fail("too_easy")
	if not check_all(clues, solution):
		return _fail("contradictory_clues")
	var found: int = 0
	for cand in all_assignments(count, top):
		if check_all(clues, cand):
			found += 1
			if found > 1:
				return _fail("not_unique")
	return {"ok": true, "reason": "", "solution": solution}


static func score(spec: Dictionary) -> float:
	var p: Dictionary = spec["params"]
	return float((p["symbols"] as Array).size()) * 1.2 + float(int(p["range"])) * 0.3


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "solution": []}
