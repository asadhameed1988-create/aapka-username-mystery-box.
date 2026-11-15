extends VBoxContainer
## Interaction + drawing for the ASTROLABE RINGS puzzle (placeholder visuals).

signal solved

const Rings = preload("res://scripts/pcg/RingsGenerator.gd")
const Painter = preload("res://scripts/ui/SymbolPainter.gd")
const Ui = preload("res://scripts/ui/UiKit.gd")

const RING_A := Color(0.55, 0.40, 0.17)
const RING_B := Color(0.42, 0.30, 0.13)
const DISC := Color(0.10, 0.13, 0.16)

var _params: Dictionary = {}
var _n: int = 0
var _m: int = 0
var _symbols: Array = []
var _links: Array = []
var _offsets: Array = []   # logical position of every ring (0 = solved)
var _turns: Array = []     # unwrapped position, used only for smooth drawing
var _visual: Array = []
var _canvas: Control
var _geo: Dictionary = {}
var _hint_ring: int = -1
var _done: bool = false


func setup(spec: Dictionary) -> void:
	_params = spec["params"]
	_n = int(_params["rings"])
	_m = int(_params["positions"])
	_symbols = _params["symbols"]
	_links = _params.get("links", [])
	for o in _params["start"]:
		_offsets.append(int(o))
		_turns.append(int(o))
		_visual.append(float(int(o)))
	add_theme_constant_override("separation", 10)
	add_child(Ui.label(Loc.t("rings_help"), 30, Ui.MUTED))
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(0, 700)
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.draw.connect(_draw_canvas)
	_canvas.gui_input.connect(_on_canvas_input)
	add_child(_canvas)
	var lines: Array = []
	for l in _links:
		var key: String = "rings_link"
		if int(l[2]) < 0:
			key = "rings_link_rev"
		lines.append(Loc.t(key, [int(l[0]) + 1, int(l[1]) + 1]))
	if not lines.is_empty():
		lines.append(Loc.t("rings_note"))
		add_child(Ui.label("\n".join(PackedStringArray(lines)), 30, Ui.GOLD))


func _process(delta: float) -> void:
	var moving: bool = false
	for i in _n:
		var target: float = float(int(_turns[i]))
		var cur: float = float(_visual[i])
		if absf(target - cur) > 0.002:
			_visual[i] = lerpf(cur, target, minf(1.0, delta * 14.0))
			moving = true
		elif cur != target:
			_visual[i] = target
			moving = true
	if moving and _canvas != null:
		_canvas.queue_redraw()


func _draw_canvas() -> void:
	var area: Vector2 = _canvas.size
	var c: Vector2 = Vector2(area.x * 0.5 + 44.0, area.y * 0.5)
	var r_max: float = minf(area.x * 0.5 - 64.0, area.y * 0.5 - 18.0)
	var r0: float = r_max * 0.26
	var band: float = (r_max - r0) / float(_n)
	_geo = {"c": c, "r0": r0, "band": band, "r_max": r_max}
	for i in _n:
		var mid: float = r0 + band * (float(i) + 0.5)
		var col: Color = RING_A
		if i % 2 == 1:
			col = RING_B
		if i == _hint_ring:
			col = Ui.GOLD.darkened(0.2)
		_canvas.draw_arc(c, mid, 0.0, TAU, 72, col, band - 6.0, true)
		var ring_syms: Array = _symbols[i]
		for k in _m:
			var ang: float = -PI * 0.5 + TAU * (float(k) - float(_visual[i])) / float(_m)
			var pos: Vector2 = c + Vector2(cos(ang), sin(ang)) * mid
			_canvas.draw_circle(pos, band * 0.40, DISC)
			Painter.draw_symbol(_canvas, int(ring_syms[k]), pos, band * 0.27)
	# golden marker window at the top
	var half: float = band * 0.46
	_canvas.draw_rect(Rect2(c.x - half, c.y - r_max - 4.0, half * 2.0, r_max - r0 + 8.0), Ui.GOLD, false, 5.0)
	_canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 16.0, c.y - r_max - 16.0), Vector2(c.x + 16.0, c.y - r_max - 16.0), Vector2(c.x, c.y - r_max - 2.0),
	]), Ui.GOLD)
	_canvas.draw_circle(c, r0 - 6.0, Ui.PANEL)
	_canvas.draw_arc(c, r0 - 6.0, 0.0, TAU, 48, Ui.GOLD, 3.0, true)
	# target column (top = outer ring)
	for i in _n:
		var row: int = _n - 1 - i
		var tp: Vector2 = Vector2(50.0, 56.0 + float(row) * 86.0)
		_canvas.draw_circle(tp, 36.0, DISC)
		_canvas.draw_arc(tp, 36.0, 0.0, TAU, 32, Ui.GOLD, 3.0, true)
		Painter.draw_symbol(_canvas, int((_symbols[i] as Array)[0]), tp, 22.0)


func _on_canvas_input(event: InputEvent) -> void:
	if _done or _geo.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var c: Vector2 = _geo["c"]
		var v: Vector2 = event.position - c
		var dist: float = v.length()
		if dist < float(_geo["r0"]) or dist > float(_geo["r_max"]):
			return
		var ring: int = clampi(int((dist - float(_geo["r0"])) / float(_geo["band"])), 0, _n - 1)
		var dir: int = -1
		if v.x < 0.0:
			dir = 1
		_move(ring, dir)


func _move(ring: int, dir: int) -> void:
	_offsets = Rings.apply_move(_offsets, ring, dir, _links, _m)
	_turns[ring] = int(_turns[ring]) + dir
	for l in _links:
		if int(l[0]) == ring:
			var target: int = int(l[1])
			_turns[target] = int(_turns[target]) + dir * int(l[2])
	_hint_ring = -1
	Fx.play("turn")
	_canvas.queue_redraw()
	if Rings.is_solved(_offsets):
		_done = true
		await get_tree().create_timer(0.45).timeout
		solved.emit()


## Returns a hint sentence (next move of the shortest solution).
func hint() -> String:
	var res: Dictionary = Rings.solve(_params, _offsets)
	var moves: Array = res["moves"]
	if moves.is_empty():
		return ""
	var mv: Array = moves[0]
	_hint_ring = int(mv[0])
	_canvas.queue_redraw()
	if int(mv[1]) > 0:
		return Loc.t("hint_ring_left", [_hint_ring + 1])
	return Loc.t("hint_ring_right", [_hint_ring + 1])
