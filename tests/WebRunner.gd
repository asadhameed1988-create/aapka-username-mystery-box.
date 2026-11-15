extends Node
## Automated smoke test used by the build sandbox (runs inside a real Godot runtime).
## 1) generator batch test  2) every puzzle screen at every level  3) menu + full game flow.
## Not part of the shipped game flow; safe to keep in the project.

const Tester = preload("res://scripts/pcg/BatchTester.gd")
const MissionGen = preload("res://scripts/pcg/MissionGenerator.gd")
const Rng = preload("res://scripts/pcg/Rng.gd")
const Content = preload("res://scripts/core/Content.gd")
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

	# Questions: every template is checked (small ones fully, big ones by 400 samples).
	var QuizGen = load("res://scripts/pcg/QuizGenerator.gd")
	var Deck = load("res://scripts/pcg/QuestionDeck.gd")
	var MathG = load("res://scripts/pcg/MathGenerator.gd")
	for cat in ["islam", "gk"]:
		var checked: int = 0
		var bad: int = 0
		var skipped: int = 0
		for t in QuizGen.templates(cat):
			var size: int = int(t[1])
			var ids: Array = range(size) if size <= 2000 else []
			if ids.is_empty():
				for k in 400:
					ids.append(Deck.permute(size, k, 7))
			for idx in ids:
				var item: Dictionary = QuizGen.make(cat, str(t[0]), int(idx))
				if item.is_empty():
					skipped += 1
					continue
				checked += 1
				var spec_q: Dictionary = QuizGen.build(cat, str(t[0]), int(idx), int(idx) * 31 + 5)
				var ok: bool = bool(spec_q["valid"]) and bool(QuizGen.validate(JSON.parse_string(JSON.stringify(spec_q)))["ok"])
				for lang in ["en", "ur"]:
					var tx: Dictionary = QuizGen.texts(spec_q, lang)
					var a: Array = tx["answers"]
					if str(tx["question"]).strip_edges() == "" or a.size() != 3 or a[0] == a[1] or a[1] == a[2] or a[0] == a[2] or str(a[0]) == "" or str(a[1]) == "" or str(a[2]) == "":
						ok = false
				if not ok:
					bad += 1
					if bad < 10:
						print("QUESTION_PROBLEM ", cat, " ", t[0], " ", idx, " ", item)
		print("QUESTIONS ", cat, " total=", QuizGen.total(cat), " checked=", checked, " problems=", bad, " no_fair_question=", skipped)
	# Known facts must come out right.
	print("FACT surah_ayahs Al-Baqarah -> ", QuizGen.make("islam", "surah_ayahs", 1)["a"][0][0])
	print("FACT surah_juz Ya-Sin -> ", QuizGen.make("islam", "surah_juz", 35)["a"][0][0])
	print("FACT surah_name 114 -> ", QuizGen.make("islam", "surah_name", 113)["a"][0][0])
	print("FACT hijri_after Ramadan -> ", QuizGen.make("islam", "hijri_after", 8)["a"][0][0])
	print("FACT first3 [0,1,2] -> ", QuizGen.make("islam", "first3", 0)["a"][0][0])
	var World = load("res://scripts/pcg/CountryData.gd")
	var caps: Array = QuizGen._list("capital")
	for ci in caps.size():
		if str(World.COUNTRIES[int(caps[ci])][0]) == "PAK":
			print("FACT capital Pakistan -> ", QuizGen.make("gk", "capital", ci)["a"][0][0])
	# No repeats: 3,000 questions per section from one deck.
	for cat in ["islam", "gk"]:
		var state: Dictionary = {}
		var seen: Dictionary = {}
		var dup: int = 0
		for n in 1500:
			var q: Dictionary = Deck.next_question(state, cat, 123457, n % 3 == 0)
			var key: String = "%s:%d" % [q["tpl"], q["idx"]]
			if seen.has(key):
				dup += 1
			seen[key] = true
			if n == 750:
				state = JSON.parse_string(JSON.stringify(state))   # survives save / load
		print("DECK ", cat, " questions=1500 repeats=", dup)
	for level in range(1, 6):
		var mbad: int = 0
		for k in 600:
			var ms: Dictionary = MathG.generate(Rng.derive(55, level, k), level)
			if not bool(ms["valid"]) or not bool(MathG.validate(JSON.parse_string(JSON.stringify(ms)))["ok"]):
				mbad += 1
		print("MATH L", level, " 600 generated, problems=", mbad, " e.g. ", MathG.question_text(MathG.generate(level * 7, level)))
	var quiz_ok: int = 0
	for i in 300:
		var sec: String = ["islam", "gk", "math"][i % 3]
		var m: Dictionary = MissionGen.generate_section_box(sec, Rng.derive(99, i, 1), 1 + i % 5,
			[Deck.next_question({}, "islam" if sec == "math" else sec, i, true), {"tpl": "bank", "idx": 1}, {"tpl": "bank", "idx": 2}])
		if bool(m["valid"]) and bool(MissionGen.validate_mission(JSON.parse_string(JSON.stringify(m)))["ok"]) and (m["stages"] as Array).size() == 3:
			quiz_ok += 1
	print("SECTION_MISSIONS 300 generated, valid=", quiz_ok, " t=", Time.get_ticks_msec() / 1000)

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

	theme_holder.queue_free()
	var menu: Node = (load("res://scenes/MainMenu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	print("MENU_OK children=", menu.get_child_count(), " t=", Time.get_ticks_msec() / 1000)
	menu.queue_free()

	# Play 11 Islamic boxes (crosses into chapter 2) and 3 of the others (crosses into chapter 2) and check prizes.
	for sec in ["islam", "gk", "math"]:
		GameState.data["section_ref"] = sec
		print("SEC_BEGIN ", sec)
		var csc: Node = (load("res://scenes/Chapters.tscn") as PackedScene).instantiate()
		add_child(csc)
		await get_tree().process_frame
		csc.queue_free()
		var count_boxes: int = 11 if sec == "islam" else 3
		print("SEC_CHAPTERS_SHOWN ", sec)
		for box_index in count_boxes:
			Missions.start_section(sec)
			print("SEC_BOX ", sec, " ", box_index)
			var sgame: Node = (load("res://scenes/Game.tscn") as PackedScene).instantiate()
			add_child(sgame)
			await get_tree().process_frame
			if box_index == 0:
				sgame._on_hint()
			var sst: int = (GameState.data["current_mission"]["stages"] as Array).size()
			for s in sst:
				sgame._on_stage_solved()
				await get_tree().create_timer(0.2).timeout
			if box_index == count_boxes - 1:
				print("GAME_OK section=", sec, " finished=", sgame._finished, " level=", Missions.section_level(sec))
			sgame.queue_free()
			await get_tree().process_frame
		print("SECTION_OK ", sec, " boxes=", Missions.section_boxes(sec), " chapter=", Missions.section_chapter(sec))
	print("REWARDS_OK won=", Missions.rewards_won(), " of ", Content.rewards().size(), " solved=", GameState.data["stats"]["solved"],
		" achievements=", GameState.data["achievements"])
	for lang_code in ["en", "ur"]:
		GameState.set_lang(lang_code)
		for page_name in ["achievements", "rewards"]:
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
	Missions.start_section("gk")
	var low_game: Node = (load("res://scenes/Game.tscn") as PackedScene).instantiate()
	add_child(low_game)
	await get_tree().process_frame
	low_game.queue_free()
	GameState.data["settings"]["quality"] = "high"
	print("SETTINGS_OK")
	GameState.set_lang("ur")
	print("LOC_UR ", Loc.t("stage_section", [1, 2, 10, 1, 3]))
	GameState.set_lang("en")
	print("RUNNER_DONE")
