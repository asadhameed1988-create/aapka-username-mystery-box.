extends VBoxContainer
## Interaction for the SEALED LATCHES puzzle (placeholder visuals).

signal solved

const Ui = preload("res://scripts/ui/UiKit.gd")


class LatchButton:
	extends Button
	const P = preload("res://scripts/ui/SymbolPainter.gd")
	const U = preload("res://scripts/ui/UiKit.gd")
	var symbol_id: int = 0
	var needs: Array = []
	var opened: bool = false
	var glow: bool = false

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if glow:
			draw_rect(Rect2(6.0, 6.0, w - 12.0, h - 12.0), U.GOLD, false, 8.0)
		if opened:
			draw_rect(Rect2(10.0, 10.0, w - 20.0, h - 20.0), Color(U.GOOD.r, U.GOOD.g, U.GOOD.b, 0.25))
		P.draw_symbol(self, symbol_id, Vector2(w * 0.5, h * 0.40), minf(w, h) * 0.24)
		var count: int = needs.size()
		for k in count:
			var x: float = w * 0.5 + (float(k) - float(count - 1) * 0.5) * 64.0
			var pos: Vector2 = Vector2(x, h * 0.82)
			draw_circle(pos, 26.0, Color(0.05, 0.07, 0.09))
			P.draw_symbol(self, int(needs[k]), pos, 16.0)


var _params: Dictionary = {}
var _n: int = 0
var _deps: Array = []
var _symbols: Array = []
var _reset: bool = false
var _opened: Array = []
var _buttons: Array = []
var _feedback: Label
var _done: bool = false


func setup(spec: Dictionary) -> void:
	_params = spec["params"]
	_n = int(_params["count"])
	_deps = _params["deps"]
	_symbols = _params["symbols"]
	_reset = bool(_params.get("reset_on_error", false))
	add_theme_constant_override("separation", 12)
	add_child(Ui.label(Loc.t("latch_help"), 30, Ui.MUTED))
	if _reset:
		add_child(Ui.label(Loc.t("latch_help_reset"), 30, Ui.BAD))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	if _n > 6:
		grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	for i in _n:
		_opened.append(false)
		var b: LatchButton = LatchButton.new()
		b.custom_minimum_size = Vector2(230, 250)
		b.symbol_id = int(_symbols[i])
		for d in _deps[i]:
			b.needs.append(int(_symbols[int(d)]))
		b.pressed.connect(_press.bind(i))
		grid.add_child(b)
		_buttons.append(b)
	add_child(grid)
	_feedback = Ui.label("", 32, Ui.BAD)
	add_child(_feedback)


func _can_open(index: int) -> bool:
	for d in _deps[index]:
		if not bool(_opened[int(d)]):
			return false
	return true


func _press(index: int) -> void:
	if _done or bool(_opened[index]):
		return
	_clear_glow()
	if _can_open(index):
		_opened[index] = true
		var b: LatchButton = _buttons[index]
		b.opened = true
		Fx.play("turn")
		b.queue_redraw()
		_feedback.text = ""
		if not _opened.has(false):
			_done = true
			await get_tree().create_timer(0.45).timeout
			solved.emit()
		return
	Fx.play("wrong")
	if _reset:
		for i in _n:
			_opened[i] = false
			var other: LatchButton = _buttons[i]
			other.opened = false
			other.queue_redraw()
		_feedback.text = Loc.t("latch_reset")
	else:
		_feedback.text = Loc.t("latch_blocked")


func _clear_glow() -> void:
	for b in _buttons:
		var lb: LatchButton = b
		if lb.glow:
			lb.glow = false
			lb.queue_redraw()


## Highlights a latch that can be opened right now.
func hint() -> String:
	for i in _n:
		if not bool(_opened[i]) and _can_open(i):
			var b: LatchButton = _buttons[i]
			b.glow = true
			b.queue_redraw()
			return Loc.t("latch_hint")
	return ""
