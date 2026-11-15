extends VBoxContainer
## Interaction for the DIAL COMBINATION LOCK puzzle (placeholder visuals).

signal solved

const Combo = preload("res://scripts/pcg/ComboGenerator.gd")
const Ui = preload("res://scripts/ui/UiKit.gd")

var _params: Dictionary = {}
var _solution: Array = []
var _base: int = 10
var _values: Array = []
var _value_labels: Array = []
var _dial_buttons: Array = []
var _locked: Array = []
var _feedback: Label
var _done: bool = false


func setup(spec: Dictionary) -> void:
	_params = spec["params"]
	_solution = spec["solution"]
	_base = int(_params["base"])
	var digits: int = int(_params["digits"])
	add_theme_constant_override("separation", 12)
	add_child(Ui.label(Loc.t("combo_help", [_base - 1]), 30, Ui.MUTED))
	for clue in _params["clues"]:
		add_child(Ui.label(clue_text(clue), 36, Ui.TEXT))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for i in digits:
		_values.append(0)
		_locked.append(false)
		var col: VBoxContainer = VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		var name_label: Label = Ui.label(Loc.t("dial", [i + 1]), 26, Ui.MUTED)
		var up: Button = Ui.button("+")
		up.custom_minimum_size = Vector2(150, 96)
		var val: Label = Ui.label("0", 84, Ui.GOLD)
		var down: Button = Ui.button("-")
		down.custom_minimum_size = Vector2(150, 96)
		up.pressed.connect(_step.bind(i, 1))
		down.pressed.connect(_step.bind(i, -1))
		col.add_child(name_label)
		col.add_child(up)
		col.add_child(val)
		col.add_child(down)
		row.add_child(col)
		_value_labels.append(val)
		_dial_buttons.append([up, down])
	add_child(row)
	var unlock: Button = Ui.button(Loc.t("unlock"))
	unlock.pressed.connect(_try_unlock)
	add_child(unlock)
	_feedback = Ui.label("", 32, Ui.BAD)
	add_child(_feedback)


func clue_text(clue: Dictionary) -> String:
	var k: String = str(clue["k"])
	var i: int = int(clue.get("i", 0)) + 1
	var j: int = int(clue.get("j", 0)) + 1
	var v: int = int(clue.get("v", 0))
	if k == "sum":
		return Loc.t("clue_sum", [v])
	if k == "parity":
		if v == 1:
			return Loc.t("clue_odd", [i])
		return Loc.t("clue_even", [i])
	if k == "gt":
		return Loc.t("clue_gt", [i, j])
	if k == "diff":
		return Loc.t("clue_diff", [i, j, v])
	if k == "sum2":
		return Loc.t("clue_sum2", [i, j, v])
	return Loc.t("clue_exact", [i, v])


func _step(index: int, dir: int) -> void:
	if _done or bool(_locked[index]):
		return
	_values[index] = posmod(int(_values[index]) + dir, _base)
	(_value_labels[index] as Label).text = str(_values[index])
	Fx.play("turn")
	_feedback.text = ""


func _try_unlock() -> void:
	if _done:
		return
	var clues: Array = _params["clues"]
	if Combo.check_all(clues, _values) and _matches_solution():
		_done = true
		_feedback.add_theme_color_override("font_color", Ui.GOOD)
		_feedback.text = Loc.t("stage_clear")
		await get_tree().create_timer(0.45).timeout
		solved.emit()
		return
	var ok: int = 0
	for clue in clues:
		if Combo.check_clue(clue, _values):
			ok += 1
	Fx.play("wrong")
	_feedback.text = Loc.t("combo_wrong", [ok, clues.size()])


func _matches_solution() -> bool:
	for i in _values.size():
		if int(_values[i]) != int(_solution[i]):
			return false
	return true


## Sets one more dial to its correct value and locks it.
func hint() -> String:
	for i in _values.size():
		if not bool(_locked[i]):
			_values[i] = int(_solution[i])
			_locked[i] = true
			var lbl: Label = _value_labels[i]
			lbl.text = str(_values[i])
			lbl.add_theme_color_override("font_color", Ui.GOOD)
			for b in _dial_buttons[i]:
				(b as Button).disabled = true
			return Loc.t("combo_hint", [i + 1])
	return ""
