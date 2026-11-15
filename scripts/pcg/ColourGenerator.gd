extends RefCounted
## COLOUR CODE (colour sequence by deduction): a hidden row of coloured gems.
## The lock shows earlier attempts with their feedback (right place / wrong place).
## Attempts are added until exactly one code fits all of them; the validator
## re-counts every possible code.

const Rng = preload("res://scripts/pcg/Rng.gd")

const TYPE := "colours"
const MAX_ATTEMPTS := 30
const MAX_CLUES := 8

const TIERS := {
	1: {"slots": 3, "colours": 3, "min_clues": 2},
	2: {"slots": 3, "colours": 4, "min_clues": 2},
	3: {"slots": 4, "colours": 4, "min_clues": 3},
	4: {"slots": 4, "colours": 5, "min_clues": 3},
	5: {"slots": 4, "colours": 6, "min_clues": 3},
}


static func generate(seed_value: int, difficulty: int) -> Dictionary:
	var level: int = clampi(difficulty, 1, 5)
	var spec: Dictionary = {}
	for attempt in MAX_ATTEMPTS:
		var sub_seed: int = seed_value
		if attempt > 0:
			sub_seed = Rng.derive(seed_value, attempt, 73)
		spec = _build(sub_seed, level)
		spec["seed"] = seed_value
		spec["attempts"] = attempt + 1
		if bool(spec["valid"]):
			break
	return spec


static func _build(seed_value: int, level: int) -> Dictionary:
	var tier: Dictionary = TIERS[level]
	var rng: RandomNumberGenerator = Rng.make(seed_value)
	var slots: int = int(tier["slots"])
	var colours: int = int(tier["colours"])
	var secret: Array = []
	for i in slots:
		secret.append(rng.randi_range(0, colours - 1))
	var cands: Array = []
	for c in _ipow(colours, slots):
		cands.append(_digits(c, slots, colours))
	var clues: Array = []
	while cands.size() > 1 and clues.size() < MAX_CLUES:
		var guess: Array = Rng.pick(cands, rng)
		var fb: Array = feedback(secret, guess)
		if int(fb[0]) == slots:
			continue
		var kept: Array = []
		for cand in cands:
			var other: Array = feedback(cand, guess)
			if int(other[0]) == int(fb[0]) and int(other[1]) == int(fb[1]):
				kept.append(cand)
		cands = kept
		clues.append({"g": guess, "e": int(fb[0]), "m": int(fb[1])})
	var spec: Dictionary = {
		"type": TYPE,
		"seed": seed_value,
		"difficulty": level,
		"params": {"slots": slots, "colours": colours, "clues": clues},
		"solution": secret,
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = res["ok"]
	spec["reason"] = res["reason"]
	spec["score"] = score(spec)
	spec["signature"] = (TYPE + JSON.stringify(spec["params"])).md5_text()
	return spec


## Returns [right colour in right place, right colour in wrong place].
static func feedback(secret: Array, guess: Array) -> Array:
	var exact: int = 0
	var left_secret: Dictionary = {}
	var left_guess: Dictionary = {}
	for i in secret.size():
		var s: int = int(secret[i])
		var g: int = int(guess[i])
		if s == g:
			exact += 1
		else:
			left_secret[s] = int(left_secret.get(s, 0)) + 1
			left_guess[g] = int(left_guess.get(g, 0)) + 1
	var misplaced: int = 0
	for key in left_guess.keys():
		misplaced += mini(int(left_guess[key]), int(left_secret.get(key, 0)))
	return [exact, misplaced]


static func fits(code: Array, clues: Array) -> bool:
	for clue in clues:
		var guess = clue.get("g")
		if typeof(guess) != TYPE_ARRAY or (guess as Array).size() != code.size():
			return false
		var fb: Array = feedback(code, guess)
		if int(fb[0]) != int(clue.get("e", -1)) or int(fb[1]) != int(clue.get("m", -1)):
			return false
	return true


static func validate(spec: Dictionary) -> Dictionary:
	var p: Dictionary = spec.get("params", {})
	var level: int = clampi(int(spec.get("difficulty", 1)), 1, 5)
	var tier: Dictionary = TIERS[level]
	var slots: int = int(p.get("slots", 0))
	var colours: int = int(p.get("colours", 0))
	var clues: Array = p.get("clues", [])
	var solution: Array = spec.get("solution", [])
	if slots < 2 or slots > 5 or colours < 2 or colours > 8 or solution.size() != slots:
		return _fail("bad_size")
	if clues.size() < int(tier["min_clues"]):
		return _fail("too_easy")
	for clue in clues:
		var g = clue.get("g")
		if typeof(g) != TYPE_ARRAY or (g as Array).size() != slots or int(clue.get("e", 0)) >= slots:
			return _fail("bad_clue")
		for v in g:
			if int(v) < 0 or int(v) >= colours:
				return _fail("bad_clue")
	for v in solution:
		if int(v) < 0 or int(v) >= colours:
			return _fail("bad_solution")
	if not fits(solution, clues):
		return _fail("contradictory_clues")
	var found: int = 0
	for c in _ipow(colours, slots):
		if fits(_digits(c, slots, colours), clues):
			found += 1
			if found > 1:
				return _fail("not_unique")
	return {"ok": true, "reason": "", "solution": solution}


static func score(spec: Dictionary) -> float:
	var p: Dictionary = spec["params"]
	return log(float(_ipow(int(p["colours"]), int(p["slots"])))) / log(10.0) * 2.5


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "solution": []}


static func _ipow(base: int, exp: int) -> int:
	var out: int = 1
	for i in exp:
		out *= base
	return out


static func _digits(code: int, count: int, base: int) -> Array:
	var out: Array = []
	var c: int = code
	for i in count:
		out.append(c % base)
		c = int(c / base)
	return out
