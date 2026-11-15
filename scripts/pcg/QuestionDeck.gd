extends RefCounted
## Hands out questions WITHOUT repeats. Each template is walked through a fixed shuffle
## (an affine permutation k -> (a*k + b) mod size, unique per install), so every question
## of a template is asked once before any is asked again. Templates take turns.
## The hand-written bank comes first in each box until it is used up.
## state (saved in GameState): {"counters": {tpl: next k}, "rr": turn, "cycle": n}

const QuizGen = preload("res://scripts/pcg/QuizGenerator.gd")


static func _gcd(a: int, b: int) -> int:
	while b != 0:
		var t: int = b
		b = a % b
		a = t
	return a


static func permute(size: int, k: int, salt: int) -> int:
	if size <= 1:
		return 0
	var h: int = absi(salt)
	var a: int = 1 + (h % (size - 1))
	while _gcd(a, size) != 1:
		a = 1 + (a % (size - 1))
	var b: int = absi(("%d" % salt).hash()) % size
	return (a * (k % size) + b) % size


## Next unused question as {"tpl", "idx"}.
static func next_question(state: Dictionary, cat: String, install_seed: int, bank_first: bool) -> Dictionary:
	var counters: Dictionary = state.get("counters", {})
	state["counters"] = counters
	var tpls: Array = QuizGen.templates(cat)
	var cycle: int = int(state.get("cycle", 0))
	if bank_first:
		var got: Dictionary = _take(state, cat, tpls[0], install_seed, cycle)
		if not got.is_empty():
			return got
	for attempt in 400:
		var turn: int = int(state.get("rr", 0))
		state["rr"] = turn + 1
		var t: Array = tpls[1 + turn % (tpls.size() - 1)]
		var got2: Dictionary = _take(state, cat, t, install_seed, cycle)
		if not got2.is_empty():
			return got2
	# Everything has been asked (would take years): start a new round with a new shuffle.
	state["counters"] = {}
	state["cycle"] = cycle + 1
	return next_question(state, cat, install_seed, bank_first)


## Takes the next question of one template, skipping ids that give no fair question.
static func _take(state: Dictionary, cat: String, t: Array, install_seed: int, cycle: int) -> Dictionary:
	var counters: Dictionary = state["counters"]
	var tpl: String = str(t[0])
	var size: int = int(t[1])
	var salt: int = ("%d|%s|%s|%d" % [install_seed, cat, tpl, cycle]).hash()
	for tries in 40:
		var k: int = int(counters.get(tpl, 0))
		if k >= size:
			return {}
		counters[tpl] = k + 1
		var idx: int = permute(size, k, salt)
		if not QuizGen.make(cat, tpl, idx).is_empty():
			return {"tpl": tpl, "idx": idx}
	return {}
