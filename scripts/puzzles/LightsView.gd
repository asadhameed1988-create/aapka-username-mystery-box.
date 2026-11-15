extends VBoxContainer
## Interaction for the LANTERN SWITCHES lock (placeholder visuals).

signal solved

const Lights = preload("res://scripts/pcg/LightsGenerator.gd")
const Ui = preload("res://scripts/ui/UiKit.gd")


class LanternButton:
	extends Button
	const U = preload("res://scripts/ui/UiKit.gd")
	var lit: bool = false
	var glow: bool = false

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.30
		if glow:
			draw_arc(c, r + 16.0, 0.0, TAU, 40, U.GOOD, 6.0, true)
		if lit:
			draw_circle(c, r + 8.0, Color(U.GOLD.r, U.GOLD.g, U.GOLD.b, 0.35))
			draw_circle(c, r, Color(1.0, 0.86, 0.45))
		else:
			draw_circle(c, r, Color(0.16, 0.18, 0.20))
			draw_arc(c, r, 0.0, TAU, 40, U.MUTED.darkened(0.3), 4.0, true)


var _params: Dictionary = {}
var _n: int = 0
var _toggles: Array = []
var _state: Array = []
var _buttons: Array = []
var _done: bool = false


func setup(spec: Dictionary) -> void:
	_params = spec["params"]
	_n = int(_params["count"])
	_toggles = _params["toggles"]
	for v in _params["start"]:
		_state.append(int(v))
	add_theme_constant_override("separation", 16)
	add_child(Ui.label(Loc.t("lights_help"), 30, Ui.MUTED))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	if _n == 4:
		grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	for i in _n:
		var b: LanternButton = LanternButton.new()
		b.custom_minimum_size = Vector2(230, 210)
		b.pressed.connect(_press.bind(i))
		grid.add_child(b)
		_buttons.append(b)
	add_child(grid)
	_refresh()


func _refresh() -> void:
	for i in _n:
		var b: LanternButton = _buttons[i]
		b.lit = int(_state[i]) != 0
		b.glow = false
		b.queue_redraw()


func _press(index: int) -> void:
	if _done:
		return
	_state = Lights.press(_state, _toggles, index)
	Fx.play("turn")
	_refresh()
	if Lights.is_solved(_state):
		_done = true
		await get_tree().create_timer(0.45).timeout
		solved.emit()


## Marks the next switch of the shortest solution.
func hint() -> String:
	var res: Dictionary = Lights.solve(_params, _state)
	var presses: Array = res["presses"]
	if presses.is_empty():
		return ""
	var b: LanternButton = _buttons[int(presses[0])]
	b.glow = true
	b.queue_redraw()
	return Loc.t("lights_hint")
