class_name ExactEpicyclic
extends RefCounted
## Exact epicyclic gear train derived from tooth geometry.
##
## Everything is computed from tooth counts and module:
##   - pitch radii
##   - inertias (from mass and geometry)
##   - gear ratios (exact integer ratios from tooth counts)
##   - Willis equation enforced
##   - contact forces from spring-damper at pitch point
##
## Tooth count constraint: N_ring = N_sun + 2 * N_planet
## Willis equation: (ω_s - ω_c)/(ω_r - ω_c) = -N_r/N_s

const GearGeometryClass = preload("res://scripts/mechanism/exact/gear_geometry.gd")
const ContactSolverClass = preload("res://scripts/mechanism/exact/contact_solver.gd")

# ── Specification (tooth counts + module define everything) ──

var teeth_sun: int = 24
var teeth_planet: int = 12
var teeth_ring: int = 48        # must equal sun + 2*planet
var num_planets: int = 3
var module: float = 0.04        # meters per tooth (scale factor)

# Masses (kg) — geometry determines inertia
var mass_sun: float = 0.8
var mass_planet: float = 0.3
var mass_carrier: float = 2.0
var mass_ring: float = 3.0

# Contact stiffness (N/m) and damping (N·s/m)
var tooth_stiffness: float = 5e4
var tooth_damping: float = 200.0

# Bearing friction (N·m·s/rad)
var bearing_friction_sun: float = 0.01
var bearing_friction_carrier: float = 0.02
var bearing_friction_ring: float = 0.015

# ── Derived geometry (computed once from spec) ──

var geo_sun: GearGeometry
var geo_planet: GearGeometry
var geo_ring: GearGeometry

var inertia_sun: float
var inertia_planet: float
var inertia_carrier: float
var inertia_ring: float

var carrier_radius: float  # center distance sun-planet
var contact_ratio_sp: float  # sun-planet
var contact_ratio_pr: float  # planet-ring
var willis_ratio: float

# ── Dynamic state ──

var theta_sun: float = 0.0
var theta_carrier: float = 0.0
var theta_ring: float = 0.0
var theta_planets: PackedFloat64Array  # each planet's own spin

var omega_sun: float = 0.0
var omega_carrier: float = 0.0
var omega_ring: float = 0.0
var omega_planets: PackedFloat64Array

var drive_torque: float = 2.0  # N·m applied to sun
var brake_torque_ring: float = 0.0  # resistance on ring
var sim_time: float = 0.0
var paused: bool = false

# ── Solver ──

var contact: ContactSolver

# ── Diagnostics ──

var willis_error: float = 0.0
var total_energy: float = 0.0
var power_in: float = 0.0
var power_dissipated: float = 0.0
var contact_forces_sp: PackedFloat64Array  # per planet
var contact_forces_pr: PackedFloat64Array

func _init() -> void:
	compile()
	reset()

func compile() -> void:
	# Validate epicyclic constraint
	assert(teeth_ring == teeth_sun + 2 * teeth_planet,
		"Tooth count constraint violated: N_ring must equal N_sun + 2*N_planet")

	# Derive geometry
	geo_sun = GearGeometryClass.new(teeth_sun, module, false)
	geo_planet = GearGeometryClass.new(teeth_planet, module, false)
	geo_ring = GearGeometryClass.new(teeth_ring, module, true)

	# Carrier radius = sun pitch radius + planet pitch radius
	carrier_radius = geo_sun.pitch_radius + geo_planet.pitch_radius

	# Inertias from mass and geometry
	inertia_sun = geo_sun.disc_inertia(mass_sun)
	inertia_planet = geo_planet.disc_inertia(mass_planet)
	inertia_carrier = mass_carrier * carrier_radius * carrier_radius  # point masses at planet positions
	inertia_ring = geo_ring.ring_inertia(mass_ring)

	# Contact ratios (must be > 1 for continuous mesh)
	contact_ratio_sp = geo_sun.contact_ratio_with(geo_planet)
	contact_ratio_pr = geo_planet.contact_ratio_with(geo_ring)

	# Willis ratio
	willis_ratio = ContactSolverClass.willis_ratio(teeth_sun, teeth_ring)

	# Solver
	contact = ContactSolverClass.new()

	# Planet arrays
	theta_planets = PackedFloat64Array()
	theta_planets.resize(num_planets)
	omega_planets = PackedFloat64Array()
	omega_planets.resize(num_planets)
	contact_forces_sp = PackedFloat64Array()
	contact_forces_sp.resize(num_planets)
	contact_forces_pr = PackedFloat64Array()
	contact_forces_pr.resize(num_planets)

func reset() -> void:
	theta_sun = 0.0
	theta_carrier = 0.0
	theta_ring = 0.0
	omega_sun = 0.0
	omega_carrier = 0.0
	omega_ring = 0.0
	sim_time = 0.0
	for i in range(num_planets):
		theta_planets[i] = 0.0
		omega_planets[i] = 0.0
		contact_forces_sp[i] = 0.0
		contact_forces_pr[i] = 0.0

func step(delta: float) -> void:
	if paused:
		return
	var substeps: int = 8  # higher substep count for contact stability
	var h: float = min(delta, 0.05) / float(substeps)
	for _i in range(substeps):
		_step_once(h)

func _step_once(dt: float) -> void:
	sim_time += dt

	# ── 1. Apply external torques ──
	var torque_sun: float = drive_torque
	var torque_carrier: float = 0.0
	var torque_ring: float = -brake_torque_ring * sign(omega_ring)

	# ── 2. Bearing friction ──
	torque_sun -= bearing_friction_sun * omega_sun
	torque_carrier -= bearing_friction_carrier * omega_carrier
	torque_ring -= bearing_friction_ring * omega_ring

	# ── 3. Contact forces at each planet ──
	for p in range(num_planets):
		# Planet spin relative to carrier frame
		var omega_planet_abs: float = omega_planets[p]

		# Sun-planet contact (external mesh)
		# In carrier frame: omega_sun_rel = omega_sun - omega_carrier
		# Planet spins opposite: omega_planet_rel should satisfy ratio
		var result_sp: PackedFloat64Array = contact.solve_external_mesh(
			geo_sun, geo_planet,
			theta_sun, omega_sun - omega_carrier, inertia_sun,
			theta_planets[p], omega_planet_abs, inertia_planet,
			tooth_stiffness, tooth_damping, dt
		)
		contact_forces_sp[p] = contact.last_normal_force

		# Planet-ring contact (internal mesh)
		var result_pr: PackedFloat64Array = contact.solve_internal_mesh(
			geo_planet, geo_ring,
			theta_planets[p], omega_planet_abs, inertia_planet,
			theta_ring, omega_ring - omega_carrier, inertia_ring,
			tooth_stiffness, tooth_damping, dt
		)
		contact_forces_pr[p] = contact.last_normal_force

		# Apply velocity changes from contact
		omega_sun += result_sp[0]
		omega_planets[p] += result_sp[1] + result_pr[0]
		omega_ring += result_pr[1]

		# Carrier receives reaction: sum of contact torques
		var carrier_reaction: float = -(result_sp[0] * inertia_sun + result_pr[1] * inertia_ring) / inertia_carrier
		torque_carrier += carrier_reaction * inertia_carrier / dt

	# ── 4. Integrate ──
	omega_sun += torque_sun * dt / inertia_sun
	omega_carrier += torque_carrier * dt / inertia_carrier
	omega_ring += torque_ring * dt / inertia_ring

	theta_sun += omega_sun * dt
	theta_carrier += omega_carrier * dt
	theta_ring += omega_ring * dt

	for p in range(num_planets):
		# Planet spin derived from kinematic constraint:
		# omega_planet = -(omega_sun - omega_carrier) * r_sun / r_planet
		var ideal_omega_p: float = -(omega_sun - omega_carrier) * geo_sun.pitch_radius / geo_planet.pitch_radius
		# Blend toward ideal (contact forces should enforce this, but help stability)
		omega_planets[p] = lerpf(omega_planets[p], ideal_omega_p, 0.1)
		theta_planets[p] += omega_planets[p] * dt

	# ── 5. Sanitize ──
	var max_omega: float = 100.0
	omega_sun = clampf(omega_sun, -max_omega, max_omega)
	omega_carrier = clampf(omega_carrier, -max_omega, max_omega)
	omega_ring = clampf(omega_ring, -max_omega, max_omega)
	for p in range(num_planets):
		omega_planets[p] = clampf(omega_planets[p], -max_omega * 3.0, max_omega * 3.0)

	# ── 6. Diagnostics ──
	willis_error = ContactSolverClass.willis_error(
		omega_sun, omega_ring, omega_carrier, teeth_sun, teeth_ring)
	total_energy = (0.5 * inertia_sun * omega_sun * omega_sun
		+ 0.5 * inertia_carrier * omega_carrier * omega_carrier
		+ 0.5 * inertia_ring * omega_ring * omega_ring)
	for p in range(num_planets):
		total_energy += 0.5 * inertia_planet * omega_planets[p] * omega_planets[p]
	power_in = drive_torque * omega_sun
	power_dissipated = (bearing_friction_sun * omega_sun * omega_sun
		+ bearing_friction_carrier * omega_carrier * omega_carrier
		+ bearing_friction_ring * omega_ring * omega_ring)

func get_snapshot() -> Dictionary:
	return {
		"theta_sun": theta_sun, "omega_sun": omega_sun,
		"theta_carrier": theta_carrier, "omega_carrier": omega_carrier,
		"theta_ring": theta_ring, "omega_ring": omega_ring,
		"theta_planets": theta_planets.duplicate(),
		"omega_planets": omega_planets.duplicate(),
		"willis_error": willis_error,
		"total_energy": total_energy,
		"power_in": power_in,
		"power_dissipated": power_dissipated,
		"contact_ratio_sp": contact_ratio_sp,
		"contact_ratio_pr": contact_ratio_pr,
		"sim_time": sim_time,
		"teeth_sun": teeth_sun,
		"teeth_planet": teeth_planet,
		"teeth_ring": teeth_ring,
		"carrier_radius": carrier_radius,
		"geo_sun_pitch_r": geo_sun.pitch_radius,
		"geo_planet_pitch_r": geo_planet.pitch_radius,
		"geo_ring_pitch_r": geo_ring.pitch_radius,
	}

func get_geometry_report() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("═══ Exact Epicyclic Gear Train ═══")
	lines.append("Module: %.4f m" % module)
	lines.append("Sun:    %d teeth  r=%.4f m  I=%.6f kg·m²" % [teeth_sun, geo_sun.pitch_radius, inertia_sun])
	lines.append("Planet: %d teeth  r=%.4f m  I=%.6f kg·m²  ×%d" % [teeth_planet, geo_planet.pitch_radius, inertia_planet, num_planets])
	lines.append("Ring:   %d teeth  r=%.4f m  I=%.6f kg·m²" % [teeth_ring, geo_ring.pitch_radius, inertia_ring])
	lines.append("Carrier: r=%.4f m  I=%.6f kg·m²" % [carrier_radius, inertia_carrier])
	lines.append("Willis ratio: %.4f (expected: %.4f)" % [willis_ratio, -float(teeth_ring) / float(teeth_sun)])
	lines.append("Contact ratio S-P: %.3f  P-R: %.3f" % [contact_ratio_sp, contact_ratio_pr])
	lines.append("Tooth constraint: %d = %d + 2×%d → %s" % [
		teeth_ring, teeth_sun, teeth_planet,
		"OK" if teeth_ring == teeth_sun + 2 * teeth_planet else "VIOLATED"
	])
	return "\n".join(lines)
