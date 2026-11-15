extends RefCounted
## Puzzle symbols (8 abstract, non-religious shapes).
## Draws from the approved sprite sheet MB-009 (4 x 2 grid of 256 px cells);
## if the sheet is missing it falls back to simple shapes drawn with code.
## Must be called from inside the target CanvasItem's draw step.

const COUNT := 8
const SHEET_PATH := "res://assets/ui/symbols_sheet.png"
const CELL := 256.0
const SHEET_SCALE := 1.5   # medallion half-size relative to the requested radius

static var _sheet: Texture2D = null
static var _checked: bool = false


static func _get_sheet() -> Texture2D:
	if not _checked:
		_checked = true
		if ResourceLoader.exists(SHEET_PATH):
			_sheet = load(SHEET_PATH) as Texture2D
	return _sheet

const COLORS := [
	Color(0.98, 0.80, 0.30),
	Color(0.80, 0.86, 0.95),
	Color(0.95, 0.55, 0.30),
	Color(0.45, 0.80, 0.60),
	Color(0.45, 0.70, 0.95),
	Color(0.90, 0.45, 0.55),
	Color(0.70, 0.55, 0.90),
	Color(0.95, 0.93, 0.85),
]


static func draw_symbol(ci: CanvasItem, id: int, c: Vector2, r: float) -> void:
	var kind: int = posmod(id, COUNT)
	var sheet: Texture2D = _get_sheet()
	if sheet != null:
		var half: float = r * SHEET_SCALE
		var region: Rect2 = Rect2(float(kind % 4) * CELL, float(int(kind / 4)) * CELL, CELL, CELL)
		ci.draw_texture_rect_region(sheet, Rect2(c.x - half, c.y - half, half * 2.0, half * 2.0), region)
		return
	var col: Color = COLORS[kind]
	if kind == 0:
		# sun
		ci.draw_circle(c, r * 0.5, col)
		for k in 8:
			var a: float = TAU * float(k) / 8.0
			var dir: Vector2 = Vector2(cos(a), sin(a))
			ci.draw_line(c + dir * r * 0.68, c + dir * r, col, maxf(2.0, r * 0.14))
	elif kind == 1:
		# moon arc
		ci.draw_arc(c, r * 0.62, 0.9, TAU - 0.9, 24, col, r * 0.42)
	elif kind == 2:
		# eight-point star
		ci.draw_colored_polygon(_star(c, r, r * 0.5, 8), col)
	elif kind == 3:
		ci.draw_colored_polygon(_ngon(c, r, 3, -PI * 0.5), col)
	elif kind == 4:
		# tall diamond
		ci.draw_colored_polygon(PackedVector2Array([
			c + Vector2(0, -r), c + Vector2(r * 0.6, 0), c + Vector2(0, r), c + Vector2(-r * 0.6, 0),
		]), col)
	elif kind == 5:
		# plus
		ci.draw_rect(Rect2(c.x - r * 0.25, c.y - r * 0.9, r * 0.5, r * 1.8), col)
		ci.draw_rect(Rect2(c.x - r * 0.9, c.y - r * 0.25, r * 1.8, r * 0.5), col)
	elif kind == 6:
		ci.draw_colored_polygon(_ngon(c, r, 6, 0.0), col)
	else:
		# ring with dot
		ci.draw_arc(c, r * 0.72, 0.0, TAU, 28, col, r * 0.28)
		ci.draw_circle(c, r * 0.2, col)


static func _ngon(c: Vector2, r: float, sides: int, start: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in sides:
		var a: float = start + TAU * float(k) / float(sides)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func _star(c: Vector2, r_out: float, r_in: float, points: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in points * 2:
		var a: float = -PI * 0.5 + PI * float(k) / float(points)
		var rr: float = r_out
		if k % 2 == 1:
			rr = r_in
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts
