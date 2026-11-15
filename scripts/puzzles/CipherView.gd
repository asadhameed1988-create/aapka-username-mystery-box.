extends VBoxContainer
## Interaction for the SYMBOL DECODING lock.

signal solved

const CipherGen = preload("res://scripts/pcg/CipherGenerator.gd")
const SymbolIcon = preload("res://scripts/ui/SymbolIcon.gd")
const Ui = preload("res://scripts/ui/UiKit.gd")

var mistakes: int = 0   # read by Game.gd; wrong attempts count like hints

var _params: Dictionary = {}
var _symbols: Array = []
var _solution: Array = []
var _top: int = 9
var _values: Array = []
var _value_labels: Array = []
var _dial_buttons: Array = []
var _locked: Array = []
var _feedback: Label
var _done: bool = false


func setup(spec: Dictionary) -> void:
	_params = spec["params"]
	_symbols = _params["symbols"]
	_solution = spec["solution"]
	_top = int(_params["range"])
	add_theme_constant_override("separation", 8)
	add_child(Ui.label(Loc.t("cipher_help", [_top]), 30, Ui.MUTED))
	for clue in _params["clues"]:
		add_child(_clue_row(clue))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for i in _symbols.size():
		_values.append(1)
		_locked.append(false)
		var col: VBoxContainer = VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		var holder: CenterContainer = CenterContainer.new()
		holder.add_child(_icon(i))
		var up: Button = Ui.button("+")
		up.custom_minimum_size = Vector2(150, 90)
		var val: Label = Ui.label("1", 76, Ui.GOLD)
		var down: Button = Ui.button("-")
		down.custom_minimum_size = Vector2(150, 90)
		up.pressed.connect(_step.bind(i, 1))
		down.pressed.connect(_step.bind(i, -1))
		col.add_child(holder)
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


func _icon(index: int) -> Control:
	var icon = SymbolIcon.new()
	icon.symbol_id = int(_symbols[index])
	return icon


func _text(value: String) -> Label:
	var l: Label = Ui.label(value, 44, Ui.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return l


func _clue_row(clue: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var k: String = str(clue["k"])
	var v: int = int(clue.get("v", 0))
	if k == "sum":
		row.add_child(_text(Loc.t("cipher_total", [v])))
		return row
	row.add_child(_icon(int(clue["i"])))
	if k == "sum2":
		row.add_child(_text("+"))
		row.add_child(_icon(int(clue["j"])))
	elif k == "diff":
		row.add_child(_text("-"))
		row.add_child(_icon(int(clue["j"])))
	row.add_child(_text("=  " + str(v)))
	return row


func _step(index: int, dir: int) -> void:
	if _done or bool(_locked[index]):
		return
	_values[index] = posmod(int(_values[index]) - 1 + dir, _top) + 1
	(_value_labels[index] as Label).text = str(_values[index])
	Fx.play("turn")
	_feedback.text = ""


func _try_unlock() -> void:
	if _done:
		return
	var same: bool = true
	for i in _values.size():
		if int(_values[i]) != int(_solution[i]):
			same = false
	if same:
		_done = true
		_feedback.add_theme_color_override("font_color", Ui.GOOD)
		_feedback.text = Loc.t("stage_clear")
		await get_tree().create_timer(0.45).timeout
		solved.emit()
		return
	mistakes += 1
	Fx.play("wrong")
	var clues: Array = _params["clues"]
	var ok: int = 0
	for clue in clues:
		if CipherGen.check_clue(clue, _values):
			ok += 1
	_feedback.text = Loc.t("combo_wrong", [ok, clues.size()])


## Sets one more symbol to its number and locks it.
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
			return Loc.t("cipher_hint", [i + 1])
	return ""
