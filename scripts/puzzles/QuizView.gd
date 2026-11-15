extends VBoxContainer
## Screen for the easy question locks: "quiz" (Islamic / general knowledge) and "math".
## Three big answer buttons. A wrong answer is greyed out and the player tries again.

signal solved

const Ui = preload("res://scripts/ui/UiKit.gd")
const QuizGen = preload("res://scripts/pcg/QuizGenerator.gd")
const MathGen = preload("res://scripts/pcg/MathGenerator.gd")

var mistakes: int = 0   # read by Game.gd

var _answer_index: int = 0
var _buttons: Array = []
var _feedback: Label
var _done: bool = false


func setup(spec: Dictionary) -> void:
	add_theme_constant_override("separation", 22)
	_answer_index = int((spec["solution"] as Array)[0])
	var heading: String
	var question: String
	var answers: Array = []
	if str(spec["type"]) == "math":
		heading = Loc.t("find_x") if MathGen.is_equation(spec) else Loc.t("cat_math")
		question = MathGen.question_text(spec)
		for v in spec["params"]["options"]:
			answers.append(str(int(v)))
	else:
		var cat: String = str(spec["params"]["cat"])
		heading = Loc.t("cat_islam") if cat == "islam" else Loc.t("cat_gk")
		var t: Dictionary = QuizGen.texts(spec, GameState.lang())
		question = str(t["question"])
		answers = t["answers"]
	add_child(Ui.label(heading, 30, Ui.MUTED))
	var q: Label = Ui.label(question, 72 if str(spec["type"]) == "math" else 44, Ui.GOLD)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(q)
	for i in answers.size():
		var b: Button = Ui.button(str(answers[i]))
		b.custom_minimum_size = Vector2(0, 130)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 42)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_choose.bind(i))
		add_child(b)
		_buttons.append(b)
	_feedback = Ui.label("", 34, Ui.BAD)
	add_child(_feedback)


func _choose(index: int) -> void:
	if _done:
		return
	if index == _answer_index:
		_done = true
		(_buttons[index] as Button).add_theme_color_override("font_color", Ui.GOOD)
		_feedback.add_theme_color_override("font_color", Ui.GOOD)
		_feedback.text = Loc.t("quiz_right")
		await get_tree().create_timer(0.6).timeout
		solved.emit()
		return
	mistakes += 1
	Fx.play("wrong")
	(_buttons[index] as Button).disabled = true
	_feedback.text = Loc.t("quiz_wrong")


## Removes one wrong answer.
func hint() -> String:
	for i in _buttons.size():
		var b: Button = _buttons[i]
		if i != _answer_index and not b.disabled:
			b.disabled = true
			return Loc.t("choice_hint")
	return ""
