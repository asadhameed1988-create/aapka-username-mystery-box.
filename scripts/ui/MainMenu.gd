extends Control
## Main menu. Features that are not built yet are shown disabled with their phase number.

const Ui = preload("res://scripts/ui/UiKit.gd")
const Content = preload("res://scripts/core/Content.gd")


func _ready() -> void:
	theme = Ui.make_theme()
	get_tree().quit_on_go_back = true
	Ui.background(self, "res://assets/bg/bg_main_menu.jpg", 0.35)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 70)
	margin.add_theme_constant_override("margin_top", 90)
	margin.add_theme_constant_override("margin_bottom", 60)
	scroll.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	margin.add_child(box)

	var logo: Texture2D = Ui.tex("res://assets/logo/logo_mystery_box.png")
	if logo != null:
		var logo_rect: TextureRect = TextureRect.new()
		logo_rect.texture = logo
		logo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_rect.custom_minimum_size = Vector2(0, 460)
		logo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(logo_rect)
	box.add_child(Ui.label(Loc.t("title"), 96, Ui.GOLD))
	box.add_child(Ui.label(Loc.t("subtitle"), 44, Ui.TEXT))
	box.add_child(Ui.label(Loc.t("tagline"), 32, Ui.MUTED))
	if logo == null:
		box.add_child(Ui.label(Loc.t("placeholder"), 26, Ui.BAD))

	var stats: Dictionary = GameState.data["stats"]
	box.add_child(Ui.label(Loc.t("stats_boxes", [int(stats["solved"])]), 32, Ui.TEXT))

	if GameState.has_mission():
		_add(box, Loc.t("continue"), _on_continue)
	var ur: bool = GameState.lang() == "ur"
	for sec in Content.SECTIONS:
		var sec_id: String = str(sec["id"])
		var b: Button = _add(box, "%s\n%s" % [str(sec["ur"] if ur else sec["en"]),
			Loc.t("chapter_n", [Missions.section_chapter(sec_id)])], _on_section.bind(sec_id))
		b.custom_minimum_size = Vector2(0, 150)
		b.add_theme_color_override("font_color", Ui.GOLD)
	if str(GameState.data["daily_done"]) == Missions.today_key():
		_add(box, Loc.t("daily_done"), _on_daily).disabled = true
	else:
		_add(box, Loc.t("daily"), _on_daily)
	_add(box, Loc.t("weekly"), _on_page.bind("weekly"))
	_add(box, Loc.t("leaderboards"), _on_page.bind("leaderboard"))
	_add(box, Loc.t("achievements"), _on_page.bind("achievements"))
	_add(box, Loc.t("rewards_title_n", [Missions.rewards_won(), Content.rewards().size()]), _on_page.bind("rewards"))
	_add(box, Loc.t("settings"), _on_page.bind("settings"))
	if OS.is_debug_build():
		_add(box, Loc.t("selftest"), _on_selftest)      # developer tool, hidden in release builds

	_add(box, Loc.t("profile"), _on_page.bind("profile"))
	var cfg: Dictionary = GameState.data["online"].get("config", {})
	var sponsor: String = str(cfg.get("sponsor_text", ""))
	if sponsor != "":
		var sponsor_btn: Button = _add(box, Loc.t("sponsored", [sponsor]), _noop)
		var link: String = str(cfg.get("sponsor_url", ""))
		if link.begins_with("https://"):
			sponsor_btn.pressed.connect(func() -> void: OS.shell_open(link))
	Online.on_menu_opened()


func _add(parent: Control, text: String, handler: Callable) -> Button:
	var b: Button = Ui.button(text)
	b.pressed.connect(handler)
	parent.add_child(b)
	return b


func _noop() -> void:
	pass


func _on_section(sec_id: String) -> void:
	GameState.data["section_ref"] = sec_id
	Fx.go("res://scenes/Chapters.tscn")


func _on_page(page_name: String) -> void:
	GameState.page = page_name
	Fx.go("res://scenes/Pages.tscn")


func _on_continue() -> void:
	Fx.go("res://scenes/Game.tscn")


func _on_endless() -> void:
	GameState.start_mission(Missions.next_endless(), "endless")
	Fx.go("res://scenes/Game.tscn")


func _on_daily() -> void:
	# Server box when available (so everyone races on the same one), else the local date-seeded box.
	var mission: Dictionary = await Online.daily_mission()
	if mission.is_empty():
		mission = Missions.daily()
	if not is_inside_tree():
		return
	GameState.start_mission(mission, "daily")
	Fx.go("res://scenes/Game.tscn")


func _on_language() -> void:
	if GameState.lang() == "en":
		GameState.set_lang("ur")
	else:
		GameState.set_lang("en")
	Fx.reload()


func _on_selftest() -> void:
	Fx.go("res://scenes/SelfTest.tscn")
