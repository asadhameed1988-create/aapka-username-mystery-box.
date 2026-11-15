extends Control
## In-game generator test (small batch, runs on the phone itself).
## The full 10,000 run is tests/batch_test.gd (headless).

const Ui = preload("res://scripts/ui/UiKit.gd")
const Tester = preload("res://scripts/pcg/BatchTester.gd")

const PUZZLES := 600
const MISSIONS := 60

var _out: Label


func _ready() -> void:
	theme = Ui.make_theme()
	Ui.background(self)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 40)
	add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	margin.add_child(box)
	var back: Button = Ui.button(Loc.t("back"))
	back.pressed.connect(_back)
	box.add_child(back)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_out = Ui.label("", 28, Ui.TEXT)
	_out.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	scroll.add_child(_out)
	_run()


func _run() -> void:
	var report: Dictionary = Tester.new_report()
	for i in PUZZLES:
		Tester.test_puzzle(report, i)
		if i % 15 == 0:
			_out.text = Loc.t("test_running", [i, PUZZLES])
			await get_tree().process_frame
			if not is_inside_tree():
				return
	for i in MISSIONS:
		Tester.test_mission(report, i)
	_out.text = Tester.summary(report)


func _back() -> void:
	Fx.go("res://scenes/MainMenu.tscn")
