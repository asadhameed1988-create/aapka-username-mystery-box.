extends VBoxContainer
## Interaction for the MECHANICAL MAZE lock (walls and pin drawn with code).

signal solved

const Maze = preload("res://scripts/pcg/MazeGenerator.gd")
const Grid = preload("res://scripts/pcg/GridTree.gd")
const Ui = preload("res://scripts/ui/UiKit.gd")

var _params: Dictionary = {}
var _w: int = 0
var _h: int = 0
var _cells: Array = []
var _pos: int = 0
var _exit: int = 0
var _key: int = -1
var _has_key: bool = false
var _hint_cell: int = -1
var _canvas: Control
var _geo: Dictionary = {}
var _done: bool = false


func setup(spec: Dictionary) -> void:
	_params = spec["params"]
	_w = int(_params["w"])
	_h = int(_params["h"])
	_cells = _params["cells"]
	_pos = int(_params["start"])
	_exit = int(_params["exit"])
	_key = int(_params["key"])
	_has_key = _key < 0
	add_theme_constant_override("separation", 10)
	var help: String = Loc.t("maze_help")
	if _key >= 0:
		help += " " + Loc.t("maze_help_key")
	add_child(Ui.label(help, 30, Ui.MUTED))
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(0, 760)
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_on_canvas_input)
	add_child(_canvas)


func _cell_center(cell: int) -> Vector2:
	var origin: Vector2 = _geo["origin"]
	var cs: float = float(_geo["cell"])
	return origin + Vector2((float(cell % _w) + 0.5) * cs, (float(int(cell / _w)) + 0.5) * cs)


func _draw_canvas() -> void:
	var area: Vector2 = _canvas.size
	var cs: float = minf((area.x - 20.0) / float(_w), (area.y - 20.0) / float(_h))
	var origin: Vector2 = Vector2((area.x - cs * float(_w)) * 0.5, (area.y - cs * float(_h)) * 0.5)
	_geo = {"origin": origin, "cell": cs}
	_canvas.draw_rect(Rect2(origin, Vector2(cs * float(_w), cs * float(_h))), Color(0.05, 0.08, 0.10, 0.85))
	if _hint_cell >= 0:
		var hc: Vector2 = _cell_center(_hint_cell)
		_canvas.draw_rect(Rect2(hc.x - cs * 0.5, hc.y - cs * 0.5, cs, cs), Color(Ui.GOOD.r, Ui.GOOD.g, Ui.GOOD.b, 0.35))
	# exit plate
	var ec: Vector2 = _cell_center(_exit)
	var exit_col: Color = Ui.GOLD
	if not _has_key:
		exit_col = Ui.MUTED.darkened(0.3)
	_canvas.draw_rect(Rect2(ec.x - cs * 0.32, ec.y - cs * 0.32, cs * 0.64, cs * 0.64), exit_col, false, 6.0)
	_canvas.draw_circle(ec, cs * 0.10, exit_col)
	# key
	if _key >= 0 and not _has_key:
		var kc: Vector2 = _cell_center(_key)
		_canvas.draw_arc(kc - Vector2(cs * 0.12, 0.0), cs * 0.12, 0.0, TAU, 20, Ui.GOLD, 5.0, true)
		_canvas.draw_line(kc, kc + Vector2(cs * 0.26, 0.0), Ui.GOLD, 5.0)
		_canvas.draw_line(kc + Vector2(cs * 0.20, 0.0), kc + Vector2(cs * 0.20, cs * 0.10), Ui.GOLD, 5.0)
	# walls
	var wall: Color = Ui.GOLD.darkened(0.15)
	for cell in _w * _h:
		var x0: float = origin.x + float(cell % _w) * cs
		var y0: float = origin.y + float(int(cell / _w)) * cs
		var mask: int = int(_cells[cell])
		if (mask & Grid.N) == 0:
			_canvas.draw_line(Vector2(x0, y0), Vector2(x0 + cs, y0), wall, 6.0)
		if (mask & Grid.W) == 0:
			_canvas.draw_line(Vector2(x0, y0), Vector2(x0, y0 + cs), wall, 6.0)
		if (mask & Grid.S) == 0:
			_canvas.draw_line(Vector2(x0, y0 + cs), Vector2(x0 + cs, y0 + cs), wall, 6.0)
		if (mask & Grid.E) == 0:
			_canvas.draw_line(Vector2(x0 + cs, y0), Vector2(x0 + cs, y0 + cs), wall, 6.0)
	# pin
	var pc: Vector2 = _cell_center(_pos)
	_canvas.draw_circle(pc, cs * 0.26, Color(0.95, 0.93, 0.85))
	_canvas.draw_circle(pc, cs * 0.14, Ui.GOLD)


func _on_canvas_input(event: InputEvent) -> void:
	if _done or _geo.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var v: Vector2 = event.position - _cell_center(_pos)
		if v.length() < float(_geo["cell"]) * 0.2:
			return
		var dir: int = Grid.E
		if absf(v.x) >= absf(v.y):
			if v.x < 0.0:
				dir = Grid.W
		elif v.y < 0.0:
			dir = Grid.N
		else:
			dir = Grid.S
		_try_move(dir)


func _try_move(dir: int) -> void:
	if (int(_cells[_pos]) & dir) == 0:
		return
	_pos = Grid.step(_pos, dir, _w, _h)
	Fx.play("turn")
	_hint_cell = -1
	if _pos == _key:
		_has_key = true
	_canvas.queue_redraw()
	if _pos == _exit and _has_key:
		_done = true
		await get_tree().create_timer(0.45).timeout
		solved.emit()


## Marks the next cell of the shortest route.
func hint() -> String:
	var route: Array = Maze.solve(_params, _pos, _has_key)
	if route.is_empty():
		return ""
	var dir: int = int(route[0])
	_hint_cell = Grid.step(_pos, dir, _w, _h)
	_canvas.queue_redraw()
	return Loc.t("maze_hint")
