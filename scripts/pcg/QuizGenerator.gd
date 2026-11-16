extends RefCounted
## QUESTION lock (type "quiz"). Questions come from "templates" filled with verified data:
##   islam: hand-written bank (Hanafi fiqh, seerah) + Quran facts from QuranData (Hafs)
##          + Islamic (Hijri) months.
##   gk:    hand-written bank (Pakistan) + facts about UN member states from CountryData.
## Each question is identified by (cat, tpl, idx). The same id always gives the same
## question and the same three answers, so a saved or server box can be re-checked.
## Triple templates ("which of these three ...") give hundreds of thousands of questions.
## params: cat, tpl, idx, order (display order of answers; answer 0 is right).

const Rng = preload("res://scripts/pcg/Rng.gd")
const Bank = preload("res://scripts/pcg/QuestionBank.gd")
const Quran = preload("res://scripts/pcg/QuranData.gd")
const World = preload("res://scripts/pcg/CountryData.gd")
const Refs = preload("res://scripts/pcg/References.gd")
const Fiqh = preload("res://scripts/pcg/FiqhData.gd")

const TYPE := "quiz"
const CATEGORIES := ["islam", "gk"]
const AREA_GAP := 1.2   # "largest of three" only when the winner is clearly bigger

const HIJRI := [
	["Muharram", "محرم", "محرم"], ["Safar", "صفر", "صفر"], ["Rabi-ul-Awwal", "ربیع الاول", "ربيع الأول"],
	["Rabi-us-Sani", "ربیع الثانی", "ربيع الآخر"], ["Jumada-al-Ula", "جمادی الاولیٰ", "جمادى الأولى"],
	["Jumada-al-Akhirah", "جمادی الآخرہ", "جمادى الآخرة"], ["Rajab", "رجب", "رجب"], ["Shaban", "شعبان", "شعبان"],
	["Ramadan", "رمضان", "رمضان"], ["Shawwal", "شوال", "شوال"], ["Dhul-Qadah", "ذوالقعدہ", "ذو القعدة"],
	["Dhul-Hijjah", "ذوالحجہ", "ذو الحجة"],
]
const REGIONS := {
	"Africa": ["Africa", "افریقہ", "أفريقيا"], "Americas": ["The Americas", "امریکہ (شمالی و جنوبی)", "الأمريكتان"],
	"Asia": ["Asia", "ایشیا", "آسيا"], "Europe": ["Europe", "یورپ", "أوروبا"], "Oceania": ["Oceania", "اوشیانا", "أوقيانوسيا"],
}
## Question languages: index into every [en, ur, ar] text.
const LANGS := ["en", "ur", "ar"]

static var _lists: Dictionary = {}


# ------------------------------------------------------------------ templates

static func templates(cat: String) -> Array:
	var n_s: int = Quran.SURAHS.size()
	var n_c: int = World.COUNTRIES.size()
	if cat == "islam":
		return [
			["bank", Bank.ISLAM.size()], ["surah_name", n_s], ["surah_number", n_s],
			["surah_ayahs", n_s], ["surah_after", n_s - 1], ["surah_before", n_s - 1],
			["surah_juz", n_s], ["hijri_after", 12], ["hijri_number", 12],
			["first3", _c3(n_s)], ["most3", _c3(n_s)], ["fewest3", _c3(n_s)],
			["fiqh4", _fiqh_pairs().size()], ["fiqh_multi", Fiqh.MULTI.size()], ["hadith", Fiqh.HADITH_Q.size()],
		]
	if cat == "gk":
		return [
			["bank", Bank.GK.size()], ["capital", _list("capital").size()],
			["capital_of", _list("capital").size()], ["region", _list("region").size()],
			["neighbor", _list("pairs").size()], ["landlocked", _list("landlocked").size()],
			["largest3", _c3(n_c)], ["smallest3", _c3(n_c)],
		]
	return []


static func template_size(cat: String, tpl: String) -> int:
	for t in templates(cat):
		if str(t[0]) == tpl:
			return int(t[1])
	return 0


## Total number of different questions in a category (for the menu and the docs).
static func total(cat: String) -> int:
	var n: int = 0
	for t in templates(cat):
		n += int(t[1])
	return n


# ------------------------------------------------------------------ spec

static func build(cat: String, tpl: String, idx: int, seed_value: int, difficulty: int = 1) -> Dictionary:
	var rng: RandomNumberGenerator = Rng.make(seed_value)
	var item: Dictionary = make(cat, tpl, idx)
	var n: int = (item["a"] as Array).size() if not item.is_empty() else 3
	var order: Array = Rng.shuffled(range(n), rng)
	var spec: Dictionary = {
		"type": TYPE,
		"difficulty": clampi(difficulty, 1, 5),
		"seed": seed_value,
		"params": {"cat": cat, "tpl": tpl, "idx": idx, "order": order},
		"solution": _solution_for(order, item.get("correct", [0])),
		"attempts": 1,
	}
	var res: Dictionary = validate(spec)
	spec["valid"] = bool(res["ok"])
	spec["reason"] = str(res["reason"])
	spec["score"] = score(spec)
	spec["signature"] = ("quiz|%s|%s|%d" % [cat, tpl, idx]).md5_text()
	return spec


## Random question (daily box, tests). Sections use QuestionDeck so nothing repeats.
static func generate(seed_value: int, difficulty: int, cat: String = "", _avoid: Array = []) -> Dictionary:
	var rng: RandomNumberGenerator = Rng.make(seed_value)
	var category: String = cat if CATEGORIES.has(cat) else str(Rng.pick(CATEGORIES, rng))
	var tpls: Array = templates(category)
	for attempt in 40:
		var t: Array = tpls[rng.randi_range(0, tpls.size() - 1)]
		var idx: int = rng.randi_range(0, int(t[1]) - 1)
		if not make(category, str(t[0]), idx).is_empty():
			return build(category, str(t[0]), idx, rng.randi(), difficulty)
	return build(category, "bank", 0, rng.randi(), difficulty)


static func validate(spec: Dictionary) -> Dictionary:
	var params: Dictionary = spec.get("params", {})
	var cat: String = str(params.get("cat", ""))
	if not CATEGORIES.has(cat):
		return {"ok": false, "reason": "bad_category", "solution": []}
	var tpl: String = str(params.get("tpl", ""))
	var size: int = template_size(cat, tpl)
	if size <= 0:
		return {"ok": false, "reason": "bad_template", "solution": []}
	var idx = params.get("idx", -1)
	if not (typeof(idx) in [TYPE_INT, TYPE_FLOAT]) or idx != floorf(float(idx)) or int(idx) < 0 or int(idx) >= size:
		return {"ok": false, "reason": "bad_index", "solution": []}
	var item: Dictionary = make(cat, tpl, int(idx))
	if item.is_empty():
		return {"ok": false, "reason": "no_question", "solution": []}
	var count: int = (item["a"] as Array).size()
	var order = params.get("order", [])
	if typeof(order) != TYPE_ARRAY or (order as Array).size() != count:
		return {"ok": false, "reason": "bad_order", "solution": []}
	var seen: Array = []
	for v in order:
		if not (typeof(v) in [TYPE_INT, TYPE_FLOAT]):
			return {"ok": false, "reason": "bad_order", "solution": []}
		var n: int = int(v)
		if n < 0 or n >= count or seen.has(n):
			return {"ok": false, "reason": "bad_order", "solution": []}
		seen.append(n)
	var expected: Array = _solution_for(seen, item.get("correct", [0]))
	var sol = spec.get("solution", [])
	if typeof(sol) != TYPE_ARRAY or (sol as Array).size() != expected.size():
		return {"ok": false, "reason": "wrong_solution", "solution": []}
	for i in expected.size():
		if not (typeof(sol[i]) in [TYPE_INT, TYPE_FLOAT]) or int(sol[i]) != int(expected[i]):
			return {"ok": false, "reason": "wrong_solution", "solution": []}
	return {"ok": true, "reason": "", "solution": expected}


## Display positions of the right answers, sorted.
static func _solution_for(order: Array, correct: Array) -> Array:
	var out: Array = []
	for c in correct:
		out.append(order.find(int(c)))
	out.sort()
	return out


## True for "choose all that are correct" questions.
static func is_multi(spec: Dictionary) -> bool:
	return (spec.get("solution", []) as Array).size() > 1


static func score(_spec: Dictionary) -> float:
	return 1.0


## Question and answers (in display order) for one language.
static func texts(spec: Dictionary, lang: String) -> Dictionary:
	var p: Dictionary = spec["params"]
	var item: Dictionary = make(str(p["cat"]), str(p["tpl"]), int(p["idx"]))
	var li: int = maxi(0, LANGS.find(lang))
	var answers: Array = []
	for i in p["order"]:
		answers.append(_pick_lang(item["a"][int(i)], li))
	return {"question": _pick_lang(item["q"], li), "answers": answers}


static func _pick_lang(texts_by_lang: Array, li: int) -> String:
	if li < texts_by_lang.size() and str(texts_by_lang[li]) != "":
		return str(texts_by_lang[li])
	return str(texts_by_lang[0])


## Reference for an Islamic question: {"ar", "en", "ur"}, or {} (general knowledge).
static func reference_of(spec: Dictionary) -> Dictionary:
	var p: Dictionary = spec.get("params", {})
	if str(p.get("cat", "")) != "islam":
		return {}
	var tpl: String = str(p.get("tpl", ""))
	var idx: int = int(p.get("idx", 0))
	match tpl:
		"bank":
			return Refs.for_key(str(Bank.ISLAM[idx].get("src", "")))
		"surah_name", "surah_number", "surah_ayahs", "surah_juz":
			return Refs.for_surahs([idx + 1])
		"surah_after", "surah_before":
			return Refs.for_surahs([idx + 1, idx + 2])
		"first3", "most3", "fewest3":
			var t: Array = unrank3(idx)
			return Refs.for_surahs([int(t[0]) + 1, int(t[1]) + 1, int(t[2]) + 1])
		"hijri_after", "hijri_number":
			return Refs.for_hijri()
		"fiqh4":
			var pr: Array = _fiqh_pairs()[idx]
			var topic: Dictionary = Fiqh.TOPICS[int(pr[0])]
			return Refs.combine(topic.get("refs", []), [Fiqh.BOOKS[str(pr[1])], Fiqh.BOOKS["compare"]], topic.get("hadith", []))
		"fiqh_multi":
			var m: Dictionary = Fiqh.MULTI[idx]
			return Refs.combine(m.get("refs", []), [Fiqh.BOOKS[str(m["school"])]], m.get("hadith", []))
		"hadith":
			return Refs.combine([], [], [int(Fiqh.HADITH_Q[idx]["hadith"])])
	return {}


# ------------------------------------------------------------------ question makers

## Returns {"q": [en, ur], "a": [[en, ur] x3]} with the right answer first,
## or {} when this id gives no fair question (for example a tie).
static func make(cat: String, tpl: String, idx: int) -> Dictionary:
	var rng: RandomNumberGenerator = Rng.make(("%s|%s|%d" % [cat, tpl, idx]).hash())
	if cat == "islam":
		return _islam(tpl, idx, rng)
	if cat == "gk":
		return _gk(tpl, idx, rng)
	return {}


static func _s_en(i: int) -> String:
	return str(Quran.SURAHS[i][0])


static func _s_ur(i: int) -> String:
	return str(Quran.SURAHS[i][1])


static func _surah_answer(i: int) -> Array:
	return ["Surah " + _s_en(i), "سورۃ " + _s_ur(i), "سورة " + _s_ur(i)]


static func _num(n: int) -> Array:
	return [str(n), str(n), Refs.ar_digits(n)]


static func _fiqh_pairs() -> Array:
	if not _lists.has("fiqh_pairs"):
		_list("capital")
		_lists["fiqh_pairs"] = Fiqh.pairs()
	return _lists["fiqh_pairs"]


## "question (Fiqh Hanafi)" in all three languages.
static func _with_school(q: Array, school: String) -> Array:
	var label: Array = Fiqh.SCHOOLS[school]
	return ["%s (%s)" % [q[0], label[0]], "%s (%s)" % [q[1], label[1]], "%s (%s)" % [q[2], label[2]]]


static func _islam(tpl: String, idx: int, rng: RandomNumberGenerator) -> Dictionary:
	var n: int = Quran.SURAHS.size()
	match tpl:
		"fiqh4":
			var pr: Array = _fiqh_pairs()[idx]
			var topic: Dictionary = Fiqh.TOPICS[int(pr[0])]
			var right: String = str(topic["ans"][str(pr[1])])
			var others: Array = []
			for k in Rng.shuffled(topic["opts"].keys(), rng):
				if str(k) != right and others.size() < 2:
					others.append(str(k))
			if others.size() < 2:
				return {}
			return {"q": _with_school(topic["q"], str(pr[1])),
				"a": [topic["opts"][right], topic["opts"][others[0]], topic["opts"][others[1]]]}
		"fiqh_multi":
			var m: Dictionary = Fiqh.MULTI[idx]
			return {"q": _with_school(m["q"], str(m["school"])), "a": m["a"], "correct": m["correct"]}
		"hadith":
			var h: Dictionary = Fiqh.HADITH_Q[idx]
			return {"q": h["q"], "a": h["a"]}
		"bank":
			var it: Dictionary = Bank.ISLAM[idx]
			return {"q": it["q"], "a": it["a"]}
		"surah_name":
			var o: Array = _others(n, [idx], rng)
			return {"q": ["Which Surah is number %d in the Holy Quran?" % (idx + 1), "قرآن مجید کی سورت نمبر %d کون سی ہے؟" % (idx + 1), "ما السورة رقم %s في القرآن الكريم؟" % Refs.ar_digits(idx + 1)],
				"a": [_surah_answer(idx), _surah_answer(o[0]), _surah_answer(o[1])]}
		"surah_number":
			var w: Array = _near(idx + 1, 1, n, 5, rng)
			return {"q": ["What is the number of Surah %s in the Quran?" % _s_en(idx), "سورۃ %s قرآن مجید میں کس نمبر پر ہے؟" % _s_ur(idx), "ما رقم سورة %s في القرآن الكريم؟" % _s_ur(idx)],
				"a": [_num(idx + 1), _num(w[0]), _num(w[1])]}
		"surah_ayahs":
			var c: int = int(Quran.SURAHS[idx][2])
			var w2: Array = _near(c, 3, 300, 6, rng)
			return {"q": ["How many ayahs are in Surah %s?" % _s_en(idx), "سورۃ %s میں کتنی آیات ہیں؟" % _s_ur(idx), "كم عدد آيات سورة %s؟" % _s_ur(idx)],
				"a": [_num(c), _num(w2[0]), _num(w2[1])]}
		"surah_after":
			var o2: Array = _others(n, [idx, idx + 1], rng)
			return {"q": ["Which Surah comes right after Surah %s in the Quran?" % _s_en(idx), "قرآن مجید میں سورۃ %s کے فوراً بعد کون سی سورت ہے؟" % _s_ur(idx), "ما السورة التي تأتي بعد سورة %s مباشرة؟" % _s_ur(idx)],
				"a": [_surah_answer(idx + 1), _surah_answer(o2[0]), _surah_answer(o2[1])]}
		"surah_before":
			var s: int = idx + 1
			var o3: Array = _others(n, [s, idx], rng)
			return {"q": ["Which Surah comes just before Surah %s in the Quran?" % _s_en(s), "قرآن مجید میں سورۃ %s سے فوراً پہلے کون سی سورت ہے؟" % _s_ur(s), "ما السورة التي تأتي قبل سورة %s مباشرة؟" % _s_ur(s)],
				"a": [_surah_answer(idx), _surah_answer(o3[0]), _surah_answer(o3[1])]}
		"surah_juz":
			var j: int = int(Quran.SURAHS[idx][3])
			var w3: Array = _near(j, 1, 30, 3, rng)
			return {"q": ["Surah %s begins in which Para (Juz)?" % _s_en(idx), "سورۃ %s کس پارے میں شروع ہوتی ہے؟" % _s_ur(idx), "في أي جزء تبدأ سورة %s؟" % _s_ur(idx)],
				"a": [_num(j), _num(w3[0]), _num(w3[1])]}
		"hijri_after":
			var nxt: int = (idx + 1) % 12
			var o4: Array = _others(12, [idx, nxt], rng)
			return {"q": ["Which Islamic month comes after %s?" % HIJRI[idx][0], "اسلامی مہینے %s کے بعد کون سا مہینہ آتا ہے؟" % HIJRI[idx][1], "ما الشهر الهجري الذي يأتي بعد %s؟" % HIJRI[idx][2]],
				"a": [HIJRI[nxt], HIJRI[o4[0]], HIJRI[o4[1]]]}
		"hijri_number":
			var o5: Array = _others(12, [idx], rng)
			return {"q": ["Which is month number %d of the Islamic (Hijri) year?" % (idx + 1), "اسلامی (ہجری) سال کا مہینہ نمبر %d کون سا ہے؟" % (idx + 1), "ما الشهر رقم %s في السنة الهجرية؟" % Refs.ar_digits(idx + 1)],
				"a": [HIJRI[idx], HIJRI[o5[0]], HIJRI[o5[1]]]}
		"first3":
			var t: Array = unrank3(idx)
			return {"q": ["Which of these Surahs comes first in the Quran?", "ان میں سے کون سی سورت قرآن مجید میں سب سے پہلے آتی ہے؟", "أي هذه السور تأتي أولًا في القرآن الكريم؟"],
				"a": [_surah_answer(t[0]), _surah_answer(t[1]), _surah_answer(t[2])]}
		"most3", "fewest3":
			var t2: Array = unrank3(idx)
			var pick: Array = _extreme(t2, func(i: int) -> float: return float(Quran.SURAHS[i][2]), tpl == "most3", 1.0)
			if pick.is_empty():
				return {}
			var q: Array = ["Which of these Surahs has the most ayahs?", "ان میں سے کس سورت کی آیات سب سے زیادہ ہیں؟", "أي هذه السور أكثر آيات؟"]
			if tpl == "fewest3":
				q = ["Which of these Surahs has the fewest ayahs?", "ان میں سے کس سورت کی آیات سب سے کم ہیں؟", "أي هذه السور أقل آيات؟"]
			return {"q": q, "a": [_surah_answer(pick[0]), _surah_answer(pick[1]), _surah_answer(pick[2])]}
	return {}


static func _c_en(i: int) -> String:
	return str(World.COUNTRIES[i][1])


static func _c_ur(i: int) -> String:
	return str(World.COUNTRIES[i][2])


static func _c_ar(i: int) -> String:
	return str(World.COUNTRIES[i][8])


static func _country(i: int) -> Array:
	return [_c_en(i), _c_ur(i), _c_ar(i)]


static func _gk(tpl: String, idx: int, rng: RandomNumberGenerator) -> Dictionary:
	var C: Array = World.COUNTRIES
	match tpl:
		"bank":
			var it: Dictionary = Bank.GK[idx]
			return {"q": it["q"], "a": it["a"]}
		"capital", "capital_of":
			var caps: Array = _list("capital")
			var i: int = int(caps[idx])
			var pool: Array = _same_region(i, caps, [])
			var o: Array = _pick2(pool, [i], rng)
			if o.is_empty():
				return {}
			if tpl == "capital":
				return {"q": ["What is the capital of %s?" % _c_en(i), "%s کا دارالحکومت کون سا ہے؟" % _c_ur(i), "ما عاصمة %s؟" % _c_ar(i)],
					"a": [[str(C[i][3])], [str(C[o[0]][3])], [str(C[o[1]][3])]]}
			return {"q": ["%s is the capital of which country?" % str(C[i][3]), "%s کس ملک کا دارالحکومت ہے؟" % str(C[i][3]), "%s عاصمة أي دولة؟" % str(C[i][3])],
				"a": [_country(i), _country(o[0]), _country(o[1])]}
		"region":
			var i2: int = int(_list("region")[idx])
			var right: String = str(C[i2][4])
			var wrong: Array = []
			for r in Rng.shuffled(REGIONS.keys(), rng):
				if str(r) != right and wrong.size() < 2:
					wrong.append(str(r))
			return {"q": ["%s is in which continent?" % _c_en(i2), "%s کس براعظم میں ہے؟" % _c_ur(i2), "في أي قارة تقع %s؟" % _c_ar(i2)],
				"a": [REGIONS[right], REGIONS[wrong[0]], REGIONS[wrong[1]]]}
		"neighbor":
			var pr: Array = _list("pairs")[idx]
			var a: int = int(pr[0])
			var b: int = int(pr[1])
			var not_near: Array = []
			for k in C.size():
				if k != a and not (C[a][7] as Array).has(str(C[k][0])):
					not_near.append(k)
			var o2: Array = _pick2(_same_region(a, not_near, []), [], rng)
			if o2.is_empty():
				return {}
			return {"q": ["Which of these countries shares a land border with %s?" % _c_en(a), "ان میں سے کس ملک کی سرحد %s سے ملتی ہے؟" % _c_ur(a), "أي هذه الدول لها حدود برية مع %s؟" % _c_ar(a)],
				"a": [_country(b), _country(o2[0]), _country(o2[1])]}
		"landlocked":
			var i3: int = int(_list("landlocked")[idx])
			var o3: Array = _pick2(_same_region(i3, _list("coastal"), []), [], rng)
			if o3.is_empty():
				return {}
			return {"q": ["Which of these countries has no sea coast (landlocked)?", "ان میں سے کس ملک کا کوئی سمندری ساحل نہیں (چاروں طرف خشکی)؟", "أي هذه الدول ليس لها ساحل بحري؟"],
				"a": [_country(i3), _country(o3[0]), _country(o3[1])]}
		"largest3", "smallest3":
			var t: Array = unrank3(idx)
			var pick: Array = _extreme(t, func(k: int) -> float: return float(C[k][5]), tpl == "largest3", AREA_GAP)
			if pick.is_empty():
				return {}
			var q: Array = ["Which of these countries is the largest by area?", "رقبے کے لحاظ سے ان میں سب سے بڑا ملک کون سا ہے؟", "أي هذه الدول أكبر مساحة؟"]
			if tpl == "smallest3":
				q = ["Which of these countries is the smallest by area?", "رقبے کے لحاظ سے ان میں سب سے چھوٹا ملک کون سا ہے؟", "أي هذه الدول أصغر مساحة؟"]
			return {"q": q, "a": [_country(pick[0]), _country(pick[1]), _country(pick[2])]}
	return {}


# ------------------------------------------------------------------ helpers

## Cached index lists built from CountryData.
static func _list(key: String) -> Array:
	if _lists.is_empty():
		var caps: Array = []
		var regs: Array = []
		var pairs: Array = []
		var land: Array = []
		var coast: Array = []
		var code_to_i: Dictionary = {}
		for i in World.COUNTRIES.size():
			code_to_i[str(World.COUNTRIES[i][0])] = i
		for i in World.COUNTRIES.size():
			var row: Array = World.COUNTRIES[i]
			if str(row[3]) != "":
				caps.append(i)
			if str(row[4]) != "":
				regs.append(i)
			if bool(row[6]):
				land.append(i)
			else:
				coast.append(i)
			for code in row[7]:
				if code_to_i.has(str(code)):
					pairs.append([i, int(code_to_i[str(code)])])
		_lists = {"capital": caps, "region": regs, "pairs": pairs, "landlocked": land, "coastal": coast}
	return _lists[key]


## Countries from `pool` in the same region as `i` (falls back to the whole pool).
static func _same_region(i: int, pool: Array, _unused: Array) -> Array:
	var reg: String = str(World.COUNTRIES[i][4])
	var out: Array = []
	if reg != "":
		for k in pool:
			if int(k) != i and str(World.COUNTRIES[int(k)][4]) == reg:
				out.append(int(k))
	if out.size() < 2:
		out = []
		for k in pool:
			if int(k) != i:
				out.append(int(k))
	return out


static func _pick2(pool: Array, exclude: Array, rng: RandomNumberGenerator) -> Array:
	var cands: Array = []
	for k in pool:
		if not exclude.has(int(k)):
			cands.append(int(k))
	if cands.size() < 2:
		return []
	var a: int = rng.randi_range(0, cands.size() - 1)
	var b: int = rng.randi_range(0, cands.size() - 2)
	if b >= a:
		b += 1
	return [cands[a], cands[b]]


## Two different numbers in 0..n-1, not in `exclude`.
static func _others(n: int, exclude: Array, rng: RandomNumberGenerator) -> Array:
	var pool: Array = []
	for k in n:
		if not exclude.has(k):
			pool.append(k)
	return _pick2(pool, [], rng)


## Two wrong numbers near `right`, inside lo..hi, different from it and each other.
static func _near(right: int, lo: int, hi: int, spread: int, rng: RandomNumberGenerator) -> Array:
	var cands: Array = []
	for d in range(-spread, spread + 1):
		var v: int = right + d
		if d != 0 and v >= lo and v <= hi:
			cands.append(v)
	return _pick2(cands, [], rng)


## [winner, other, other] when one value is clearly the highest (or lowest), else [].
static func _extreme(items: Array, value: Callable, highest: bool, gap: float) -> Array:
	var sorted_items: Array = items.duplicate()
	sorted_items.sort_custom(func(x: int, y: int) -> bool:
		return value.call(x) > value.call(y) if highest else value.call(x) < value.call(y))
	var best: float = value.call(sorted_items[0])
	var second: float = value.call(sorted_items[1])
	if highest and best < second * gap or best == second:
		return []
	if not highest and best * gap > second:
		return []
	return sorted_items


static func _c3(n: int) -> int:
	return n * (n - 1) * (n - 2) / 6


static func _c2(n: int) -> int:
	return n * (n - 1) / 2


## idx -> [a, b, c] with a < b < c (combinatorial number system).
static func unrank3(idx: int) -> Array:
	var c3: int = 2
	while _c3(c3 + 1) <= idx:
		c3 += 1
	var rest: int = idx - _c3(c3)
	var c2: int = 1
	while _c2(c2 + 1) <= rest:
		c2 += 1
	return [rest - _c2(c2), c2, c3]
