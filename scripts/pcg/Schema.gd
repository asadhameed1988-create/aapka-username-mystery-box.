extends RefCounted
## Shape check for puzzle data that came from disk or from the network.
## The validators assume well-formed data; this guard runs first so that a damaged
## save file or a bad server response is rejected cleanly instead of breaking the game.

const MAX_ITEMS := 4096
const MAX_ABS := 1000000000.0

## kinds: int | bool | str | ints | int_rows | int_rows:N (rows of exactly N) |
##        int_rows3:N (rows of rows of exactly N) | dicts
const SPECS := {
	"rings": {"params": {"rings": "int", "positions": "int", "symbols": "int_rows", "links": "int_rows:3", "start": "ints"}, "solution": "int_rows:2"},
	"combo": {"params": {"digits": "int", "base": "int", "clues": "dicts"}, "solution": "ints"},
	"latch": {"params": {"count": "int", "symbols": "ints", "deps": "int_rows", "reset_on_error": "bool"}, "solution": "ints"},
	"seq": {"params": {"shown": "ints", "options": "ints", "rule": "str", "args": "ints"}, "solution": "ints"},
	"pattern": {"params": {"shown": "ints", "options": "ints", "period": "int"}, "solution": "ints"},
	"lights": {"params": {"count": "int", "toggles": "int_rows", "start": "ints"}, "solution": "ints"},
	"maze": {"params": {"w": "int", "h": "int", "cells": "ints", "start": "int", "exit": "int", "key": "int"}, "solution": "ints"},
	"circuit": {"params": {"w": "int", "h": "int", "tiles": "ints", "source": "int"}, "solution": "ints"},
	"slider": {"params": {"w": "int", "h": "int", "start": "ints"}, "solution": "ints"},
	"gears": {"params": {"teeth": "ints", "cranks": "int_rows3:2", "start": "ints"}, "solution": "int_rows:2"},
	"colours": {"params": {"slots": "int", "colours": "int", "clues": "dicts"}, "solution": "ints"},
	"cipher": {"params": {"symbols": "ints", "range": "int", "clues": "dicts"}, "solution": "ints"},
	"quiz": {"params": {"cat": "str", "tpl": "str", "idx": "int", "order": "ints"}, "solution": "ints"},
	"math": {"params": {"kind": "str", "nums": "ints", "options": "ints"}, "solution": "ints"},
	"mirrors": {"params": {"w": "int", "h": "int", "entry_row": "int", "mirrors": "int_rows:2", "target": "int"}, "solution": "ints"},
}


static func is_int(v) -> bool:
	var t: int = typeof(v)
	if t == TYPE_INT:
		return absf(float(v)) <= MAX_ABS
	if t == TYPE_FLOAT:
		return v == floorf(v) and absf(v) <= MAX_ABS
	return false


static func is_ints(v, exact: int = -1) -> bool:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() > MAX_ITEMS:
		return false
	if exact >= 0 and (v as Array).size() != exact:
		return false
	for item in v:
		if not is_int(item):
			return false
	return true


static func is_rows(v, exact: int = -1) -> bool:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() > MAX_ITEMS:
		return false
	for row in v:
		if not is_ints(row, exact):
			return false
	return true


static func is_kind(v, kind: String) -> bool:
	if kind == "int":
		return is_int(v)
	if kind == "bool":
		return typeof(v) == TYPE_BOOL
	if kind == "str":
		return typeof(v) == TYPE_STRING and (v as String).length() <= 64
	if kind == "ints":
		return is_ints(v)
	if kind == "int_rows":
		return is_rows(v)
	if kind.begins_with("int_rows:"):
		return is_rows(v, int(kind.get_slice(":", 1)))
	if kind.begins_with("int_rows3:"):
		if typeof(v) != TYPE_ARRAY or (v as Array).size() > MAX_ITEMS:
			return false
		for group in v:
			if not is_rows(group, int(kind.get_slice(":", 1))):
				return false
		return true
	if kind == "dicts":
		if typeof(v) != TYPE_ARRAY or (v as Array).size() > 64:
			return false
		for d in v:
			if typeof(d) != TYPE_DICTIONARY:
				return false
			for key in (d as Dictionary).keys():
				var item = d[key]
				if typeof(key) != TYPE_STRING:
					return false
				if not (is_int(item) or is_ints(item) or (typeof(item) == TYPE_STRING and (item as String).length() <= 16)):
					return false
		return true
	return false


## Returns "" when one puzzle stage has the right shape, otherwise a short reason.
static func check_stage(spec) -> String:
	if typeof(spec) != TYPE_DICTIONARY:
		return "stage_not_a_dictionary"
	var type_name = spec.get("type")
	if typeof(type_name) != TYPE_STRING or not SPECS.has(type_name):
		return "unknown_type"
	if not is_int(spec.get("difficulty", 1)):
		return "bad_difficulty"
	var params = spec.get("params")
	if typeof(params) != TYPE_DICTIONARY:
		return "bad_params"
	var wanted: Dictionary = SPECS[type_name]["params"]
	for key in wanted.keys():
		if not (params as Dictionary).has(key) or not is_kind(params[key], str(wanted[key])):
			return "bad_" + str(key)
	if not is_kind(spec.get("solution"), str(SPECS[type_name]["solution"])):
		return "bad_solution_shape"
	return ""


## Returns "" when the mission wrapper has the right shape, otherwise a short reason.
static func check_mission(mission) -> String:
	if typeof(mission) != TYPE_DICTIONARY:
		return "mission_not_a_dictionary"
	var stages = mission.get("stages")
	if typeof(stages) != TYPE_ARRAY or (stages as Array).is_empty() or (stages as Array).size() > 3:
		return "bad_stages"
	if mission.has("difficulty") and (not is_int(mission["difficulty"]) or int(mission["difficulty"]) < 1 or int(mission["difficulty"]) > 5):
		return "bad_difficulty"
	if mission.has("signature") and typeof(mission["signature"]) != TYPE_STRING:
		return "bad_signature"
	if mission.has("visual"):
		if typeof(mission["visual"]) != TYPE_DICTIONARY:
			return "bad_visual"
		for value in (mission["visual"] as Dictionary).values():
			if typeof(value) != TYPE_STRING:
				return "bad_visual"
	if mission.has("types"):
		if typeof(mission["types"]) != TYPE_ARRAY:
			return "bad_types"
		for t in mission["types"]:
			if typeof(t) != TYPE_STRING:
				return "bad_types"
	return ""
