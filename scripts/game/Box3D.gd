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

const SYMBOLS_TEX := "res://assets/ui/symbols_sheet.png"   # 4 x 2 cells (owner's art)
const COIN_COLORS := {"gold": Color(1.0, 0.78, 0.30), "silver": Color(0.86, 0.88, 0.93)}

var _pivot: Node3D
var _lid_pivot: Node3D
var _glow: OmniLight3D
var _yaw: float = -0.5
var _pitch: float = 0.0
var _time: float = 0.0
var _idle: float = 0.0          # seconds since the player last turned the box
var _sparks: CPUParticles3D
var _inner_glow: StandardMaterial3D
var _effects: bool = true
var _symbol: int = 0


func build(visual: Dictionary, transparent_background: bool = false, effects: bool = true) -> void:
	_effects = effects
	var mat_cfg: Dictionary = MATERIALS.get(str(visual.get("material", "")), MATERIALS["walnut_inlay"])
	var light_cfg: Dictionary = LIGHTS.get(str(visual.get("light", "")), LIGHTS["lantern_warm"])
	_symbol = absi(str(visual.get("material", "")).hash() + str(visual.get("backdrop", "")).hash()) % 8
	var body: StandardMaterial3D = _material(mat_cfg["body"], float(mat_cfg["metal"]), float(mat_cfg["rough"]),
		str(mat_cfg["body_tex"]), mat_cfg["body_tint"])
	var trim: StandardMaterial3D = _material(mat_cfg["trim"], 0.9, 0.28, str(mat_cfg["trim_tex"]), mat_cfg["trim_tint"])
	trim.rim_enabled = true
	trim.rim = 0.25
	var dark_trim: StandardMaterial3D = _material(Color(0.30, 0.18, 0.09), 0.1, 0.45, WOOD_TEX, Color(0.62, 0.5, 0.42))
	var pearl: StandardMaterial3D = _material(Color(0.95, 0.93, 0.88), 0.15, 0.12)
	pearl.emission_enabled = true
	pearl.emission = Color(0.55, 0.52, 0.48)
	pearl.emission_energy_multiplier = 0.35
	pearl.rim_enabled = true
	pearl.rim = 0.6
	pearl.rim_tint = 0.2
	var velvet: StandardMaterial3D = _material(Color(0.42, 0.04, 0.07), 0.0, 1.0)
	var keyhole: StandardMaterial3D = _material(Color(0.02, 0.015, 0.01), 0.0, 1.0)

	_pivot = Node3D.new()
	add_child(_pivot)

	# --- body: carcass, plinth, bands, raised framed panels ---------------------
	_add_box(_pivot, Vector3(2.0, 0.92, 1.4), Vector3(0.0, 0.54, 0.0), body)
	_add_box(_pivot, Vector3(2.14, 0.12, 1.54), Vector3(0.0, 0.06, 0.0), body)          # plinth
	_add_box(_pivot, Vector3(2.18, 0.035, 1.58), Vector3(0.0, 0.125, 0.0), trim)       # plinth moulding
	_add_box(_pivot, Vector3(2.04, 0.06, 1.44), Vector3(0.0, 0.97, 0.0), trim)          # top band
	_add_box(_pivot, Vector3(2.04, 0.04, 1.44), Vector3(0.0, 0.52, 0.0), trim)          # middle band
	for side in [-1.0, 1.0]:
		# Front / back framed panels (brass frame around a darker sunken field).
		_add_box(_pivot, Vector3(1.5, 0.30, 0.02), Vector3(0.0, 0.74, side * 0.71), dark_trim)
		_frame(_pivot, Vector3(0.0, 0.74, side * 0.715), Vector2(1.56, 0.36), 0.035, trim, false)
		_add_box(_pivot, Vector3(1.5, 0.26, 0.02), Vector3(0.0, 0.32, side * 0.71), dark_trim)
		_frame(_pivot, Vector3(0.0, 0.32, side * 0.715), Vector2(1.56, 0.32), 0.035, trim, false)
		# Side panels with a pearl star.
		_add_box(_pivot, Vector3(0.02, 0.70, 1.0), Vector3(side * 1.01, 0.54, 0.0), dark_trim)
		_frame(_pivot, Vector3(side * 1.015, 0.54, 0.0), Vector2(1.06, 0.76), 0.035, trim, true)
		_star(_pivot, Vector3(side * 1.03, 0.54, 0.0), 0.26, pearl, Vector3(0.0, 0.0, PI * 0.5))
		# Brass corner brackets on all four corners, top and bottom.
		for sz in [-1.0, 1.0]:
			for y in [0.24, 0.84]:
				_add_box(_pivot, Vector3(0.22, 0.20, 0.025), Vector3(side * 0.9, y, sz * 0.715), trim)
				_add_box(_pivot, Vector3(0.025, 0.20, 0.22), Vector3(side * 1.015, y, sz * 0.6), trim)
			var foot: MeshInstance3D = MeshInstance3D.new()
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.1
			sphere.height = 0.16
			foot.mesh = sphere
			foot.material_override = trim
			foot.position = Vector3(side * 0.95, -0.04, sz * 0.66)
			_pivot.add_child(foot)

	# --- front: pearl star and the lock plate with a keyhole ---------------------
	_star(_pivot, Vector3(0.0, 0.32, 0.735), 0.17, pearl, Vector3(PI * 0.5, 0.0, 0.0))
	var plate: MeshInstance3D = _cylinder(_pivot, 0.17, 0.035, trim, Vector3(0.0, 0.78, 0.735), Vector3(PI * 0.5, 0.0, 0.0))
	plate.scale = Vector3(1.0, 1.0, 1.25)
	_cylinder(_pivot, 0.035, 0.02, keyhole, Vector3(0.0, 0.81, 0.755), Vector3(PI * 0.5, 0.0, 0.0))
	_add_box(_pivot, Vector3(0.035, 0.09, 0.02), Vector3(0.0, 0.76, 0.755), keyhole)

	# --- inside: velvet lining, a few coins and a warm glow ----------------------
	_add_box(_pivot, Vector3(1.86, 0.02, 1.26), Vector3(0.0, 1.0, 0.0), velvet)
	_inner_glow = StandardMaterial3D.new()
	_inner_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_inner_glow.albedo_color = Color(1.0, 0.75, 0.3, 0.0)
	_inner_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_inner_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_add_box(_pivot, Vector3(1.8, 0.01, 1.2), Vector3(0.0, 1.02, 0.0), _inner_glow)
	var pile_gold: StandardMaterial3D = _coin_material(COIN_COLORS["gold"])
	var pile_mesh: CylinderMesh = CylinderMesh.new()
	pile_mesh.top_radius = 0.085
	pile_mesh.bottom_radius = 0.085
	pile_mesh.height = 0.02
	for k in 9:
		var c: MeshInstance3D = MeshInstance3D.new()
		c.mesh = pile_mesh
		c.material_override = pile_gold
		c.position = Vector3(-0.5 + float(k % 5) * 0.24, 1.02 + float(k / 5) * 0.02, -0.25 + float((k * 7) % 5) * 0.12)
		c.rotation = Vector3(float(k % 3) * 0.12, float(k) * 0.7, 0.0)
		_pivot.add_child(c)

	# --- lid on a hinge: two tiers, band, pearl star in a brass ring, hasp --------
	_lid_pivot = Node3D.new()
	_lid_pivot.position = Vector3(0.0, 1.0, -0.72)
	_pivot.add_child(_lid_pivot)
	_add_box(_lid_pivot, Vector3(2.08, 0.18, 1.48), Vector3(0.0, 0.09, 0.72), body)
	_add_box(_lid_pivot, Vector3(2.12, 0.05, 1.52), Vector3(0.0, 0.025, 0.72), trim)
	_add_box(_lid_pivot, Vector3(1.84, 0.12, 1.24), Vector3(0.0, 0.24, 0.72), body)
	_add_box(_lid_pivot, Vector3(1.88, 0.03, 1.28), Vector3(0.0, 0.18, 0.72), trim)
	_add_box(_lid_pivot, Vector3(1.6, 0.06, 1.0), Vector3(0.0, 0.33, 0.72), body)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.36
	torus.outer_radius = 0.42
	ring.mesh = torus
	ring.material_override = trim
	ring.position = Vector3(0.0, 0.365, 0.72)
	_lid_pivot.add_child(ring)
	_star(_lid_pivot, Vector3(0.0, 0.37, 0.72), 0.3, pearl, Vector3.ZERO)
	_symbol_inlay(_lid_pivot, Vector3(0.0, 0.385, 0.72), 0.26)
	for sx in [-1.0, 1.0]:
		for sz in [0.08, 1.36]:
			_cylinder(_lid_pivot, 0.05, 0.03, trim, Vector3(sx * 0.82, 0.375, sz), Vector3.ZERO)
	_add_box(_lid_pivot, Vector3(0.14, 0.24, 0.03), Vector3(0.0, -0.04, 1.47), trim)    # hasp over the lock

	_glow = OmniLight3D.new()
	_glow.position = Vector3(0.0, 1.3, 0.0)
	_glow.light_color = Color(1.0, 0.82, 0.45)
	_glow.light_energy = 0.0
	_glow.omni_range = 6.0
	_pivot.add_child(_glow)

	# --- display table (carved wood disc with a brass edge) ----------------------
	var table: MeshInstance3D = _cylinder(self, 1.7, 0.16, _material(Color(0.20, 0.11, 0.05), 0.0, 0.32),
		Vector3(0.0, -0.24, 0.0), Vector3.ZERO)
	table.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var edge: MeshInstance3D = MeshInstance3D.new()
	var edge_mesh: TorusMesh = TorusMesh.new()
	edge_mesh.inner_radius = 1.66
	edge_mesh.outer_radius = 1.74
	edge.mesh = edge_mesh
	edge.material_override = trim
	edge.position = Vector3(0.0, -0.17, 0.0)
	add_child(edge)

	if effects:
		# Golden sparks released when the lid opens.
		_sparks = CPUParticles3D.new()
		_sparks.position = Vector3(0.0, 1.05, 0.0)
		_sparks.emitting = false
		_sparks.one_shot = true
		_sparks.amount = 60
		_sparks.lifetime = 1.6
		_sparks.explosiveness = 0.7
		_sparks.direction = Vector3(0.0, 1.0, 0.0)
		_sparks.spread = 40.0
		_sparks.initial_velocity_min = 1.5
		_sparks.initial_velocity_max = 3.6
		_sparks.gravity = Vector3(0.0, -1.2, 0.0)
		_sparks.scale_amount_min = 0.4
		_sparks.scale_amount_max = 1.2
		var spark_mesh: SphereMesh = SphereMesh.new()
		spark_mesh.radius = 0.025
		spark_mesh.height = 0.05
		var spark_mat: StandardMaterial3D = StandardMaterial3D.new()
		spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spark_mat.albedo_color = Color(1.0, 0.9, 0.55)
		spark_mesh.material = spark_mat
		_sparks.mesh = spark_mesh
		_pivot.add_child(_sparks)

	var cam: Camera3D = Camera3D.new()
	var cam_pos: Vector3 = Vector3(0.0, 2.3, 4.3)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.7, 0.0) - cam_pos, Vector3.UP), cam_pos)
	cam.fov = 42.0
	cam.current = true
	add_child(cam)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_color = light_cfg["light"]
	sun.light_energy = 1.6
	sun.shadow_enabled = effects
	sun.shadow_blur = 2.0
	add_child(sun)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, 160.0, 0.0)
	rim.light_color = Color(0.70, 0.80, 1.0)
	rim.light_energy = 0.55
	add_child(rim)

	var env: Environment = Environment.new()
	if transparent_background:
		# Lets the 2D chapter background show behind the box.
		env.background_mode = Environment.BG_CLEAR_COLOR
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = light_cfg["bg"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = light_cfg["ambient"]
	env.ambient_light_energy = 1.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	if effects:
		env.glow_enabled = true
		env.glow_intensity = 0.7
		env.glow_bloom = 0.08
		env.glow_hdr_threshold = 0.9
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


func open_lid(coin_kind: String = "gold") -> void:
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_lid_pivot, "rotation:x", deg_to_rad(-108.0), 1.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_glow, "light_energy", 3.2, 1.0)
	tw.tween_property(_inner_glow, "albedo_color:a", 0.45, 0.8)
	if _sparks != null:
		_sparks.emitting = true
	if _effects:
		get_tree().create_timer(0.45).timeout.connect(_coin_burst.bind(coin_kind))


## Coins fly up out of the box, spinning, and fall around it.
func _coin_burst(coin_kind: String) -> void:
	if not is_inside_tree():
		return
	var mat: StandardMaterial3D = _coin_material(COIN_COLORS.get(coin_kind, COIN_COLORS["gold"]))
	for wave in 2:
		var p: CPUParticles3D = CPUParticles3D.new()
		p.position = Vector3(0.0, 1.1, 0.0)
		p.mesh = _coin_mesh(mat)
		p.amount = 26 if wave == 0 else 18
		p.lifetime = 2.2
		p.one_shot = true
		p.explosiveness = 0.85
		p.direction = Vector3(0.0, 1.0, 0.0)
		p.spread = 32.0
		p.initial_velocity_min = 3.2
		p.initial_velocity_max = 5.0
		p.gravity = Vector3(0.0, -7.5, 0.0)
		p.particle_flag_rotate_y = true
		p.angle_min = 0.0
		p.angle_max = 360.0
		p.angular_velocity_min = 300.0
		p.angular_velocity_max = 720.0
		p.scale_amount_min = 0.85
		p.scale_amount_max = 1.15
		p.emitting = false
		_pivot.add_child(p)
		get_tree().create_timer(0.35 * wave).timeout.connect(func() -> void:
			if is_instance_valid(p):
				p.emitting = true)
		get_tree().create_timer(3.5 + 0.35 * wave).timeout.connect(func() -> void:
			if is_instance_valid(p):
				p.queue_free())


static func _coin_material(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 1.0
	m.roughness = 0.22
	m.emission_enabled = true
	m.emission = color * 0.35
	m.rim_enabled = true
	m.rim = 0.5
	return m


## A coin standing on its edge (axis along Z), so spinning around Y makes it flip.
static func _coin_mesh(mat: Material) -> ArrayMesh:
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.09
	cyl.bottom_radius = 0.09
	cyl.height = 0.022
	cyl.radial_segments = 20
	cyl.rings = 1
	var arrays: Array = cyl.get_mesh_arrays()
	var rot: Basis = Basis(Vector3.RIGHT, PI * 0.5)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in verts.size():
		verts[i] = rot * verts[i]
		norms[i] = rot * norms[i]
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	return mesh


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


## Eight-point star: two flat squares turned 45 degrees (inlay).
func _star(parent: Node3D, pos: Vector3, size: float, mat: Material, rot: Vector3) -> void:
	var holder: Node3D = Node3D.new()
	holder.position = pos
	holder.rotation = rot
	parent.add_child(holder)
	_add_box(holder, Vector3(size, 0.015, size), Vector3.ZERO, mat)
	var b: MeshInstance3D = _add_box(holder, Vector3(size, 0.016, size), Vector3.ZERO, mat)
	b.rotation.y = PI * 0.25


## Rectangular brass frame of thin bars; `on_side` = frame lies in the YZ plane.
func _frame(parent: Node3D, center: Vector3, frame_size: Vector2, bar: float, mat: Material, on_side: bool) -> void:
	var w: float = frame_size.x
	var h: float = frame_size.y
	for sy in [-1.0, 1.0]:
		if on_side:
			_add_box(parent, Vector3(0.02, bar, w), center + Vector3(0.0, sy * (h - bar) * 0.5, 0.0), mat)
			_add_box(parent, Vector3(0.02, h, bar), center + Vector3(0.0, 0.0, sy * (w - bar) * 0.5), mat)
		else:
			_add_box(parent, Vector3(w, bar, 0.02), center + Vector3(0.0, sy * (h - bar) * 0.5, 0.0), mat)
			_add_box(parent, Vector3(bar, h, 0.02), center + Vector3(sy * (w - bar) * 0.5, 0.0, 0.0), mat)


func _cylinder(parent: Node3D, radius: float, height: float, mat: Material, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## One of the owner's symbols (symbols_sheet.png, 4 x 2) as a flat brass-tinted inlay.
func _symbol_inlay(parent: Node3D, pos: Vector3, size: float) -> void:
	if not ResourceLoader.exists(SYMBOLS_TEX):
		return
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = load(SYMBOLS_TEX) as Texture2D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.albedo_color = Color(1.0, 0.86, 0.5)
	m.metallic = 0.8
	m.roughness = 0.3
	m.uv1_scale = Vector3(0.25, 0.5, 1.0)
	m.uv1_offset = Vector3(0.25 * float(_symbol % 4), 0.5 * float(_symbol / 4), 0.0)
	var q: MeshInstance3D = MeshInstance3D.new()
	var quad: PlaneMesh = PlaneMesh.new()
	quad.size = Vector2(size, size)
	q.mesh = quad
	q.material_override = m
	q.position = pos
	parent.add_child(q)
