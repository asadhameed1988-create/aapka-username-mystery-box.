extends Control
## Chapter selection: list of chapters, then the 10 boxes of the chosen chapter.

const Ui = preload("res://scripts/ui/UiKit.gd")
const Content = preload("res://scripts/core/Content.gd")

var _box: VBoxContainer
var _open_chapter: int = 0   # 0 = chapter list


func _ready() -> void:
	theme = Ui.make_theme()
	get_tree().quit_on_go_back = false
	Ui.background(self, "res://assets/bg/bg_main_menu.jpg", 0.55)
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
	var ref: Array = GameState.data.get("chapter_ref", [])
	if GameState.open_chapter_on_return and ref.size() == 2:
		_open_chapter = int(ref[0])
	GameState.open_chapter_on_return = false
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


func _rebuild() -> void:
	for child in _box.get_children():
		child.queue_free()
	var back: Button = Ui.button(Loc.t("back"))
	back.pressed.connect(_back)
	_box.add_child(back)
	if _open_chapter == 0:
		_build_list()
	else:
		_build_boxes()


func _chapter_name(chapter: Dictionary) -> String:
	return str(chapter.get(GameState.lang(), chapter["en"]))


func _build_list() -> void:
	_box.add_child(Ui.label(Loc.t("chapters"), 64, Ui.GOLD))
	for chapter in Content.CHAPTERS:
		var id: int = int(chapter["id"])
		var done: int = Missions.chapter_done(id).size()
		var b: Button = Ui.button("%s\n%s" % [_chapter_name(chapter), Loc.t("chapter_progress", [done, Content.BOXES_PER_CHAPTER])])
		b.custom_minimum_size = Vector2(0, 170)
		if Missions.is_chapter_unlocked(id):
			b.pressed.connect(_open.bind(id))
		else:
			b.disabled = true
			b.text = "%s\n%s" % [_chapter_name(chapter), Loc.t("chapter_locked", [Content.UNLOCK_NEEDED])]
		_box.add_child(b)


func _build_boxes() -> void:
	var chapter: Dictionary = Content.chapter(_open_chapter)
	_box.add_child(Ui.label(_chapter_name(chapter), 52, Ui.GOLD))
	var done: int = Missions.chapter_done(_open_chapter).size()
	_box.add_child(Ui.label(Loc.t("chapter_progress", [done, Content.BOXES_PER_CHAPTER]), 34, Ui.TEXT))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	for i in Content.BOXES_PER_CHAPTER:
		var level: int = int((chapter["levels"] as Array)[i])
		var b: Button = Ui.button("%s\n%s" % [Loc.t("box_number", [i + 1]), Loc.t("d%d" % level)])
		b.custom_minimum_size = Vector2(0, 170)
		if Missions.is_box_done(_open_chapter, i):
			b.add_theme_color_override("font_color", Ui.GOOD)
			b.text += "\n" + Loc.t("box_done")
		b.pressed.connect(_play.bind(i))
		grid.add_child(b)
	_box.add_child(grid)


func _open(chapter_id: int) -> void:
	_open_chapter = chapter_id
	_rebuild()


func _play(index: int) -> void:
	Missions.start_chapter(_open_chapter, index)
	Fx.go("res://scenes/Game.tscn")


func _back() -> void:
	if _open_chapter != 0:
		_open_chapter = 0
		_rebuild()
		return
	Fx.go("res://scenes/MainMenu.tscn")
