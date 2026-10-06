class_name OfWorld
extends Node3D

## The 3D scene (DESIGN sections 6-7): deep-space backdrop cards, the frame,
## the force-field glass, captured crystal in one MultiMesh showing the
## hidden picture, white rim lines, ice bars, stones, balls with halo and
## trail, the growing beam, tokens. It only draws: OfPlay owns the OfSim
## and calls sync() and the on_* functions. Logic px of the bottom-anchored
## design frame map to the play plane z = 0 with 1 px = 0.01 m; the screen
## bottom is world y 0 and x 540 is world x 0.

const PX := OfBalance.PX_TO_M
const VOID := Color(0.020, 0.031, 0.086)
const RAIL := Color(0.102, 0.133, 0.220)
const RAIL_LIGHT := Color(0.353, 0.663, 1.000)
const NODE := Color(0.165, 0.208, 0.314)
const NODE_LENS := Color(0.561, 0.816, 1.000)
const CRYSTAL_W1 := Color(0.498, 0.714, 1.000)
const BEAM := Color(1.000, 0.788, 0.302)
const ORB_SHELL := Color(1.000, 0.435, 0.380)
const STONE := Color(0.420, 0.369, 0.341)
const SNEGL := Color(0.361, 0.949, 0.722)
const WHITE := Color(1.0, 1.0, 1.0)
const BALL_Z: float = 0.32
const CRYSTAL_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(0.95, 1.0, 1.04),
	Color(1.03, 0.98, 1.06),
	Color(0.97, 0.97, 0.97),
]
const TRAIL_POINTS: int = 12
const TRAIL_LEN_PX: float = 130.0
const BALL_POOL: int = 8
const TOKEN_POOL: int = 2
const RIM_PX: float = 5.0
## crystal_tile.glb is 0.70 m wide; scale it to cover the 0.72 m cell so
## the grid under the glass never shows between tiles.
const TILE_FILL: float = 1.03

var camera: Camera3D
var cam_pivot: Node3D
var env: Environment

var _vw: float = 1080.0
var _vh: float = 1920.0
var _less_motion: bool = false
var _t: float = 0.0
var _intro_t: float = 99.0
var _push_t: float = -1.0
var _shake_t: float = 99.0

var _game_nodes: Array[Node3D] = []
var _rails: MultiMeshInstance3D
var _rail_lights: MultiMeshInstance3D
var _rail_specs: Array[Dictionary] = []

var _crystal_mmi: MultiMeshInstance3D
var _crystal_mat: ShaderMaterial
var _crystal_mesh: Mesh
var _cry_state: PackedByteArray = PackedByteArray()
var _cry_t: PackedFloat32Array = PackedFloat32Array()
var _cry_pulse: float = 0.0
var _cry_animating: bool = false
var _cry_hide: float = 0.0
var _ice_mmi: MultiMeshInstance3D
var _stone_mmi: MultiMeshInstance3D
var _rim: MeshInstance3D
var _rim_mat: ShaderMaterial
var _glass_mat: ShaderMaterial

var _balls: Array[Node3D] = []
var _ball_halo_mats: Array[ShaderMaterial] = []
var _snegl_quads: Array[MeshInstance3D] = []
var _snegl_mat: ShaderMaterial
var _trails: Array[MeshInstance3D] = []
var _trail_meshes: Array[ImmediateMesh] = []
var _hist: Array[Array] = []
var _squash_t: PackedFloat32Array = PackedFloat32Array()

var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var _tips: Array[MeshInstance3D] = []
var _origin_ring: MeshInstance3D
var _origin_ring_mat: ShaderMaterial
var _ring_burst_t: float = 99.0

var _tokens: Array[Node3D] = []
var _token_cells: Array[Vector2i] = []

var _reveal_all_t: float = -1.0
var _frozen: bool = false


func _ready() -> void:
	_build_environment()
	_build_camera()
	_build_backdrop()
	_build_frame()
	_build_field()
	_build_actors()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()


## Logic px of the bottom-anchored design frame -> play plane.
static func to_world(p: Vector2, z: float = 0.0) -> Vector3:
	return Vector3((p.x - 540.0) * PX, (OfBalance.DESIGN_H - p.y) * PX, z)


## Field-local px (the sim's space) -> play plane.
static func field_to_world(p: Vector2, z: float = 0.0) -> Vector3:
	return to_world(p + OfBalance.FIELD_ORIGIN, z)


# ---------------------------------------------------------------- build


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = VOID
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.10, 0.16, 0.34)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.0
	for i: int in 7:
		env.set_glow_level(i, 1.0 if i in [1, 2, 3] else 0.0)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.95, 0.88)
	key.light_energy = 3.2
	key.shadow_enabled = false
	# From the upper left, in front of the field.
	key.look_at_from_position(Vector3(-4.0, 6.0, 8.0), Vector3.ZERO, Vector3.UP)
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.55, 0.70, 1.0)
	fill.light_energy = 0.6
	fill.shadow_enabled = false
	fill.look_at_from_position(Vector3(-5.0, -6.0, 6.0), Vector3.ZERO, Vector3.UP)
	add_child(fill)


func _build_camera() -> void:
	cam_pivot = Node3D.new()
	var fc: Vector2 = OfBalance.FIELD_ORIGIN + Vector2(OfBalance.FIELD_W, OfBalance.FIELD_H) * 0.5
	cam_pivot.position = to_world(fc)
	add_child(cam_pivot)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_FRUSTUM
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.near = OfBalance.CAM_NEAR
	camera.far = 400.0
	camera.position = _cam_rest_local()
	cam_pivot.add_child(camera)
	camera.current = true


func _cam_rest_local() -> Vector3:
	return Vector3(0.0, OfBalance.CAM_Y - cam_pivot.position.y, OfBalance.CAM_DIST)


func _on_resize() -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	_vw = s.x
	_vh = s.y
	_apply_frustum(OfBalance.CAM_DIST)


## Lens shift, not tilt (DESIGN 6a): 1 logic px stays 1 screen px on the play
## plane; the screen bottom stays at world y 0 so taller screens add sky.
func _apply_frustum(dist: float) -> void:
	var k: float = OfBalance.CAM_NEAR / dist
	camera.size = _vw * PX * k
	camera.frustum_offset = Vector2(0.0, (_vh * PX * 0.5 - OfBalance.CAM_Y) * k)


## Screen px offset of the bottom-anchored 1080 x 1920 design frame.
func frame_offset() -> Vector2:
	return Vector2((_vw - OfBalance.DESIGN_W) * 0.5, _vh - OfBalance.DESIGN_H)


func _card(
	tex_path: String, size: Vector2, pos: Vector3, alpha: int, tint: float = 1.0
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = load(tex_path) as Texture2D
	m.transparency = alpha as BaseMaterial3D.Transparency
	if alpha == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		m.alpha_scissor_threshold = 0.5
	m.disable_receive_shadows = true
	m.albedo_color = Color(tint, tint, tint)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	add_child(mi)
	return mi


## Backdrop cards at their depths (DESIGN 6a, 7a): nebula + stars at
## -150 m (sized to cover 1080 x 2400 and 1440 x 1920 plus the drift), the
## ocean planet at -125 m (limb near screen y 1530), the moon at -60 m upper
## right. Sizes follow the projection from the camera at 30 m.
func _build_backdrop() -> void:
	_card(
		"res://assets/textures/world1_sky.png",
		Vector2(96.0, 170.7),
		Vector3(0.0, 19.0, -150.0),
		BaseMaterial3D.TRANSPARENCY_DISABLED
	)
	_card(
		"res://assets/textures/world1_planet.png",
		Vector2(167.0, 167.0),
		Vector3(-4.65, -97.35, -125.0),
		BaseMaterial3D.TRANSPARENCY_ALPHA
	)
	_card(
		"res://assets/textures/world1_moon.png",
		Vector2(9.4, 9.4),
		Vector3(7.8, 24.3, -60.0),
		BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR,
		0.72
	)


func _build_frame() -> void:
	var o: Vector2 = OfBalance.FIELD_ORIGIN
	var fw: float = OfBalance.FIELD_W
	var fh: float = OfBalance.FIELD_H
	var t: float = 22.0
	var corners: Array[Vector2] = [
		o + Vector2(-t * 0.5, -t * 0.5),
		o + Vector2(fw + t * 0.5, -t * 0.5),
		o + Vector2(fw + t * 0.5, fh + t * 0.5),
		o + Vector2(-t * 0.5, fh + t * 0.5),
	]
	# Each side is two half rails, each growing from its corner node.
	for i: int in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var mid: Vector2 = (a + b) * 0.5
		var inward: Vector2 = (o + Vector2(fw, fh) * 0.5 - mid).normalized()
		for end: Array in [[a, mid], [b, mid]]:
			_rail_specs.append({"from": end[0], "to": end[1], "inward": inward})
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = RAIL
	rail_mat.metallic = 0.8
	rail_mat.roughness = 0.32
	rail_mat.clearcoat_enabled = true
	rail_mat.clearcoat = 0.6
	_rails = _mm_instance(BoxMesh.new(), rail_mat, _rail_specs.size())
	var light_mat := _unshaded(RAIL_LIGHT * 2.2)
	_rail_lights = _mm_instance(BoxMesh.new(), light_mat, _rail_specs.size())
	_game_nodes.append(_rails)
	_game_nodes.append(_rail_lights)
	# Corner hex nodes: body + glowing lens.
	var ps: PackedScene = load("res://assets/models/frame_node.glb")
	var root: Node = ps.instantiate()
	var body_mi: MeshInstance3D = _find_mesh(root, "frame_node")
	var lens_mi: MeshInstance3D = _find_mesh(root, "frame_node_lens")
	var node_mat := StandardMaterial3D.new()
	node_mat.albedo_color = NODE
	node_mat.metallic = 0.6
	node_mat.roughness = 0.35
	var bodies := _mm_instance(body_mi.mesh, node_mat, 4)
	var lenses := _mm_instance(lens_mi.mesh, _unshaded(NODE_LENS * 4.0), 4)
	var face := Basis(Vector3.RIGHT, PI * 0.5)
	for i: int in 4:
		var xf := Transform3D(face, to_world(corners[i], 0.05))
		bodies.multimesh.set_instance_transform(i, xf)
		lenses.multimesh.set_instance_transform(i, xf * lens_mi.transform)
	_game_nodes.append(bodies)
	_game_nodes.append(lenses)
	root.free()
	_set_rails(1.0)


func _set_rails(k: float) -> void:
	var e: float = clampf(k, 0.0, 1.0)
	e = 1.0 - pow(1.0 - e, 3.0)
	for i: int in _rail_specs.size():
		var sp: Dictionary = _rail_specs[i]
		var a: Vector2 = sp["from"]
		var b: Vector2 = sp["to"]
		var len_px: float = a.distance_to(b) * e + 11.0
		var dir: Vector2 = (b - a).normalized()
		var c: Vector2 = a + dir * (len_px * 0.5 - 5.5)
		var horizontal: bool = absf(dir.x) > 0.5
		var size := Vector3(len_px, 22.0, 20.0) if horizontal else Vector3(22.0, len_px, 20.0)
		var xf := Transform3D(Basis.from_scale(size * PX), to_world(c, -0.02))
		_rails.multimesh.set_instance_transform(i, xf)
		var inward: Vector2 = sp["inward"]
		var lc: Vector2 = c + inward * 9.0
		var lsize := Vector3(len_px, 3.0, 4.0) if horizontal else Vector3(3.0, len_px, 4.0)
		_rail_lights.multimesh.set_instance_transform(
			i, Transform3D(Basis.from_scale(lsize * PX), to_world(lc, 0.1))
		)


func _build_field() -> void:
	var glass := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(OfBalance.FIELD_W, OfBalance.FIELD_H) * PX
	glass.mesh = q
	_glass_mat = ShaderMaterial.new()
	_glass_mat.shader = preload("res://shaders/field.gdshader")
	glass.material_override = _glass_mat
	glass.position = field_to_world(Vector2(OfBalance.FIELD_W, OfBalance.FIELD_H) * 0.5, 0.0)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	_game_nodes.append(glass)
	# Crystal MultiMesh (max 224).
	var ps: PackedScene = load("res://assets/models/crystal_tile.glb")
	var root: Node = ps.instantiate()
	_crystal_mesh = _find_mesh(root, "crystal_tile").mesh
	root.free()
	_crystal_mat = ShaderMaterial.new()
	_crystal_mat.shader = preload("res://shaders/crystal.gdshader")
	_crystal_mat.set_shader_parameter("tint", CRYSTAL_W1)
	_crystal_mmi = _mm_instance(_crystal_mesh, _crystal_mat, OfSim.COLS * OfSim.ROWS, true)
	_game_nodes.append(_crystal_mmi)
	_cry_state.resize(OfSim.COLS * OfSim.ROWS)
	_cry_t.resize(OfSim.COLS * OfSim.ROWS)
	# Ice bars.
	var iq := QuadMesh.new()
	iq.size = Vector2(OfBalance.CELL, OfBalance.CELL) * PX
	var ice_mat := ShaderMaterial.new()
	ice_mat.shader = preload("res://shaders/ice.gdshader")
	_ice_mmi = _mm_instance(iq, ice_mat, OfSim.COLS * OfSim.ROWS)
	_game_nodes.append(_ice_mmi)
	# Stones.
	var sps: PackedScene = load("res://assets/models/stone_block.glb")
	var sroot: Node = sps.instantiate()
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = STONE
	stone_mat.roughness = 0.85
	_stone_mmi = _mm_instance(_find_mesh(sroot, "stone_block").mesh, stone_mat, 32)
	sroot.free()
	_game_nodes.append(_stone_mmi)
	# Rim lines.
	_rim = MeshInstance3D.new()
	_rim_mat = ShaderMaterial.new()
	_rim_mat.shader = preload("res://shaders/rim.gdshader")
	_rim.material_override = _rim_mat
	_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rim)
	_game_nodes.append(_rim)


func _build_actors() -> void:
	_snegl_mat = ShaderMaterial.new()
	_snegl_mat.shader = preload("res://shaders/snegl.gdshader")
	var ball_mat := ShaderMaterial.new()
	ball_mat.shader = preload("res://shaders/ball.gdshader")
	var ring_mat := _unshaded(Color(1.5, 1.5, 1.5))
	var trail_mat := StandardMaterial3D.new()
	trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	trail_mat.vertex_color_use_as_albedo = true
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	trail_mat.no_depth_test = false
	for i: int in BALL_POOL:
		var root := Node3D.new()
		add_child(root)
		var sphere := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.24
		sm.height = 0.48
		sm.radial_segments = 16
		sm.rings = 8
		sphere.mesh = sm
		sphere.material_override = ball_mat
		root.add_child(sphere)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.33
		tm.outer_radius = 0.38
		tm.rings = 24
		tm.ring_segments = 6
		ring.mesh = tm
		ring.material_override = ring_mat
		ring.rotation = Vector3(deg_to_rad(24.0), 0.0, deg_to_rad(-14.0))
		root.add_child(ring)
		var halo := _glow_quad(1.2, ORB_SHELL, 0, 0.9)
		halo.position = Vector3(0.0, 0.0, -0.3)
		root.add_child(halo)
		_ball_halo_mats.append(halo.material_override as ShaderMaterial)
		var sq := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.95, 0.95)
		sq.mesh = q
		sq.material_override = _snegl_mat
		sq.position = Vector3(0.0, 0.0, 0.05)
		sq.visible = false
		root.add_child(sq)
		_snegl_quads.append(sq)
		root.visible = false
		_balls.append(root)
		var trail := MeshInstance3D.new()
		var im := ImmediateMesh.new()
		trail.mesh = im
		trail.material_override = trail_mat
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(trail)
		_trails.append(trail)
		_trail_meshes.append(im)
		_hist.append([])
	_squash_t.resize(BALL_POOL)
	_squash_t.fill(99.0)
	# Beam.
	_beam = MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(1.0, 1.0)
	_beam.mesh = bq
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = preload("res://shaders/beam.gdshader")
	_beam.material_override = _beam_mat
	_beam.visible = false
	add_child(_beam)
	for i: int in 2:
		var tip := _glow_quad(1.25, Color(1.0, 0.86, 0.55), 2, 2.6)
		tip.visible = false
		add_child(tip)
		_tips.append(tip)
	_origin_ring = _glow_quad(0.8, BEAM, 1, 1.9)
	_origin_ring_mat = _origin_ring.material_override as ShaderMaterial
	_origin_ring.visible = false
	add_child(_origin_ring)
	# Tokens.
	var tps: PackedScene = load("res://assets/models/token_snegl.glb")
	for i: int in TOKEN_POOL:
		var t: Node3D = tps.instantiate()
		for mi: MeshInstance3D in _all_meshes(t):
			var c: Color = SNEGL * 1.05 if mi.name == "token_snegl" else Color(1.3, 1.3, 1.3)
			mi.material_override = _unshaded(c)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var halo := _glow_quad(1.1, SNEGL, 0, 0.45)
		halo.position = Vector3(0.0, -0.2, 0.0)
		halo.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		t.add_child(halo)
		t.visible = false
		add_child(t)
		_tokens.append(t)


func _mm_instance(
	mesh: Mesh, mat: Material, count: int, custom: bool = false
) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = custom
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = count
	for i: int in count:
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _glow_quad(size_m: float, c: Color, mode: int, gain: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size_m, size_m)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/glow_quad.gdshader")
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("gain", gain)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _find_mesh(n: Node, name_wanted: String) -> MeshInstance3D:
	for mi: MeshInstance3D in _all_meshes(n):
		if mi.name == name_wanted:
			return mi
	return null


func _all_meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c: Node in n.get_children():
		out.append_array(_all_meshes(c))
	return out


# ---------------------------------------------------------------- level


func show_gameplay(on: bool) -> void:
	for n: Node3D in _game_nodes:
		n.visible = on
	if not on:
		for b: Node3D in _balls:
			b.visible = false
		for t: MeshInstance3D in _trails:
			t.visible = false
		for t: Node3D in _tokens:
			t.visible = false
		_hide_beam()


func set_less_motion(on: bool) -> void:
	_less_motion = on


func set_picture(tex: Texture2D) -> void:
	_crystal_mat.set_shader_parameter("picture", tex)


func bind_level(sim: OfSim, picture: Texture2D) -> void:
	set_picture(picture)
	_frozen = false
	_reveal_all_t = -1.0
	_cry_state.fill(0)
	_cry_t.fill(0.0)
	_cry_pulse = 0.0
	_cry_hide = 0.0
	for i: int in OfSim.COLS * OfSim.ROWS:
		_crystal_mmi.multimesh.set_instance_transform(i, _hidden_xf())
	_rebuild_static(sim)
	_place_stones(sim)
	_place_tokens(sim)
	for i: int in BALL_POOL:
		_hist[i] = []
		_squash_t[i] = 99.0
	_hide_beam()
	sync(sim, 0.0, 0.0)


func _hidden_xf() -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ZERO), Vector3(0.0, -50.0, 0.0))


func _place_stones(sim: OfSim) -> void:
	var n: int = 0
	var face := Basis(Vector3.RIGHT, PI * 0.5)
	for r: int in OfSim.ROWS:
		for c: int in OfSim.COLS:
			if sim.get_cell(Vector2i(c, r)) == OfSim.Cell.ROCK and n < 32:
				var p: Vector3 = field_to_world(OfSim.cell_center(Vector2i(c, r)), 0.17)
				_stone_mmi.multimesh.set_instance_transform(n, Transform3D(face, p))
				n += 1
	for i: int in range(n, 32):
		_stone_mmi.multimesh.set_instance_transform(i, _hidden_xf())


func _place_tokens(sim: OfSim) -> void:
	_token_cells.clear()
	for k: Variant in sim.tokens.keys():
		_token_cells.append(k as Vector2i)
	for i: int in _tokens.size():
		_tokens[i].visible = i < _token_cells.size()


## Which cells draw as crystal: captured/caged cells, plus wall cells that
## touch them (a wall that closed a room hardens with it). Other wall cells
## draw as ice bars.
func _crystal_cell(sim: OfSim, c: Vector2i) -> bool:
	var s: int = sim.get_cell(c)
	if s == OfSim.Cell.CAPTURED or s == OfSim.Cell.CAGED:
		return true
	if s != OfSim.Cell.WALL:
		return false
	for n: Vector2i in [c + Vector2i.LEFT, c + Vector2i.RIGHT, c + Vector2i.UP, c + Vector2i.DOWN]:
		var ns: int = sim.get_cell(n)
		if ns == OfSim.Cell.CAPTURED or ns == OfSim.Cell.CAGED:
			return true
	return false


## Ice bars and rim lines follow the grid; crystal cells that newly become
## crystal start their grow-in (instant unless on_captured set a delay).
func _rebuild_static(sim: OfSim) -> void:
	var ice_n: int = 0
	var face_v := Basis(Vector3.BACK, PI * 0.5)
	for r: int in OfSim.ROWS:
		for c: int in OfSim.COLS:
			var cell := Vector2i(c, r)
			var i: int = r * OfSim.COLS + c
			var cry: bool = _crystal_cell(sim, cell)
			if cry and _cry_state[i] == 0:
				_cry_state[i] = 1
				if _cry_t[i] >= 0.0:
					_cry_t[i] = 0.0
				_cry_animating = true
			elif not cry and _cry_state[i] == 1:
				_cry_state[i] = 0
				_crystal_mmi.multimesh.set_instance_transform(i, _hidden_xf())
			if not cry and sim.get_cell(cell) == OfSim.Cell.WALL:
				var vertical: bool = sim.wall_dir[i] == 1
				var b: Basis = face_v if vertical else Basis.IDENTITY
				var p: Vector3 = field_to_world(OfSim.cell_center(cell), 0.12)
				_ice_mmi.multimesh.set_instance_transform(ice_n, Transform3D(b, p))
				ice_n += 1
	for i: int in range(ice_n, OfSim.COLS * OfSim.ROWS):
		_ice_mmi.multimesh.set_instance_transform(i, _hidden_xf())
	_build_rim(sim)
	_update_crystal(0.0)


func _build_rim(sim: OfSim) -> void:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cell: float = OfBalance.CELL
	var hw: float = RIM_PX * 0.5
	for r: int in OfSim.ROWS:
		for c: int in OfSim.COLS:
			var cc := Vector2i(c, r)
			if _cry_state[r * OfSim.COLS + c] == 0:
				continue
			var x0: float = c * cell
			var y0: float = r * cell
			var sides: Array = [
				[Vector2i.UP, Vector2(x0, y0), Vector2(x0 + cell, y0)],
				[Vector2i.DOWN, Vector2(x0, y0 + cell), Vector2(x0 + cell, y0 + cell)],
				[Vector2i.LEFT, Vector2(x0, y0), Vector2(x0, y0 + cell)],
				[Vector2i.RIGHT, Vector2(x0 + cell, y0), Vector2(x0 + cell, y0 + cell)],
			]
			for sd: Array in sides:
				var n: Vector2i = cc + (sd[0] as Vector2i)
				if not OfSim.in_grid(n):
					continue
				if _cry_state[n.y * OfSim.COLS + n.x] == 1:
					continue
				if sim.get_cell(n) == OfSim.Cell.ROCK:
					continue
				var a: Vector2 = sd[1]
				var b: Vector2 = sd[2]
				var along: Vector2 = (b - a).normalized()
				var nrm := Vector2(-along.y, along.x)
				# Extend a little so corners join.
				a -= along * hw
				b += along * hw
				var q: Array[Vector2] = [a - nrm * hw, b - nrm * hw, b + nrm * hw, a + nrm * hw]
				var quv: Array[Vector2] = [
					Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)
				]
				for k: int in [0, 1, 2, 0, 2, 3]:
					verts.append(field_to_world(q[k], 0.29))
					uvs.append(quv[k])
	var am := ArrayMesh.new()
	if not verts.is_empty():
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_TEX_UV] = uvs
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_rim.mesh = am


## Captured cells: crystal grows in a wave from the new wall (DESIGN 6b).
func on_captured(
	sim: OfSim, cells: Array[Vector2i], delays: PackedFloat32Array, pulse: bool
) -> void:
	for k: int in cells.size():
		var c: Vector2i = cells[k]
		var i: int = c.y * OfSim.COLS + c.x
		_cry_t[i] = 0.0 if _less_motion else -delays[k]
	_rebuild_static(sim)
	if pulse and not _less_motion:
		_cry_pulse = 1.0


func on_wall_finished(sim: OfSim) -> void:
	_hide_beam()
	_rebuild_static(sim)


func on_wall_vanished() -> void:
	_hide_beam()


func on_token_taken(cell: Vector2i) -> void:
	var idx: int = _token_cells.find(cell)
	if idx >= 0 and idx < _tokens.size():
		_tokens[idx].visible = false


func on_ball_squash(i: int) -> void:
	if not _less_motion and i < BALL_POOL:
		_squash_t[i] = 0.0


func on_wall_started() -> void:
	_ring_burst_t = 0.0


## Level clear: freeze, the rest of the picture fades in (DESIGN 6a/GDD 9).
func reveal_all(sim: OfSim) -> void:
	_frozen = true
	_reveal_all_t = 0.0
	for r: int in OfSim.ROWS:
		for c: int in OfSim.COLS:
			var i: int = r * OfSim.COLS + c
			var s: int = sim.get_cell(Vector2i(c, r))
			if _cry_state[i] == 0 and s != OfSim.Cell.ROCK and s != OfSim.Cell.MIRROR:
				_cry_state[i] = 1
				var d: float = Vector2(c, r).distance_to(Vector2(6.5, 7.5)) / 10.0
				_cry_t[i] = 0.0 if _less_motion else -d * (OfBalance.CLEAR_PICTURE_FADE_S - 0.15)
	for i: int in _ice_mmi.multimesh.instance_count:
		_ice_mmi.multimesh.set_instance_transform(i, _hidden_xf())
	_rim.mesh = null
	_cry_animating = true
	_hide_beam()
	for t: Node3D in _tokens:
		t.visible = false
	if not _less_motion:
		_push_t = 0.0
		_shake_t = 0.0


func start_intro() -> void:
	_intro_t = 99.0 if _less_motion else 0.0
	_set_rails(1.0 if _less_motion else 0.0)


func reset_camera_fx() -> void:
	_push_t = -1.0
	_shake_t = 99.0
	camera.position = _cam_rest_local()
	cam_pivot.rotation = Vector3.ZERO
	_apply_frustum(OfBalance.CAM_DIST)


# ---------------------------------------------------------------- per frame


func sync(sim: OfSim, real_dt: float, game_dt: float) -> void:
	_t += real_dt
	if _intro_t < OfBalance.INTRO_FRAME_S:
		_intro_t += real_dt
		_set_rails(_intro_t / OfBalance.INTRO_FRAME_S)
	_sync_balls(sim, real_dt, game_dt)
	_sync_beam(sim)
	_sync_tokens(sim)
	_sync_restart(sim)
	if _reveal_all_t >= 0.0:
		_reveal_all_t += real_dt
	_update_crystal(real_dt)
	_ring_burst_t += real_dt


func _sync_balls(sim: OfSim, real_dt: float, game_dt: float) -> void:
	var left: float = sim.snegl_left()
	var snegl_on: bool = sim.snegl_t > 0.0
	_snegl_mat.set_shader_parameter("left", left)
	if not _less_motion:
		_snegl_mat.set_shader_parameter("spin", _t * 2.5)
	for i: int in BALL_POOL:
		var on: bool = i < sim.balls.size() and not _frozen_hidden()
		_balls[i].visible = on
		_trails[i].visible = on
		if not on:
			continue
		var b: OfSim.Ball = sim.balls[i]
		var wp: Vector3 = field_to_world(b.pos, BALL_Z)
		_balls[i].position = wp
		var sc: float = b.radius / OfBalance.BALL_RADIUS
		_squash_t[i] += real_dt
		var sq: float = 1.0
		if _squash_t[i] < 0.08:
			sq = 0.9
		_balls[i].scale = Vector3(sc / sq, sc * sq, sc)
		_snegl_quads[i].visible = snegl_on
		var h: Array = _hist[i]
		if game_dt > 0.0 or h.is_empty():
			h.push_front(wp)
			while h.size() > TRAIL_POINTS:
				h.pop_back()
		_draw_trail(i, b)


## During the level-clear reveal the balls pop into stars (2D), so the 3D
## balls hide once the freeze starts.
func _frozen_hidden() -> bool:
	return _frozen and _reveal_all_t > OfBalance.CLEAR_SLOWMO_S * 0.5


func _draw_trail(i: int, b: OfSim.Ball) -> void:
	var im: ImmediateMesh = _trail_meshes[i]
	im.clear_surfaces()
	var h: Array = _hist[i]
	if h.size() < 2 or _frozen:
		return
	# Resample to a fixed length behind the ball along its direction.
	var dir3 := Vector3(b.dir.x, -b.dir.y, 0.0).normalized()
	var side := Vector3(-dir3.y, dir3.x, 0.0)
	var head: Vector3 = h[0]
	var len_m: float = TRAIL_LEN_PX * PX
	var travelled: float = 0.0
	for k: int in range(1, h.size()):
		travelled += (h[k] as Vector3).distance_to(h[k - 1] as Vector3)
	len_m = minf(len_m, travelled)
	if len_m < 0.02:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n: int = 10
	for k: int in n:
		var t: float = float(k) / float(n - 1)
		var p: Vector3 = head - dir3 * len_m * t - Vector3(0.0, 0.0, 0.05)
		var w: float = 0.2 * (1.0 - t) + 0.01
		var a: float = 0.55 * (1.0 - t)
		var col := Color(ORB_SHELL.r * a * 1.4, ORB_SHELL.g * a * 1.2, ORB_SHELL.b * a * 1.2, a)
		im.surface_set_color(col)
		im.surface_add_vertex(p + side * w)
		im.surface_set_color(col)
		im.surface_add_vertex(p - side * w)
	im.surface_end()


func _hide_beam() -> void:
	_beam.visible = false
	for t: MeshInstance3D in _tips:
		t.visible = false
	_origin_ring.visible = false


func _sync_beam(sim: OfSim) -> void:
	var w: OfSim.Wall = sim.wall
	if w == null or _frozen:
		_hide_beam()
		return
	var cell: float = OfBalance.CELL
	var o: Vector2 = OfSim.cell_center(w.origin)
	var axis := Vector2(0.0, 1.0) if w.vertical else Vector2(1.0, 0.0)
	# Visual length of each half in px from the origin centre.
	var ext: Array[float] = [0.0, 0.0]
	for k: int in 2:
		var h: OfSim.Half = w.halves[k]
		if h.popped:
			ext[k] = 0.0
		elif h.done:
			ext[k] = h.cells.size() * cell + cell * 0.5
		else:
			ext[k] = minf(h.progress, h.cells.size() + 1.0) * cell + cell * 0.5
	var a: Vector2 = o - axis * ext[0]
	var b: Vector2 = o + axis * ext[1]
	if w.halves[0].popped:
		a = o - axis * cell * 0.5
	if w.halves[1].popped:
		b = o + axis * cell * 0.5
	var len_px: float = a.distance_to(b)
	var mid: Vector2 = (a + b) * 0.5
	var basis := Basis(Vector3.BACK, PI * 0.5 if w.vertical else 0.0)
	basis = basis.scaled_local(Vector3(len_px * PX, 0.64, 1.0))
	_beam.transform = Transform3D(basis, field_to_world(mid, 0.3))
	_beam.visible = true
	_beam_mat.set_shader_parameter("len_px", len_px)
	_beam_mat.set_shader_parameter("origin_u", o.distance_to(a) / maxf(len_px, 1.0))
	_beam_mat.set_shader_parameter("speed_px", 0.0 if _less_motion else 140.0)
	var ends: Array[Vector2] = [a, b]
	for k: int in 2:
		var h: OfSim.Half = w.halves[k]
		_tips[k].visible = not h.popped
		_tips[k].position = field_to_world(ends[k], 0.34)
	_origin_ring.visible = true
	_origin_ring.position = field_to_world(o, 0.33)
	var burst: float = clampf(_ring_burst_t / 0.2, 0.0, 1.0)
	var rs: float = 1.0 if _less_motion else lerpf(1.8, 1.0, burst)
	_origin_ring.scale = Vector3(rs, rs, 1.0)


func _sync_tokens(sim: OfSim) -> void:
	var face := Basis(Vector3.RIGHT, PI * 0.5)
	for i: int in _tokens.size():
		if i >= _token_cells.size() or not _tokens[i].visible:
			continue
		var c: Vector2i = _token_cells[i]
		if not sim.tokens.has(c):
			_tokens[i].visible = false
			continue
		var spin: float = 0.0 if _less_motion else _t * TAU * OfBalance.TOKEN_SPIN_REV_S
		var b := Basis(Vector3.BACK, -spin) * face
		_tokens[i].transform = Transform3D(b, field_to_world(OfSim.cell_center(c), 0.22))


## Gentle restart: crystal and ice slide back out during the rewind.
func _sync_restart(sim: OfSim) -> void:
	var rw: float = sim.restart_rewind()
	if sim.state == OfSim.State.RESTART and rw > 0.0 and rw < 1.0:
		if _cry_hide == 0.0:
			_ice_mmi.visible = false
			_rim.visible = false
			_hide_beam()
		_cry_hide = rw
		_cry_animating = true
	elif _cry_hide > 0.0:
		_cry_hide = 0.0
		_ice_mmi.visible = true
		_rim.visible = true
		_cry_state.fill(0)
		_cry_t.fill(0.0)
		for i: int in OfSim.COLS * OfSim.ROWS:
			_crystal_mmi.multimesh.set_instance_transform(i, _hidden_xf())
		_rebuild_static(sim)
		_place_tokens(sim)


func _update_crystal(dt: float) -> void:
	if _cry_pulse > 0.0:
		_cry_pulse = maxf(0.0, _cry_pulse - dt / OfBalance.CAPTURE_PULSE_S)
		_cry_animating = true
	if not _cry_animating:
		return
	var still: bool = _cry_pulse <= 0.0 and _cry_hide <= 0.0
	var mm: MultiMesh = _crystal_mmi.multimesh
	var face := Basis(Vector3.RIGHT, PI * 0.5)
	var grow: float = OfBalance.CELL_GROW_S
	for i: int in OfSim.COLS * OfSim.ROWS:
		if _cry_state[i] == 0:
			continue
		var t: float = _cry_t[i]
		if t < grow + 0.05:
			_cry_t[i] = t + dt
			still = false
		var c := Vector2i(i % OfSim.COLS, i / OfSim.COLS)
		var s: float = _grow_curve(t) * TILE_FILL
		if _cry_hide > 0.0:
			s *= 1.0 - _cry_hide
		var turn: float = float((c.x * 7 + c.y * 13) % 4) * PI * 0.5
		var b: Basis = (Basis(Vector3.BACK, turn) * face).scaled(Vector3(s, s, s))
		var p: Vector3 = field_to_world(OfSim.cell_center(c), 0.0)
		mm.set_instance_transform(i, Transform3D(b, p))
		var tint: Color = CRYSTAL_TINTS[(c.x * 3 + c.y * 5) % CRYSTAL_TINTS.size()]
		mm.set_instance_color(i, tint)
		var reveal: float = clampf(t / grow, 0.0, 1.0)
		mm.set_instance_custom_data(i, Color(reveal, _cry_pulse * 0.6, 0.0, 0.0))
	if still:
		_cry_animating = false


static func _grow_curve(t: float) -> float:
	var g: float = OfBalance.CELL_GROW_S
	if t <= 0.0:
		return 0.0
	if t >= g:
		return 1.0
	var k: float = t / g
	if k < 0.7:
		return lerpf(0.0, 1.05, k / 0.7)
	return lerpf(1.05, 1.0, (k - 0.7) / 0.3)


func sync_camera(dt: float) -> void:
	var rot := Vector3.ZERO
	if not _less_motion:
		var a: float = deg_to_rad(OfBalance.DRIFT_DEG)
		var w: float = TAU / OfBalance.DRIFT_PERIOD_S
		rot = Vector3(sin(_t * w * 0.83 + 1.3) * a, sin(_t * w) * a, 0.0)
	cam_pivot.rotation = rot
	var dist: float = OfBalance.CAM_DIST
	var off := Vector3.ZERO
	if _push_t >= 0.0:
		_push_t += dt
		var k: float = clampf(_push_t / 0.5, 0.0, 1.0)
		dist *= 1.0 - OfBalance.PUSH_IN * (1.0 - pow(1.0 - k, 3.0))
	if _shake_t < OfBalance.SHAKE_S:
		_shake_t += dt
		var amp: float = OfBalance.SHAKE_PX * PX * (1.0 - _shake_t / OfBalance.SHAKE_S)
		off = Vector3(sin(_t * 91.0) * amp, cos(_t * 77.0) * amp, 0.0)
	var rest: Vector3 = _cam_rest_local()
	# Frustum size stays tied to the rest distance, so moving closer zooms in.
	camera.position = Vector3(rest.x, rest.y, dist) + off


## Glass fade for the map (field hidden) and the restart dim.
func set_glass_fade(f: float) -> void:
	_glass_mat.set_shader_parameter("fade", f)
