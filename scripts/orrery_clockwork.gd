extends Node3D
## Clockwork orrery — concentric orbs, restrained palette, considered light.
## Inner: epicyclic core. Middle: regulation. Outer: ceremonial outputs.

const MechanismModelClass = preload("res://scripts/mechanism_model.gd")
const TAU_F: float = PI * 2.0
const INNER_R: float = 2.0
const MIDDLE_R: float = 3.5
const OUTER_R: float = 5.0

var model: RefCounted
var gear_nodes: Dictionary = {}
var orb_meshes: Array[MeshInstance3D] = []
var connector_nodes: Array[Node3D] = []
var orbit_angle: float = 0.0
var auto_orbit: bool = true
var time_acc: float = 0.0

var rotor_map: Dictionary = {
	"sun":        {"orb": 0, "theta": PI*0.50, "phi": 0.0,        "scale": 0.9},
	"carrier":    {"orb": 0, "theta": PI*0.50, "phi": 0.0,        "scale": 1.2},
	"planet_a":   {"orb": 0, "theta": PI*0.38, "phi": PI*0.35,    "scale": 0.6},
	"planet_b":   {"orb": 0, "theta": PI*0.62, "phi": PI*-0.35,   "scale": 0.6},
	"ring":       {"orb": 0, "theta": PI*0.50, "phi": PI,         "scale": 1.1},
	"dial":       {"orb": 1, "theta": PI*0.35, "phi": 0.0,        "scale": 0.55},
	"escapement": {"orb": 1, "theta": PI*0.25, "phi": PI*0.5,     "scale": 0.45},
	"balance":    {"orb": 1, "theta": PI*0.50, "phi": PI,         "scale": 0.8},
	"flywheel":   {"orb": 2, "theta": PI*0.40, "phi": PI*0.2,     "scale": 0.7},
	"clickwheel": {"orb": 2, "theta": PI*0.60, "phi": PI*0.9,     "scale": 0.35},
	"geneva":     {"orb": 2, "theta": PI*0.50, "phi": PI*1.5,     "scale": 0.55},
}

var orb_radii: Array[float] = [INNER_R, MIDDLE_R, OUTER_R]

# --- Materials (created once, shared) ---

var mat_brass: StandardMaterial3D
var mat_brass_light: StandardMaterial3D
var mat_dark_steel: StandardMaterial3D
var mat_polished_steel: StandardMaterial3D
var mat_bone: StandardMaterial3D
var mat_glass_inner: StandardMaterial3D
var mat_glass_middle: StandardMaterial3D
var mat_glass_outer: StandardMaterial3D
var mat_shaft: StandardMaterial3D
var mat_connector: StandardMaterial3D
var mat_ring_accent: Array[StandardMaterial3D] = []

func _ready() -> void:
	model = MechanismModelClass.new()
	model.reset()
	_create_materials()
	_setup_lighting()
	_create_orbs()
	_create_gears()
	_create_connectors()
	_create_camera()

func _physics_process(delta: float) -> void:
	model.step(delta)
	time_acc += delta
	_update_orbs(delta)
	_update_gears()
	_update_connectors()
	_update_lighting()
	if auto_orbit:
		orbit_angle += delta * 0.05
		_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE: model.paused = not model.paused
			KEY_R: model.reset()
			KEY_O: auto_orbit = not auto_orbit
			KEY_UP: model.drive_torque = min(model.drive_torque + 4.0, 80.0)
			KEY_DOWN: model.drive_torque = max(model.drive_torque - 4.0, 4.0)

# ──────────────────── Materials ────────────────────

func _create_materials() -> void:
	# Warm aged brass — the primary gear material
	mat_brass = StandardMaterial3D.new()
	mat_brass.albedo_color = Color(0.76, 0.60, 0.33)
	mat_brass.metallic = 0.85
	mat_brass.roughness = 0.28
	mat_brass.metallic_specular = 0.7
	mat_brass.clearcoat_enabled = true
	mat_brass.clearcoat = 0.15
	mat_brass.clearcoat_roughness = 0.4

	# Lighter brass for teeth — catches light on edges
	mat_brass_light = StandardMaterial3D.new()
	mat_brass_light.albedo_color = Color(0.82, 0.68, 0.38)
	mat_brass_light.metallic = 0.90
	mat_brass_light.roughness = 0.20
	mat_brass_light.metallic_specular = 0.8

	# Dark oxidized steel — for frames and structure
	mat_dark_steel = StandardMaterial3D.new()
	mat_dark_steel.albedo_color = Color(0.18, 0.20, 0.24)
	mat_dark_steel.metallic = 0.70
	mat_dark_steel.roughness = 0.45
	mat_dark_steel.metallic_specular = 0.5

	# Polished steel — for shafts and hubs
	mat_polished_steel = StandardMaterial3D.new()
	mat_polished_steel.albedo_color = Color(0.72, 0.74, 0.78)
	mat_polished_steel.metallic = 0.95
	mat_polished_steel.roughness = 0.12
	mat_polished_steel.metallic_specular = 0.9
	mat_polished_steel.clearcoat_enabled = true
	mat_polished_steel.clearcoat = 0.3
	mat_polished_steel.clearcoat_roughness = 0.2

	# Bone/enamel — for dial faces
	mat_bone = StandardMaterial3D.new()
	mat_bone.albedo_color = Color(0.92, 0.88, 0.80)
	mat_bone.metallic = 0.0
	mat_bone.roughness = 0.6
	mat_bone.metallic_specular = 0.2

	# Shaft material — dark with high polish
	mat_shaft = StandardMaterial3D.new()
	mat_shaft.albedo_color = Color(0.12, 0.13, 0.16)
	mat_shaft.metallic = 0.90
	mat_shaft.roughness = 0.15
	mat_shaft.metallic_specular = 0.85

	# Glass orb materials — each progressively more transparent
	mat_glass_inner = _make_glass(Color(0.85, 0.72, 0.45), 0.88)
	mat_glass_middle = _make_glass(Color(0.55, 0.68, 0.82), 0.92)
	mat_glass_outer = _make_glass(Color(0.70, 0.55, 0.85), 0.94)

	# Connector rods
	mat_connector = StandardMaterial3D.new()
	mat_connector.albedo_color = Color(0.45, 0.42, 0.38)
	mat_connector.metallic = 0.75
	mat_connector.roughness = 0.35
	mat_connector.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_connector.albedo_color.a = 0.7

	# Ring accents per orb
	for c in [Color(0.90, 0.75, 0.40), Color(0.55, 0.70, 0.85), Color(0.75, 0.55, 0.90)]:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(c.r, c.g, c.b, 0.35)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission = c * 0.4
		m.emission_energy_multiplier = 0.5
		mat_ring_accent.append(m)

func _make_glass(tint: Color, transparency: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(tint.r, tint.g, tint.b, 1.0 - transparency)
	m.metallic = 0.05
	m.roughness = 0.1
	m.metallic_specular = 0.9
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.refraction_enabled = false
	m.clearcoat_enabled = true
	m.clearcoat = 0.6
	m.clearcoat_roughness = 0.1
	return m

# ──────────────────── Lighting ────────────────────

func _setup_lighting() -> void:
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.02, 0.035)

	# Subtle ambient — let directional lights do the work
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.08, 0.09, 0.14)
	env.ambient_light_energy = 0.3

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1

	# Restrained bloom — only on bright specular highlights
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.03
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	# Slight fog for depth
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.07, 0.12)
	env.fog_density = 0.003
	env.fog_sky_affect = 0.0

	env_node.environment = env
	env_node.name = "env"
	add_child(env_node)

	# Key light — warm, from upper-right, casts shadows
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.name = "key_light"
	key.rotation_degrees = Vector3(-42, -28, 0)
	key.light_energy = 2.2
	key.light_color = Color(1.0, 0.92, 0.78)
	key.shadow_enabled = true
	key.shadow_bias = 0.03
	key.directional_shadow_max_distance = 20.0
	add_child(key)

	# Fill light — cool from left, softer
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "fill_light"
	fill.rotation_degrees = Vector3(-15, 145, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.55, 0.65, 0.95)
	fill.shadow_enabled = false
	add_child(fill)

	# Rim light — cool backlight for edge definition
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.name = "rim_light"
	rim.rotation_degrees = Vector3(20, 180, 0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.50, 0.58, 1.0)
	rim.shadow_enabled = false
	add_child(rim)

	# Core glow — warm point light at center
	var core: OmniLight3D = OmniLight3D.new()
	core.name = "core_glow"
	core.position = Vector3.ZERO
	core.light_energy = 1.2
	core.light_color = Color(1.0, 0.82, 0.55)
	core.omni_range = INNER_R * 2.0
	core.omni_attenuation = 2.0
	core.shadow_enabled = false
	add_child(core)

	# Outer accent light — very faint, cool, from below
	var under: OmniLight3D = OmniLight3D.new()
	under.name = "under_glow"
	under.position = Vector3(0, -OUTER_R * 0.8, 0)
	under.light_energy = 0.15
	under.light_color = Color(0.4, 0.5, 0.9)
	under.omni_range = OUTER_R * 2.0
	under.omni_attenuation = 1.5
	add_child(under)

func _update_lighting() -> void:
	# Subtle light breathing tied to simulation energy
	var sun_omega: float = abs((model.rotors["sun"] as RefCounted).omega)
	var energy_factor: float = clampf(sun_omega / 3.0, 0.3, 1.0)
	var breath: float = 0.9 + 0.1 * sin(time_acc * 0.2)

	var core: OmniLight3D = get_node_or_null("core_glow")
	if core != null:
		core.light_energy = 0.8 + energy_factor * 0.6 * breath

	var key: DirectionalLight3D = get_node_or_null("key_light")
	if key != null:
		# Warm shift with torque
		var warmth: float = clampf(model.drive_torque / 60.0, 0.0, 1.0)
		key.light_color = Color(1.0, 0.92 - warmth * 0.04, 0.78 - warmth * 0.06)

# ──────────────────── Orbs ────────────────────

func _create_orbs() -> void:
	var glass_mats: Array[StandardMaterial3D] = [mat_glass_inner, mat_glass_middle, mat_glass_outer]
	for i in range(3):
		var orb: MeshInstance3D = MeshInstance3D.new()
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = orb_radii[i]
		mesh.height = orb_radii[i] * 2.0
		mesh.radial_segments = 64
		mesh.rings = 32
		orb.mesh = mesh
		orb.material_override = glass_mats[i]
		orb.name = "orb_%d" % i
		add_child(orb)
		orb_meshes.append(orb)

		# Equatorial ring
		_add_accent_ring(orb, orb_radii[i], 0.025, mat_ring_accent[i])
		# Tropics
		var tropic_mat: StandardMaterial3D = mat_ring_accent[i].duplicate()
		tropic_mat.albedo_color.a *= 0.4
		tropic_mat.emission_energy_multiplier *= 0.3
		for lat in [0.35, 0.65]:
			_add_accent_ring(orb, orb_radii[i] * sin(PI * lat), 0.012, tropic_mat, orb_radii[i] * cos(PI * lat))

func _add_accent_ring(parent: Node3D, ring_r: float, thickness: float, mat: StandardMaterial3D, y: float = 0.0) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var tmesh: TorusMesh = TorusMesh.new()
	tmesh.inner_radius = ring_r - thickness
	tmesh.outer_radius = ring_r + thickness
	tmesh.rings = 80
	tmesh.ring_segments = 8
	ring.mesh = tmesh
	ring.material_override = mat
	ring.position.y = y
	parent.add_child(ring)

func _update_orbs(delta: float) -> void:
	if orb_meshes.size() < 3:
		return
	var carrier_omega: float = (model.rotors["carrier"] as RefCounted).omega
	orb_meshes[0].rotation.y += carrier_omega * delta * 0.3
	var dial_omega: float = (model.rotors["dial"] as RefCounted).omega
	orb_meshes[1].rotation.y += dial_omega * delta * 0.2
	var geneva_theta: float = (model.rotors["geneva"] as RefCounted).theta
	orb_meshes[2].rotation.y = geneva_theta * 0.08

# ──────────────────── Gears ────────────────────

func _create_gears() -> void:
	for rotor_name in rotor_map:
		var info: Dictionary = rotor_map[rotor_name]
		var orb_idx: int = int(info["orb"])
		var sph_theta: float = float(info["theta"])
		var sph_phi: float = float(info["phi"])
		var gear_scale: float = float(info["scale"])
		var r: float = orb_radii[orb_idx]

		var node: Node3D = Node3D.new()
		node.name = rotor_name
		node.position = _sph2cart(sph_theta, sph_phi, r)
		node.look_at(Vector3.ZERO, Vector3.UP)
		node.rotate_object_local(Vector3.RIGHT, PI)

		_build_gear(node, rotor_name, gear_scale)
		orb_meshes[orb_idx].add_child(node)
		gear_nodes[rotor_name] = node

func _build_gear(parent: Node3D, rotor_name: String, gear_scale: float) -> void:
	var rotor: RefCounted = model.rotors.get(rotor_name)
	if rotor == null:
		return

	var teeth: int = rotor.tooth_count
	var radius: float = rotor.display_radius * 0.011 * gear_scale
	var height: float = 0.045 * gear_scale
	var tooth_depth: float = 0.04 * gear_scale
	var tooth_width: float = 0.025 * gear_scale

	# Choose material based on rotor role
	var body_mat: StandardMaterial3D = mat_brass
	if rotor_name == "balance":
		body_mat = mat_polished_steel
	elif rotor_name == "ring":
		body_mat = mat_dark_steel
	elif rotor_name == "dial":
		body_mat = mat_bone

	# Gear body — the main disc
	var body: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = max(teeth * 2, 24)
	body.mesh = cyl
	body.material_override = body_mat
	body.name = "body"
	parent.add_child(body)

	# Inner hub ring — visual depth
	var hub_ring: MeshInstance3D = MeshInstance3D.new()
	var hr_cyl: CylinderMesh = CylinderMesh.new()
	hr_cyl.top_radius = radius * 0.55
	hr_cyl.bottom_radius = radius * 0.55
	hr_cyl.height = height * 1.3
	hub_ring.mesh = hr_cyl
	hub_ring.material_override = mat_dark_steel
	hub_ring.name = "hub_ring"
	parent.add_child(hub_ring)

	# Teeth — individual boxes
	for i in range(teeth):
		var angle: float = TAU_F * float(i) / float(teeth)
		var tooth: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(tooth_depth, height * 0.75, tooth_width)
		tooth.mesh = box
		tooth.material_override = mat_brass_light
		tooth.position = Vector3(cos(angle) * (radius + tooth_depth * 0.35), 0, sin(angle) * (radius + tooth_depth * 0.35))
		tooth.rotation.y = -angle
		parent.add_child(tooth)

	# Spokes — connecting hub to rim
	var spoke_count: int = max(rotor.spoke_count, 3)
	for i in range(spoke_count):
		var angle: float = TAU_F * float(i) / float(spoke_count)
		var spoke: MeshInstance3D = MeshInstance3D.new()
		var spoke_mesh: BoxMesh = BoxMesh.new()
		var spoke_len: float = radius * 0.55
		spoke_mesh.size = Vector3(spoke_len, height * 0.4, 0.012 * gear_scale)
		spoke.mesh = spoke_mesh
		spoke.material_override = mat_dark_steel
		spoke.position = Vector3(cos(angle) * radius * 0.35, 0, sin(angle) * radius * 0.35)
		spoke.rotation.y = -angle
		parent.add_child(spoke)

	# Central shaft — polished steel pin
	var shaft: MeshInstance3D = MeshInstance3D.new()
	var s_cyl: CylinderMesh = CylinderMesh.new()
	s_cyl.top_radius = 0.018 * gear_scale
	s_cyl.bottom_radius = 0.022 * gear_scale  # slight taper
	s_cyl.height = height * 3.0
	shaft.mesh = s_cyl
	shaft.material_override = mat_shaft
	shaft.name = "shaft"
	parent.add_child(shaft)

	# Shaft cap — polished dome
	var cap: MeshInstance3D = MeshInstance3D.new()
	var cap_mesh: SphereMesh = SphereMesh.new()
	cap_mesh.radius = 0.024 * gear_scale
	cap_mesh.height = 0.032 * gear_scale
	cap.mesh = cap_mesh
	cap.material_override = mat_polished_steel
	cap.position.y = height * 1.6
	parent.add_child(cap)

func _update_gears() -> void:
	for rotor_name in gear_nodes:
		var node: Node3D = gear_nodes[rotor_name]
		var rotor: RefCounted = model.rotors.get(rotor_name)
		if rotor == null:
			continue
		# Rotate the entire gear node around its local Y
		# (all children — body, teeth, spokes — rotate together)
		var base_orient: Basis = Basis.IDENTITY
		node.basis = base_orient
		node.look_at(node.global_position * 2.0 - orb_meshes[0].global_position, Vector3.UP)
		node.rotate_object_local(Vector3.RIGHT, PI)
		node.rotate_object_local(Vector3.UP, rotor.theta)

# ──────────────────── Connectors ────────────────────

func _create_connectors() -> void:
	var pairs: Array = [
		["ring", "dial"],
		["dial", "flywheel"],
		["escapement", "balance"],
	]
	for pair in pairs:
		var rod: Node3D = Node3D.new()
		rod.name = "conn_%s_%s" % [str(pair[0]), str(pair[1])]
		add_child(rod)
		connector_nodes.append(rod)

		# Create the mesh — will be repositioned in _update_connectors
		var mesh: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.008
		cyl.bottom_radius = 0.010
		cyl.height = 1.0  # will be rescaled
		mesh.mesh = cyl
		mesh.material_override = mat_connector
		mesh.name = "mesh"
		rod.add_child(mesh)

		# End caps — small spheres
		for cap_name in ["cap_a", "cap_b"]:
			var cap: MeshInstance3D = MeshInstance3D.new()
			var cap_mesh: SphereMesh = SphereMesh.new()
			cap_mesh.radius = 0.016
			cap_mesh.height = 0.032
			cap.mesh = cap_mesh
			cap.material_override = mat_polished_steel
			cap.name = cap_name
			rod.add_child(cap)

func _update_connectors() -> void:
	var pairs: Array = [
		["ring", "dial"],
		["dial", "flywheel"],
		["escapement", "balance"],
	]
	for i in range(mini(pairs.size(), connector_nodes.size())):
		var from_name: String = str(pairs[i][0])
		var to_name: String = str(pairs[i][1])
		var from_node: Node3D = gear_nodes.get(from_name)
		var to_node: Node3D = gear_nodes.get(to_name)
		if from_node == null or to_node == null:
			continue
		var from_pos: Vector3 = from_node.global_position
		var to_pos: Vector3 = to_node.global_position
		var mid: Vector3 = (from_pos + to_pos) * 0.5
		var length: float = from_pos.distance_to(to_pos)

		var rod: Node3D = connector_nodes[i]
		var mesh: MeshInstance3D = rod.get_node_or_null("mesh")
		if mesh != null:
			mesh.global_position = mid
			if length > 0.01:
				mesh.look_at(to_pos, Vector3.UP)
				mesh.rotate_object_local(Vector3.RIGHT, PI / 2.0)
				mesh.scale = Vector3(1, length, 1)

		var cap_a: MeshInstance3D = rod.get_node_or_null("cap_a")
		var cap_b: MeshInstance3D = rod.get_node_or_null("cap_b")
		if cap_a != null:
			cap_a.global_position = from_pos
		if cap_b != null:
			cap_b.global_position = to_pos

# ──────────────────── Camera ────────────────────

func _create_camera() -> void:
	var cam: Camera3D = Camera3D.new()
	cam.name = "Camera"
	cam.current = true
	cam.fov = 42.0  # tighter for intimacy
	add_child(cam)
	_update_camera()

func _update_camera() -> void:
	var cam: Camera3D = get_node_or_null("Camera")
	if cam == null:
		return
	var dist: float = OUTER_R * 3.0
	# Slow gentle elevation drift
	var elev: float = sin(orbit_angle * 0.25) * 0.18 + 0.15
	cam.position = Vector3(
		cos(orbit_angle) * dist * cos(elev),
		sin(elev) * dist * 0.4 + 0.8,
		sin(orbit_angle) * dist * cos(elev)
	)
	# Look slightly above center for better composition
	cam.look_at(Vector3(0, 0.25, 0), Vector3.UP)

# ──────────────────── Util ────────────────────

func _sph2cart(theta: float, phi: float, r: float) -> Vector3:
	return Vector3(r * sin(theta) * cos(phi), r * cos(theta), r * sin(theta) * sin(phi))
