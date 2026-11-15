extends RefCounted
## NUMBER SEQUENCE lock: find the next number.
## The rule is chosen first, the terms are computed from it, and the validator
## rejects any sequence where a simpler well-known rule would give a different answer.

const Rng = preload("res://scripts/pcg/Rng.gd")

const TYPE := "seq"
const MAX_ATTEMPTS := 30
const OPTION_COUNT := 4

const TIERS := {
	1: {"rules": ["arith"], "len": 4},
	2: {"rules": ["arith", "geom"], "len": 4},
	3: {"rules": ["geom", "alt", "second"], "len": 5},
	4: {"rules": ["alt", "fib", "second"], "len": 5},
	5: {"rules": ["fib", "second", "cube"], "len": 6},
}


static func generate(seed_value: int, difficulty: int) -> Dictionary:
	var level: int = clampi(difficulty, 1, 5)
	var spec: Dictionary = {}
	for attempt in MAX_ATTEMPTS:
		var sub_seed: int = seed_value
		if attempt > 0:
			sub_seed = Rng.derive(seed_value, attempt, 43)
		spec = _build(sub_seed, level)
		spec["seed"] = seed_value
		spec["attempts"] = attempt + 1
		if bool(spec["valid"]):
			break
	return spec


static func _build(seed_value: int, level: int) -> Dictionary:
	var tier: Dictionary = TIERS[level]
	var rng: RandomNumberGenerator = Rng.make(seed_value)
	var rule: String = str(Rng.pick(tier["rules"], rng))
	var args: Array = _make_args(rule, rng)
	var count: int = int(tier["len"])
	var all_terms: Array = terms(rule, args, count + 1)
	var answer: int = int(all_terms[count])
	var options: Array = [answer]
	var offsets: Array = Rng.shuffled([-10, -4, -3, -2, -1, 1, 2, 3, 4, 10], rng)
	for off in offsets:
		if options.size() >= OPTION_COUNT:
			break
		options.append(answer + int(off))
	options = Rng.shuffled(options, rng)
	var spec: Dictionary = {
		"type": TYPE,
		"seed": seed_value,
		"difficulty": level,
		"params": {"shown": all_terms.slice(0, count), "options": options, "rule": rule, "args": args},
		"solution": [options.find(answer)],
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = res["ok"]
	spec["reason"] = res["reason"]
	spec["score"] = score(spec)
	spec["signature"] = (TYPE + JSON.stringify(spec["params"])).md5_text()
	return spec


static func _make_args(rule: String, rng: RandomNumberGenerator) -> Array:
	if rule == "arith":
		return [rng.randi_range(1, 20), rng.randi_range(1, 9) * Rng.coin(rng)]
	if rule == "geom":
		return [rng.randi_range(1, 4), rng.randi_range(2, 3)]
	if rule == "alt":
		var d1: int = rng.randi_range(1, 6)
		var d2: int = rng.randi_range(1, 8)
		if d2 == d1:
			d2 += 1
		return [rng.randi_range(1, 15), d1, d2 * Rng.coin(rng)]
	if rule == "fib":
		return [rng.randi_range(1, 5), rng.randi_range(1, 6)]
	if rule == "second":
		return [rng.randi_range(1, 10), rng.randi_range(1, 5), rng.randi_range(1, 4)]
	return [rng.randi_range(0, 2), rng.randi_range(-3, 5)]


## Computes `count` terms of the sequence defined by a rule and its arguments.
static func terms(rule: String, args: Array, count: int) -> Array:
	var out: Array = []
	var a: int = int(args[0])
	var b: int = 0
	if args.size() > 1:
		b = int(args[1])
	var c: int = 0
	if args.size() > 2:
		c = int(args[2])
	for k in count:
		if rule == "arith":
			out.append(a + b * k)
		elif rule == "geom":
			var v: int = a
			for i in k:
				v *= b
			out.append(v)
		elif rule == "alt":
			if k == 0:
				out.append(a)
			elif k % 2 == 1:
				out.append(int(out[k - 1]) + b)
			else:
				out.append(int(out[k - 1]) + c)
		elif rule == "fib":
			if k == 0:
				out.append(a)
			elif k == 1:
				out.append(b)
			else:
				out.append(int(out[k - 1]) + int(out[k - 2]))
		elif rule == "second":
			if k == 0:
				out.append(a)
			else:
				out.append(int(out[k - 1]) + b + (k - 1) * c)
		else:
			var n: int = k + a + 1
			out.append(n * n * n + b)
	return out


## Next-term predictions of every simple rule that fits the shown terms.
static func predictions(shown: Array) -> Array:
	var out: Array = []
	var n: int = shown.size()
	if n < 3:
		return out
	var t: Array = []
	for v in shown:
		t.append(int(v))
	var d: Array = []
	for i in range(1, n):
		d.append(int(t[i]) - int(t[i - 1]))
	# constant second difference (includes plain arithmetic)
	var second_ok: bool = n >= 4
	for i in range(2, d.size()):
		if int(d[i]) - int(d[i - 1]) != int(d[1]) - int(d[0]):
			second_ok = false
	var arith_ok: bool = true
	for i in range(1, d.size()):
		if int(d[i]) != int(d[0]):
			arith_ok = false
	if arith_ok:
		out.append(int(t[n - 1]) + int(d[0]))
	elif second_ok:
		var e: int = int(d[1]) - int(d[0])
		out.append(int(t[n - 1]) + int(d[d.size() - 1]) + e)
	# geometric with integer ratio
	if int(t[0]) != 0 and int(t[1]) % int(t[0]) == 0:
		var r: int = int(int(t[1]) / int(t[0]))
		var geom_ok: bool = r != 1 and r != 0
		for i in range(1, n):
			if int(t[i]) != int(t[i - 1]) * r:
				geom_ok = false
		if geom_ok:
			out.append(int(t[n - 1]) * r)
	# fibonacci-like
	var fib_ok: bool = true
	for i in range(2, n):
		if int(t[i]) != int(t[i - 1]) + int(t[i - 2]):
			fib_ok = false
	if fib_ok:
		out.append(int(t[n - 1]) + int(t[n - 2]))
	# alternating steps
	if n >= 5 and not arith_ok:
		var alt_ok: bool = true
		for i in range(2, d.size()):
			if int(d[i]) != int(d[i - 2]):
				alt_ok = false
		if alt_ok:
			out.append(int(t[n - 1]) + int(d[d.size() - 2]))
	return out


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
		if seen.has(int(o)):
			return _fail("duplicate_option")
		seen[int(o)] = true
	var answer: int = int(options[index])
	var rule: String = str(p.get("rule", ""))
	var args: Array = p.get("args", [])
	var needed: int = 2
	if rule == "alt" or rule == "second":
		needed = 3
	if not ["arith", "geom", "alt", "fib", "second", "cube"].has(rule) or args.size() < needed or shown.size() > 12:
		return _fail("bad_rule")
	var again: Array = terms(str(p.get("rule", "")), p.get("args", []), shown.size() + 1)
	for i in shown.size():
		if int(again[i]) != int(shown[i]):
			return _fail("rule_mismatch")
		if absi(int(shown[i])) > 100000:
			return _fail("too_large")
	if int(again[shown.size()]) != answer:
		return _fail("wrong_answer")
	for guess in predictions(shown):
		if int(guess) != answer:
			return _fail("ambiguous")
	return {"ok": true, "reason": "", "solution": sol}


static func score(spec: Dictionary) -> float:
	var weights: Dictionary = {"arith": 1.0, "geom": 2.0, "alt": 3.0, "second": 3.5, "fib": 4.0, "cube": 5.0}
	return float(weights.get(str(spec["params"]["rule"]), 1.0))


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason, "solution": []}
