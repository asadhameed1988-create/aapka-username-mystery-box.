extends RefCounted
## Shared look (night-blue + brass palette).
## Uses the approved art from res://assets when it exists and falls back to
## flat placeholder styles when a file is missing.

const PANEL_TEX := "res://assets/ui/panel_brass_9slice.png"
const URDU_FONT := "res://assets/fonts/NotoNaskhArabic-Regular.ttf"   # SIL Open Font License 1.1

static var _font: Font = null
static var _font_checked: bool = false

const BG := Color(0.07, 0.125, 0.17)
const PANEL := Color(0.11, 0.19, 0.25)
const GOLD := Color(0.85, 0.70, 0.37)
const TEXT := Color(0.95, 0.91, 0.82)
const MUTED := Color(0.62, 0.69, 0.72)
const GOOD := Color(0.44, 0.81, 0.59)
const BAD := Color(0.90, 0.45, 0.45)


## Default Latin font with the bundled Arabic-script font as fallback, so Urdu
## text shows on every device (no dependence on the phone's system fonts).
static func ui_font() -> Font:
	if not _font_checked:
		_font_checked = true
		var urdu: Font = null
		if ResourceLoader.exists(URDU_FONT):
			urdu = load(URDU_FONT) as Font
		elif FileAccess.file_exists(URDU_FONT):
			var raw: FontFile = FontFile.new()
			if raw.load_dynamic_font(URDU_FONT) == OK:
				urdu = raw
		if urdu != null:
			var combined: FontVariation = FontVariation.new()
			combined.base_font = ThemeDB.fallback_font
			var extra: Array[Font] = [urdu]
			combined.fallbacks = extra
			_font = combined
	return _font


static func make_theme() -> Theme:
	var th: Theme = Theme.new()
	th.default_font_size = 38
	if ui_font() != null:
		th.default_font = ui_font()
	var panel: Texture2D = tex(PANEL_TEX)
	if panel != null:
		th.set_stylebox("normal", "Button", _tex_box(panel, Color(1.0, 1.0, 1.0)))
		th.set_stylebox("hover", "Button", _tex_box(panel, Color(1.0, 1.0, 1.0)))
		th.set_stylebox("pressed", "Button", _tex_box(panel, Color(0.65, 0.65, 0.65)))
		th.set_stylebox("disabled", "Button", _tex_box(panel, Color(0.45, 0.45, 0.45, 0.85)))
	else:
		th.set_stylebox("normal", "Button", _box(PANEL, GOLD))
		th.set_stylebox("hover", "Button", _box(PANEL.lightened(0.08), GOLD))
		th.set_stylebox("pressed", "Button", _box(GOLD.darkened(0.5), GOLD))
		th.set_stylebox("disabled", "Button", _box(PANEL.darkened(0.25), MUTED.darkened(0.4)))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", TEXT)
	th.set_color("font_hover_color", "Button", TEXT)
	th.set_color("font_pressed_color", "Button", TEXT)
	th.set_color("font_disabled_color", "Button", MUTED.darkened(0.2))
	th.set_color("font_color", "Label", TEXT)
	return th


static func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(22)
	return sb


## Loads a texture if the file exists in the project, otherwise returns null.
static func tex(path: String) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


static func _tex_box(texture: Texture2D, tint: Color) -> StyleBoxTexture:
	var sb: StyleBoxTexture = StyleBoxTexture.new()
	sb.texture = texture
	sb.set_texture_margin_all(44.0)
	sb.set_content_margin_all(26.0)
	sb.modulate_color = tint
	return sb


## Full-screen background. `image_path` is optional; `dim` darkens it for readability.
static func background(parent: Control, image_path: String = "", dim: float = 0.5) -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var picture: Texture2D = tex(image_path)
	if picture == null:
		return
	var tr: TextureRect = TextureRect.new()
	tr.texture = picture
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, dim)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)


static func button(text: String) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 110)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
		b.scale = Vector2(0.96, 0.96))
	b.button_up.connect(func() -> void:
		b.scale = Vector2.ONE)
	b.pressed.connect(func() -> void:
		Fx.play("tap"))
	return b


static func label(text: String, font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func format_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%d:%02d" % [int(total / 60), total % 60]
