extends RefCounted
## MATHS lock (type "math"), generated without limit, five levels:
##   1: two-digit plus/minus, times tables to 12
##   2: exact division, x + a = b, a*x = b, two-digit x one-digit
##   3: a*x + b = c, a*b + c, a*b - c, (a + b)*c
##   4: a*x - b = c, percentages, squares
##   5: a(x + b) = c, square roots, a + b*c - d, larger equations
## params: kind, nums, options (3 numbers). solution: [index]. The validator recomputes it.

const Rng = preload("res://scripts/pcg/Rng.gd")

const TYPE := "math"
const KINDS := {
	"add": 2, "sub": 2, "mul": 2, "div": 2, "eq_add": 2, "eq_mul": 2, "eq_lin": 3,
	"eq_lin_sub": 3, "eq_par": 3, "two_add": 3, "two_sub": 3, "paren": 3, "pct": 2,
	"sq": 1, "sqrt": 1, "mix": 4,
}
const LEVEL_KINDS := {
	1: ["add", "sub", "mul"],
	2: ["div", "eq_add", "eq_mul", "mul"],
	3: ["eq_lin", "two_add", "two_sub", "paren"],
	4: ["eq_lin_sub", "pct", "sq", "eq_lin"],
	5: ["eq_par", "sqrt", "mix", "eq_lin_sub"],
}
const MAX_NUM := 100000


static func generate(seed_value: int, difficulty: int) -> Dictionary:
	var level: int = clampi(difficulty, 1, 5)
	var rng: RandomNumberGenerator = Rng.make(seed_value)
	var kind: String = str(Rng.pick(LEVEL_KINDS[level], rng))
	var nums: Array = _numbers(kind, level, rng)
	var right: int = answer_of(kind, nums)
	var wrong: Array = []
	var spread: Array = [1, 2, 3, 5, 10]
	if right >= 20:
		spread.append(right / 10)
	for d in Rng.shuffled(spread, rng):
		for s in [1, -1]:
			var w: int = right + int(d) * s
			if w >= 0 and w != right and not wrong.has(w) and wrong.size() < 2:
				wrong.append(w)
	var options: Array = Rng.shuffled([right, wrong[0], wrong[1]], rng)
	var spec: Dictionary = {
		"type": TYPE,
		"difficulty": level,
		"seed": seed_value,
		"params": {"kind": kind, "nums": nums, "options": options},
		"solution": [options.find(right)],
		"attempts": 1,
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = bool(res["ok"])
	spec["reason"] = str(res["reason"])
	spec["score"] = score(spec)
	spec["signature"] = ("math|%s|%s" % [kind, str(nums)]).md5_text()
	return spec


static func _numbers(kind: String, level: int, rng: RandomNumberGenerator) -> Array:
	var big: int = 1 if level < 5 else 2
	match kind:
		"add":
			return [rng.randi_range(10, 99), rng.randi_range(10, 99)]
		"sub":
			var a: int = rng.randi_range(30, 99)
			return [a, rng.randi_range(10, a - 1)]
		"mul":
			if level == 1:
				return [rng.randi_range(2, 12), rng.randi_range(2, 12)]
			return [rng.randi_range(11, 49), rng.randi_range(2, 9)]
		"div":
			var b: int = rng.randi_range(2, 12)
			return [b * rng.randi_range(2, 15), b]
		"eq_add":
			var a2: int = rng.randi_range(5, 60)
			return [a2, a2 + rng.randi_range(5, 60)]
		"eq_mul":
			var a3: int = rng.randi_range(2, 12)
			return [a3, a3 * rng.randi_range(2, 12)]
		"eq_lin":
			var a4: int = rng.randi_range(2, 9 * big)
			var b4: int = rng.randi_range(1, 30 * big)
			var x: int = rng.randi_range(2, 15)
			return [a4, b4, a4 * x + b4]
		"eq_lin_sub":
			var a5: int = rng.randi_range(2, 12)
			var x2: int = rng.randi_range(3, 20)
			var b5: int = rng.randi_range(1, a5 * x2 - 1)
			return [a5, b5, a5 * x2 - b5]
		"eq_par":
			var a6: int = rng.randi_range(2, 9)
			var b6: int = rng.randi_range(1, 12)
			var x3: int = rng.randi_range(1, 15)
			return [a6, b6, a6 * (x3 + b6)]
		"two_add", "two_sub":
			var a7: int = rng.randi_range(3, 12)
			var b7: int = rng.randi_range(3, 12)
			var c7: int = rng.randi_range(1, a7 * b7 - 1) if kind == "two_sub" else rng.randi_range(1, 50)
			return [a7, b7, c7]
		"paren":
			return [rng.randi_range(2, 20), rng.randi_range(2, 20), rng.randi_range(2, 9)]
		"pct":
			var p: int = Rng.pick([10, 20, 25, 50, 75], rng)
			var n: int = rng.randi_range(2, 40) * 20
			return [p, n]
		"sq":
			return [rng.randi_range(4, 25)]
		"sqrt":
			var r: int = rng.randi_range(4, 25)
			return [r * r]
		"mix":
			var b8: int = rng.randi_range(2, 9)
			var c8: int = rng.randi_range(2, 9)
			var a8: int = rng.randi_range(5, 60)
			return [a8, b8, c8, rng.randi_range(1, a8 + b8 * c8 - 1)]
	return [1, 1]


## The right answer, or -1 if the numbers do not make a fair whole-number question.
static func answer_of(kind: String, n: Array) -> int:
	match kind:
		"add":
			return n[0] + n[1]
		"sub":
			return n[0] - n[1] if n[0] >= n[1] else -1
		"mul":
			return n[0] * n[1]
		"div":
			return n[0] / n[1] if n[1] > 0 and n[0] % n[1] == 0 else -1
		"eq_add":
			return n[1] - n[0] if n[1] >= n[0] else -1
		"eq_mul":
			return n[1] / n[0] if n[0] > 0 and n[1] % n[0] == 0 else -1
		"eq_lin":
			return (n[2] - n[1]) / n[0] if n[0] > 0 and n[2] >= n[1] and (n[2] - n[1]) % n[0] == 0 else -1
		"eq_lin_sub":
			return (n[2] + n[1]) / n[0] if n[0] > 0 and (n[2] + n[1]) % n[0] == 0 else -1
		"eq_par":
			if n[0] <= 0 or n[2] % n[0] != 0 or n[2] / n[0] < n[1]:
				return -1
			return n[2] / n[0] - n[1]
		"two_add":
			return n[0] * n[1] + n[2]
		"two_sub":
			return n[0] * n[1] - n[2] if n[0] * n[1] >= n[2] else -1
		"paren":
			return (n[0] + n[1]) * n[2]
		"pct":
			return n[0] * n[1] / 100 if (n[0] * n[1]) % 100 == 0 else -1
		"sq":
			return n[0] * n[0]
		"sqrt":
			var r: int = int(round(sqrt(float(n[0]))))
			return r if r * r == n[0] else -1
		"mix":
			var v: int = n[0] + n[1] * n[2] - n[3]
			return v if v >= 0 else -1
	return -1


static func validate(spec: Dictionary) -> Dictionary:
	var params: Dictionary = spec.get("params", {})
	var kind: String = str(params.get("kind", ""))
	if not KINDS.has(kind):
		return {"ok": false, "reason": "bad_kind", "solution": []}
	var raw = params.get("nums", [])
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() != int(KINDS[kind]):
		return {"ok": false, "reason": "bad_numbers", "solution": []}
	var nums: Array = []
	for v in raw:
		if not (typeof(v) in [TYPE_INT, TYPE_FLOAT]) or v != floorf(float(v)) or int(v) < 0 or int(v) > MAX_NUM:
			return {"ok": false, "reason": "bad_numbers", "solution": []}
		nums.append(int(v))
	var right: int = answer_of(kind, nums)
	if right < 0:
		return {"ok": false, "reason": "no_whole_answer", "solution": []}
	var options = params.get("options", [])
	if typeof(options) != TYPE_ARRAY or (options as Array).size() != 3:
		return {"ok": false, "reason": "bad_options", "solution": []}
	var values: Array = []
	for v in options:
		if not (typeof(v) in [TYPE_INT, TYPE_FLOAT]) or v != floorf(float(v)) or int(v) < 0 or int(v) > MAX_NUM * MAX_NUM:
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


static func is_equation(spec: Dictionary) -> bool:
	return str(spec["params"]["kind"]).begins_with("eq_")


static func question_text(spec: Dictionary) -> String:
	var n: Array = spec["params"]["nums"]
	match str(spec["params"]["kind"]):
		"add":
			return "%d + %d = ?" % [n[0], n[1]]
		"sub":
			return "%d - %d = ?" % [n[0], n[1]]
		"mul":
			return "%d × %d = ?" % [n[0], n[1]]
		"div":
			return "%d ÷ %d = ?" % [n[0], n[1]]
		"eq_add":
			return "x + %d = %d" % [n[0], n[1]]
		"eq_mul":
			return "%dx = %d" % [n[0], n[1]]
		"eq_lin":
			return "%dx + %d = %d" % [n[0], n[1], n[2]]
		"eq_lin_sub":
			return "%dx - %d = %d" % [n[0], n[1], n[2]]
		"eq_par":
			return "%d(x + %d) = %d" % [n[0], n[1], n[2]]
		"two_add":
			return "%d × %d + %d = ?" % [n[0], n[1], n[2]]
		"two_sub":
			return "%d × %d - %d = ?" % [n[0], n[1], n[2]]
		"paren":
			return "(%d + %d) × %d = ?" % [n[0], n[1], n[2]]
		"pct":
			return "%d%% of %d = ?" % [n[0], n[1]]
		"sq":
			return "%d² = ?" % [n[0]]
		"sqrt":
			return "√%d = ?" % [n[0]]
		"mix":
			return "%d + %d × %d - %d = ?" % [n[0], n[1], n[2], n[3]]
	return "?"
