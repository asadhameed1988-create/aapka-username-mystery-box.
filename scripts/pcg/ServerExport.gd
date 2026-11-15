extends RefCounted
## Used by the server worker (tools/server_generate.gd): builds missions for a
## list of seeds and re-validates each one after a JSON round trip, exactly as
## a phone would receive it.

const MissionGen = preload("res://scripts/pcg/MissionGenerator.gd")


static func build(seeds: Array, difficulty: int) -> Array:
	var out: Array = []
	for s in seeds:
		var mission: Dictionary = MissionGen.generate_mission(int(s), difficulty)
		var parsed = JSON.parse_string(JSON.stringify(mission))
		var check: Dictionary = {"ok": false, "reason": "not_a_dictionary"}
		if typeof(parsed) == TYPE_DICTIONARY:
			check = MissionGen.validate_mission(parsed)
		mission["server_check"] = {"ok": bool(mission["valid"]) and bool(check["ok"]), "reason": str(check["reason"])}
		out.append(mission)
	return out
