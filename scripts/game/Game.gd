extends Control
## Game screen: 3D box on top, the current lock (puzzle stage) below.

const Ui = preload("res://scripts/ui/UiKit.gd")
const Box3D = preload("res://scripts/game/Box3D.gd")
const Content = preload("res://scripts/core/Content.gd")
const VIEWS := {
	"rings": preload("res://scripts/puzzles/RingsView.gd"),
	"combo": preload("res://scripts/puzzles/ComboView.gd"),
	"latch": preload("res://scripts/puzzles/LatchView.gd"),
	"seq": preload("res://scripts/puzzles/ChoiceView.gd"),
	"pattern": preload("res://scripts/puzzles/ChoiceView.gd"),
	"lights": preload("res://scripts/puzzles/LightsView.gd"),
	"maze": preload("res://scripts/puzzles/MazeView.gd"),
	"circuit": preload("res://scripts/puzzles/CircuitView.gd"),
	"slider": preload("res://scripts/puzzles/SliderView.gd"),
	"gears": preload("res://scripts/puzzles/GearView.gd"),
	"colours": preload("res://scripts/puzzles/ColourView.gd"),
	"cipher": preload("res://scripts/puzzles/CipherView.gd"),
	"mirrors": preload("res://scripts/puzzles/MirrorView.gd"),
	"quiz": preload("res://scripts/puzzles/QuizView.gd"),
	"math": preload("res://scripts/puzzles/QuizView.gd"),
}

var _mission: Dictionary = {}
var _stages: Array = []
var _stage: int = 0
var _elapsed: float = 0.0
var _hints: int = 0
var _finished: bool = false
var _box   # Box3D instance
var _view  # current puzzle view (RingsView / ComboView / LatchView)
var _holder: VBoxContainer
var _stage_label: Label
var _status: Label
var _hint_btn: Button


func _ready() -> void:
	if not GameState.has_mission():
		_to_menu()
		return
	theme = Ui.make_theme()
	get_tree().quit_on_go_back = false
	_mission = GameState.data["current_mission"]
	_stages = _mission["stages"]
	_stage = clampi(int(GameState.data["current_stage"]), 0, _stages.size() - 1)
	_elapsed = float(GameState.data["mission_time"])
	_hints = int(GameState.data["mission_hints"])
	_build_ui()
	_load_stage()


func _backdrop_path() -> String:
	var key: String = str((_mission.get("visual", {}) as Dictionary).get("backdrop", ""))
	var path: String = "res://assets/bg/bg_%s.jpg" % key
	if ResourceLoader.exists(path):
		return path
	return "res://assets/bg/bg_house_of_wisdom.jpg"


func _build_ui() -> void:
	var backdrop: String = _backdrop_path()
	var has_backdrop: bool = ResourceLoader.exists(backdrop)
	Ui.background(self, backdrop, 0.55)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	add_child(margin)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	var back: Button = Ui.button(Loc.t("back"))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.custom_minimum_size = Vector2(220, 96)
	back.pressed.connect(_leave)
	_stage_label = Ui.label("", 30, Ui.GOLD)
	_hint_btn = Ui.button("")
	_hint_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_hint_btn.custom_minimum_size = Vector2(220, 96)
	_hint_btn.pressed.connect(_on_hint)
	bar.add_child(back)
	bar.add_child(_stage_label)
	bar.add_child(_hint_btn)
	_update_hint_button()
	root.add_child(bar)

	var svc: SubViewportContainer = SubViewportContainer.new()
	svc.stretch = true
	svc.custom_minimum_size = Vector2(0, 520)
	var sv: SubViewport = SubViewport.new()
	sv.own_world_3d = true
	var high_quality: bool = str(GameState.data["settings"].get("quality", "high")) == "high"
	if high_quality:
		sv.msaa_3d = Viewport.MSAA_2X
	sv.transparent_bg = has_backdrop
	svc.add_child(sv)
	_box = Box3D.new()
	sv.add_child(_box)
	_box.build(_mission.get("visual", {}), has_backdrop, high_quality)
	svc.gui_input.connect(_on_box_input)
	root.add_child(svc)

	_status = Ui.label(Loc.t("drag_box"), 30, Ui.MUTED)
	root.add_child(_status)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_holder = VBoxContainer.new()
	_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_holder.add_theme_constant_override("separation", 16)
	scroll.add_child(_holder)


func _process(delta: float) -> void:
	if not _finished:
		_elapsed += delta


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_leave()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_progress()


func _on_box_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_box.rotate_by(event.relative)


func _load_stage() -> void:
	if _view != null:
		_view.queue_free()
		_view = null
	var spec: Dictionary = _stages[_stage]
	var level_name: String = Loc.t("d%d" % int(_mission["difficulty"]))
	var mode: String = str(GameState.data["mode"])
	if mode == "section":
		var sec: String = str(_mission.get("section", "islam"))
		var boxes: int = Missions.section_boxes(sec)
		_stage_label.text = Loc.t("stage_section", [Missions.section_chapter(sec), boxes % Content.BOXES_PER_CHAPTER + 1, Content.BOXES_PER_CHAPTER, mini(_stage + 1, _stages.size()), _stages.size()])
	elif mode == "chapter":
		var ref: Array = GameState.data["chapter_ref"]
		_stage_label.text = Loc.t("stage_chapter", [int(ref[0]), int(ref[1]) + 1, level_name, mini(_stage + 1, _stages.size()), _stages.size()])
	elif mode == "daily":
		_stage_label.text = Loc.t("stage_daily", [level_name, mini(_stage + 1, _stages.size()), _stages.size()])
	elif mode == "weekly":
		_stage_label.text = Loc.t("stage_weekly", [level_name, mini(_stage + 1, _stages.size()), _stages.size()])
	else:
		_stage_label.text = Loc.t("stage", [int(GameState.data["round"]) + 1, level_name, mini(_stage + 1, _stages.size()), _stages.size()])
	var script: GDScript = VIEWS[str(spec["type"])]
	_view = script.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_holder.add_child(_view)
	_view.setup(spec)
	_view.solved.connect(_on_stage_solved)


func _update_hint_button() -> void:
	if _hint_btn == null:
		return
	if Missions.hint_tokens() <= 0 and not Missions.hint_bonus_used() and Ads.rewarded_available():
		_hint_btn.text = Loc.t("hint_ad")
	else:
		_hint_btn.text = Loc.t("hint_count", [Missions.hint_tokens()])


func _on_hint() -> void:
	if _finished or _view == null:
		return
	if Missions.hint_tokens() <= 0:
		if not Missions.hint_bonus_used() and Ads.rewarded_available():
			# One extra hint for this box, only if the player chooses to watch an ad.
			Ads.reward_granted.connect(func(_amount: int) -> void:
				if is_inside_tree():
					_update_hint_button(), CONNECT_ONE_SHOT)
			Ads.show_rewarded()
			return
		_status.add_theme_color_override("font_color", Ui.BAD)
		_status.text = Loc.t("no_hints")
		return
	var text: String = _view.hint()
	if text != "":
		_hints += 1
		Missions.spend_hint()
		Fx.play("hint")
		_update_hint_button()
		_status.add_theme_color_override("font_color", Ui.GOLD)
		_status.text = text


func _on_stage_solved() -> void:
	if _view != null and "mistakes" in _view:
		_hints += int(_view.mistakes)
	_stage += 1
	Fx.play("clear")
	_box.pulse()
	_status.add_theme_color_override("font_color", Ui.GOOD)
	_status.text = Loc.t("stage_clear")
	if _stage >= _stages.size():
		_finish()
		return
	_save_progress()
	await get_tree().create_timer(0.7).timeout
	_load_stage()


func _finish() -> void:
	_finished = true
	_hint_btn.disabled = true
	if _view != null:
		_view.queue_free()
		_view = null
	var mode: String = str(GameState.data["mode"])
	var result: Dictionary = Missions.complete(_mission, _elapsed, _hints)
	var coin_kind: String = str(result.get("coin_kind", "silver"))
	_box.open_lid(coin_kind)
	Fx.play("open")
	get_tree().create_timer(0.5).timeout.connect(func() -> void: Fx.play("coins"))
	_holder.modulate = Color(1.0, 1.0, 1.0, 0.0)
	create_tween().tween_property(_holder, "modulate:a", 1.0, 0.6).set_delay(1.4)
	_hint_btn.text = Loc.t("hint_count", [0])
	_holder.add_child(Ui.label(Loc.t("solved_title"), 64, Ui.GOLD))
	var coins_label: Label = Ui.label(Loc.t("coins_" + coin_kind, [int(result.get("coin_amount", 0))]), 44,
		Color(1.0, 0.82, 0.35) if coin_kind == "gold" else Color(0.86, 0.89, 0.95))
	_holder.add_child(coins_label)
	_holder.add_child(Ui.label(Loc.t("result", [Ui.format_time(_elapsed), _hints]), 34, Ui.TEXT))
	if not (result["new_achievements"] as Array).is_empty():
		Fx.play("award")
	for id in result["new_achievements"]:
		for ach in Content.ACHIEVEMENTS:
			if str(ach["id"]) == str(id):
				_holder.add_child(Ui.label(Loc.t("ach_new", [str(ach.get(GameState.lang(), ach["en"]))]), 36, Ui.GOLD))
	if int(result.get("new_reward", -1)) >= 0:
		Fx.play("award")
		var prize: Dictionary = Content.rewards()[int(result["new_reward"])]
		_holder.add_child(Ui.label(Loc.t("reward_new", [str(prize.get(GameState.lang(), prize["en"]))]), 38, Ui.GOLD))
	_holder.add_child(_summary_panel())
	if mode == "section":
		var next_sec: Button = Ui.button(Loc.t("next_box"))
		next_sec.pressed.connect(_next_section_box)
		_holder.add_child(next_sec)
		var sec_btn: Button = Ui.button(Loc.t("all_chapters"))
		sec_btn.pressed.connect(func() -> void: Fx.go("res://scenes/Chapters.tscn"))
		_holder.add_child(sec_btn)
	elif mode == "endless":
		var next_btn: Button = Ui.button(Loc.t("next_box"))
		next_btn.pressed.connect(_next_box)
		_holder.add_child(next_btn)
	elif mode == "chapter":
		var ref: Array = GameState.data["chapter_ref"]
		if int(ref[1]) + 1 < Content.BOXES_PER_CHAPTER:
			var next_ch: Button = Ui.button(Loc.t("next_box"))
			next_ch.pressed.connect(_next_chapter_box)
			_holder.add_child(next_ch)
		var list_btn: Button = Ui.button(Loc.t("chapters"))
		list_btn.pressed.connect(_to_chapters)
		_holder.add_child(list_btn)
	var menu_btn: Button = Ui.button(Loc.t("menu"))
	menu_btn.pressed.connect(_to_menu)
	_holder.add_child(menu_btn)


func _next_box() -> void:
	# An interstitial may appear here, between boxes, and nowhere else.
	Ads.maybe_interstitial(func() -> void:
		GameState.start_mission(Missions.next_endless(), "endless")
		Fx.reload())


## After the box opens: every question with its right answer, and references for Islamic ones.
func _summary_panel() -> Control:
	var QuizGen = load("res://scripts/pcg/QuizGenerator.gd")
	var MathGen = load("res://scripts/pcg/MathGenerator.gd")
	var QuizView = load("res://scripts/puzzles/QuizView.gd")
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	scroll.add_child(col)
	var any: bool = false
	for i in _stages.size():
		var spec: Dictionary = _stages[i]
		var question: String = ""
		var answer: String = ""
		var ref: Dictionary = {}
		if str(spec.get("type", "")) == "quiz":
			var t: Dictionary = QuizGen.texts(spec, GameState.lang())
			question = str(t["question"])
			answer = str(t["answers"][int(spec["solution"][0])])
			ref = QuizGen.reference_of(spec)
		elif str(spec.get("type", "")) == "math":
			question = MathGen.question_text(spec)
			answer = str(int(spec["params"]["options"][int(spec["solution"][0])]))
		else:
			continue
		if not any:
			col.add_child(Ui.label(Loc.t("summary_title"), 36, Ui.GOLD))
			any = true
		var q: Label = Ui.label("%d. %s" % [i + 1, question], 30, Ui.TEXT)
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(q)
		col.add_child(Ui.label(Loc.t("summary_answer", [answer]), 30, Ui.GOOD))
		if not ref.is_empty():
			col.add_child(QuizView.reference_panel(ref))
	return scroll if any else Control.new()


func _next_section_box() -> void:
	var sec: String = str(_mission.get("section", "islam"))
	Ads.maybe_interstitial(func() -> void:
		Missions.start_section(sec)
		Fx.reload())


func _next_chapter_box() -> void:
	var ref: Array = GameState.data["chapter_ref"]
	Ads.maybe_interstitial(func() -> void:
		Missions.start_chapter(int(ref[0]), int(ref[1]) + 1)
		Fx.reload())


func _to_chapters() -> void:
	GameState.open_chapter_on_return = true
	Fx.go("res://scenes/Chapters.tscn")


func _save_progress() -> void:
	if _finished or not GameState.has_mission():
		return
	GameState.data["current_stage"] = _stage
	GameState.data["mission_time"] = _elapsed
	GameState.data["mission_hints"] = _hints
	GameState.save_game()


func _leave() -> void:
	_save_progress()
	_to_menu()


func _to_menu() -> void:
	Fx.go("res://scenes/MainMenu.tscn")
