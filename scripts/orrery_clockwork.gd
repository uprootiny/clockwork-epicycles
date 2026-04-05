extends Node3D
## Clockwork orrery: mechanical subsystems on concentric transparent orbs.
## Inner orb: epicyclic core (sun, carrier, planets, ring)
## Middle orb: transmission (dial, escapement, balance)
## Outer orb: ceremonial outputs (flywheel, clickwheel, geneva)
## Each orb rotates at its own rate derived from the simulation.

const MechanismModelClass = preload("res://scripts/mechanism_model.gd")

const TAU_F: float = PI * 2.0
const INNER_R: float = 2.0
const MIDDLE_R: float = 3.5
const OUTER_R: float = 5.0

var model: RefCounted
var gear_nodes: Dictionary = {}
var orb_nodes: Array[MeshInstance3D] = []
var orbit_angle: float = 0.0
var auto_orbit: bool = true

# Which orb each rotor lives on, plus its angular placement
var rotor_map: Dictionary = {
	# Inner orb — epicyclic core
	"sun":        {"orb": 0, "theta": PI * 0.50, "phi": 0.0,        "scale": 0.9},
	"carrier":    {"orb": 0, "theta": PI * 0.50, "phi": 0.0,        "scale": 1.2},
	"planet_a":   {"orb": 0, "theta": PI * 0.38, "phi": PI * 0.35,  "scale": 0.6},
	"planet_b":   {"orb": 0, "theta": PI * 0.62, "phi": PI * -0.35, "scale": 0.6},
	"ring":       {"orb": 0, "theta": PI * 0.50, "phi": PI * 1.0,   "scale": 1.1},
	# Middle orb — regulation
	"dial":       {"orb": 1, "theta": PI * 0.35, "phi": PI * 0.0,   "scale": 0.55},
	"escapement": {"orb": 1, "theta": PI * 0.25, "phi": PI * 0.5,   "scale": 0.45},
	"balance":    {"orb": 1, "theta": PI * 0.50, "phi": PI * 1.0,   "scale": 0.8},
	# Outer orb — ceremonial
	"flywheel":   {"orb": 2, "theta": PI * 0.40, "phi": PI * 0.2,   "scale": 0.7},
	"clickwheel": {"orb": 2, "theta": PI * 0.60, "phi": PI * 0.9,   "scale": 0.35},
	"geneva":     {"orb": 2, "theta": PI * 0.50, "phi": PI * 1.5,   "scale": 0.55},
}

var orb_radii: Array[float] = [INNER_R, MIDDLE_R, OUTER_R]
var orb_colors: Array[Color] = [
	Color(0.85, 0.70, 0.40, 0.08),  # inner: warm brass tint
	Color(0.50, 0.65, 0.80, 0.06),  # middle: cool steel
	Color(0.70, 0.50, 0.85, 0.05),  # outer: violet ceremonial
]
var orb_ring_colors: Array[Color] = [
	Color(0.90, 0.75, 0.45, 0.25),
	Color(0.55, 0.70, 0.85, 0.20),
	Color(0.75, 0.55, 0.90, 0.18),
]

func _ready() -> void:
	model = MechanismModelClass.new()
	model.reset()
	_setup_environment()
	_create_orbs()
	_create_gears()
	_create_connectors()
	_create_camera()

func _physics_process(delta: float) -> void:
	model.step(delta)
	_update_orbs()
	_update_gears()
	if auto_orbit:
		orbit_angle += delta * 0.06
		_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE: model.paused = not model.paused
			KEY_R: model.reset()
			KEY_O: auto_orbit = not auto_orbit
			KEY_UP: model.drive_torque = min(model.drive_torque + 4.0, 80.0)
			KEY_DOWN: model.drive_torque = max(model.drive_torque - 4.0, 4.0)

func _setup_environment() -> void:
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.14, 0.20)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.08
	env_node.environment = env
	add_child(env_node)

	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -25, 0)
	key.light_energy = 2.0
	key.light_color = Color(1.0, 0.93, 0.82)
	key.shadow_enabled = true
	add_child(key)

	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(25, 160, 0)
	rim.light_energy = 0.4
	rim.light_color = Color(0.5, 0.6, 1.0)
	add_child(rim)

	# Point light at center — warm core glow
	var core_light: OmniLight3D = OmniLight3D.new()
	core_light.position = Vector3.ZERO
	core_light.light_energy = 0.8
	core_light.light_color = Color(1.0, 0.85, 0.6)
	core_light.omni_range = INNER_R * 2.5
	core_light.omni_attenuation = 1.5
	add_child(core_light)

func _create_orbs() -> void:
	for i in range(3):
		var orb: MeshInstance3D = MeshInstance3D.new()
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = orb_radii[i]
		mesh.height = orb_radii[i] * 2.0
		mesh.radial_segments = 48
		mesh.rings = 24
		orb.mesh = mesh

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = orb_colors[i]
		mat.metallic = 0.1
		mat.roughness = 0.9
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		orb.material_override = mat
		orb.name = "orb_%d" % i
		add_child(orb)
		orb_nodes.append(orb)

		# Equatorial ring — brighter accent
		_add_ring(orb_radii[i], orb_ring_colors[i], 0.03, i)
		# Tropic rings
		_add_ring(orb_radii[i] * sin(PI * 0.35), orb_ring_colors[i] * Color(1, 1, 1, 0.5), 0.015, i, orb_radii[i] * cos(PI * 0.35))
		_add_ring(orb_radii[i] * sin(PI * 0.65), orb_ring_colors[i] * Color(1, 1, 1, 0.5), 0.015, i, orb_radii[i] * cos(PI * 0.65))

func _add_ring(ring_radius: float, color: Color, thickness: float, orb_idx: int, y_offset: float = 0.0) -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	var tmesh: TorusMesh = TorusMesh.new()
	tmesh.inner_radius = ring_radius - thickness
	tmesh.outer_radius = ring_radius + thickness
	tmesh.rings = 64
	tmesh.ring_segments = 6
	ring.mesh = tmesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	ring.position.y = y_offset
	orb_nodes[orb_idx].add_child(ring)

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
		var pos: Vector3 = _spherical_to_cartesian(sph_theta, sph_phi, r)
		node.position = pos
		node.look_at(Vector3.ZERO, Vector3.UP)
		node.rotate_object_local(Vector3.RIGHT, PI)

		_add_gear_mesh(node, rotor_name, gear_scale)
		orb_nodes[orb_idx].add_child(node)
		gear_nodes[rotor_name] = node

func _add_gear_mesh(parent: Node3D, rotor_name: String, gear_scale: float) -> void:
	var rotor: RefCounted = model.rotors.get(rotor_name)
	if rotor == null:
		return

	var teeth: int = rotor.tooth_count
	var radius: float = rotor.display_radius * 0.01 * gear_scale
	var color: Color = rotor.color
	var height: float = 0.05 * gear_scale

	# Gear body
	var body: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = max(teeth, 12)
	body.mesh = cyl
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.65
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = color * 0.15
	mat.emission_energy_multiplier = 0.3
	body.material_override = mat
	body.name = "body"
	parent.add_child(body)

	# Teeth
	var tooth_mat: StandardMaterial3D = StandardMaterial3D.new()
	tooth_mat.albedo_color = color.lightened(0.25)
	tooth_mat.metallic = 0.7
	tooth_mat.roughness = 0.25
	for i in range(teeth):
		var angle: float = TAU_F * float(i) / float(teeth)
		var tooth: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		var ts: float = 0.035 * gear_scale
		box.size = Vector3(ts, height * 0.8, ts * 0.5)
		tooth.mesh = box
		tooth.material_override = tooth_mat
		tooth.position = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		tooth.rotation.y = -angle
		parent.add_child(tooth)

	# Shaft
	var hub: MeshInstance3D = MeshInstance3D.new()
	var hcyl: CylinderMesh = CylinderMesh.new()
	hcyl.top_radius = 0.03 * gear_scale
	hcyl.bottom_radius = 0.03 * gear_scale
	hcyl.height = height * 2.5
	hub.mesh = hcyl
	var hub_mat: StandardMaterial3D = StandardMaterial3D.new()
	hub_mat.albedo_color = Color(0.82, 0.78, 0.65)
	hub_mat.metallic = 0.85
	hub_mat.roughness = 0.15
	hub.material_override = hub_mat
	parent.add_child(hub)

func _create_connectors() -> void:
	# Visual connectors between orbs — thin rods from inner to outer gear pairs
	var connections: Array = [
		["ring", "dial"],        # inner → middle
		["dial", "flywheel"],    # middle → outer (belt)
		["escapement", "balance"],
	]
	var rod_mat: StandardMaterial3D = StandardMaterial3D.new()
	rod_mat.albedo_color = Color(0.5, 0.55, 0.65, 0.6)
	rod_mat.metallic = 0.5
	rod_mat.roughness = 0.4
	rod_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for conn in connections:
		var from_name: String = str(conn[0])
		var to_name: String = str(conn[1])
		var from_info: Dictionary = rotor_map[from_name]
		var to_info: Dictionary = rotor_map[to_name]
		var from_r: float = orb_radii[int(from_info["orb"])]
		var to_r: float = orb_radii[int(to_info["orb"])]
		var from_pos: Vector3 = _spherical_to_cartesian(float(from_info["theta"]), float(from_info["phi"]), from_r)
		var to_pos: Vector3 = _spherical_to_cartesian(float(to_info["theta"]), float(to_info["phi"]), to_r)

		var rod: MeshInstance3D = MeshInstance3D.new()
		var rod_cyl: CylinderMesh = CylinderMesh.new()
		var length: float = from_pos.distance_to(to_pos)
		rod_cyl.top_radius = 0.012
		rod_cyl.bottom_radius = 0.012
		rod_cyl.height = length
		rod.mesh = rod_cyl
		rod.material_override = rod_mat
		var midpoint: Vector3 = (from_pos + to_pos) * 0.5
		rod.position = midpoint
		rod.look_at(to_pos, Vector3.UP)
		rod.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		rod.name = "rod_%s_%s" % [from_name, to_name]
		add_child(rod)

func _update_orbs() -> void:
	if orb_nodes.size() < 3:
		return
	# Inner orb slowly follows carrier
	var carrier_omega: float = (model.rotors["carrier"] as RefCounted).omega
	orb_nodes[0].rotation.y += carrier_omega * 0.02

	# Middle orb tracks dial
	var dial_omega: float = (model.rotors["dial"] as RefCounted).omega
	orb_nodes[1].rotation.y += dial_omega * 0.015

	# Outer orb follows geneva steps
	var geneva_theta: float = (model.rotors["geneva"] as RefCounted).theta
	orb_nodes[2].rotation.y = geneva_theta * 0.1

func _update_gears() -> void:
	for rotor_name in gear_nodes:
		var node: Node3D = gear_nodes[rotor_name]
		var rotor: RefCounted = model.rotors.get(rotor_name)
		if rotor == null:
			continue
		# Rotate gear around local Y (outward from sphere)
		# Find the body child and rotate it
		var body: Node = node.get_node_or_null("body")
		if body != null:
			body.rotation.y = rotor.theta
		# Rotate teeth too
		for child in node.get_children():
			if child.name != "body" and child is MeshInstance3D:
				# Only rotate the hub to show spin
				pass

func _create_camera() -> void:
	var cam: Camera3D = Camera3D.new()
	cam.name = "Camera"
	cam.current = true
	cam.fov = 50.0
	add_child(cam)
	_update_camera()

func _update_camera() -> void:
	var cam: Camera3D = get_node_or_null("Camera")
	if cam == null:
		return
	var dist: float = OUTER_R * 2.8
	var elev: float = sin(orbit_angle * 0.3) * 0.25 + 0.2
	cam.position = Vector3(
		cos(orbit_angle) * dist * cos(elev),
		sin(elev) * dist * 0.5 + 0.5,
		sin(orbit_angle) * dist * cos(elev)
	)
	cam.look_at(Vector3(0, 0.3, 0), Vector3.UP)

func _spherical_to_cartesian(theta: float, phi: float, r: float) -> Vector3:
	return Vector3(
		r * sin(theta) * cos(phi),
		r * cos(theta),
		r * sin(theta) * sin(phi)
	)
