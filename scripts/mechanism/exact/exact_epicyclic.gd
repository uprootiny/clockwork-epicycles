class_name ExactEpicyclic
extends RefCounted
## Complete epicyclic mechanism derived from tooth counts.
##
## Power flow:
##   drive torque → sun
##   sun meshes with planets (external, 3×)
##   planets mesh with ring (internal, 3×)
##   carrier output (slow, high torque)
##   ring output (medium)
##
## Outputs feed downstream:
##   carrier → hour hand (direct)
##   ring → minute reduction via output gear pair
##   sun → escapement regulation
##
## All geometry from: module=0.04, teeth=(24, 12, 48)
## Willis: (ω_s - ω_c)/(ω_r - ω_c) = -48/24 = -2
## Tooth constraint: 48 = 24 + 2×12 ✓

const GearGeometryClass = preload("res://scripts/mechanism/exact/gear_geometry.gd")
const ContactSolverClass = preload("res://scripts/mechanism/exact/contact_solver.gd")

# ═══ Specification ═══

# Epicyclic core
var teeth_sun: int = 24
var teeth_planet: int = 12
var teeth_ring: int = 48
var num_planets: int = 3
var module: float = 0.04

# Output reduction pair (ring → dial)
var teeth_output_a: int = 40  # on ring shaft
var teeth_output_b: int = 10  # dial pinion

# Escapement wheel (on sun shaft)
var teeth_escape: int = 30

# Masses
var mass_sun: float = 0.5
var mass_planet: float = 0.2
var mass_carrier: float = 1.5
var mass_ring: float = 2.5
var mass_output_a: float = 0.3
var mass_output_b: float = 0.1
var mass_escape: float = 0.15
var mass_balance: float = 0.4

# Contact
var contact_stiffness: float = 0.92  # compliance (0-1)
var contact_damping: float = 0.08
var solver_iterations: int = 20

# Friction
var friction_sun: float = 0.008
var friction_carrier: float = 0.012
var friction_ring: float = 0.010
var friction_output: float = 0.006
var friction_escape: float = 0.005
var friction_balance: float = 0.003

# Escapement
var balance_stiffness: float = 6.0  # hairspring (N·m/rad)
var balance_damping: float = 0.3
var escape_engage_angle: float = 0.3  # radians

# ═══ Compiled geometry ═══

var geo_sun: GearGeometry
var geo_planet: GearGeometry
var geo_ring: GearGeometry
var geo_out_a: GearGeometry
var geo_out_b: GearGeometry
var geo_escape: GearGeometry

var I_sun: float
var I_planet: float
var I_carrier: float
var I_ring: float
var I_out_a: float
var I_out_b: float
var I_escape: float
var I_balance: float
var carrier_radius: float

# ═══ State ═══

var theta: PackedFloat64Array  # [sun, carrier, ring, planet0..2, out_a, out_b, escape, balance]
var omega: PackedFloat64Array
# Indices
const SUN: int = 0
const CARRIER: int = 1
const RING: int = 2
const PLANET0: int = 3
# PLANET1 = 4, PLANET2 = 5
const OUT_A: int = 6
const OUT_B: int = 7
const ESCAPE: int = 8
const BALANCE: int = 9
const STATE_SIZE: int = 10

var inertias: PackedFloat64Array
var frictions: PackedFloat64Array

var drive_torque: float = 1.5
var brake_ring: float = 0.0
var sim_time: float = 0.0
var paused: bool = false

var contact: ContactSolver

# ═══ Diagnostics ═══

var willis_error: float = 0.0
var total_energy: float = 0.0
var power_in: float = 0.0
var carrier_to_sun_ratio: float = 0.0
var output_ratio: float = 0.0
var escape_impulse: float = 0.0

func _init() -> void:
	_compile()
	reset()

func _compile() -> void:
	# Geometry from tooth counts
	geo_sun = GearGeometryClass.new(teeth_sun, module)
	geo_planet = GearGeometryClass.new(teeth_planet, module)
	geo_ring = GearGeometryClass.new(teeth_ring, module, true)
	geo_out_a = GearGeometryClass.new(teeth_output_a, module)
	geo_out_b = GearGeometryClass.new(teeth_output_b, module)
	geo_escape = GearGeometryClass.new(teeth_escape, module)

	carrier_radius = geo_sun.pitch_radius + geo_planet.pitch_radius

	# Inertias from mass + geometry
	I_sun = geo_sun.disc_inertia(mass_sun)
	I_planet = geo_planet.disc_inertia(mass_planet)
	I_carrier = mass_carrier * carrier_radius * carrier_radius
	I_ring = geo_ring.ring_inertia(mass_ring)
	I_out_a = geo_out_a.disc_inertia(mass_output_a)
	I_out_b = geo_out_b.disc_inertia(mass_output_b)
	I_escape = geo_escape.disc_inertia(mass_escape)
	I_balance = 0.5 * mass_balance * 0.05 * 0.05  # small balance wheel

	# Pack into arrays
	inertias = PackedFloat64Array()
	inertias.resize(STATE_SIZE)
	inertias[SUN] = I_sun
	inertias[CARRIER] = I_carrier
	inertias[RING] = I_ring
	for p in range(num_planets):
		inertias[PLANET0 + p] = I_planet
	inertias[OUT_A] = I_out_a
	inertias[OUT_B] = I_out_b
	inertias[ESCAPE] = I_escape
	inertias[BALANCE] = I_balance

	frictions = PackedFloat64Array()
	frictions.resize(STATE_SIZE)
	frictions[SUN] = friction_sun
	frictions[CARRIER] = friction_carrier
	frictions[RING] = friction_ring
	for p in range(num_planets):
		frictions[PLANET0 + p] = 0.004
	frictions[OUT_A] = friction_output
	frictions[OUT_B] = friction_output
	frictions[ESCAPE] = friction_escape
	frictions[BALANCE] = friction_balance

	contact = ContactSolverClass.new()

func reset() -> void:
	theta = PackedFloat64Array()
	theta.resize(STATE_SIZE)
	omega = PackedFloat64Array()
	omega.resize(STATE_SIZE)
	for i in range(STATE_SIZE):
		theta[i] = 0.0
		omega[i] = 0.0
	sim_time = 0.0

func step(delta: float) -> void:
	if paused:
		return
	var h: float = min(delta, 0.05) / 8.0
	for _s in range(8):
		_substep(h)

func _substep(dt: float) -> void:
	sim_time += dt

	# ── External torques ──
	var torques: PackedFloat64Array = PackedFloat64Array()
	torques.resize(STATE_SIZE)
	for i in range(STATE_SIZE):
		torques[i] = 0.0

	# Drive on sun
	torques[SUN] += drive_torque

	# Ring brake
	if abs(omega[RING]) > 1e-8:
		torques[RING] -= brake_ring * sign(omega[RING])

	# Balance hairspring: τ = -k·θ - c·ω
	torques[BALANCE] += -balance_stiffness * theta[BALANCE] - balance_damping * omega[BALANCE]

	# Escapement impulse: gate energy from escape wheel to balance
	var gate: float = clampf(1.0 - abs(theta[BALANCE]) / escape_engage_angle, 0.0, 1.0)
	gate = gate * gate
	if gate > 0.01:
		var tick_dir: float = -sign(theta[BALANCE]) if abs(theta[BALANCE]) > 1e-6 else -sign(omega[ESCAPE])
		var tick: float = 0.3 * gate * tick_dir
		torques[BALANCE] += tick / I_balance * I_escape
		torques[ESCAPE] -= tick * 0.5
		escape_impulse = tick
	else:
		escape_impulse = 0.0

	# ── Bearing friction ──
	for i in range(STATE_SIZE):
		torques[i] -= frictions[i] * omega[i]

	# ── Apply torques (half-step, symplectic) ──
	for i in range(STATE_SIZE):
		omega[i] += torques[i] * dt / inertias[i]

	# ── Contact constraints (iterated) ──
	for _iter in range(solver_iterations):
		# Sun-planet meshes (external) — in carrier frame
		for p in range(num_planets):
			var pi: int = PLANET0 + p
			var omega_sun_rel: float = omega[SUN] - omega[CARRIER]
			var omega_planet_rel: float = omega[pi]
			var result: PackedFloat64Array = contact.solve_external(
				geo_sun.pitch_radius, omega_sun_rel, I_sun,
				geo_planet.pitch_radius, omega_planet_rel, I_planet,
				contact_stiffness, contact_damping, dt)
			omega[SUN] += result[0]
			omega[pi] += result[1]

		# Planet-ring meshes (internal) — in carrier frame
		for p in range(num_planets):
			var pi: int = PLANET0 + p
			var omega_planet_rel: float = omega[pi]
			var omega_ring_rel: float = omega[RING] - omega[CARRIER]
			var result: PackedFloat64Array = contact.solve_internal(
				geo_planet.pitch_radius, omega_planet_rel, I_planet,
				geo_ring.pitch_radius, omega_ring_rel, I_ring,
				contact_stiffness, contact_damping, dt)
			omega[pi] += result[0]
			omega[RING] += result[1]

		# Carrier reacts to planet forces (Newton's third law)
		var carrier_torque_sum: float = 0.0
		for p in range(num_planets):
			carrier_torque_sum += omega[PLANET0 + p] * I_planet
		omega[CARRIER] += carrier_torque_sum * 0.01 / I_carrier

		# Output gear pair: ring shaft → dial (external mesh)
		var result_out: PackedFloat64Array = contact.solve_external(
			geo_out_a.pitch_radius, omega[OUT_A] - omega[RING], I_out_a,
			geo_out_b.pitch_radius, omega[OUT_B], I_out_b,
			contact_stiffness, contact_damping, dt)
		omega[OUT_A] += result_out[0]
		omega[OUT_B] += result_out[1]
		# Output A is fixed to ring shaft
		omega[OUT_A] = lerpf(omega[OUT_A], omega[RING], 0.5)

		# Escapement wheel coupled to sun shaft
		omega[ESCAPE] = lerpf(omega[ESCAPE], omega[SUN] * float(teeth_sun) / float(teeth_escape), 0.3)

	# ── Integrate positions ──
	for i in range(STATE_SIZE):
		theta[i] += omega[i] * dt

	# ── Clamp ──
	var max_omega: float = 80.0
	for i in range(STATE_SIZE):
		omega[i] = clampf(omega[i], -max_omega, max_omega)
		if is_nan(omega[i]) or is_inf(omega[i]):
			omega[i] = 0.0
		if is_nan(theta[i]) or is_inf(theta[i]):
			theta[i] = 0.0

	# ── Diagnostics ──
	willis_error = ContactSolverClass.willis_error(
		omega[SUN], omega[RING], omega[CARRIER], teeth_sun, teeth_ring)
	total_energy = 0.0
	for i in range(STATE_SIZE):
		total_energy += 0.5 * inertias[i] * omega[i] * omega[i]
	power_in = drive_torque * omega[SUN]
	if abs(omega[SUN]) > 1e-6:
		carrier_to_sun_ratio = omega[CARRIER] / omega[SUN]
	output_ratio = GearGeometryClass.ratio(teeth_output_a, teeth_output_b)

func get_snapshot() -> Dictionary:
	var planet_thetas: Array = []
	var planet_omegas: Array = []
	for p in range(num_planets):
		planet_thetas.append(theta[PLANET0 + p])
		planet_omegas.append(omega[PLANET0 + p])
	return {
		"sun": {"theta": theta[SUN], "omega": omega[SUN]},
		"carrier": {"theta": theta[CARRIER], "omega": omega[CARRIER]},
		"ring": {"theta": theta[RING], "omega": omega[RING]},
		"planets": {"theta": planet_thetas, "omega": planet_omegas},
		"output_a": {"theta": theta[OUT_A], "omega": omega[OUT_A]},
		"output_b": {"theta": theta[OUT_B], "omega": omega[OUT_B]},
		"escapement": {"theta": theta[ESCAPE], "omega": omega[ESCAPE]},
		"balance": {"theta": theta[BALANCE], "omega": omega[BALANCE]},
		"willis_error": willis_error,
		"total_energy": total_energy,
		"power_in": power_in,
		"carrier_sun_ratio": carrier_to_sun_ratio,
		"output_ratio": output_ratio,
		"escape_impulse": escape_impulse,
		"sim_time": sim_time,
		"carrier_radius": carrier_radius,
	}

func get_report() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Exact Epicyclic Mechanism")
	lines.append("  Sun     %2dT  r=%.3f  I=%.5f" % [teeth_sun, geo_sun.pitch_radius, I_sun])
	lines.append("  Planet  %2dT  r=%.3f  I=%.5f  x%d" % [teeth_planet, geo_planet.pitch_radius, I_planet, num_planets])
	lines.append("  Ring    %2dT  r=%.3f  I=%.5f" % [teeth_ring, geo_ring.pitch_radius, I_ring])
	lines.append("  Carrier      r=%.3f  I=%.5f" % [carrier_radius, I_carrier])
	lines.append("  Output  %dT:%dT ratio=%.1f:1" % [teeth_output_a, teeth_output_b, output_ratio])
	lines.append("  Escape  %2dT  Balance I=%.5f" % [teeth_escape, I_balance])
	lines.append("  Willis: (ws-wc)/(wr-wc) = -%.1f" % abs(ContactSolverClass.willis_ratio(teeth_sun, teeth_ring)))
	lines.append("  Contact CR s-p=%.2f  p-r=%.2f" % [
		geo_sun.contact_ratio_with(geo_planet),
		geo_planet.contact_ratio_with(geo_ring)])
	lines.append("  %dT = %dT + 2x%dT  %s" % [
		teeth_ring, teeth_sun, teeth_planet,
		"OK" if teeth_ring == teeth_sun + 2 * teeth_planet else "FAIL"])
	return "\n".join(lines)
