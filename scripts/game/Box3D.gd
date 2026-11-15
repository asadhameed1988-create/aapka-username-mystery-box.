extends Node3D
## A REAL 3D mystery box built from primitive meshes (procedural geometry).
## It can be turned freely and its lid opens on a hinge.
## Materials use the approved textures (MB-006 wood, MB-007 brass), tinted per
## material key, with triplanar mapping so they tile on every face. If a texture
## file is missing, the flat "body"/"trim" colour is used instead.
## The shape itself is still simple; a Blender .glb model can replace it later.

const WOOD_TEX := "res://assets/tex/tex_walnut_inlay.jpg"
const BRASS_TEX := "res://assets/tex/tex_brass_engraved.jpg"

const MATERIALS := {
	"walnut_inlay": {
		"body": Color(0.36, 0.21, 0.11), "trim": Color(0.80, 0.62, 0.25), "metal": 0.0, "rough": 0.55,
		"body_tex": WOOD_TEX, "body_tint": Color(1.0, 1.0, 1.0), "trim_tex": BRASS_TEX, "trim_tint": Color(1.0, 1.0, 1.0),
	},
	"brass_engraved": {
		"body": Color(0.72, 0.53, 0.20), "trim": Color(0.33, 0.20, 0.09), "metal": 0.8, "rough": 0.35,
		"body_tex": BRASS_TEX, "body_tint": Color(1.0, 1.0, 1.0), "trim_tex": "", "trim_tint": Color(1.0, 1.0, 1.0),
	},
	"ebony_pearl": {
		"body": Color(0.09, 0.08, 0.08), "trim": Color(0.90, 0.88, 0.80), "metal": 0.1, "rough": 0.4,
		"body_tex": WOOD_TEX, "body_tint": Color(0.34, 0.32, 0.34), "trim_tex": "", "trim_tint": Color(1.0, 1.0, 1.0),
	},
	"gold_damascene": {
		"body": Color(0.85, 0.66, 0.22), "trim": Color(0.13, 0.11, 0.11), "metal": 0.9, "rough": 0.25,
		"body_tex": BRASS_TEX, "body_tint": Color(1.0, 0.95, 0.75), "trim_tex": "", "trim_tint": Color(1.0, 1.0, 1.0),
	},
	"cedar_copper": {
		"body": Color(0.50, 0.28, 0.14), "trim": Color(0.72, 0.40, 0.22), "metal": 0.0, "rough": 0.65,
		"body_tex": WOOD_TEX, "body_tint": Color(1.0, 0.82, 0.66), "trim_tex": BRASS_TEX, "trim_tint": Color(1.0, 0.72, 0.58),
	},
}

const LIGHTS := {
	"lantern_warm": {"light": Color(1.0, 0.84, 0.62), "ambient": Color(0.34, 0.25, 0.18), "bg": Color(0.10, 0.07, 0.05)},
	"moonlit_cool": {"light": Color(0.75, 0.84, 1.0), "ambient": Color(0.18, 0.22, 0.32), "bg": Color(0.04, 0.06, 0.11)},
	"dawn_gold": {"light": Color(1.0, 0.90, 0.70), "ambient": Color(0.36, 0.30, 0.22), "bg": Color(0.13, 0.10, 0.07)},
}

var _pivot: Node3D
var _lid_pivot: Node3D
var _glow: OmniLight3D
var _yaw: float = -0.5
var _pitch: float = 0.0
var _time: float = 0.0
var _idle: float = 0.0          # seconds since the player last turned the box
var _sparks: CPUParticles3D


func build(visual: Dictionary, transparent_background: bool = false, effects: bool = true) -> void:
	var mat_cfg: Dictionary = MATERIALS.get(str(visual.get("material", "")), MATERIALS["walnut_inlay"])
	var light_cfg: Dictionary = LIGHTS.get(str(visual.get("light", "")), LIGHTS["lantern_warm"])
	var body: StandardMaterial3D = _material(mat_cfg["body"], float(mat_cfg["metal"]), float(mat_cfg["rough"]),
		str(mat_cfg["body_tex"]), mat_cfg["body_tint"])
	var trim: StandardMaterial3D = _material(mat_cfg["trim"], 0.85, 0.3, str(mat_cfg["trim_tex"]), mat_cfg["trim_tint"])

	_pivot = Node3D.new()
	add_child(_pivot)
	_add_box(_pivot, Vector3(2.0, 1.0, 1.4), Vector3(0.0, 0.5, 0.0), body)
	_add_box(_pivot, Vector3(2.05, 0.08, 1.45), Vector3(0.0, 0.08, 0.0), trim)
	_add_box(_pivot, Vector3(2.05, 0.08, 1.45), Vector3(0.0, 0.93, 0.0), trim)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_box(_pivot, Vector3(0.12, 1.0, 0.12), Vector3(sx * 0.98, 0.5, sz * 0.68), trim)
			var foot: MeshInstance3D = MeshInstance3D.new()
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.11
			sphere.height = 0.22
			foot.mesh = sphere
			foot.material_override = trim
			foot.position = Vector3(sx * 0.9, -0.05, sz * 0.6)
			_pivot.add_child(foot)

	# Lock plate on the front face.
	var lock: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.2
	cyl.height = 0.06
	lock.mesh = cyl
	lock.material_override = trim
	lock.rotation.x = PI * 0.5
	lock.position = Vector3(0.0, 0.6, 0.72)
	_pivot.add_child(lock)

	# Lid on a hinge at the back top edge.
	_lid_pivot = Node3D.new()
	_lid_pivot.position = Vector3(0.0, 1.0, -0.7)
	_pivot.add_child(_lid_pivot)
	_add_box(_lid_pivot, Vector3(2.06, 0.28, 1.46), Vector3(0.0, 0.14, 0.7), body)
	_add_box(_lid_pivot, Vector3(2.1, 0.06, 1.5), Vector3(0.0, 0.03, 0.7), trim)
	# Eight-point star inlay (two crossed squares) on the lid.
	_add_box(_lid_pivot, Vector3(0.62, 0.02, 0.62), Vector3(0.0, 0.285, 0.7), trim)
	var star_b: MeshInstance3D = _add_box(_lid_pivot, Vector3(0.62, 0.02, 0.62), Vector3(0.0, 0.286, 0.7), trim)
	star_b.rotation.y = PI * 0.25

	_glow = OmniLight3D.new()
	_glow.position = Vector3(0.0, 0.8, 0.0)
	_glow.light_color = Color(1.0, 0.85, 0.45)
	_glow.light_energy = 0.0
	_glow.omni_range = 5.0
	_pivot.add_child(_glow)

	if effects:
		# Golden sparks released when the lid opens.
		_sparks = CPUParticles3D.new()
		_sparks.position = Vector3(0.0, 1.0, 0.0)
		_sparks.emitting = false
		_sparks.one_shot = true
		_sparks.amount = 36
		_sparks.lifetime = 1.3
		_sparks.explosiveness = 0.85
		_sparks.direction = Vector3(0.0, 1.0, 0.0)
		_sparks.spread = 55.0
		_sparks.initial_velocity_min = 1.6
		_sparks.initial_velocity_max = 3.2
		_sparks.gravity = Vector3(0.0, -3.5, 0.0)
		var spark_mesh: SphereMesh = SphereMesh.new()
		spark_mesh.radius = 0.035
		spark_mesh.height = 0.07
		var spark_mat: StandardMaterial3D = StandardMaterial3D.new()
		spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark_mat.albedo_color = Color(1.0, 0.86, 0.45)
		spark_mesh.material = spark_mat
		_sparks.mesh = spark_mesh
		_pivot.add_child(_sparks)

	var cam: Camera3D = Camera3D.new()
	var cam_pos: Vector3 = Vector3(0.0, 2.3, 4.6)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.65, 0.0) - cam_pos, Vector3.UP), cam_pos)
	cam.fov = 40.0
	cam.current = true
	add_child(cam)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_color = light_cfg["light"]
	sun.light_energy = 1.3
	add_child(sun)

	var env: Environment = Environment.new()
	if transparent_background:
		# Lets the 2D chapter background show behind the box.
		env.background_mode = Environment.BG_CLEAR_COLOR
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = light_cfg["bg"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = light_cfg["ambient"]
	env.ambient_light_energy = 1.0
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_apply_rotation()


## Called with the finger/mouse drag distance in pixels.
func rotate_by(rel: Vector2) -> void:
	_yaw += rel.x * 0.008
	_pitch = clampf(_pitch + rel.y * 0.006, -0.45, 0.75)
	_idle = 0.0
	_apply_rotation()


func _process(delta: float) -> void:
	# Gentle sway while the player is not turning the box.
	_time += delta
	_idle += delta
	if _idle > 1.5:
		_apply_rotation()


func pulse() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_pivot, "scale", Vector3(1.06, 1.06, 1.06), 0.12)
	tw.tween_property(_pivot, "scale", Vector3.ONE, 0.18)


func open_lid() -> void:
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_lid_pivot, "rotation:x", deg_to_rad(-105.0), 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_glow, "light_energy", 3.0, 1.4)
	if _sparks != null:
		_sparks.emitting = true


func _apply_rotation() -> void:
	if _pivot != null:
		var sway: float = 0.0
		if _idle > 1.5:
			sway = sin(_time * 0.7) * 0.07
		_pivot.rotation = Vector3(_pitch, _yaw + sway, 0.0)


func _material(color: Color, metallic: float, roughness: float, tex_path: String = "", tint: Color = Color(1.0, 1.0, 1.0)) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	if tex_path != "" and ResourceLoader.exists(tex_path):
		m.albedo_texture = load(tex_path) as Texture2D
		m.albedo_color = tint
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.8, 0.8, 0.8)
	return m


func _add_box(parent: Node3D, box_size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
