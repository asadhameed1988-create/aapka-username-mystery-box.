extends RefCounted
## QUESTION lock (type "quiz"): one easy multiple-choice question from QuestionBank.
## params: cat ("islam" | "gk"), qid (index in that bank), order (display order of the
## three answers; answer 0 of the bank is the correct one). solution: [display index].

const Rng = preload("res://scripts/pcg/Rng.gd")
const Bank = preload("res://scripts/pcg/QuestionBank.gd")

const TYPE := "quiz"
const CATEGORIES := ["islam", "gk"]


## `cat` "" = random category. `avoid` = ["islam:3", "gk:10", ...] recently asked questions.
static func generate(seed_value: int, difficulty: int, cat: String = "", avoid: Array = []) -> Dictionary:
	var rng: RandomNumberGenerator = Rng.make(seed_value)
	var category: String = cat if CATEGORIES.has(cat) else str(Rng.pick(CATEGORIES, rng))
	var items: Array = Bank.bank(category)
	var qid: int = rng.randi_range(0, items.size() - 1)
	for attempt in 40:
		if not avoid.has("%s:%d" % [category, qid]):
			break
		qid = rng.randi_range(0, items.size() - 1)
	var order: Array = Rng.shuffled([0, 1, 2], rng)
	var spec: Dictionary = {
		"type": TYPE,
		"difficulty": clampi(difficulty, 1, 5),
		"seed": seed_value,
		"params": {"cat": category, "qid": qid, "order": order},
		"solution": [order.find(0)],
		"attempts": 1,
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = bool(res["ok"])
	spec["reason"] = str(res["reason"])
	spec["score"] = score(spec)
	spec["signature"] = ("quiz|%s|%d" % [category, qid]).md5_text()
	return spec


static func validate(spec: Dictionary) -> Dictionary:
	var params: Dictionary = spec.get("params", {})
	var category: String = str(params.get("cat", ""))
	if not CATEGORIES.has(category):
		return {"ok": false, "reason": "bad_category", "solution": []}
	var items: Array = Bank.bank(category)
	var qid = params.get("qid", -1)
	if typeof(qid) != TYPE_INT and typeof(qid) != TYPE_FLOAT:
		return {"ok": false, "reason": "bad_qid", "solution": []}
	if int(qid) < 0 or int(qid) >= items.size():
		return {"ok": false, "reason": "bad_qid", "solution": []}
	var order = params.get("order", [])
	if typeof(order) != TYPE_ARRAY or (order as Array).size() != 3:
		return {"ok": false, "reason": "bad_order", "solution": []}
	var seen: Array = []
	for v in order:
		var n: int = int(v)
		if n < 0 or n > 2 or seen.has(n):
			return {"ok": false, "reason": "bad_order", "solution": []}
		seen.append(n)
	var answer: int = seen.find(0)
	var sol = spec.get("solution", [])
	if typeof(sol) != TYPE_ARRAY or (sol as Array).size() != 1 or int(sol[0]) != answer:
		return {"ok": false, "reason": "wrong_solution", "solution": []}
	return {"ok": true, "reason": "", "solution": [answer]}


static func score(_spec: Dictionary) -> float:
	return 1.0


## Text of the question and the three answers in display order, for one language.
static func texts(spec: Dictionary, lang: String) -> Dictionary:
	var params: Dictionary = spec["params"]
	var item: Dictionary = Bank.bank(str(params["cat"]))[int(params["qid"])]
	var li: int = 1 if lang == "ur" else 0
	var answers: Array = []
	for idx in params["order"]:
		answers.append(str(item["a"][int(idx)][li]))
	return {"question": str(item["q"][li]), "answers": answers}
