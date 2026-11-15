extends Control
## Small non-interactive symbol picture (used inside clue rows).

const Painter = preload("res://scripts/ui/SymbolPainter.gd")

var symbol_id: int = 0


func _init() -> void:
	custom_minimum_size = Vector2(84, 84)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	Painter.draw_symbol(self, symbol_id, size * 0.5, minf(size.x, size.y) * 0.32)
