extends VBoxContainer
## Screen for the question locks: "quiz" (Islamic / general knowledge) and "math".
## Single-answer questions: tap an answer; a wrong one is greyed out and the player tries again.
## "Choose all" questions: tap to select several answers, then Check.
## A language bar lets the player read the question in Urdu, English or Arabic.
## Islamic questions show their reference (Quran / hadith / fiqh book) after the right answer.

signal solved

const Ui = preload("res://scripts/ui/UiKit.gd")
const QuizGen = preload("res://scripts/pcg/QuizGenerator.gd")
const MathGen = preload("res://scripts/pcg/MathGenerator.gd")

const SELECTED := Color(0.98, 0.84, 0.45)

var mistakes: int = 0   # read by Game.gd

var _spec: Dictionary = {}
var _right: Array = []          # display indices of the right answers
var _multi: bool = false
var _selected: Dictionary = {}  # display index -> true (multi only)
var _ruled_out: Dictionary = {} # display index -> true (wrong answers already greyed)
var _buttons: Array = []
var _feedback: Label
var _done: bool = false
var _reference: Dictionary = {}


func setup(spec: Dictionary) -> void:
	_spec = spec
	add_theme_constant_override("separation", 20)
	_right = []
	for v in spec["solution"]:
		_right.append(int(v))
	_multi = str(spec["type"]) == "quiz" and QuizGen.is_multi(spec)
	if str(spec["type"]) == "quiz":
		_reference = QuizGen.reference_of(spec)
	_render()


## Language used for question text: the player's choice, else the game language.
static func question_lang() -> String:
	var q: String = str((GameState.data["settings"] as Dictionary).get("qlang", ""))
	return q if QuizGen.LANGS.has(q) else GameState.lang()


func _render() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_buttons.clear()
	var heading: String
	var question: String
	var answers: Array = []
	var lang: String = question_lang()
	if str(_spec["type"]) == "math":
		heading = Loc.t("find_x") if MathGen.is_equation(_spec) else Loc.t("cat_math")
		question = MathGen.question_text(_spec)
		for v in _spec["params"]["options"]:
			answers.append(str(int(v)))
	else:
		var cat: String = str(_spec["params"]["cat"])
		heading = Loc.t("cat_islam") if cat == "islam" else Loc.t("cat_gk")
		var t: Dictionary = QuizGen.texts(_spec, lang)
		question = str(t["question"])
		answers = t["answers"]
		add_child(_language_bar())
	add_child(Ui.label(heading, 30, Ui.MUTED))
	var q: Label = Ui.label(question, 72 if str(_spec["type"]) == "math" else 42, Ui.GOLD)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(q)
	if _multi:
		var how: Label = Ui.label(Loc.t("choose_all"), 30, Ui.TEXT)
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(how)
	var many: bool = answers.size() > 3
	for i in answers.size():
		var b: Button = Ui.button(str(answers[i]))
		b.custom_minimum_size = Vector2(0, 100 if many else 128)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 34 if many else 40)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_choose.bind(i))
		b.disabled = _ruled_out.has(i) or (_done and not _right.has(i))
		if _selected.has(i) or (_done and _right.has(i)):
			b.add_theme_color_override("font_color", Ui.GOOD if _done else SELECTED)
			b.add_theme_color_override("font_disabled_color", Ui.GOOD if _done else SELECTED)
		add_child(b)
		_buttons.append(b)
	if _multi and not _done:
		var check: Button = Ui.button(Loc.t("check"))
		check.pressed.connect(_check_multi)
		add_child(check)
	_feedback = Ui.label("", 32, Ui.BAD)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_feedback)
	if _done:
		_show_done()


## Small Urdu / English / Arabic switch for the question text.
func _language_bar() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var current: String = question_lang()
	for pair in [["ur", "اردو"], ["en", "English"], ["ar", "عربي"]]:
		var code: String = str(pair[0])
		var b: Button = Ui.button(str(pair[1]))
		b.custom_minimum_size = Vector2(170, 70)
		b.add_theme_font_size_override("font_size", 28)
		if code == current:
			b.add_theme_color_override("font_color", SELECTED)
		else:
			b.modulate = Color(1, 1, 1, 0.55)
		b.pressed.connect(func() -> void:
			GameState.data["settings"]["qlang"] = code
			GameState.save_game()
			_render())
		row.add_child(b)
	return row


func _choose(index: int) -> void:
	if _done:
		return
	if _multi:
		if _selected.has(index):
			_selected.erase(index)
		else:
			_selected[index] = true
		Fx.play("tap")
		_render()
		return
	if _right.has(index):
		_done = true
		_render()
		return
	mistakes += 1
	Fx.play("wrong")
	_ruled_out[index] = true
	(_buttons[index] as Button).disabled = true
	_feedback.text = Loc.t("quiz_wrong")


func _check_multi() -> void:
	var picked: Array = _selected.keys()
	picked.sort()
	var want: Array = _right.duplicate()
	want.sort()
	if picked == want:
		_done = true
		_render()
		return
	mistakes += 1
	Fx.play("wrong")
	# Grey out the wrong ones the player picked; keep the right picks selected.
	for i in picked:
		if not _right.has(int(i)):
			_selected.erase(i)
			_ruled_out[int(i)] = true
	_render()
	_feedback.text = Loc.t("multi_wrong")


func _show_done() -> void:
	_feedback.add_theme_color_override("font_color", Ui.GOOD)
	_feedback.text = Loc.t("quiz_right")
	if _reference.is_empty():
		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			if is_inside_tree():
				solved.emit(), CONNECT_ONE_SHOT)
		return
	# Islamic question: show the reference, then continue when the player is ready.
	add_child(reference_panel(_reference))
	var next: Button = Ui.button(Loc.t("quiz_next"))
	next.pressed.connect(func() -> void: solved.emit())
	add_child(next)


## Panel with the Arabic reference line(s), the same in the player's language and, for
## hadiths, the Arabic text with its English translation (scrollable).
static func reference_panel(ref: Dictionary) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.85)
	style.border_color = Color(0.85, 0.68, 0.32)
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(Ui.label(Loc.t("reference"), 28, Ui.MUTED))
	var ar: Label = Ui.label(str(ref["ar"]), 34, Ui.GOLD)
	ar.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(ar)
	var local: Label = Ui.label(str(ref.get(GameState.lang(), ref["en"])), 27, Ui.TEXT)
	local.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	local.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(local)
	var hadiths: Array = ref.get("hadith", [])
	for h in hadiths:
		var title: Label = Ui.label(Loc.t("hadith_text", [int(h["num"])]), 26, Ui.MUTED)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(title)
		var h_ar: Label = Ui.label(str(h["ar"]), 30, Color(0.98, 0.9, 0.7))
		h_ar.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h_ar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(h_ar)
		var h_en: Label = Ui.label(str(h["en"]), 25, Ui.TEXT)
		h_en.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h_en.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(h_en)
	if hadiths.is_empty():
		panel.add_child(col)
		return panel
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 460)
	scroll.add_child(col)
	panel.add_child(scroll)
	return panel


## Hint: grey out one wrong answer (single) or one wrong, unselected answer (multi).
func hint() -> String:
	if _done:
		return ""
	for i in _buttons.size():
		if not _right.has(i) and not _ruled_out.has(i):
			_ruled_out[i] = true
			_selected.erase(i)
			_render()
			return Loc.t("choice_hint")
	return ""
