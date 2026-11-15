extends VBoxContainer
## Interaction for the SLIDING MECHANICAL LOCK (numbered plates).

signal solved

const SlideGen = preload("res://scripts/pcg/SliderGenerator.gd")
const Ui = preload("res://scripts/ui/UiKit.gd")

var _w: int = 0
var _h: int = 0
var _board: Array = []
var _buttons: Array = []
var _hint_cell: int = -1
var _done: bool = false


func setup(spec: Dictionary) -> void:
	var params: Dictionary = spec["params"]
	_w = int(params["w"])
	_h = int(params["h"])
	for v in params["start"]:
		_board.append(int(v))
	add_theme_constant_override("separation", 16)
	add_child(Ui.label(Loc.t("slider_help", [_w * _h - 1]), 30, Ui.MUTED))
	var grid: GridContainer = GridContainer.new()
	grid.columns = _w
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	for i in _w * _h:
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(220, 220)
		b.add_theme_font_size_override("font_size", 84)
		b.pressed.connect(_press.bind(i))
		grid.add_child(b)
		_buttons.append(b)
	add_child(grid)
	_refresh()


func _refresh() -> void:
	for i in _buttons.size():
		var b: Button = _buttons[i]
		var plate: int = int(_board[i])
		if plate == 0:
			b.text = ""
			b.modulate = Color(1.0, 1.0, 1.0, 0.15)
		else:
			b.text = str(plate)
			b.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if i == _hint_cell:
			b.add_theme_color_override("font_color", Ui.GOOD)
		else:
			b.add_theme_color_override("font_color", Ui.GOLD)


func _press(cell: int) -> void:
	if _done or int(_board[cell]) == 0:
		return
	var blank: int = _board.find(0)
	if not SlideGen.neighbours(blank, _w, _h).has(cell):
		return
	_board = SlideGen.slide(_board, cell)
	Fx.play("turn")
	_hint_cell = -1
	_refresh()
	if SlideGen.is_solved(_board):
		_done = true
		await get_tree().create_timer(0.45).timeout
		solved.emit()


## Colours the plate that should slide next (shortest solution).
func hint() -> String:
	var res: Dictionary = SlideGen.solve(_w, _h, _board)
	var moves: Array = res["moves"]
	if moves.is_empty():
		return ""
	_hint_cell = int(moves[0])
	_refresh()
	return Loc.t("slider_hint")
