extends SceneTree
## Headless batch test.
## Run from the project folder:
##   godot --headless --path . -s tests/batch_test.gd
##   godot --headless --path . -s tests/batch_test.gd -- 50000
## Exit code 0 = PASS, 1 = FAIL. Report is also saved to user://batch_report.json

const Tester = preload("res://scripts/pcg/BatchTester.gd")


func _init() -> void:
	var total: int = 10000
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int():
			total = int(arg)
	var report: Dictionary = Tester.new_report()
	for i in total:
		Tester.test_puzzle(report, i)
	for i in int(total / 10):
		Tester.test_mission(report, i)
	print(Tester.summary(report))
	var out: Dictionary = report.duplicate()
	out.erase("signatures")
	var f: FileAccess = FileAccess.open("user://batch_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
	quit(0 if Tester.passed(report) else 1)
