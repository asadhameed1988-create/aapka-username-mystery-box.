extends Control
## One scene for the simple pages chosen by GameState.page:
## "achievements" (with personal statistics), "journal", "inventory",
## "leaderboard", "weekly", "profile" (account + privacy).

const Ui = preload("res://scripts/ui/UiKit.gd")
const Content = preload("res://scripts/core/Content.gd")
const SymbolIcon = preload("res://scripts/ui/SymbolIcon.gd")

var _box: VBoxContainer


func _ready() -> void:
	theme = Ui.make_theme()
	get_tree().quit_on_go_back = false
	Ui.background(self, "res://assets/bg/bg_main_menu.jpg", 0.6)
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
	_box.add_theme_constant_override("separation", 18)
	scroll.add_child(_box)
	var back: Button = Ui.button(Loc.t("back"))
	back.pressed.connect(_back)
	_box.add_child(back)
	if GameState.page == "settings":
		_build_settings()
	elif GameState.page == "leaderboard":
		_build_leaderboard()
	elif GameState.page == "weekly":
		_build_weekly()
	elif GameState.page == "profile":
		_build_profile()
	elif GameState.page == "journal":
		_build_journal()
	elif GameState.page == "rewards":
		_build_rewards()
	else:
		_build_achievements()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_back()


func _lang(entry: Dictionary, key: String) -> String:
	if GameState.lang() == "ur":
		return str(entry.get("ur" + key, entry["en" + key]))
	return str(entry["en" + key])


func _left(text: String, font_size: int, color: Color) -> Label:
	var l: Label = Ui.label(text, font_size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if GameState.lang() == "ur":
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


func _build_achievements() -> void:
	_box.add_child(Ui.label(Loc.t("achievements"), 64, Ui.GOLD))
	var stats: Dictionary = GameState.data["stats"]
	var solved: int = int(stats["solved"])
	var average: float = 0.0
	if solved > 0:
		average = float(stats["total_time"]) / float(solved)
	var lines: PackedStringArray = PackedStringArray([
		Loc.t("stat_solved", [solved]),
		Loc.t("stat_no_hint", [int(stats["no_hint"])]),
		Loc.t("stat_best", [Ui.format_time(float(stats["best_time"]))]),
		Loc.t("stat_average", [Ui.format_time(average)]),
		Loc.t("stat_sections", [Missions.section_boxes("islam"), Missions.section_boxes("gk"), Missions.section_boxes("math")]),
		Loc.t("rewards_count", [Missions.rewards_won(), Content.rewards().size()]),
		Loc.t("stat_daily", [int(stats["daily_streak"]), int(stats["daily_best"])]),
	])
	_box.add_child(Ui.label("\n".join(lines), 34, Ui.TEXT))
	var have: int = (GameState.data["achievements"] as Array).size()
	_box.add_child(Ui.label(Loc.t("ach_count", [have, Content.ACHIEVEMENTS.size()]), 38, Ui.GOLD))
	for ach in Content.ACHIEVEMENTS:
		var unlocked: bool = Missions.has_achievement(str(ach["id"]))
		var title: String = _lang(ach, "")
		var desc: String = Loc.t(str(ach["desc"]), [int(ach["need"])])
		var progress: int = mini(Missions.stat(str(ach["stat"])), int(ach["need"]))
		var color: Color = Ui.MUTED
		var mark: String = "%d / %d" % [progress, int(ach["need"])]
		if unlocked:
			color = Ui.GOOD
			mark = Loc.t("box_done")
		_box.add_child(Ui.label("%s\n%s  (%s)" % [title, desc, mark], 34, color))


func _build_journal() -> void:
	_box.add_child(Ui.label(Loc.t("journal"), 64, Ui.GOLD))
	for entry in Content.JOURNAL:
		var chapter: Dictionary = Content.chapter(int(entry["chapter"]))
		if Missions.journal_unlocked(entry):
			_box.add_child(_left(_lang(entry, "_title"), 44, Ui.GOLD))
			_box.add_child(_left(_lang(entry, ""), 34, Ui.TEXT))
		else:
			var chapter_name: String = str(chapter.get(GameState.lang(), chapter["en"]))
			_box.add_child(_left(Loc.t("journal_locked", [int(entry["need"]), chapter_name]), 32, Ui.MUTED))


## Hint tokens, rewarded ad and the store (shown at the end of Settings).
func _build_hints_and_store() -> void:
	_box.add_child(Ui.label(Loc.t("hints_title"), 44, Ui.GOLD))
	_box.add_child(Ui.label(Loc.t("inv_hints", [Missions.hint_tokens(), Missions.MAX_HINT_TOKENS]), 40, Ui.TEXT))
	_box.add_child(Ui.label(Loc.t("inv_hints_how"), 30, Ui.MUTED))
	if Ads.rewarded_available():
		var watch: Button = Ui.button(Loc.t("ad_reward", [Ads.REWARD_HINTS]))
		watch.pressed.connect(func() -> void:
			watch.disabled = true
			Ads.show_rewarded())
		_box.add_child(watch)
		# The reward arrives when the ad finishes, which can be much later than the tap.
		Ads.reward_granted.connect(func(_amount: int) -> void:
			_reload(), CONNECT_ONE_SHOT)
	_box.add_child(Ui.label(Loc.t("store_title"), 44, Ui.GOLD))
	if Store.available():
		var pack: Button = Ui.button(Loc.t("store_hint_pack") + "  " + Store.price("hint_pack_20"))
		pack.pressed.connect(func() -> void: Store.buy("hint_pack_20"))
		_box.add_child(pack)
		var no_ads: Button = Ui.button(Loc.t("store_remove_ads") + "  " + Store.price("remove_ads"))
		if Store.owned("remove_ads"):
			no_ads.text = Loc.t("store_owned")
			no_ads.disabled = true
		no_ads.pressed.connect(func() -> void: Store.buy("remove_ads"))
		_box.add_child(no_ads)
		Store.purchase_finished.connect(func(_product: String, ok: bool) -> void:
			if ok:
				_reload())
	else:
		_box.add_child(Ui.label(Loc.t("store_unavailable"), 30, Ui.MUTED))


const TIER_TINT := [Color(0.88, 0.58, 0.36), Color(0.86, 0.90, 0.97), Color(1.0, 0.84, 0.38)]


## Prizes: one for every few boxes; won ones in colour, the rest dimmed with the box count.
func _build_rewards() -> void:
	var all: Array = Content.rewards()
	var won: int = Missions.rewards_won()
	_box.add_child(Ui.label(Loc.t("rewards_title"), 64, Ui.GOLD))
	_box.add_child(Ui.label(Loc.t("rewards_count", [won, all.size()]), 38, Ui.TEXT))
	_box.add_child(Ui.label(Loc.t("rewards_how", [Content.BOXES_PER_REWARD]), 30, Ui.MUTED))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 22)
	for i in all.size():
		var prize: Dictionary = all[i]
		var cell: VBoxContainer = VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pic: Control
		if str(prize["kind"]) == "seal":
			var icon = SymbolIcon.new()
			icon.symbol_id = int(prize["symbol"])
			icon.self_modulate = TIER_TINT[int(prize["tier"])]
			pic = icon
		else:
			var tr: TextureRect = TextureRect.new()
			tr.texture = Ui.tex(str(prize["path"]))
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			pic = tr
		pic.custom_minimum_size = Vector2(0, 220)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(pic)
		var name_label: Label = Ui.label(str(prize.get(GameState.lang(), prize["en"])), 26, Ui.TEXT)
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.add_child(name_label)
		if i >= won:
			pic.modulate = Color(1, 1, 1, 0.18)
			name_label.text = Loc.t("rewards_locked", [(i + 1) * Content.BOXES_PER_REWARD])
			name_label.add_theme_color_override("font_color", Ui.MUTED)
		grid.add_child(cell)
	_box.add_child(grid)


func _toggle(text_on: String, text_off: String, key: String) -> void:
	var settings: Dictionary = GameState.data["settings"]
	var on: bool = bool(settings.get(key, true))
	var b: Button = Ui.button(Loc.t(text_on) if on else Loc.t(text_off))
	b.pressed.connect(func() -> void:
		settings[key] = not on
		GameState.save_game()
		Fx.refresh_music()
		_reload())
	_box.add_child(b)


func _build_settings() -> void:
	_box.add_child(Ui.label(Loc.t("settings"), 64, Ui.GOLD))
	var settings: Dictionary = GameState.data["settings"]
	_toggle("sound_on", "sound_off", "sound")
	_toggle("music_on", "music_off", "music")
	var high: bool = str(settings.get("quality", "high")) == "high"
	var quality: Button = Ui.button(Loc.t("quality_high") if high else Loc.t("quality_low"))
	quality.pressed.connect(func() -> void:
		settings["quality"] = "low" if high else "high"
		GameState.save_game()
		_reload())
	_box.add_child(quality)
	_box.add_child(Ui.label(Loc.t("quality_note"), 30, Ui.MUTED))
	var lang: Button = Ui.button(Loc.t("language"))
	lang.pressed.connect(func() -> void:
		GameState.set_lang("ur" if GameState.lang() == "en" else "en")
		_reload())
	_box.add_child(lang)
	_build_hints_and_store()


func _online_problem() -> String:
	if not Online.is_configured():
		return Loc.t("online_not_set")
	if not Online.is_enabled():
		return Loc.t("online_off")
	return ""


func _build_leaderboard() -> void:
	_box.add_child(Ui.label(Loc.t("leaderboards"), 64, Ui.GOLD))
	var status: Label = Ui.label(Loc.t("loading"), 34, Ui.MUTED)
	_box.add_child(status)
	if _online_problem() != "":
		status.text = _online_problem()
		return
	var mission: Dictionary = await Online.daily_mission()
	if not is_inside_tree():
		return
	if mission.is_empty():
		status.text = Loc.t("online_fail")
		return
	var result: Dictionary = await Online.leaderboard(str(mission["server_id"]))
	if not is_inside_tree():
		return
	if not bool(result["ok"]):
		status.text = Loc.t("online_fail")
		return
	var entries: Array = result["entries"]
	if entries.is_empty():
		status.text = Loc.t("lb_empty")
		return
	status.text = Loc.t("lb_daily")
	for e in entries:
		var color: Color = Ui.TEXT
		if bool(e.get("me", false)):
			color = Ui.GOOD
		var line: String = Loc.t("lb_row", [int(e["rank"]), str(e["name"]), Ui.format_time(float(e["time_ms"]) / 1000.0), int(e["hints"])])
		_box.add_child(Ui.label(line, 36, color))


func _build_weekly() -> void:
	_box.add_child(Ui.label(Loc.t("weekly"), 64, Ui.GOLD))
	var status: Label = Ui.label(Loc.t("loading"), 34, Ui.MUTED)
	_box.add_child(status)
	var missions: Array = await Online.weekly_missions()
	if not is_inside_tree():
		return
	if missions.is_empty():
		status.text = _online_problem()
		if status.text == "":
			status.text = Loc.t("online_fail")
		return
	status.text = Loc.t("weekly_info")
	var done: Array = GameState.data["online"]["weekly_done"]
	for i in missions.size():
		var mission: Dictionary = missions[i]
		var b: Button = Ui.button("%s  -  %s" % [Loc.t("box_number", [i + 1]), Loc.t("d%d" % int(mission["difficulty"]))])
		if done.has(str(mission.get("server_id", ""))):
			b.add_theme_color_override("font_color", Ui.GOOD)
			b.text += "  -  " + Loc.t("box_done")
		b.pressed.connect(_play_weekly.bind(mission))
		_box.add_child(b)


func _play_weekly(mission: Dictionary) -> void:
	GameState.start_mission(mission, "weekly")
	Fx.go("res://scenes/Game.tscn")


func _field(placeholder: String, secret: bool) -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.secret = secret
	edit.custom_minimum_size = Vector2(0, 100)
	edit.add_theme_font_size_override("font_size", 38)
	return edit


func _reload() -> void:
	if is_inside_tree():
		Fx.reload()


func _build_profile() -> void:
	_box.add_child(Ui.label(Loc.t("profile"), 64, Ui.GOLD))
	_box.add_child(_left(Loc.t("privacy_note"), 30, Ui.MUTED))
	var message: Label = Ui.label("", 32, Ui.BAD)
	if not Online.is_configured():
		_box.add_child(Ui.label(Loc.t("online_not_set"), 34, Ui.TEXT))
		return
	var online_on: bool = bool(GameState.data["settings"].get("online", true))
	var toggle: Button = Ui.button(Loc.t("online_toggle_on") if online_on else Loc.t("online_toggle_off"))
	toggle.pressed.connect(func() -> void:
		GameState.data["settings"]["online"] = not online_on
		GameState.save_game()
		_reload())
	_box.add_child(toggle)
	if not online_on:
		return
	var stats_on: bool = bool(GameState.data["settings"].get("analytics", true))
	var stats_btn: Button = Ui.button(Loc.t("analytics_on") if stats_on else Loc.t("analytics_off"))
	stats_btn.pressed.connect(func() -> void:
		GameState.data["settings"]["analytics"] = not stats_on
		GameState.save_game()
		_reload())
	_box.add_child(stats_btn)
	var prof: Dictionary = Online.profile()
	if prof.is_empty():
		_box.add_child(Ui.label(Loc.t("profile_none"), 34, Ui.TEXT))
	elif bool(prof.get("is_guest", true)):
		_box.add_child(Ui.label(Loc.t("profile_guest", [str(prof.get("display_name", ""))]), 34, Ui.TEXT))
	else:
		_box.add_child(Ui.label(Loc.t("profile_registered", [str(prof.get("display_name", "")), str(prof.get("email", ""))]), 34, Ui.TEXT))
	_box.add_child(message)

	var name_edit: LineEdit = _field(Loc.t("name_placeholder"), false)
	_box.add_child(name_edit)
	var save_name: Button = Ui.button(Loc.t("name_save"))
	save_name.pressed.connect(func() -> void:
		var r: Dictionary = await Online.update_account({"display_name": name_edit.text.strip_edges()})
		if bool(r["ok"]):
			_reload()
		elif is_inside_tree():
			message.text = Loc.t("name_bad"))
	_box.add_child(save_name)

	var shown: bool = bool(prof.get("show_on_leaderboard", true))
	var show_btn: Button = Ui.button(Loc.t("lb_show_on") if shown else Loc.t("lb_show_off"))
	show_btn.pressed.connect(func() -> void:
		await Online.update_account({"show_on_leaderboard": not shown})
		_reload())
	_box.add_child(show_btn)

	if prof.is_empty() or bool(prof.get("is_guest", true)):
		_box.add_child(_left(Loc.t("register_note"), 30, Ui.MUTED))
		var email_edit: LineEdit = _field(Loc.t("email_placeholder"), false)
		var pass_edit: LineEdit = _field(Loc.t("password_placeholder"), true)
		_box.add_child(email_edit)
		_box.add_child(pass_edit)
		var reg: Button = Ui.button(Loc.t("register"))
		reg.pressed.connect(func() -> void:
			var r: Dictionary = await Online.register(email_edit.text.strip_edges(), pass_edit.text)
			if bool(r["ok"]):
				_reload()
			elif is_inside_tree():
				message.text = Loc.t("register_fail"))
		_box.add_child(reg)
		var log_in: Button = Ui.button(Loc.t("login"))
		log_in.pressed.connect(func() -> void:
			var r: Dictionary = await Online.login(email_edit.text.strip_edges(), pass_edit.text)
			if bool(r["ok"]):
				_reload()
			elif is_inside_tree():
				message.text = Loc.t("login_fail"))
		_box.add_child(log_in)

	var del: Button = Ui.button(Loc.t("delete_account"))
	del.add_theme_color_override("font_color", Ui.BAD)
	var armed: Array = [false]
	del.pressed.connect(func() -> void:
		if not bool(armed[0]):
			armed[0] = true
			del.text = Loc.t("delete_confirm")
			return
		if await Online.delete_account():
			_reload()
		elif is_inside_tree():
			message.text = Loc.t("online_fail"))
	_box.add_child(del)


func _back() -> void:
	Fx.go("res://scenes/MainMenu.tscn")
