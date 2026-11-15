extends VBoxContainer
## Interaction for the LIGHT REFLECTION lock (beam and mirrors drawn with code).

signal solved

const MirrorGen = preload("res://scripts/pcg/MirrorGenerator.gd")
const Ui = preload("res://scripts/ui/UiKit.gd")

var _params: Dictionary = {}
var _w: int = 0
var _h: int = 0
var _cells: Array = []
var _orients: Array = []
var _target: int = 0
var _entry_row: int = 0
var _hint_index: int = -1
var _canvas: Control
var _geo: Dictionary = {}
var _done: bool = false


func setup(spec: Dictionary) -> void:
	_params = spec["params"]
	_w = int(_params["w"])
	_h = int(_params["h"])
	_target = int(_params["target"])
	_entry_row = int(_params["entry_row"])
	var packed: Dictionary = MirrorGen.unpack(_params)
	_cells = packed["cells"]
	_orients = packed["orients"]
	add_theme_constant_override("separation", 10)
	add_child(Ui.label(Loc.t("mirrors_help"), 30, Ui.MUTED))
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(0, 760)
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_on_canvas_input)
	add_child(_canvas)


func _center(cell: int) -> Vector2:
	var origin: Vector2 = _geo["origin"]
	var cs: float = float(_geo["cell"])
	return origin + Vector2((float(cell % _w) + 0.5) * cs, (float(int(cell / _w)) + 0.5) * cs)


func _draw_canvas() -> void:
	var area: Vector2 = _canvas.size
	var cs: float = minf((area.x - 80.0) / float(_w), (area.y - 20.0) / float(_h))
	var origin: Vector2 = Vector2((area.x - cs * float(_w)) * 0.5, (area.y - cs * float(_h)) * 0.5)
	_geo = {"origin": origin, "cell": cs}
	for cell in _w * _h:
		var x0: float = origin.x + float(cell % _w) * cs
		var y0: float = origin.y + float(int(cell / _w)) * cs
		_canvas.draw_rect(Rect2(x0 + 2.0, y0 + 2.0, cs - 4.0, cs - 4.0), Color(0.05, 0.08, 0.10, 0.85))
		_canvas.draw_rect(Rect2(x0 + 2.0, y0 + 2.0, cs - 4.0, cs - 4.0), Ui.GOLD.darkened(0.6), false, 2.0)
	var beam: Array = MirrorGen.beam_cells(_w, _h, _entry_row, _cells, _orients)
	var hit: bool = beam.has(_target)
	# crystal
	var tc: Vector2 = _center(_target)
	var crystal: Color = Ui.MUTED
	if hit:
		crystal = Ui.GOOD
	_canvas.draw_colored_polygon(PackedVector2Array([
		tc + Vector2(0.0, -cs * 0.32), tc + Vector2(cs * 0.22, 0.0), tc + Vector2(0.0, cs * 0.32), tc + Vector2(-cs * 0.22, 0.0),
	]), crystal)
	# beam
	var beam_col: Color = Color(1.0, 0.86, 0.45)
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2(origin.x - 34.0, origin.y + (float(_entry_row) + 0.5) * cs))
	for cell in beam:
		points.append(_center(int(cell)))
	if beam.size() > 0:
		# Short tail showing where the beam leaves the last cell (after its mirror, if any).
		var last: Vector2 = points[points.size() - 1]
		var before: Vector2 = points[points.size() - 2]
		var step_dir: Vector2 = (last - before).normalized()
		var dir: int = 0
		if step_dir.y > 0.5:
			dir = 1
		elif step_dir.x < -0.5:
			dir = 2
		elif step_dir.y < -0.5:
			dir = 3
		var last_index: int = _cells.find(int(beam[beam.size() - 1]))
		if last_index >= 0:
			dir = int(MirrorGen.REFLECT[int(_orients[last_index])][dir])
		points.append(last + Vector2(float(int(MirrorGen.DX[dir])), float(int(MirrorGen.DY[dir]))) * cs * 0.5)
	for i in range(1, points.size()):
		_canvas.draw_line(points[i - 1], points[i], beam_col, 8.0)
	_canvas.draw_circle(points[0], 16.0, beam_col)
	# mirrors
	for i in _cells.size():
		var c: Vector2 = _center(int(_cells[i]))
		var half: float = cs * 0.34
		var col: Color = Color(0.80, 0.88, 0.95)
		if i == _hint_index:
			col = Ui.GOOD
		if int(_orients[i]) == 0:
			_canvas.draw_line(c + Vector2(-half, half), c + Vector2(half, -half), col, 10.0)
		else:
			_canvas.draw_line(c + Vector2(-half, -half), c + Vector2(half, half), col, 10.0)


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
		var index: int = _cells.find(cy * _w + cx)
		if index < 0:
			return
		_orients[index] = 1 - int(_orients[index])
		Fx.play("turn")
		_hint_index = -1
		_canvas.queue_redraw()
		if MirrorGen.hits_target(_params, _orients):
			_done = true
			await get_tree().create_timer(0.6).timeout
			solved.emit()


## Marks one mirror that must be flipped (fewest-flips solution).
func hint() -> String:
	var res: Dictionary = MirrorGen.solve(_params, _orients)
	var flips: Array = res["flips"]
	if flips.is_empty():
		return ""
	_hint_index = int(flips[0])
	_canvas.queue_redraw()
	return Loc.t("mirrors_hint")
