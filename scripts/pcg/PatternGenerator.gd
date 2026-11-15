extends RefCounted
## SYMBOL PATTERN lock: a repeating row of symbols with the next one missing.
## The validator independently finds the smallest repeating unit of the shown
## row and checks that at least two full repeats are visible.

const Rng = preload("res://scripts/pcg/Rng.gd")

const TYPE := "pattern"
const SYMBOL_COUNT := 8
const MAX_ATTEMPTS := 30
const OPTION_COUNT := 4

const TIERS := {
	1: {"period": 2, "repeat": false},
	2: {"period": 3, "repeat": false},
	3: {"period": 3, "repeat": true},
	4: {"period": 4, "repeat": true},
	5: {"period": 5, "repeat": true},
}


static func generate(seed_value: int, difficulty: int) -> Dictionary:
	var level: int = clampi(difficulty, 1, 5)
	var spec: Dictionary = {}
	for attempt in MAX_ATTEMPTS:
		var sub_seed: int = seed_value
		if attempt > 0:
			sub_seed = Rng.derive(seed_value, attempt, 47)
		spec = _build(sub_seed, level)
		spec["seed"] = seed_value
		spec["attempts"] = attempt + 1
		if bool(spec["valid"]):
			break
	return spec


static func _build(seed_value: int, level: int) -> Dictionary:
	var tier: Dictionary = TIERS[level]
	var rng: RandomNumberGenerator = Rng.make(seed_value)
	var period: int = int(tier["period"])
	var pool: Array = Rng.shuffled(range(SYMBOL_COUNT), rng)
	var unit: Array = pool.slice(0, period)
	if bool(tier["repeat"]):
		var src: int = rng.randi_range(0, period - 1)
		var dst: int = rng.randi_range(0, period - 1)
		if dst != src:
			unit[dst] = unit[src]
	var length: int = period * 2 + rng.randi_range(0, period - 1)
	var shown: Array = []
	for i in length:
		shown.append(unit[i % period])
	var answer: int = int(unit[length % period])
	var options: Array = [answer]
	for s in Rng.shuffled(range(SYMBOL_COUNT), rng):
		if options.size() >= OPTION_COUNT:
			break
		if int(s) != answer:
			options.append(int(s))
	options = Rng.shuffled(options, rng)
	var spec: Dictionary = {
		"type": TYPE,
		"seed": seed_value,
		"difficulty": level,
		"params": {"shown": shown, "options": options, "period": period},
		"solution": [options.find(answer)],
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = res["ok"]
	spec["reason"] = res["reason"]
	spec["score"] = score(spec)
	spec["signature"] = (TYPE + JSON.stringify(spec["params"])).md5_text()
	return spec


## Smallest q such that shown[i] == shown[i - q] for every i >= q.
static func smallest_period(shown: Array) -> int:
	var n: int = shown.size()
	for q in range(1, n + 1):
		var ok: bool = true
		for i in range(q, n):
			if int(shown[i]) != int(shown[i - q]):
				ok = false
				break
		if ok:
			return q
	return n


static func validate(spec: Dictionary) -> Dictionary:
	var p: Dictionary = spec.get("params", {})
	var shown: Array = p.get("shown", [])
	var options: Array = p.get("options", [])
	var sol: Array = spec.get("solution", [])
	if shown.size() < 4 or options.size() != OPTION_COUNT or sol.size() != 1:
		return _fail("bad_arrays")
	var index: int = int(sol[0])
	if index < 0 or index >= options.size():
		return _fail("bad_solution")
	var seen: Dictionary = {}
	for o in options:
		var oid: int = int(o)
		if oid < 0 or oid >= SYMBOL_COUNT or seen.has(oid):
			return _fail("bad_option")
		seen[oid] = true
	for s in shown:
		if int(s) < 0 or int(s) >= SYMBOL_COUNT:
			return _fail("bad_symbol")
	var q: int = smallest_period(shown)
	if q != int(p.get("period", 0)):
		return _fail("degenerate_period")
	if shown.size() < q * 2:
		return _fail("too_short")
	if int(options[index]) != int(shown[shown.size() - q]):
		return _fail("wrong_answer")
	return {"ok": true, "reason": "", "solution": sol}


static func score(spec: Dictionary) -> float:
	var p: Dictionary = spec["params"]
	var distinct: Dictionary = {}
	for s in p["shown"]:
		distinct[int(s)] = true
	return float(int(p["period"])) + float(int(p["period"]) - distinct.size()) * 0.8


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "solution": []}
