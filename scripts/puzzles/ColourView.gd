extends VBoxContainer
## Interaction for the COLOUR CODE lock.

signal solved

const ColourGen = preload("res://scripts/pcg/ColourGenerator.gd")
const SymbolIcon = preload("res://scripts/ui/SymbolIcon.gd")
const Ui = preload("res://scripts/ui/UiKit.gd")


class GemButton:
	extends Button
	const P = preload("res://scripts/ui/SymbolPainter.gd")
	var symbol_id: int = 0

	func _draw() -> void:
		P.draw_symbol(self, symbol_id, size * 0.5, minf(size.x, size.y) * 0.28)


var mistakes: int = 0   # read by Game.gd; wrong attempts count like hints

var _solution: Array = []
var _colours: int = 0
var _values: Array = []
var _buttons: Array = []
var _locked: Array = []
var _feedback: Label
var _done: bool = false


func setup(spec: Dictionary) -> void:
	var params: Dictionary = spec["params"]
	_solution = spec["solution"]
	_colours = int(params["colours"])
	var slots: int = int(params["slots"])
	add_theme_constant_override("separation", 10)
	add_child(Ui.label(Loc.t("colours_help", [_colours]), 30, Ui.MUTED))
	for clue in params["clues"]:
		var row: HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		for v in clue["g"]:
			var icon = SymbolIcon.new()
			icon.symbol_id = int(v)
			row.add_child(icon)
		var info: Label = Ui.label(Loc.t("colours_clue", [int(clue["e"]), int(clue["m"])]), 30, Ui.TEXT)
		info.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		info.custom_minimum_size = Vector2(430, 0)
		row.add_child(info)
		add_child(row)
	var play: HBoxContainer = HBoxContainer.new()
	play.alignment = BoxContainer.ALIGNMENT_CENTER
	play.add_theme_constant_override("separation", 14)
	for i in slots:
		_values.append(0)
		_locked.append(false)
		var b: GemButton = GemButton.new()
		b.custom_minimum_size = Vector2(190, 190)
		b.pressed.connect(_cycle.bind(i))
		play.add_child(b)
		_buttons.append(b)
	add_child(play)
	var unlock: Button = Ui.button(Loc.t("unlock"))
	unlock.pressed.connect(_try_unlock)
	add_child(unlock)
	_feedback = Ui.label("", 32, Ui.BAD)
	add_child(_feedback)


func _cycle(index: int) -> void:
	if _done or bool(_locked[index]):
		return
	_values[index] = (int(_values[index]) + 1) % _colours
	var b: GemButton = _buttons[index]
	b.symbol_id = int(_values[index])
	b.queue_redraw()
	Fx.play("turn")
	_feedback.text = ""


func _try_unlock() -> void:
	if _done:
		return
	var fb: Array = ColourGen.feedback(_solution, _values)
	if int(fb[0]) == _solution.size():
		_done = true
		_feedback.add_theme_color_override("font_color", Ui.GOOD)
		_feedback.text = Loc.t("stage_clear")
		await get_tree().create_timer(0.45).timeout
		solved.emit()
		return
	mistakes += 1
	Fx.play("wrong")
	_feedback.text = Loc.t("colours_clue", [int(fb[0]), int(fb[1])])


## Sets one more gem to its correct colour and locks it.
func hint() -> String:
	for i in _values.size():
		if not bool(_locked[i]):
			_values[i] = int(_solution[i])
			_locked[i] = true
			var b: GemButton = _buttons[i]
			b.symbol_id = int(_values[i])
			b.disabled = true
			b.queue_redraw()
			return Loc.t("colours_hint", [i + 1])
	return ""
