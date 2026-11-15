extends Node
## Autoload "Missions": decides WHICH mission comes next and records results
## (difficulty rating, chapters, achievements, hint tokens, statistics).
## Everything is generated locally (works fully offline).
## Phase 6 adds: download of server missions + cache, falling back to this local path.

const Rng = preload("res://scripts/pcg/Rng.gd")
const MissionGen = preload("res://scripts/pcg/MissionGenerator.gd")
const Content = preload("res://scripts/core/Content.gd")

const RECENT_TYPES_KEPT := 12
const RECENT_SIGNATURES_KEPT := 60
const FAST_SECONDS := 60.0
const MAX_HINT_TOKENS := 20


const RECENT_QUESTIONS_KEPT := 60
const QuestionDeck = preload("res://scripts/pcg/QuestionDeck.gd")


# ---------------------------------------------------------------- sections

func section_info(section: String) -> Dictionary:
	return GameState.data["sections"][section]


func section_boxes(section: String) -> int:
	return int(section_info(section)["boxes"])


## Chapter the player is in now (1-based): 10 boxes per chapter, chapters never end.
func section_chapter(section: String) -> int:
	return section_boxes(section) / Content.BOXES_PER_CHAPTER + 1


## Maths gets harder every two chapters; questions sections stay at level 1.
func section_level(section: String) -> int:
	if section != "math":
		return 1
	return clampi(1 + (section_chapter(section) - 1) / 2, 1, 5)


## Next box of a section. Questions come from the no-repeat deck and are taken now,
## so even an unfinished box never gives the same questions again.
func next_section_box(section: String) -> Dictionary:
	var info: Dictionary = section_info(section)
	var deck: Dictionary = info["deck"]
	var picks: Array = []
	if section != "math":
		for q in 3:
			picks.append(QuestionDeck.next_question(deck, section, int(GameState.data["install_seed"]), q == 0))
	var box_no: int = section_boxes(section) + int(deck.get("started", 0)) + 1
	deck["started"] = int(deck.get("started", 0)) + 1
	var seed_value: int = Rng.derive(int(GameState.data["install_seed"]), box_no, ["islam", "gk", "math"].find(section) + 41)
	return MissionGen.generate_section_box(section, seed_value, section_level(section), picks)


func start_section(section: String) -> void:
	GameState.data["section_ref"] = section
	GameState.start_mission(next_section_box(section), "section")


func rewards_won() -> int:
	return int(GameState.data.get("rewards_won", 0))


## "quiz" (easy questions, default) or "puzzles" (mechanical locks), from Settings.
func lock_mode() -> String:
	var m: String = str((GameState.data["settings"] as Dictionary).get("locks", "quiz"))
	return m if MissionGen.MODES.has(m) else "quiz"


func current_difficulty() -> int:
	return clampi(int(round(float(GameState.data["rating"]))), 1, 5)


## Next endless round: seed = install seed + round number, so it is reproducible.
func next_endless() -> Dictionary:
	var round_no: int = int(GameState.data["round"]) + 1
	var recent_sigs: Array = GameState.data["recent_signatures"]
	var mission: Dictionary = {}
	var recent_q: Array = GameState.data.get("recent_questions", [])
	for attempt in 12:
		var seed_value: int = Rng.derive(int(GameState.data["install_seed"]), round_no, attempt)
		mission = MissionGen.generate_mission(seed_value, current_difficulty(), GameState.data["recent_types"], lock_mode(), recent_q)
		if bool(mission["valid"]) and not recent_sigs.has(mission["signature"]):
			break
	recent_q.append_array(MissionGen.question_keys(mission))
	GameState.data["recent_questions"] = recent_q.slice(maxi(0, recent_q.size() - RECENT_QUESTIONS_KEPT))
	return mission


## Local daily challenge: same box for everyone on the same date (server version in Phase 6).
func daily() -> Dictionary:
	var d: Dictionary = Time.get_date_dict_from_system()
	var seed_value: int = int(d["year"]) * 10000 + int(d["month"]) * 100 + int(d["day"])
	return MissionGen.generate_mission(seed_value, 3, [], "quiz")


func today_key() -> String:
	return Time.get_date_string_from_system()


func yesterday_key() -> String:
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) - 86400)


# ---------------------------------------------------------------- chapters

## Box `index` (0-based) of a chapter: a fixed seed, identical for every player.
func chapter_mission(chapter_id: int, index: int) -> Dictionary:
	var chapter: Dictionary = Content.chapter(chapter_id)
	var level: int = int((chapter["levels"] as Array)[index])
	var mission: Dictionary = {}
	for attempt in 8:
		mission = MissionGen.generate_mission(500000 + chapter_id * 1000 + index + attempt * 37, level, [], lock_mode())
		if bool(mission["valid"]):
			break
	mission["visual"]["backdrop"] = chapter["backdrop"]
	return mission


func start_chapter(chapter_id: int, index: int) -> void:
	GameState.start_mission(chapter_mission(chapter_id, index), "chapter")
	GameState.data["chapter_ref"] = [chapter_id, index]
	GameState.save_game()


func chapter_done(chapter_id: int) -> Array:
	var all: Dictionary = GameState.data["chapters"]
	return all.get(str(chapter_id), [])


func is_box_done(chapter_id: int, index: int) -> bool:
	for v in chapter_done(chapter_id):
		if int(v) == index:
			return true
	return false


func is_chapter_unlocked(chapter_id: int) -> bool:
	if chapter_id <= 1:
		return true
	return chapter_done(chapter_id - 1).size() >= Content.UNLOCK_NEEDED


# ------------------------------------------------------------ stats / awards

## Named statistic used by achievements (see Content.ACHIEVEMENTS).
func stat(stat_name: String) -> int:
	var stats: Dictionary = GameState.data["stats"]
	if stat_name.begins_with("chapter:"):
		return chapter_done(int(stat_name.get_slice(":", 1))).size()
	if stat_name.begins_with("sec:"):
		return section_boxes(stat_name.get_slice(":", 1))
	if stat_name == "rewards":
		return rewards_won()
	if stat_name == "types":
		return (stats["by_type"] as Dictionary).size()
	return int(stats.get(stat_name, 0))


func has_achievement(id: String) -> bool:
	return (GameState.data["achievements"] as Array).has(id)


func hint_tokens() -> int:
	return int(GameState.data["inventory"]["hints"])


func spend_hint() -> bool:
	if hint_tokens() <= 0:
		return false
	GameState.data["inventory"]["hints"] = hint_tokens() - 1
	return true


func add_hints(amount: int) -> void:
	GameState.data["inventory"]["hints"] = mini(MAX_HINT_TOKENS, hint_tokens() + amount)


## Journal notes that are open now (see Content.JOURNAL).
func journal_unlocked(entry: Dictionary) -> bool:
	return chapter_done(int(entry["chapter"])).size() >= int(entry["need"])


## Records a finished mission and adapts difficulty fairly to the player's performance.
## Returns {"delta", "rating", "tokens", "new_achievements"}.
func complete(mission: Dictionary, time_sec: float, hints: int) -> Dictionary:
	var d: Dictionary = GameState.data
	var mode: String = str(d["mode"])
	var diff: int = int(mission["difficulty"])
	var stage_count: int = (mission["stages"] as Array).size()
	var expected: float = 50.0 * float(diff) * float(stage_count)
	var delta: float = 0.1
	if hints == 0 and time_sec <= expected:
		delta = 0.34
	elif hints >= 2 or time_sec > expected * 2.5:
		delta = -0.34
	var tokens: int = 1
	var stats: Dictionary = d["stats"]
	if mode == "endless":
		d["rating"] = clampf(float(d["rating"]) + delta, 1.0, 5.0)
		d["round"] = int(d["round"]) + 1
	elif mode == "daily":
		tokens = 2
		if str(d["daily_done"]) != today_key():
			if str(d["daily_done"]) == yesterday_key():
				stats["daily_streak"] = int(stats["daily_streak"]) + 1
			else:
				stats["daily_streak"] = 1
			stats["daily_best"] = maxi(int(stats["daily_best"]), int(stats["daily_streak"]))
		d["daily_done"] = today_key()
	elif mode == "weekly":
		var weekly_done: Array = d["online"]["weekly_done"]
		var server_id: String = str(mission.get("server_id", ""))
		if weekly_done.has(server_id):
			tokens = 0
		else:
			weekly_done.append(server_id)
			while weekly_done.size() > 40:
				weekly_done.pop_front()
	elif mode == "section":
		var sec: String = str(mission.get("section", d.get("section_ref", "islam")))
		if d["sections"].has(sec):
			d["sections"][sec]["boxes"] = section_boxes(sec) + 1
	elif mode == "chapter":
		var ref: Array = d.get("chapter_ref", [1, 0])
		var chapter_id: int = int(ref[0])
		var index: int = int(ref[1])
		if not is_box_done(chapter_id, index):
			var done: Array = chapter_done(chapter_id).duplicate()
			done.append(index)
			d["chapters"][str(chapter_id)] = done
			(d["inventory"]["artifacts"] as Array).append("%d-%d" % [chapter_id, index])
		else:
			tokens = 0
	var types: Array = d["recent_types"]
	var by_type: Dictionary = stats["by_type"]
	for t in mission.get("types", []):
		types.append(t)
		by_type[str(t)] = int(by_type.get(str(t), 0)) + 1
	while types.size() > RECENT_TYPES_KEPT:
		types.pop_front()
	var sigs: Array = d["recent_signatures"]
	sigs.append(mission["signature"])
	while sigs.size() > RECENT_SIGNATURES_KEPT:
		sigs.pop_front()
	stats["solved"] = int(stats["solved"]) + 1
	stats["hints"] = int(stats["hints"]) + hints
	stats["total_time"] = float(stats["total_time"]) + time_sec
	if hints == 0:
		stats["no_hint"] = int(stats["no_hint"]) + 1
	if time_sec <= FAST_SECONDS:
		stats["fast"] = int(stats["fast"]) + 1
	if float(stats["best_time"]) <= 0.0 or time_sec < float(stats["best_time"]):
		stats["best_time"] = time_sec
	add_hints(tokens)
	# Prize every BOXES_PER_REWARD boxes, until every prize is won.
	var new_reward: int = -1
	var can_win: int = mini(Content.rewards().size(), int(stats["solved"]) / Content.BOXES_PER_REWARD)
	if can_win > rewards_won():
		new_reward = rewards_won()
		d["rewards_won"] = rewards_won() + 1
	var unlocked: Array = []
	for ach in Content.ACHIEVEMENTS:
		var id: String = str(ach["id"])
		if not has_achievement(id) and stat(str(ach["stat"])) >= int(ach["need"]):
			(d["achievements"] as Array).append(id)
			unlocked.append(id)
	d["current_mission"] = null
	d["current_stage"] = 0
	GameState.save_game()
	# Online (does nothing when no server is set up or the network is down).
	Online.report_completion(mission, time_sec, hints)
	Ads.box_finished()
	Analytics.track("box_complete", {"mode": mode, "difficulty": diff, "seconds": int(time_sec), "hints": hints})
	Online.sync_progress()
	return {"delta": delta, "rating": float(d["rating"]), "tokens": tokens, "new_achievements": unlocked, "new_reward": new_reward}
