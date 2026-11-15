extends RefCounted
## Batch QA for the generators. Used by tests/batch_test.gd (headless, 10,000+)
## and by the in-game "Generator Test" screen (small run on the phone).

const Rng = preload("res://scripts/pcg/Rng.gd")
const MissionGen = preload("res://scripts/pcg/MissionGenerator.gd")


static func new_report() -> Dictionary:
	return {
		"total": 0, "valid": 0, "invalid": 0, "duplicates": 0,
		"rejected_attempts": 0, "serialization_failures": 0, "nondeterministic": 0,
		"time_usec": 0, "by_type": {}, "by_difficulty": {}, "failures": {},
		"score_min": {}, "score_max": {}, "signatures": {},
		"missions": 0, "missions_valid": 0, "mission_failures": {},
	}


static func test_puzzle(report: Dictionary, index: int) -> void:
	var types: Array = MissionGen.GENERATORS.keys()
	var type_name: String = str(types[index % types.size()])
	var difficulty: int = 1 + int(index / types.size()) % 5
	var gen = MissionGen.GENERATORS[type_name]
	var seed_value: int = Rng.derive(20261112, index, 7)
	var t0: int = Time.get_ticks_usec()
	var spec: Dictionary = gen.generate(seed_value, difficulty)
	report["time_usec"] = int(report["time_usec"]) + Time.get_ticks_usec() - t0
	report["total"] = int(report["total"]) + 1
	report["rejected_attempts"] = int(report["rejected_attempts"]) + int(spec.get("attempts", 1)) - 1
	if not bool(spec.get("valid", false)):
		report["invalid"] = int(report["invalid"]) + 1
		_inc(report["failures"], type_name + ":" + str(spec.get("reason", "?")))
		return
	report["valid"] = int(report["valid"]) + 1
	_inc(report["by_type"], type_name)
	_inc(report["by_difficulty"], str(difficulty))
	var sig: String = str(spec["signature"])
	if (report["signatures"] as Dictionary).has(sig):
		report["duplicates"] = int(report["duplicates"]) + 1
	else:
		report["signatures"][sig] = true
	var sc: float = float(spec["score"])
	var key: String = str(difficulty)
	if not (report["score_min"] as Dictionary).has(key) or sc < float(report["score_min"][key]):
		report["score_min"][key] = sc
	if not (report["score_max"] as Dictionary).has(key) or sc > float(report["score_max"][key]):
		report["score_max"][key] = sc
	# Mission serialization: JSON round trip must still validate.
	var parsed = JSON.parse_string(JSON.stringify(spec))
	if typeof(parsed) != TYPE_DICTIONARY or not bool(gen.validate(parsed)["ok"]):
		report["serialization_failures"] = int(report["serialization_failures"]) + 1
	# Determinism: same seed must give the same puzzle (checked on every 10th).
	if index % 10 == 0:
		var again: Dictionary = gen.generate(seed_value, difficulty)
		if str(again.get("signature", "")) != sig:
			report["nondeterministic"] = int(report["nondeterministic"]) + 1


static func test_mission(report: Dictionary, index: int) -> void:
	var difficulty: int = 1 + index % 5
	var mode: String = "quiz" if index % 2 == 0 else "puzzles"
	var mission: Dictionary = MissionGen.generate_mission(Rng.derive(777, index, 3), difficulty, [], mode)
	report["missions"] = int(report["missions"]) + 1
	var parsed = JSON.parse_string(JSON.stringify(mission))
	var res: Dictionary = {"ok": false, "reason": "not_a_dictionary"}
	if typeof(parsed) == TYPE_DICTIONARY:
		res = MissionGen.validate_mission(parsed)
	if bool(mission["valid"]) and bool(res["ok"]):
		report["missions_valid"] = int(report["missions_valid"]) + 1
	else:
		_inc(report["mission_failures"], str(res["reason"]))


## Corrupts every parameter of a valid puzzle in several ways and validates the result.
## The engine must never break, and whatever is still accepted must be a puzzle the validator
## has fully re-solved (for example a maze whose key was removed is easier, but still fair).
## Returns the list of accepted cases, with a summary line first.
static func tamper_test() -> Array:
	var problems: Array = []
	var checked: int = 0
	var bad_values: Array = [null, -1, 999, [], [[-5]], "x", {}, 1.5, [null], [["a"]]]
	for type_name in MissionGen.GENERATORS.keys():
		var gen = MissionGen.GENERATORS[type_name]
		for level in [1, 3, 5]:
			var spec: Dictionary = gen.generate(Rng.derive(31337, level, 2), level)
			var text: String = JSON.stringify(spec)
			var targets: Array = []
			for key in (spec["params"] as Dictionary).keys():
				targets.append(["params", key])
			targets.append(["", "solution"])
			targets.append(["", "params"])
			for target in targets:
				for bad in bad_values:
					var copy: Dictionary = JSON.parse_string(text)
					var holder: Dictionary = copy
					if str(target[0]) == "params":
						holder = copy["params"]
					if JSON.stringify(holder[target[1]]) == JSON.stringify(bad):
						continue          # same as the original value: not a corruption
					holder[target[1]] = bad
					checked += 1
					var res = MissionGen.validate_mission({"stages": [copy]})
					if typeof(res) != TYPE_DICTIONARY or bool(res.get("ok", false)):
						problems.append("%s L%d %s=%s" % [type_name, level, str(target[1]), str(bad)])
	problems.push_front("checked %d corrupted puzzles" % checked)
	return problems


static func passed(report: Dictionary) -> bool:
	return int(report["invalid"]) == 0 and int(report["serialization_failures"]) == 0 \
		and int(report["nondeterministic"]) == 0 \
		and int(report["missions"]) == int(report["missions_valid"])


static func summary(report: Dictionary) -> String:
	var total: int = int(report["total"])
	var ms: float = float(int(report["time_usec"])) / 1000.0
	var lines: Array = [
		"MYSTERY BOX generator batch test",
		"Total generated: %d" % total,
		"Valid puzzles: %d" % int(report["valid"]),
		"Invalid puzzles: %d" % int(report["invalid"]),
		"Rejected and regenerated attempts: %d" % int(report["rejected_attempts"]),
		"Duplicate configurations: %d" % int(report["duplicates"]),
		"Serialization failures: %d" % int(report["serialization_failures"]),
		"Non-deterministic seeds: %d" % int(report["nondeterministic"]),
		"Generation time: %.1f ms total, %.3f ms each" % [ms, ms / maxf(1.0, float(total))],
		"By type: %s" % JSON.stringify(report["by_type"]),
		"Difficulty distribution: %s" % JSON.stringify(report["by_difficulty"]),
		"Score min per difficulty: %s" % JSON.stringify(report["score_min"]),
		"Score max per difficulty: %s" % JSON.stringify(report["score_max"]),
		"Validation failures: %s" % JSON.stringify(report["failures"]),
		"Missions: %d generated, %d valid" % [int(report["missions"]), int(report["missions_valid"])],
		"Mission failures: %s" % JSON.stringify(report["mission_failures"]),
		"RESULT: %s" % ("PASS" if passed(report) else "FAIL"),
	]
	return "\n".join(PackedStringArray(lines))


static func _inc(d: Dictionary, key: String) -> void:
	d[key] = int(d.get(key, 0)) + 1
