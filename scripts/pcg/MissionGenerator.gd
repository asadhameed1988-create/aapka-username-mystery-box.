extends RefCounted
## Builds a full mission (one mystery box = 1..3 puzzle stages + visual variation).
## Pure logic: no autoloads, no scene tree. Runs in the game, in headless tests,
## and later on the server worker (Godot headless) with the same code.
##
## To add a new puzzle type: write XxxGenerator.gd with
## generate(seed, difficulty), validate(spec), score(spec) and register it below.

const Rng = preload("res://scripts/pcg/Rng.gd")
const Schema = preload("res://scripts/pcg/Schema.gd")
const Rings = preload("res://scripts/pcg/RingsGenerator.gd")
const Combo = preload("res://scripts/pcg/ComboGenerator.gd")
const Latch = preload("res://scripts/pcg/LatchGenerator.gd")
const Seq = preload("res://scripts/pcg/SeqGenerator.gd")
const Pattern = preload("res://scripts/pcg/PatternGenerator.gd")
const Lights = preload("res://scripts/pcg/LightsGenerator.gd")
const Maze = preload("res://scripts/pcg/MazeGenerator.gd")
const Circuit = preload("res://scripts/pcg/CircuitGenerator.gd")
const SlideGen = preload("res://scripts/pcg/SliderGenerator.gd")
const GearGen = preload("res://scripts/pcg/GearGenerator.gd")
const ColourGen = preload("res://scripts/pcg/ColourGenerator.gd")
const CipherGen = preload("res://scripts/pcg/CipherGenerator.gd")
const MirrorGen = preload("res://scripts/pcg/MirrorGenerator.gd")
const QuizGen = preload("res://scripts/pcg/QuizGenerator.gd")
const MathGen = preload("res://scripts/pcg/MathGenerator.gd")

const VERSION := 5
const GENERATORS := {
	"rings": Rings, "combo": Combo, "latch": Latch,
	"seq": Seq, "pattern": Pattern, "lights": Lights,
	"maze": Maze, "circuit": Circuit, "slider": SlideGen,
	"gears": GearGen, "colours": ColourGen, "cipher": CipherGen, "mirrors": MirrorGen,
	"quiz": QuizGen, "math": MathGen,
}
## Mechanical locks used in "puzzles" mode. "quiz" mode (the default) uses questions.
const MECHANICAL := ["rings", "combo", "latch", "seq", "pattern", "lights", "maze",
	"circuit", "slider", "gears", "colours", "cipher", "mirrors"]
const MODES := ["quiz", "puzzles"]
const STAGES := {1: 1, 2: 2, 3: 2, 4: 3, 5: 3}

# Approved reusable visual components (no new picture needed per round).
const MATERIALS := ["walnut_inlay", "brass_engraved", "ebony_pearl", "gold_damascene", "cedar_copper"]
const BACKDROPS := ["house_of_wisdom", "damascus_workshop", "cordoba_library", "cairo_bazaar", "samarkand_observatory"]
const LIGHTS := ["lantern_warm", "moonlit_cool", "dawn_gold"]


static func generate_mission(seed_value: int, difficulty: int, recent_types: Array = [], mode: String = "quiz", avoid: Array = []) -> Dictionary:
	var level: int = clampi(difficulty, 1, 5)
	var rng: RandomNumberGenerator = Rng.make(seed_value)
	if mode != "puzzles":
		return _quiz_mission(seed_value, level, rng, avoid)
	var stage_count: int = STAGES[level]
	var stages: Array = []
	var used: Array = []
	var valid: bool = true
	var sigs: Array = []
	for s in stage_count:
		var type_name: String = _pick_type(rng, used, recent_types)
		used.append(type_name)
		var stage_level: int = level
		if s < stage_count - 1:
			stage_level = maxi(1, level - 1)
		var spec: Dictionary = GENERATORS[type_name].generate(Rng.derive(seed_value, s + 1, 17), stage_level)
		if not bool(spec.get("valid", false)):
			valid = false
		sigs.append(str(spec.get("signature", "")))
		stages.append(spec)
	return {
		"id": "mb-%d-%d-%d" % [VERSION, level, seed_value],
		"generator_version": VERSION,
		"seed": seed_value,
		"difficulty": level,
		"stages": stages,
		"types": used,
		"visual": {
			"material": Rng.pick(MATERIALS, rng),
			"backdrop": Rng.pick(BACKDROPS, rng),
			"light": Rng.pick(LIGHTS, rng),
		},
		"signature": "|".join(PackedStringArray(sigs)).md5_text(),
		"valid": valid,
	}


## Question box: one Islamic question, one easy sum and one general-knowledge question,
## in a random order. All three must be answered to open the box.
static func _quiz_mission(seed_value: int, level: int, rng: RandomNumberGenerator, avoid: Array) -> Dictionary:
	var kinds: Array = Rng.shuffled(["islam", "math", "gk"], rng)
	var stages: Array = []
	var sigs: Array = []
	var used: Array = []
	var valid: bool = true
	for s in kinds.size():
		var sub_seed: int = Rng.derive(seed_value, s + 1, 23)
		var spec: Dictionary
		if str(kinds[s]) == "math":
			spec = MathGen.generate(sub_seed, level)
		else:
			spec = QuizGen.generate(sub_seed, level, str(kinds[s]), avoid)
		if not bool(spec.get("valid", false)):
			valid = false
		used.append(str(spec["type"]))
		sigs.append(str(spec.get("signature", "")))
		stages.append(spec)
	return {
		"id": "mb-%d-q%d-%d" % [VERSION, level, seed_value],
		"generator_version": VERSION,
		"seed": seed_value,
		"difficulty": level,
		"mode": "quiz",
		"stages": stages,
		"types": used,
		"visual": {
			"material": Rng.pick(MATERIALS, rng),
			"backdrop": Rng.pick(BACKDROPS, rng),
			"light": Rng.pick(LIGHTS, rng),
		},
		"signature": "|".join(PackedStringArray(sigs)).md5_text(),
		"valid": valid,
	}


## Question keys ("islam:4") asked in a mission, so the next boxes can avoid them.
static func question_keys(mission: Dictionary) -> Array:
	var out: Array = []
	for st in mission.get("stages", []):
		if str(st.get("type", "")) == "quiz":
			out.append("%s:%d" % [str(st["params"]["cat"]), int(st["params"]["qid"])])
	return out


## Re-validates a mission that came from disk or the network: first its shape (Schema),
## then every stage with its own validator. Never trusts the data.
static func validate_mission(mission) -> Dictionary:
	var shape: String = Schema.check_mission(mission)
	if shape != "":
		return {"ok": false, "reason": shape}
	for st in mission["stages"]:
		var stage_shape: String = Schema.check_stage(st)
		if stage_shape != "":
			return {"ok": false, "reason": stage_shape}
		var type_name: String = str(st["type"])
		if not GENERATORS.has(type_name):
			return {"ok": false, "reason": "unknown_type:" + type_name}
		var res: Dictionary = GENERATORS[type_name].validate(st)
		if not bool(res["ok"]):
			return {"ok": false, "reason": type_name + ":" + str(res["reason"])}
		# The stored solution record must match what the validator worked out.
		if (res["solution"] as Array).size() != (st["solution"] as Array).size():
			return {"ok": false, "reason": type_name + ":solution_record_mismatch"}
	return {"ok": true, "reason": ""}


## Diversity: types used recently (or already in this box) are less likely.
static func _pick_type(rng: RandomNumberGenerator, used: Array, recent_types: Array) -> String:
	var names: Array = []
	for key in MECHANICAL:
		if not used.has(key):
			names.append(key)
	if names.is_empty():
		names = MECHANICAL.duplicate()
	var weights: Array = []
	var total: float = 0.0
	var tail: Array = recent_types.slice(maxi(0, recent_types.size() - 4))
	for nm in names:
		var w: float = 1.0 / (1.0 + float(tail.count(nm)) * 1.5)
		weights.append(w)
		total += w
	var roll: float = rng.randf() * total
	for i in names.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return str(names[i])
	return str(names[names.size() - 1])
