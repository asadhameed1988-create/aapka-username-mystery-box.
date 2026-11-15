extends VBoxContainer
## Interaction for the CIRCUIT CONNECTION lock (channels drawn with code).

signal solved

const Circuit = preload("res://scripts/pcg/CircuitGenerator.gd")
const Grid = preload("res://scripts/pcg/GridTree.gd")
const Ui = preload("res://scripts/ui/UiKit.gd")

var _w: int = 0
var _h: int = 0
var _tiles: Array = []
var _target: Array = []
var _source: int = 0
var _hint_cell: int = -1
var _canvas: Control
var _geo: Dictionary = {}
var _done: bool = false


func setup(spec: Dictionary) -> void:
	var params: Dictionary = spec["params"]
	_w = int(params["w"])
	_h = int(params["h"])
	_source = int(params["source"])
	for t in params["tiles"]:
		_tiles.append(int(t))
	_target = Circuit.solved_tiles(spec)
	add_theme_constant_override("separation", 10)
	add_child(Ui.label(Loc.t("circuit_help"), 30, Ui.MUTED))
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(0, 760)
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_on_canvas_input)
	add_child(_canvas)


func _draw_canvas() -> void:
	var area: Vector2 = _canvas.size
	var cs: float = minf((area.x - 20.0) / float(_w), (area.y - 20.0) / float(_h))
	var origin: Vector2 = Vector2((area.x - cs * float(_w)) * 0.5, (area.y - cs * float(_h)) * 0.5)
	_geo = {"origin": origin, "cell": cs}
	var powered: Array = Grid.bfs(_tiles, _w, _h, _source, true)["dist"]
	for cell in _w * _h:
		var x0: float = origin.x + float(cell % _w) * cs
		var y0: float = origin.y + float(int(cell / _w)) * cs
		var c: Vector2 = Vector2(x0 + cs * 0.5, y0 + cs * 0.5)
		_canvas.draw_rect(Rect2(x0 + 4.0, y0 + 4.0, cs - 8.0, cs - 8.0), Color(0.05, 0.08, 0.10, 0.85))
		var border: Color = Ui.GOLD.darkened(0.45)
		if cell == _hint_cell:
			border = Ui.GOOD
		_canvas.draw_rect(Rect2(x0 + 4.0, y0 + 4.0, cs - 8.0, cs - 8.0), border, false, 4.0)
		var col: Color = Ui.MUTED.darkened(0.35)
		if int(powered[cell]) >= 0:
			col = Color(1.0, 0.82, 0.40)
		var mask: int = int(_tiles[cell])
		var half: float = cs * 0.5 - 4.0
		var width: float = cs * 0.16
		if (mask & Grid.N) != 0:
			_canvas.draw_line(c, c + Vector2(0.0, -half), col, width)
		if (mask & Grid.E) != 0:
			_canvas.draw_line(c, c + Vector2(half, 0.0), col, width)
		if (mask & Grid.S) != 0:
			_canvas.draw_line(c, c + Vector2(0.0, half), col, width)
		if (mask & Grid.W) != 0:
			_canvas.draw_line(c, c + Vector2(-half, 0.0), col, width)
		_canvas.draw_circle(c, width * 0.75, col)
		if cell == _source:
			_canvas.draw_circle(c, cs * 0.20, Ui.GOOD)
			_canvas.draw_circle(c, cs * 0.10, Color(1.0, 1.0, 1.0))


func _on_canvas_input(event: InputEvent) -> void:
	if _done or _geo.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var origin: Vector2 = _geo["origin"]
		var cs: float = float(_geo["cell"])
		var local: Vector2 = event.position - origin
		if local.x < 0.0 or local.y < 0.0:
			return
		var cx: int = int(local.x / cs)
		var cy: int = int(local.y / cs)
		if cx >= _w or cy >= _h:
			return
		var cell: int = cy * _w + cx
		_tiles[cell] = Grid.rotate_mask(int(_tiles[cell]), 1)
		Fx.play("turn")
		_hint_cell = -1
		_canvas.queue_redraw()
		if Circuit.is_network_complete(_tiles, _w, _h, _source):
			_done = true
			await get_tree().create_timer(0.45).timeout
			solved.emit()


## Marks one tile that is not yet in its solved position.
func hint() -> String:
	for cell in _tiles.size():
		if int(_tiles[cell]) != int(_target[cell]):
			_hint_cell = cell
			_canvas.queue_redraw()
			return Loc.t("circuit_hint")
	return ""
