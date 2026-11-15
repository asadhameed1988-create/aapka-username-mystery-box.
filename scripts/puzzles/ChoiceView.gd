extends VBoxContainer
## Shared screen for "what comes next?" locks:
## NUMBER SEQUENCE (type "seq") and SYMBOL PATTERN (type "pattern"). Placeholder visuals.

signal solved

const Ui = preload("res://scripts/ui/UiKit.gd")
const Painter = preload("res://scripts/ui/SymbolPainter.gd")

const PER_ROW := 7


class SymbolButton:
	extends Button
	const P = preload("res://scripts/ui/SymbolPainter.gd")
	var symbol_id: int = 0

	func _draw() -> void:
		var r: float = minf(size.x, size.y) * 0.28
		if disabled:
			r *= 0.6
		P.draw_symbol(self, symbol_id, size * 0.5, r)


var mistakes: int = 0   # read by Game.gd; wrong picks count like hints

var _is_pattern: bool = false
var _shown: Array = []
var _options: Array = []
var _answer_index: int = 0
var _buttons: Array = []
var _canvas: Control
var _feedback: Label
var _done: bool = false


func setup(spec: Dictionary) -> void:
	var params: Dictionary = spec["params"]
	_is_pattern = str(spec["type"]) == "pattern"
	_shown = params["shown"]
	_options = params["options"]
	_answer_index = int((spec["solution"] as Array)[0])
	add_theme_constant_override("separation", 18)
	if _is_pattern:
		add_child(Ui.label(Loc.t("pattern_help"), 30, Ui.MUTED))
		_canvas = Control.new()
		var rows: int = int((_shown.size() + PER_ROW) / PER_ROW)
		_canvas.custom_minimum_size = Vector2(0, 150 * rows)
		_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_canvas.draw.connect(_draw_pattern)
		add_child(_canvas)
	else:
		add_child(Ui.label(Loc.t("seq_help"), 30, Ui.MUTED))
		var parts: PackedStringArray = PackedStringArray()
		for v in _shown:
			parts.append(str(int(v)))
		parts.append("?")
		add_child(Ui.label("   ".join(parts), 72, Ui.GOLD))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for i in _options.size():
		var b: Button
		if _is_pattern:
			var sb: SymbolButton = SymbolButton.new()
			sb.symbol_id = int(_options[i])
			b = sb
		else:
			b = Button.new()
			b.text = str(int(_options[i]))
			b.add_theme_font_size_override("font_size", 56)
		b.custom_minimum_size = Vector2(220, 200)
		b.pressed.connect(_choose.bind(i))
		row.add_child(b)
		_buttons.append(b)
	add_child(row)
	_feedback = Ui.label("", 32, Ui.BAD)
	add_child(_feedback)


func _draw_pattern() -> void:
	var cell: float = minf(_canvas.size.x / float(PER_ROW), 140.0)
	var total: int = _shown.size() + 1
	for i in total:
		var col: int = i % PER_ROW
		var row: int = int(i / PER_ROW)
		var in_row: int = mini(PER_ROW, total - row * PER_ROW)
		var x0: float = (_canvas.size.x - cell * float(in_row)) * 0.5
		var pos: Vector2 = Vector2(x0 + cell * (float(col) + 0.5), 75.0 + 150.0 * float(row))
		_canvas.draw_circle(pos, cell * 0.44, Ui.PANEL)
		if i < _shown.size():
			Painter.draw_symbol(_canvas, int(_shown[i]), pos, cell * 0.28)
		else:
			_canvas.draw_arc(pos, cell * 0.44, 0.0, TAU, 40, Ui.GOLD, 5.0, true)
			_canvas.draw_circle(pos + Vector2(0.0, cell * 0.2), 6.0, Ui.GOLD)
			_canvas.draw_arc(pos - Vector2(0.0, cell * 0.08), cell * 0.14, -PI, PI * 0.5, 16, Ui.GOLD, 6.0)


func _choose(index: int) -> void:
	if _done:
		return
	if index == _answer_index:
		_done = true
		_feedback.add_theme_color_override("font_color", Ui.GOOD)
		_feedback.text = Loc.t("stage_clear")
		await get_tree().create_timer(0.45).timeout
		solved.emit()
		return
	mistakes += 1
	Fx.play("wrong")
	(_buttons[index] as Button).disabled = true
	_feedback.text = Loc.t("choice_wrong")


## Removes one wrong option.
func hint() -> String:
	for i in _buttons.size():
		var b: Button = _buttons[i]
		if i != _answer_index and not b.disabled:
			b.disabled = true
			b.queue_redraw()
			return Loc.t("choice_hint")
	return ""
