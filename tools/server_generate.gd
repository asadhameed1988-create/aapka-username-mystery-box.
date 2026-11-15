extends SceneTree
## Server-side mission generation (run by backend/app/generator.py).
##   godot --headless --path <project> -s res://tools/server_generate.gd -- <out_file> <difficulty> <seed> [<seed> ...]
## Writes a JSON array of missions to <out_file>. Exit code 0 = file written.

const ServerExport = preload("res://scripts/pcg/ServerExport.gd")


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr("usage: -- <out_file> <difficulty> <seed> [<seed> ...]")
		quit(2)
		return
	var seeds: Array = []
	for i in range(2, args.size()):
		seeds.append(int(args[i]))
	var missions: Array = ServerExport.build(seeds, int(args[1]))
	var f: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	if f == null:
		printerr("cannot write ", args[0])
		quit(3)
		return
	f.store_string(JSON.stringify(missions))
	f.close()
	quit(0)
