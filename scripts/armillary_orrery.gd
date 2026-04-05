extends Node3D
## Armillary orrery with mechanically honest power transmission.
##
## Architecture:
##   Drive shaft (vertical) → crown gear at base
##   Crown gear meshes with lantern pinion on equatorial ring
##   Equatorial ring carries epicyclic differential
##   Differential outputs drive meridian rings at different rates
##   Bevel gears transfer rotation between ring planes
##
## Ring hierarchy (inside out):
##   Ring 0: Hour ring (fast, equatorial plane)
##   Ring 1: Day ring (medium, tilted 23.4°)
##   Ring 2: Month ring (slow, tilted 45°)
##   Ring 3: Year ring (very slow, polar plane)
##
## Each ring has gear teeth on its inner/outer edge.
## Adjacent rings mesh through bevel gears at their intersection points.

const OrreryMechanismClass = preload("res://scripts/mechanism/exact/orrery_mechanism.gd")
const TAU_F: float = PI * 2.0

var mech: RefCounted  # OrreryMechanism
var time_acc: float = 0.0
var orbit_angle: float = 0.0
var auto_orbit: bool = true

# Ring parameters
var ring_count: int = 4
var ring_radii: Array[float] = [1.8, 2.6, 3.4, 4.2]
var ring_tilts: Array[float] = [0.0, 0.408, 0.785, 1.571]  # 0°, 23.4°, 45°, 90°
var ring_widths: Array[float] = [0.12, 0.10, 0.08, 0.07]
var ring_speeds: Array[float] = [1.0, 0.35, 0.12, 0.03]  # relative to sun
var ring_teeth: Array[int] = [48, 36, 28, 20]
var ring_colors: Array[Color] = [
	Color(0.82, 0.65, 0.35),  # brass
	Color(0.70, 0.72, 0.76),  # steel
	Color(0.60, 0.50, 0.42),  # bronze
	Color(0.45, 0.48, 0.55),  # dark steel
]

var ring_nodes: Array[Node3D] = []
var ring_angles: Array[float] = [0.0, 0.0, 0.0, 0.0]
var bevel_nodes: Array[Node3D] = []
var lantern_nodes: Array[Node3D] = []
var drive_shaft_node: Node3D
var crown_gear_node: Node3D
var differential_cage: Node3D

# Materials
var mat_brass: StandardMaterial3D
var mat_brass_teeth: StandardMaterial3D
var mat_steel: StandardMaterial3D
var mat_dark_steel: StandardMaterial3D
var mat_polished: StandardMaterial3D
var mat_bronze: StandardMaterial3D
var mat_shaft: StandardMaterial3D
var mat_lantern_bar: StandardMaterial3D

func _ready() -> void:
	mech = OrreryMechanismClass.new()
	print(mech.get_report())
	_create_materials()
	_setup_lighting()
	_build_drive_shaft()
	_build_crown_gear()
	_build_rings()
	_build_bevel_gears()
	_build_lantern_pinions()
	_build_differential()
	_create_camera()

func _physics_process(delta: float) -> void:
	mech.step(delta)
	time_acc += delta
	_update_mechanism(delta)
	if auto_orbit:
		orbit_angle += delta * 0.04
	_update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE: mech.paused = not mech.paused
			KEY_R: mech.reset()
			KEY_O: auto_orbit = not auto_orbit
			KEY_UP: mech.drive_torque = min(mech.drive_torque + 0.5, 10.0)
			KEY_DOWN: mech.drive_torque = max(mech.drive_torque - 0.5, 0.1)

# ═══════════════════ Materials ═══════════════════

func _create_materials() -> void:
	mat_brass = StandardMaterial3D.new()
	mat_brass.albedo_color = Color(0.76, 0.60, 0.33)
	mat_brass.metallic = 0.85
	mat_brass.roughness = 0.28
	mat_brass.clearcoat_enabled = true
	mat_brass.clearcoat = 0.15
	mat_brass.clearcoat_roughness = 0.35

	mat_brass_teeth = StandardMaterial3D.new()
	mat_brass_teeth.albedo_color = Color(0.84, 0.70, 0.40)
	mat_brass_teeth.metallic = 0.90
	mat_brass_teeth.roughness = 0.18

	mat_steel = StandardMaterial3D.new()
	mat_steel.albedo_color = Color(0.68, 0.70, 0.74)
	mat_steel.metallic = 0.80
	mat_steel.roughness = 0.30
	mat_steel.clearcoat_enabled = true
	mat_steel.clearcoat = 0.1
	mat_steel.clearcoat_roughness = 0.3

	mat_dark_steel = StandardMaterial3D.new()
	mat_dark_steel.albedo_color = Color(0.15, 0.17, 0.21)
	mat_dark_steel.metallic = 0.75
	mat_dark_steel.roughness = 0.40

	mat_polished = StandardMaterial3D.new()
	mat_polished.albedo_color = Color(0.80, 0.82, 0.85)
	mat_polished.metallic = 0.95
	mat_polished.roughness = 0.08
	mat_polished.clearcoat_enabled = true
	mat_polished.clearcoat = 0.4
	mat_polished.clearcoat_roughness = 0.1

	mat_bronze = StandardMaterial3D.new()
	mat_bronze.albedo_color = Color(0.55, 0.42, 0.28)
	mat_bronze.metallic = 0.80
	mat_bronze.roughness = 0.35

	mat_shaft = StandardMaterial3D.new()
	mat_shaft.albedo_color = Color(0.10, 0.11, 0.14)
	mat_shaft.metallic = 0.92
	mat_shaft.roughness = 0.12

	mat_lantern_bar = StandardMaterial3D.new()
	mat_lantern_bar.albedo_color = Color(0.70, 0.58, 0.38)
	mat_lantern_bar.metallic = 0.88
	mat_lantern_bar.roughness = 0.22

# ═══════════════════ Lighting ═══════════════════

func _setup_lighting() -> void:
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.018, 0.032)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.06, 0.07, 0.11)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.2
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.05, 0.09)
	env.fog_density = 0.002
	env_node.environment = env
	add_child(env_node)

	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, -32, 0)
	key.light_energy = 2.4
	key.light_color = Color(1.0, 0.91, 0.76)
	key.shadow_enabled = true
	key.shadow_bias = 0.02
	add_child(key)

	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 150, 0)
	fill.light_energy = 0.3
	fill.light_color = Color(0.50, 0.60, 0.90)
	add_child(fill)

	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(15, 200, 0)
	rim.light_energy = 0.55
	rim.light_color = Color(0.45, 0.55, 1.0)
	add_child(rim)

	# Warm glow at center where drive shaft meets crown
	var core: OmniLight3D = OmniLight3D.new()
	core.name = "core_glow"
	core.position = Vector3(0, -0.5, 0)
	core.light_energy = 1.0
	core.light_color = Color(1.0, 0.80, 0.50)
	core.omni_range = 3.0
	core.omni_attenuation = 2.0
	add_child(core)

# ═══════════════════ Drive Shaft ═══════════════════

func _build_drive_shaft() -> void:
	drive_shaft_node = Node3D.new()
	drive_shaft_node.name = "drive_shaft"
	add_child(drive_shaft_node)

	# Main vertical shaft
	var shaft: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.07
	cyl.height = 3.0
	shaft.mesh = cyl
	shaft.material_override = mat_shaft
	shaft.position.y = -0.5
	drive_shaft_node.add_child(shaft)

	# Bearing collars
	for y_pos in [-1.8, -0.2, 0.8]:
		var collar: MeshInstance3D = MeshInstance3D.new()
		var col_cyl: CylinderMesh = CylinderMesh.new()
		col_cyl.top_radius = 0.10
		col_cyl.bottom_radius = 0.10
		col_cyl.height = 0.06
		collar.mesh = col_cyl
		collar.material_override = mat_polished
		collar.position.y = y_pos
		drive_shaft_node.add_child(collar)

# ═══════════════════ Crown Gear ═══════════════════

func _build_crown_gear() -> void:
	crown_gear_node = Node3D.new()
	crown_gear_node.name = "crown_gear"
	crown_gear_node.position.y = -1.5
	drive_shaft_node.add_child(crown_gear_node)

	# Crown gear: face gear — teeth point upward from a flat disc
	var disc: MeshInstance3D = MeshInstance3D.new()
	var disc_cyl: CylinderMesh = CylinderMesh.new()
	disc_cyl.top_radius = 0.45
	disc_cyl.bottom_radius = 0.48
	disc_cyl.height = 0.04
	disc.mesh = disc_cyl
	disc.material_override = mat_brass
	crown_gear_node.add_child(disc)

	# Crown teeth — vertical pegs around the disc edge
	var crown_teeth: int = 24
	for i in range(crown_teeth):
		var angle: float = TAU_F * float(i) / float(crown_teeth)
		var tooth: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.035, 0.07, 0.02)
		tooth.mesh = box
		tooth.material_override = mat_brass_teeth
		tooth.position = Vector3(cos(angle) * 0.42, 0.05, sin(angle) * 0.42)
		tooth.rotation.y = -angle
		crown_gear_node.add_child(tooth)

# ═══════════════════ Armillary Rings ═══════════════════

func _build_rings() -> void:
	for i in range(ring_count):
		var ring_root: Node3D = Node3D.new()
		ring_root.name = "ring_%d" % i
		# Tilt the ring plane
		ring_root.rotation.x = ring_tilts[i]
		add_child(ring_root)
		ring_nodes.append(ring_root)

		var r: float = ring_radii[i]
		var w: float = ring_widths[i]
		var teeth: int = ring_teeth[i]

		# Select material for this ring
		var ring_mat: StandardMaterial3D
		match i:
			0: ring_mat = mat_brass
			1: ring_mat = mat_steel
			2: ring_mat = mat_bronze
			3: ring_mat = mat_dark_steel
			_: ring_mat = mat_brass

		# Main ring body — torus
		var body: MeshInstance3D = MeshInstance3D.new()
		var tmesh: TorusMesh = TorusMesh.new()
		tmesh.inner_radius = r - w * 0.5
		tmesh.outer_radius = r + w * 0.5
		tmesh.rings = 96
		tmesh.ring_segments = 12
		body.mesh = tmesh
		body.material_override = ring_mat
		body.name = "body"
		ring_root.add_child(body)

		# Inner edge teeth — point inward for meshing with bevels
		_add_ring_teeth(ring_root, r - w * 0.5 - 0.015, teeth, -0.025, w * 0.4, true)

		# Outer edge teeth — point outward
		_add_ring_teeth(ring_root, r + w * 0.5 + 0.015, teeth, 0.025, w * 0.4, false)

		# Degree markings — small notches every 15°
		for d in range(24):
			var angle: float = TAU_F * float(d) / 24.0
			var mark: MeshInstance3D = MeshInstance3D.new()
			var mark_mesh: BoxMesh = BoxMesh.new()
			var mark_len: float = 0.02 if d % 6 != 0 else 0.035
			mark_mesh.size = Vector3(mark_len, w * 0.15, 0.004)
			mark.mesh = mark_mesh
			mark.material_override = mat_polished if d % 6 == 0 else mat_dark_steel
			mark.position = Vector3(cos(angle) * (r + w * 0.5 + 0.04), 0, sin(angle) * (r + w * 0.5 + 0.04))
			mark.rotation.y = -angle
			ring_root.add_child(mark)

func _add_ring_teeth(parent: Node3D, radius: float, count: int, depth: float, height: float, inward: bool) -> void:
	for i in range(count):
		var angle: float = TAU_F * float(i) / float(count)
		var tooth: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(abs(depth), height, 0.015)
		tooth.mesh = box
		tooth.material_override = mat_brass_teeth
		var dir: float = -1.0 if inward else 1.0
		tooth.position = Vector3(cos(angle) * (radius + depth * 0.5 * dir), 0, sin(angle) * (radius + depth * 0.5 * dir))
		tooth.rotation.y = -angle
		parent.add_child(tooth)

# ═══════════════════ Bevel Gears ═══════════════════

func _build_bevel_gears() -> void:
	# Bevel gears at intersection points between adjacent rings
	# They transfer rotation from one ring plane to another
	for i in range(ring_count - 1):
		var r_inner: float = ring_radii[i]
		var r_outer: float = ring_radii[i + 1]
		var avg_r: float = (r_inner + r_outer) * 0.5

		# Place 2 bevels per ring pair, 180° apart
		for j in range(2):
			var phi: float = TAU_F * float(j) / 2.0 + float(i) * 0.4
			var bevel: Node3D = _create_bevel_gear(avg_r, phi, i)
			add_child(bevel)
			bevel_nodes.append(bevel)

func _create_bevel_gear(radius: float, phi: float, pair_idx: int) -> Node3D:
	var node: Node3D = Node3D.new()
	node.name = "bevel_%d_%.0f" % [pair_idx, rad_to_deg(phi)]

	# Position at the intersection of ring planes
	node.position = Vector3(cos(phi) * radius, 0, sin(phi) * radius)
	# Orient to face between the two ring planes
	var avg_tilt: float = (ring_tilts[pair_idx] + ring_tilts[pair_idx + 1]) * 0.5
	node.rotation.x = avg_tilt
	node.rotation.y = phi

	# Bevel gear body — cone-ish cylinder
	var body: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.10
	cyl.bottom_radius = 0.14
	cyl.height = 0.08
	cyl.radial_segments = 16
	body.mesh = cyl
	body.material_override = mat_brass
	body.rotation.z = PI * 0.5  # lay on side
	node.add_child(body)

	# Bevel teeth — angled pegs
	var bevel_teeth: int = 12
	for i in range(bevel_teeth):
		var angle: float = TAU_F * float(i) / float(bevel_teeth)
		var tooth: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.03, 0.025, 0.012)
		tooth.mesh = box
		tooth.material_override = mat_brass_teeth
		var tr: float = 0.13
		tooth.position = Vector3(0, cos(angle) * tr, sin(angle) * tr)
		tooth.rotation.x = angle
		node.add_child(tooth)

	# Axle through bevel
	var axle: MeshInstance3D = MeshInstance3D.new()
	var axle_cyl: CylinderMesh = CylinderMesh.new()
	axle_cyl.top_radius = 0.012
	axle_cyl.bottom_radius = 0.012
	axle_cyl.height = 0.25
	axle.mesh = axle_cyl
	axle.material_override = mat_shaft
	axle.rotation.z = PI * 0.5
	node.add_child(axle)

	return node

# ═══════════════════ Lantern Pinions ═══════════════════

func _build_lantern_pinions() -> void:
	# Lantern pinion on the equatorial ring meshing with the crown gear
	# A lantern pinion = two discs connected by cylindrical bars (trundles)
	for phi_offset in [0.0, PI]:
		var lantern: Node3D = _create_lantern_pinion(8, 0.15, 0.12)
		# Position at crown gear radius, on the equatorial ring
		var mount_r: float = ring_radii[0] - ring_widths[0] * 0.5
		lantern.position = Vector3(cos(phi_offset) * 0.42, -1.45, sin(phi_offset) * 0.42)
		# Orient so the pinion axis is horizontal, meshing with crown teeth
		lantern.rotation.z = PI * 0.5
		lantern.rotation.y = phi_offset
		lantern.name = "lantern_%d" % lantern_nodes.size()
		add_child(lantern)
		lantern_nodes.append(lantern)

func _create_lantern_pinion(bars: int, radius: float, height: float) -> Node3D:
	var node: Node3D = Node3D.new()

	# Top and bottom discs
	for y_sign in [-1.0, 1.0]:
		var disc: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.height = 0.012
		cyl.radial_segments = bars * 2
		disc.mesh = cyl
		disc.material_override = mat_dark_steel
		disc.position.y = y_sign * height * 0.5
		node.add_child(disc)

	# Trundles — the cylindrical bars that act as teeth
	for i in range(bars):
		var angle: float = TAU_F * float(i) / float(bars)
		var bar: MeshInstance3D = MeshInstance3D.new()
		var bar_cyl: CylinderMesh = CylinderMesh.new()
		bar_cyl.top_radius = 0.012
		bar_cyl.bottom_radius = 0.012
		bar_cyl.height = height
		bar.mesh = bar_cyl
		bar.material_override = mat_lantern_bar
		bar.position = Vector3(cos(angle) * radius * 0.8, 0, sin(angle) * radius * 0.8)
		node.add_child(bar)

	# Central axle
	var axle: MeshInstance3D = MeshInstance3D.new()
	var axle_cyl: CylinderMesh = CylinderMesh.new()
	axle_cyl.top_radius = 0.018
	axle_cyl.bottom_radius = 0.018
	axle_cyl.height = height * 1.8
	axle.mesh = axle_cyl
	axle.material_override = mat_shaft
	node.add_child(axle)

	return node

# ═══════════════════ Epicyclic Differential ═══════════════════

func _build_differential() -> void:
	# The differential sits at the top of the drive shaft
	# It splits the input into multiple output rates for the rings
	differential_cage = Node3D.new()
	differential_cage.name = "differential"
	differential_cage.position.y = 0.8
	drive_shaft_node.add_child(differential_cage)

	# Carrier cage — the rotating frame
	var cage_mat: StandardMaterial3D = mat_dark_steel.duplicate()
	cage_mat.albedo_color = Color(0.20, 0.22, 0.28)

	# Cage arms
	for i in range(3):
		var angle: float = TAU_F * float(i) / 3.0
		var arm: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.35, 0.015, 0.03)
		arm.mesh = box
		arm.material_override = cage_mat
		arm.rotation.y = angle
		differential_cage.add_child(arm)

	# Sun gear at center
	var sun: MeshInstance3D = MeshInstance3D.new()
	var sun_cyl: CylinderMesh = CylinderMesh.new()
	sun_cyl.top_radius = 0.08
	sun_cyl.bottom_radius = 0.08
	sun_cyl.height = 0.04
	sun.mesh = sun_cyl
	sun.material_override = mat_brass
	sun.name = "diff_sun"
	differential_cage.add_child(sun)

	# Planet gears on the carrier arms
	for i in range(3):
		var angle: float = TAU_F * float(i) / 3.0
		var planet: MeshInstance3D = MeshInstance3D.new()
		var p_cyl: CylinderMesh = CylinderMesh.new()
		p_cyl.top_radius = 0.05
		p_cyl.bottom_radius = 0.05
		p_cyl.height = 0.035
		planet.mesh = p_cyl
		planet.material_override = mat_steel
		planet.position = Vector3(cos(angle) * 0.15, 0, sin(angle) * 0.15)
		planet.name = "diff_planet_%d" % i
		differential_cage.add_child(planet)

		# Planet teeth
		for t in range(8):
			var t_angle: float = TAU_F * float(t) / 8.0
			var tooth: MeshInstance3D = MeshInstance3D.new()
			var t_box: BoxMesh = BoxMesh.new()
			t_box.size = Vector3(0.015, 0.03, 0.008)
			tooth.mesh = t_box
			tooth.material_override = mat_brass_teeth
			tooth.position = planet.position + Vector3(cos(t_angle) * 0.055, 0, sin(t_angle) * 0.055)
			tooth.rotation.y = -t_angle
			differential_cage.add_child(tooth)

	# Ring gear — outer ring of differential
	var ring_gear: MeshInstance3D = MeshInstance3D.new()
	var ring_torus: TorusMesh = TorusMesh.new()
	ring_torus.inner_radius = 0.22
	ring_torus.outer_radius = 0.26
	ring_torus.rings = 48
	ring_torus.ring_segments = 8
	ring_gear.mesh = ring_torus
	ring_gear.material_override = mat_bronze
	ring_gear.name = "diff_ring"
	differential_cage.add_child(ring_gear)

# ═══════════════════ Update ═══════════════════

func _update_mechanism(delta: float) -> void:
	var snap: Dictionary = mech.get_snapshot()
	var sun_theta: float = float(snap["sun"]["theta"])
	var sun_omega: float = float(snap["sun"]["omega"])
	var carrier_theta: float = float(snap["carrier"]["theta"])

	# Drive shaft rotates with sun
	drive_shaft_node.rotation.y = sun_theta

	# Lantern pinions spin driven by crown
	for lantern in lantern_nodes:
		lantern.rotation.x = sun_theta * 2.5

	# Differential cage follows carrier
	differential_cage.rotation.y = carrier_theta * 0.5

	# Rings driven by exact mechanism outputs
	if ring_nodes.size() >= 4:
		ring_nodes[0].rotation.y = float(snap["hour"]["theta"])
		ring_nodes[1].rotation.y = float(snap["day"]["theta"])
		ring_nodes[2].rotation.y = float(snap["month"]["theta"])
		ring_nodes[3].rotation.y = float(snap["year"]["theta"])

	# Bevel gears spin at the speed difference between adjacent rings
	var ring_thetas: Array[float] = [
		float(snap["hour"]["theta"]),
		float(snap["day"]["theta"]),
		float(snap["month"]["theta"]),
		float(snap["year"]["theta"]),
	]
	for i in range(bevel_nodes.size()):
		var pair_idx: int = i / 2
		if pair_idx + 1 < 4:
			var diff: float = ring_thetas[pair_idx] - ring_thetas[pair_idx + 1]
			bevel_nodes[i].rotation.x = diff * 2.0

	# Core glow responds to energy
	var core: OmniLight3D = get_node_or_null("core_glow")
	if core != null:
		var energy_frac: float = clampf(abs(sun_omega) / 5.0, 0.2, 1.0)
		core.light_energy = 0.6 + energy_frac * 0.8 + sin(time_acc * 0.15) * 0.1

# ═══════════════════ Camera ═══════════════════

func _create_camera() -> void:
	var cam: Camera3D = Camera3D.new()
	cam.name = "Camera"
	cam.current = true
	cam.fov = 38.0
	add_child(cam)

func _update_camera() -> void:
	var cam: Camera3D = get_node_or_null("Camera")
	if cam == null:
		return
	var dist: float = ring_radii[3] * 2.8
	var elev: float = sin(orbit_angle * 0.2) * 0.15 + 0.22
	cam.position = Vector3(
		cos(orbit_angle) * dist * cos(elev),
		sin(elev) * dist * 0.35 + 0.5,
		sin(orbit_angle) * dist * cos(elev)
	)
	cam.look_at(Vector3(0, -0.2, 0), Vector3.UP)
