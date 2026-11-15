extends Control
## Chapters of one question section (GameState.data["section_ref"]).
## Chapters never end: each has 10 boxes; finished chapters show a tick, the current
## one has a Play button, the next ones are shown locked.

const Ui = preload("res://scripts/ui/UiKit.gd")
const Content = preload("res://scripts/core/Content.gd")
const QuizGen = preload("res://scripts/pcg/QuizGenerator.gd")
const SymbolIcon = preload("res://scripts/ui/SymbolIcon.gd")

const LOCKED_SHOWN := 2

var _box: VBoxContainer


func _ready() -> void:
	theme = Ui.make_theme()
	get_tree().quit_on_go_back = false
	Ui.background(self, "res://assets/bg/bg_house_of_wisdom.jpg", 0.6)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 50)
	add_child(margin)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 20)
	scroll.add_child(_box)
	_build()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


static func section_def(id: String) -> Dictionary:
	for s in Content.SECTIONS:
		if str(s["id"]) == id:
			return s
	return Content.SECTIONS[0]


func _build() -> void:
	var sec_id: String = str(GameState.data.get("section_ref", "islam"))
	var sec: Dictionary = section_def(sec_id)
	var ur: bool = GameState.lang() == "ur"
	var back: Button = Ui.button(Loc.t("back"))
	back.pressed.connect(_back)
	_box.add_child(back)
	var icon = SymbolIcon.new()
	icon.custom_minimum_size = Vector2(0, 170)
	icon.symbol_id = int(sec["symbol"])
	_box.add_child(icon)
	_box.add_child(Ui.label(str(sec["ur"] if ur else sec["en"]), 64, Ui.GOLD))
	_box.add_child(Ui.label(str(sec["ur_note"] if ur else sec["en_note"]), 32, Ui.TEXT))
	if sec_id == "math":
		_box.add_child(Ui.label(Loc.t("sec_math_count"), 28, Ui.MUTED))
	else:
		_box.add_child(Ui.label(Loc.t("sec_question_count", [_grouped(QuizGen.total(sec_id))]), 28, Ui.MUTED))
	var done: int = Missions.section_boxes(sec_id)
	var current: int = Missions.section_chapter(sec_id)
	_box.add_child(Ui.label(Loc.t("sec_boxes_done", [done]), 34, Ui.TEXT))
	if GameState.has_mission() and str(GameState.data["mode"]) == "section" and str(GameState.data.get("section_ref", "")) == sec_id:
		var cont: Button = Ui.button(Loc.t("continue"))
		cont.pressed.connect(func() -> void: Fx.go("res://scenes/Game.tscn"))
		_box.add_child(cont)
	for ch in range(current + LOCKED_SHOWN, 0, -1):
		var b: Button = Ui.button("")
		b.custom_minimum_size = Vector2(0, 150)
		if ch < current:
			b.text = "%s\n%s" % [Loc.t("chapter_n", [ch]), Loc.t("chapter_complete")]
			b.add_theme_color_override("font_color", Ui.GOOD)
			b.disabled = true
		elif ch == current:
			var in_chapter: int = done % Content.BOXES_PER_CHAPTER
			b.text = "%s\n%s" % [Loc.t("chapter_n", [ch]), Loc.t("chapter_play", [in_chapter + 1, Content.BOXES_PER_CHAPTER])]
			b.pressed.connect(_play.bind(sec_id))
		else:
			b.text = "%s\n%s" % [Loc.t("chapter_n", [ch]), Loc.t("chapter_locked_next")]
			b.disabled = true
		_box.add_child(b)


## 722,000 -> "722,000"
static func _grouped(n: int) -> String:
	var s: String = str(n)
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _play(sec_id: String) -> void:
	if not (GameState.has_mission() and str(GameState.data["mode"]) == "section" and str(GameState.data.get("section_ref", "")) == sec_id):
		Missions.start_section(sec_id)
	Fx.go("res://scenes/Game.tscn")


func _back() -> void:
	Fx.go("res://scenes/MainMenu.tscn")
