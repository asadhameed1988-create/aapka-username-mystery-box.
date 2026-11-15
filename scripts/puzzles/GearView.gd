extends VBoxContainer
## Interaction for the GEAR ALIGNMENT lock (gears drawn with code).

signal solved

const GearGen = preload("res://scripts/pcg/GearGenerator.gd")
const Ui = preload("res://scripts/ui/UiKit.gd")

const NAMES := ["A", "B", "C", "D", "E"]

var _params: Dictionary = {}
var _teeth: Array = []
var _cranks: Array = []
var _offsets: Array = []
var _canvas: Control
var _hint_label: Label
var _done: bool = false


func setup(spec: Dictionary) -> void:
	_params = spec["params"]
	_teeth = _params["teeth"]
	_cranks = _params["cranks"]
	for o in _params["start"]:
		_offsets.append(int(o))
	add_theme_constant_override("separation", 12)
	add_child(Ui.label(Loc.t("gears_help"), 30, Ui.MUTED))
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(0, 300)
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.draw.connect(_draw_canvas)
	add_child(_canvas)
	for c in _cranks.size():
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var back: Button = Ui.button(NAMES[c] + "  -")
		back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		back.custom_minimum_size = Vector2(200, 100)
		back.pressed.connect(_turn.bind(c, -1))
		var parts: PackedStringArray = PackedStringArray()
		for part in _cranks[c]:
			var arrow: String = "+"
			if int(part[1]) < 0:
				arrow = "-"
			parts.append(Loc.t("gear_part", [int(part[0]) + 1, arrow]))
		var info: Label = Ui.label(", ".join(parts), 30, Ui.TEXT)
		var fwd: Button = Ui.button(NAMES[c] + "  +")
		fwd.size_flags_horizontal = Control.SIZE_SHRINK_END
		fwd.custom_minimum_size = Vector2(200, 100)
		fwd.pressed.connect(_turn.bind(c, 1))
		row.add_child(back)
		row.add_child(info)
		row.add_child(fwd)
		add_child(row)
	_hint_label = Ui.label("", 32, Ui.GOOD)
	add_child(_hint_label)


func _draw_canvas() -> void:
	var n: int = _teeth.size()
	var area: Vector2 = _canvas.size
	var slot: float = area.x / float(n)
	var font: Font = ThemeDB.fallback_font
	for i in n:
		var t: int = int(_teeth[i])
		var r: float = minf(slot * 0.42, area.y * 0.40) * (0.75 + 0.25 * float(t) / 8.0)
		var c: Vector2 = Vector2(slot * (float(i) + 0.5), area.y * 0.55)
		var aligned: bool = int(_offsets[i]) == 0
		var body: Color = Color(0.55, 0.40, 0.17)
		if aligned:
			body = Color(0.70, 0.55, 0.22)
		_canvas.draw_circle(c, r, body)
		for k in t:
			var ang: float = -PI * 0.5 + TAU * (float(k) + float(int(_offsets[i]))) / float(t)
			var dir: Vector2 = Vector2(cos(ang), sin(ang))
			var col: Color = body.darkened(0.25)
			var width: float = 10.0
			if k == 0:
				col = Ui.GOOD
				width = 16.0
			_canvas.draw_line(c + dir * r * 0.72, c + dir * (r + 12.0), col, width)
		_canvas.draw_circle(c, r * 0.30, Ui.PANEL)
		# target notch above the gear
		_canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(c.x - 14.0, c.y - r - 36.0), Vector2(c.x + 14.0, c.y - r - 36.0), Vector2(c.x, c.y - r - 16.0),
		]), Ui.GOLD)
		_canvas.draw_string(font, Vector2(c.x - 40.0, c.y + 14.0), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 80.0, 40, Ui.GOLD)


func _turn(crank: int, dir: int) -> void:
	if _done:
		return
	_offsets = GearGen.turn(_offsets, _teeth, _cranks[crank], dir)
	Fx.play("turn")
	_hint_label.text = ""
	_canvas.queue_redraw()
	if GearGen.is_solved(_offsets):
		_done = true
		await get_tree().create_timer(0.45).timeout
		solved.emit()


## Names the next crank press of the shortest solution.
func hint() -> String:
	var res: Dictionary = GearGen.solve(_params, _offsets)
	var moves: Array = res["moves"]
	if moves.is_empty():
		return ""
	var mv: Array = moves[0]
	var sign_text: String = "+"
	if int(mv[1]) < 0:
		sign_text = "-"
	var text: String = Loc.t("gears_hint", [NAMES[int(mv[0])] + " " + sign_text])
	_hint_label.text = text
	return text
