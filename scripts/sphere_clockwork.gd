extends Node3D
## Clockwork mechanism wrapped around the surface of a sphere.
## The simulation is identical — only the rendering maps flat rotors
## onto spherical coordinates. Each gear's rotation axis is the
## sphere's surface normal at its placement point.

const MechanismModelClass = preload("res://scripts/mechanism_model.gd")

const SPHERE_RADIUS: float = 4.0
const TAU_F: float = PI * 2.0

var model: RefCounted
var gear_nodes: Dictionary = {}
var linkage_meshes: Array = []
var sphere_mesh: MeshInstance3D
var orbit_angle: float = 0.0
var auto_orbit: bool = true

# Spherical placement of each rotor (theta=polar from +Y, phi=azimuthal from +X)
var rotor_placements: Dictionary = {
	"sun":        {"theta": PI * 0.50, "phi": 0.0,          "scale": 1.0},
	"carrier":    {"theta": PI * 0.50, "phi": 0.0,          "scale": 1.4},
	"planet_a":   {"theta": PI * 0.32, "phi": PI * 0.25,    "scale": 0.7},
	"planet_b":   {"theta": PI * 0.68, "phi": PI * -0.25,   "scale": 0.7},
	"ring":       {"theta": PI * 0.50, "phi": 0.0,          "scale": 2.0},
	"dial":       {"theta": PI * 0.30, "phi": PI * 0.70,    "scale": 0.6},
	"escapement": {"theta": PI * 0.22, "phi": PI * 0.90,    "scale": 0.5},
	"balance":    {"theta": PI * 0.15, "phi": PI * 1.10,    "scale": 0.9},
	"flywheel":   {"theta": PI * 0.75, "phi": PI * 0.80,    "scale": 0.8},
	"clickwheel": {"theta": PI * 0.82, "phi": PI * 1.05,    "scale": 0.4},
	"geneva":     {"theta": PI * 0.88, "phi": PI * 1.30,    "scale": 0.65},
}

func _ready() -> void:
	model = MechanismModelClass.new()
	model.reset()
	_setup_environment()
	_create_sphere()
	_create_gears()
	_create_camera()

func _physics_process(delta: float) -> void:
	model.step(delta)
	_update_gears()
	if auto_orbit:
		orbit_angle += delta * 0.08
		_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			model.paused = not model.paused
		elif event.keycode == KEY_R:
			model.reset()
		elif event.keycode == KEY_O:
			auto_orbit = not auto_orbit
		elif event.keycode == KEY_UP:
			model.drive_torque = min(model.drive_torque + 4.0, 80.0)
		elif event.keycode == KEY_DOWN:
			model.drive_torque = max(model.drive_torque - 4.0, 4.0)

func _setup_environment() -> void:
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.18, 0.25)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.05
	env_node.environment = env
	add_child(env_node)

	# Key light — warm from above-right
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, -30, 0)
	key.light_energy = 1.8
	key.light_color = Color(1.0, 0.95, 0.85)
	key.shadow_enabled = true
	add_child(key)

	# Rim light — cool from below-left
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(30, 150, 0)
	rim.light_energy = 0.5
	rim.light_color = Color(0.6, 0.7, 1.0)
	add_child(rim)

func _create_sphere() -> void:
	sphere_mesh = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = SPHERE_RADIUS * 0.98
	mesh.height = SPHERE_RADIUS * 1.96
	mesh.radial_segments = 64
	mesh.rings = 32
	sphere_mesh.mesh = mesh

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.07, 0.10)
	mat.metallic = 0.3
	mat.roughness = 0.7
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.4
	sphere_mesh.material_override = mat
	add_child(sphere_mesh)

	# Wireframe latitude/longitude lines
	_add_sphere_grid()

func _add_sphere_grid() -> void:
	var grid_mat: StandardMaterial3D = StandardMaterial3D.new()
	grid_mat.albedo_color = Color(0.15, 0.20, 0.30, 0.3)
	grid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Latitude lines
	for lat_i in range(1, 6):
		var lat_theta: float = PI * float(lat_i) / 6.0
		var ring_r: float = SPHERE_RADIUS * sin(lat_theta)
		var ring_y: float = SPHERE_RADIUS * cos(lat_theta)
		var torus: MeshInstance3D = MeshInstance3D.new()
		var tmesh: TorusMesh = TorusMesh.new()
		tmesh.inner_radius = ring_r - 0.01
		tmesh.outer_radius = ring_r + 0.01
		tmesh.rings = 64
		tmesh.ring_segments = 4
		torus.mesh = tmesh
		torus.material_override = grid_mat
		torus.position.y = ring_y
		add_child(torus)

func _create_gears() -> void:
	for rotor_name in rotor_placements:
		var placement: Dictionary = rotor_placements[rotor_name]
		var node: Node3D = Node3D.new()
		node.name = rotor_name

		# Position on sphere surface
		var sph_theta: float = float(placement["theta"])
		var sph_phi: float = float(placement["phi"])
		var pos: Vector3 = _spherical_to_cartesian(sph_theta, sph_phi, SPHERE_RADIUS)
		node.position = pos

		# Orient so local Z points outward (along sphere normal)
		node.look_at(Vector3.ZERO, Vector3.UP)
		node.rotate_object_local(Vector3.RIGHT, PI)

		# Create gear mesh
		var gear_scale: float = float(placement["scale"])
		_add_gear_mesh(node, rotor_name, gear_scale)

		add_child(node)
		gear_nodes[rotor_name] = node

func _add_gear_mesh(parent: Node3D, rotor_name: String, gear_scale: float) -> void:
	var rotor: RefCounted = model.rotors.get(rotor_name)
	if rotor == null:
		return

	var teeth: int = rotor.tooth_count
	var radius: float = rotor.display_radius * 0.012 * gear_scale
	var color: Color = rotor.color

	# Gear body — cylinder
	var body: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.06 * gear_scale
	cyl.radial_segments = max(teeth, 12)
	body.mesh = cyl

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.6
	mat.roughness = 0.35
	body.material_override = mat
	body.name = "body"
	parent.add_child(body)

	# Gear teeth — small boxes around the perimeter
	for i in range(teeth):
		var angle: float = TAU_F * float(i) / float(teeth)
		var tooth: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		var tooth_size: float = 0.04 * gear_scale
		box.size = Vector3(tooth_size, 0.05 * gear_scale, tooth_size * 0.6)
		tooth.mesh = box

		var tooth_mat: StandardMaterial3D = StandardMaterial3D.new()
		tooth_mat.albedo_color = color.lightened(0.2)
		tooth_mat.metallic = 0.7
		tooth_mat.roughness = 0.3
		tooth.material_override = tooth_mat

		tooth.position = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		tooth.rotation.y = -angle
		tooth.name = "tooth_%d" % i
		parent.add_child(tooth)

	# Shaft hub
	var hub: MeshInstance3D = MeshInstance3D.new()
	var hub_cyl: CylinderMesh = CylinderMesh.new()
	hub_cyl.top_radius = 0.04 * gear_scale
	hub_cyl.bottom_radius = 0.04 * gear_scale
	hub_cyl.height = 0.12 * gear_scale
	hub.mesh = hub_cyl

	var hub_mat: StandardMaterial3D = StandardMaterial3D.new()
	hub_mat.albedo_color = Color(0.8, 0.75, 0.6)
	hub_mat.metallic = 0.8
	hub_mat.roughness = 0.2
	hub.material_override = hub_mat
	hub.name = "hub"
	parent.add_child(hub)

func _update_gears() -> void:
	for rotor_name in gear_nodes:
		var node: Node3D = gear_nodes[rotor_name]
		var rotor: RefCounted = model.rotors.get(rotor_name)
		if rotor == null:
			continue
		# Rotate gear around its local Y axis (which points along sphere normal)
		node.rotation.y = rotor.theta

	# Update planet positions on the sphere (they orbit)
	var carrier_theta: float = (model.rotors["carrier"] as RefCounted).theta
	for planet_name in ["planet_a", "planet_b"]:
		var rotor: RefCounted = model.rotors[planet_name]
		var base_placement: Dictionary = rotor_placements[planet_name]
		var base_phi: float = float(base_placement["phi"])
		var base_theta: float = float(base_placement["theta"])
		# Orbit the planets around the equator
		var orbit_offset: float = carrier_theta * 0.15
		var new_phi: float = base_phi + orbit_offset
		var pos: Vector3 = _spherical_to_cartesian(base_theta, new_phi, SPHERE_RADIUS)
		var node: Node3D = gear_nodes[planet_name]
		node.position = pos
		node.look_at(Vector3.ZERO, Vector3.UP)
		node.rotate_object_local(Vector3.RIGHT, PI)
		node.rotation.y = rotor.theta

func _create_camera() -> void:
	var cam: Camera3D = Camera3D.new()
	cam.name = "Camera"
	cam.current = true
	add_child(cam)
	_update_camera()

func _update_camera() -> void:
	var cam: Camera3D = get_node("Camera")
	if cam == null:
		return
	var dist: float = SPHERE_RADIUS * 3.2
	var elevation: float = 0.3
	cam.position = Vector3(
		cos(orbit_angle) * dist * cos(elevation),
		sin(elevation) * dist * 0.6 + 1.0,
		sin(orbit_angle) * dist * cos(elevation)
	)
	cam.look_at(Vector3.ZERO, Vector3.UP)

func _spherical_to_cartesian(theta: float, phi: float, r: float) -> Vector3:
	return Vector3(
		r * sin(theta) * cos(phi),
		r * cos(theta),
		r * sin(theta) * sin(phi)
	)
