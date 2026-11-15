extends Node
## Automated smoke test used by the build sandbox (runs inside a real Godot runtime).
## 1) generator batch test  2) every puzzle screen at every level  3) menu + full game flow.
## Not part of the shipped game flow; safe to keep in the project.

const Tester = preload("res://scripts/pcg/BatchTester.gd")
const MissionGen = preload("res://scripts/pcg/MissionGenerator.gd")
const Rng = preload("res://scripts/pcg/Rng.gd")
const GameScript = preload("res://scripts/game/Game.gd")

const BATCH := 3000


func _ready() -> void:
	print("RUNNER_START engine=", Engine.get_version_info()["string"])
	print("AUDIO sounds=", Fx.loaded_sounds(), " of ", Fx.SOUNDS.size(), " music=", Fx.has_music())
	for sound_name in Fx.SOUNDS:
		Fx.play(sound_name)
	await get_tree().process_frame
	var report: Dictionary = Tester.new_report()
	for i in BATCH:
		Tester.test_puzzle(report, i)
		if i % 250 == 0:
			print("BATCH_PROGRESS ", i)
			await get_tree().process_frame
	for i in int(BATCH / 10):
		Tester.test_mission(report, i)
	print(Tester.summary(report))
	await get_tree().process_frame

	print("TAMPER_START")
	var tamper: Array = Tester.tamper_test()
	print("TAMPER ", tamper[0], "; still accepted as solvable: ", tamper.size() - 1)
	for i in range(1, mini(tamper.size(), 40)):
		print("TAMPER_PROBLEM ", tamper[i])
	await get_tree().process_frame

	# Question bank: every question must validate and show three different answers.
	var Bank = load("res://scripts/pcg/QuestionBank.gd")
	var QuizGen = load("res://scripts/pcg/QuizGenerator.gd")
	var bank_bad: int = 0
	var bank_total: int = 0
	for cat in ["islam", "gk"]:
		var items: Array = Bank.bank(cat)
		for qid in items.size():
			bank_total += 1
			var spec_q: Dictionary = {"type": "quiz", "difficulty": 1, "params": {"cat": cat, "qid": qid, "order": [2, 0, 1]}, "solution": [1]}
			var ok: bool = bool(QuizGen.validate(spec_q)["ok"])
			for lang in ["en", "ur"]:
				var t: Dictionary = QuizGen.texts(spec_q, lang)
				var a: Array = t["answers"]
				if str(t["question"]).strip_edges() == "" or a.size() != 3 or a[0] == a[1] or a[1] == a[2] or a[0] == a[2]:
					ok = false
			if not ok:
				bank_bad += 1
				print("BANK_PROBLEM ", cat, ":", qid)
	print("BANK questions=", bank_total, " problems=", bank_bad)
	var quiz_ok: int = 0
	for i in 500:
		var m: Dictionary = MissionGen.generate_mission(Rng.derive(99, i, 1), 1 + i % 5)
		if bool(m["valid"]) and bool(MissionGen.validate_mission(JSON.parse_string(JSON.stringify(m)))["ok"]) and (m["stages"] as Array).size() == 3:
			quiz_ok += 1
	print("QUIZ_MISSIONS 500 generated, valid=", quiz_ok)

	var theme_holder: Control = Control.new()
	theme_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(theme_holder)
	var count: int = 0
	for type_name in MissionGen.GENERATORS.keys():
		for level in range(1, 6):
			var spec: Dictionary = MissionGen.GENERATORS[type_name].generate(Rng.derive(4242, level, count), level)
			# Round-trip through JSON exactly like a saved / downloaded mission.
			var parsed: Dictionary = JSON.parse_string(JSON.stringify(spec))
			var view = GameScript.VIEWS[type_name].new()
			theme_holder.add_child(view)
			view.setup(parsed)
			await get_tree().process_frame
			var hint_text: String = view.hint()
			await get_tree().process_frame
			view.queue_free()
			count += 1
			print("VIEW_OK ", type_name, " L", level, " valid=", spec["valid"], " hint=", hint_text != "")
	await get_tree().process_frame

	var menu: Node = (load("res://scenes/MainMenu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	print("MENU_OK children=", menu.get_child_count())
	menu.queue_free()

	for round_index in 6:
		GameState.start_mission(Missions.next_endless(), "endless")
		var game: Node = (load("res://scenes/Game.tscn") as PackedScene).instantiate()
		add_child(game)
		await get_tree().process_frame
		await get_tree().process_frame
		var stages: int = (GameState.data["current_mission"]["stages"] as Array).size()
		game._on_hint()
		for s in stages:
			game._on_stage_solved()
			await get_tree().create_timer(0.9).timeout
		print("GAME_OK round=", round_index + 1, " stages=", stages, " finished=", game._finished,
			" rating=", GameState.data["rating"], " solved=", GameState.data["stats"]["solved"])
		game.queue_free()
		await get_tree().process_frame

	# Chapters: play 8 boxes of chapter 1 (unlocks chapter 2), then open every extra screen.
	for box_index in 8:
		Missions.start_chapter(1, box_index)
		var cgame: Node = (load("res://scenes/Game.tscn") as PackedScene).instantiate()
		add_child(cgame)
		await get_tree().process_frame
		var cstages: int = (GameState.data["current_mission"]["stages"] as Array).size()
		for s in cstages:
			cgame._on_stage_solved()
			await get_tree().create_timer(0.9).timeout
		cgame.queue_free()
		await get_tree().process_frame
	print("CHAPTER_OK done=", Missions.chapter_done(1).size(), " ch2_unlocked=", Missions.is_chapter_unlocked(2),
		" ch3_unlocked=", Missions.is_chapter_unlocked(3), " hints=", Missions.hint_tokens(),
		" achievements=", GameState.data["achievements"], " artifacts=", (GameState.data["inventory"]["artifacts"] as Array).size())
	for chapter_id in range(1, 6):
		for box_index in 10:
			if not bool(Missions.chapter_mission(chapter_id, box_index)["valid"]):
				print("CHAPTER_INVALID ", chapter_id, " ", box_index)
	print("CHAPTER_MISSIONS_CHECKED 50")
	var chapters_scene: Node = (load("res://scenes/Chapters.tscn") as PackedScene).instantiate()
	add_child(chapters_scene)
	await get_tree().process_frame
	chapters_scene._open(1)
	await get_tree().process_frame
	chapters_scene.queue_free()
	for lang_code in ["en", "ur"]:
		GameState.set_lang(lang_code)
		for page_name in ["achievements", "journal", "inventory"]:
			GameState.page = page_name
			var page: Node = (load("res://scenes/Pages.tscn") as PackedScene).instantiate()
			add_child(page)
			await get_tree().process_frame
			await get_tree().process_frame
			page.queue_free()
	GameState.set_lang("en")
	print("PAGES_OK")
	# Monetization rules, with the stand-in ad provider (no SDK).
	var provider = load("res://scripts/monetize/TestAdProvider.gd").new()
	Ads.set_provider(provider)
	var tokens_before: int = Missions.hint_tokens()
	Ads.show_rewarded()
	var ran: Array = [0]
	var after: Callable = func() -> void: ran[0] += 1
	Ads._boxes_since_ad = 0
	Ads.maybe_interstitial(after)                       # too few boxes since the last ad
	Ads._boxes_since_ad = 4
	Ads.maybe_interstitial(after)                       # shown
	Ads._boxes_since_ad = 4
	Ads.maybe_interstitial(after)                       # blocked: shown too recently
	Ads._last_interstitial_msec = -1000000
	GameState.data["purchases"]["remove_ads"] = true
	Ads.maybe_interstitial(after)                       # blocked: ads were bought off
	GameState.data["purchases"]["remove_ads"] = false
	provider.ads_ready = false
	Ads.maybe_interstitial(after)                       # blocked: no ad loaded
	print("ADS rewarded_hints=", Missions.hint_tokens() - tokens_before, " interstitials_shown=", provider.interstitials_shown,
		" callbacks_run=", ran[0], " (expected 3, 1, 5)")
	provider.ads_ready = true
	for i in 7:
		Ads.show_rewarded()
	print("ADS daily cap: rewarded_shown=", provider.rewarded_shown, " left_today=", Ads.rewarded_left_today(), " (expected 5, 0)")
	GameState.data["ads"]["rewarded_count"] = 0
	# The real providers must be harmless without their Android plugins.
	var admob = load("res://scripts/monetize/AdmobProvider.gd").new()
	Ads.set_provider(admob)
	print("ADMOB without plugin: interstitial_ready=", admob.is_interstitial_ready(), " rewarded_available=", Ads.rewarded_available())
	Ads.set_provider(null)
	var billing = load("res://scripts/monetize/PlayBillingProvider.gd").new()
	Store.set_provider(billing)
	var pack_before: int = Missions.hint_tokens()
	var bought: Dictionary = {"purchase_state": 1, "purchase_token": "tok-1", "product_ids": PackedStringArray(["hint_pack_20"]), "is_acknowledged": false}
	billing.process_purchase(bought)
	billing.process_purchase(bought)                    # the same purchase reported twice must grant once
	billing.process_purchase({"purchase_state": 2, "purchase_token": "tok-2", "product_ids": PackedStringArray(["hint_pack_20"])})   # pending
	billing.process_purchase({"purchase_state": 1, "purchase_token": "tok-3", "product_ids": PackedStringArray(["remove_ads"]), "is_acknowledged": true})
	print("BILLING without plugin: available=", Store.available(), " hints_granted=", Missions.hint_tokens() - pack_before,
		" remove_ads=", Store.owned("remove_ads"), " (expected false, 20, true)")
	GameState.data["purchases"]["remove_ads"] = false
	Store.set_provider(null)
	var hints_before: int = Missions.hint_tokens()
	Store.grant("hint_pack_20")
	Store.grant("remove_ads")
	print("STORE available=", Store.available(), " pack_hints=", Missions.hint_tokens() - hints_before,
		" remove_ads=", Store.owned("remove_ads"), " ads_removed=", Ads.ads_removed())
	GameState.data["purchases"]["remove_ads"] = false
	print("ANALYTICS allowed_offline=", Analytics.allowed())
	GameState.start_mission(Missions.daily(), "daily")
	print("DAILY_OK valid=", GameState.data["current_mission"]["valid"])
	var selftest: Node = (load("res://scenes/SelfTest.tscn") as PackedScene).instantiate()
	add_child(selftest)
	await get_tree().create_timer(1.0).timeout
	print("SELFTEST_SCENE_OK")
	selftest.queue_free()
	for lang_code in ["en", "ur"]:
		GameState.set_lang(lang_code)
		GameState.page = "settings"
		var settings_page: Node = (load("res://scenes/Pages.tscn") as PackedScene).instantiate()
		add_child(settings_page)
		await get_tree().process_frame
		settings_page.queue_free()
	GameState.data["settings"]["quality"] = "low"
	Missions.start_chapter(1, 9)
	var low_game: Node = (load("res://scenes/Game.tscn") as PackedScene).instantiate()
	add_child(low_game)
	await get_tree().process_frame
	low_game.queue_free()
	GameState.data["settings"]["quality"] = "high"
	print("SETTINGS_OK")
	GameState.set_lang("ur")
	print("LOC_UR ", Loc.t("stage", [1, Loc.t("d3"), 1, 2]))
	GameState.set_lang("en")
	print("RUNNER_DONE")
