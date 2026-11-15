extends RefCounted
## EASY MATHS lock (type "math"): plus, minus and times-table questions, generated
## without limit. params: a, b, op ("add" | "sub" | "mul"), options (3 numbers).
## solution: [index of the right answer in options]. The validator recomputes it.

const Rng = preload("res://scripts/pcg/Rng.gd")

const TYPE := "math"
const OPS := ["add", "sub", "mul"]
const MAX_OPERAND := 100

## Per difficulty: allowed operations and the largest operand.
const TIERS := {
	1: {"ops": ["add"], "max": 10},
	2: {"ops": ["add", "sub"], "max": 20},
	3: {"ops": ["add", "sub"], "max": 50},
	4: {"ops": ["add", "sub", "mul"], "max": 50},
	5: {"ops": ["add", "sub", "mul"], "max": 100},
}


static func generate(seed_value: int, difficulty: int) -> Dictionary:
	var level: int = clampi(difficulty, 1, 5)
	var tier: Dictionary = TIERS[level]
	var rng: RandomNumberGenerator = Rng.make(seed_value)
	var op: String = str(Rng.pick(tier["ops"], rng))
	var a: int = 0
	var b: int = 0
	if op == "mul":
		a = rng.randi_range(2, 10)
		b = rng.randi_range(2, 10)
	else:
		a = rng.randi_range(1, int(tier["max"]))
		b = rng.randi_range(1, int(tier["max"]))
		if op == "sub" and b > a:
			var t: int = a
			a = b
			b = t
	var right: int = answer_of(a, b, op)
	var wrong: Array = []
	var deltas: Array = Rng.shuffled([1, 2, 10, -1, -2, -10, 3, -3], rng)
	for d in deltas:
		var w: int = right + int(d)
		if w >= 0 and w != right and not wrong.has(w):
			wrong.append(w)
		if wrong.size() == 2:
			break
	var options: Array = Rng.shuffled([right, wrong[0], wrong[1]], rng)
	var spec: Dictionary = {
		"type": TYPE,
		"difficulty": level,
		"seed": seed_value,
		"params": {"a": a, "b": b, "op": op, "options": options},
		"solution": [options.find(right)],
		"attempts": 1,
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = bool(res["ok"])
	spec["reason"] = str(res["reason"])
	spec["score"] = score(spec)
	spec["signature"] = ("math|%s|%d|%d" % [op, a, b]).md5_text()
	return spec


static func answer_of(a: int, b: int, op: String) -> int:
	if op == "add":
		return a + b
	if op == "sub":
		return a - b
	return a * b


static func validate(spec: Dictionary) -> Dictionary:
	var params: Dictionary = spec.get("params", {})
	var op: String = str(params.get("op", ""))
	if not OPS.has(op):
		return {"ok": false, "reason": "bad_op", "solution": []}
	var a = params.get("a", -1)
	var b = params.get("b", -1)
	if not (typeof(a) in [TYPE_INT, TYPE_FLOAT]) or not (typeof(b) in [TYPE_INT, TYPE_FLOAT]):
		return {"ok": false, "reason": "bad_operand", "solution": []}
	if a != floorf(float(a)) or b != floorf(float(b)):
		return {"ok": false, "reason": "bad_operand", "solution": []}
	if int(a) < 0 or int(b) < 0 or int(a) > MAX_OPERAND or int(b) > MAX_OPERAND:
		return {"ok": false, "reason": "bad_operand", "solution": []}
	if op == "sub" and int(b) > int(a):
		return {"ok": false, "reason": "negative_answer", "solution": []}
	var right: int = answer_of(int(a), int(b), op)
	var options = params.get("options", [])
	if typeof(options) != TYPE_ARRAY or (options as Array).size() != 3:
		return {"ok": false, "reason": "bad_options", "solution": []}
	var values: Array = []
	for v in options:
		if not (typeof(v) in [TYPE_INT, TYPE_FLOAT]) or v != floorf(float(v)) or int(v) < 0:
			return {"ok": false, "reason": "bad_options", "solution": []}
		if values.has(int(v)):
			return {"ok": false, "reason": "duplicate_option", "solution": []}
		values.append(int(v))
	var index: int = values.find(right)
	if index < 0:
		return {"ok": false, "reason": "no_right_answer", "solution": []}
	var sol = spec.get("solution", [])
	if typeof(sol) != TYPE_ARRAY or (sol as Array).size() != 1 or int(sol[0]) != index:
		return {"ok": false, "reason": "wrong_solution", "solution": []}
	return {"ok": true, "reason": "", "solution": [index]}


static func score(spec: Dictionary) -> float:
	return float(int(spec.get("difficulty", 1)))


static func question_text(spec: Dictionary) -> String:
	var p: Dictionary = spec["params"]
	var sign: String = {"add": "+", "sub": "-", "mul": "×"}[str(p["op"])]
	return "%d  %s  %d  =  ?" % [int(p["a"]), sign, int(p["b"])]
