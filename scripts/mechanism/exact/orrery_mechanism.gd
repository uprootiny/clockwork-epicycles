class_name OrreryMechanism
extends RefCounted
## Complete orrery mechanism — single source of truth.
## Epicyclic core → bevel transfers → armillary ring outputs.
##
## Power chain (all ratios from tooth counts):
##
##   Drive → Sun(24T)
##           ↕ external mesh
##         3×Planet(12T) on Carrier
##           ↕ internal mesh
##         Ring(48T)
##           │
##   ┌───────┴────────┐
##   │                │
##   Carrier output   Ring output
##   (hour ring)      ↕ bevel 16T:32T (2:1 reduction)
##                    Day ring
##                    ↕ bevel 12T:36T (3:1 reduction)
##                    Month ring
##                    ↕ bevel 10T:40T (4:1 reduction)
##                    Year ring
##
##   Sun → Escapement(30T) → Balance (hairspring)
##
## Bevel pairs transfer between ring planes.
## Each bevel ratio is exact from tooth counts.
## Willis equation enforced by contact dynamics.

const GearGeometryClass = preload("res://scripts/mechanism/exact/gear_geometry.gd")
const ContactSolverClass = preload("res://scripts/mechanism/exact/contact_solver.gd")
const BevelGeometryClass = preload("res://scripts/mechanism/exact/bevel_geometry.gd")

# ═══ Bodies ═══
# [sun, carrier, ring, p0, p1, p2, hour_ring, day_ring, month_ring, year_ring, escape, balance]
const SUN: int = 0
const CARRIER: int = 1
const RING: int = 2
const P0: int = 3
const P1: int = 4
const P2: int = 5
const HOUR: int = 6    # driven by carrier
const DAY: int = 7     # via bevel from hour
const MONTH: int = 8   # via bevel from day
const YEAR: int = 9    # via bevel from month
const ESC: int = 10    # escapement wheel
const BAL: int = 11    # balance wheel
const N: int = 12

# ═══ Tooth counts (everything follows from these) ═══
var T_sun: int = 24
var T_planet: int = 12
var T_ring: int = 48   # = 24 + 2×12

# Bevel pairs: [driver_teeth, driven_teeth] for each ring-to-ring transfer
var T_bevel: Array = [
	[16, 32],   # hour→day: 2:1 slowdown
	[12, 36],   # day→month: 3:1 slowdown
	[10, 40],   # month→year: 4:1 slowdown
]

var T_escape: int = 30
var module: float = 0.04

# ═══ Masses ═══
var masses: PackedFloat64Array

# ═══ Compiled ═══
var geo_sun: GearGeometry
var geo_planet: GearGeometry
var geo_ring: GearGeometry
var geo_escape: GearGeometry
var bevel_angles: Array  # [[δ_a, δ_b], ...] for each bevel pair

var inertias: PackedFloat64Array
var frictions: PackedFloat64Array
var carrier_radius: float

# ═══ State ═══
var theta: PackedFloat64Array
var omega: PackedFloat64Array

var drive_torque: float = 1.5
var sim_time: float = 0.0
var paused: bool = false

# Escapement
var balance_k: float = 5.0     # hairspring stiffness
var balance_c: float = 0.2     # hairspring damping
var escape_gate_angle: float = 0.28

# Solver
var contact: ContactSolver
var stiffness: float = 0.90
var damping: float = 0.10
var iterations: int = 15

# ═══ Diagnostics ═══
var willis_error: float = 0.0
var total_energy: float = 0.0
var ring_speeds: PackedFloat64Array  # [hour, day, month, year] in rad/s

func _init() -> void:
	_compile()
	reset()

func _compile() -> void:
	# Epicyclic geometry
	geo_sun = GearGeometryClass.new(T_sun, module)
	geo_planet = GearGeometryClass.new(T_planet, module)
	geo_ring = GearGeometryClass.new(T_ring, module, true)
	geo_escape = GearGeometryClass.new(T_escape, module)
	carrier_radius = geo_sun.pitch_radius + geo_planet.pitch_radius

	# Bevel cone angles (all 90° shaft angles)
	bevel_angles = []
	for pair in T_bevel:
		var ta: int = int(pair[0])
		var tb: int = int(pair[1])
		var da: float = BevelGeometryClass.cone_angle_for_90deg(ta, tb)
		var db: float = PI / 2.0 - da
		bevel_angles.append([da, db])

	# Masses
	masses = PackedFloat64Array()
	masses.resize(N)
	masses[SUN] = 0.5
	masses[CARRIER] = 1.5
	masses[RING] = 2.5
	masses[P0] = 0.2; masses[P1] = 0.2; masses[P2] = 0.2
	masses[HOUR] = 0.8
	masses[DAY] = 0.6
	masses[MONTH] = 0.5
	masses[YEAR] = 0.4
	masses[ESC] = 0.15
	masses[BAL] = 0.3

	# Inertias from geometry
	inertias = PackedFloat64Array()
	inertias.resize(N)
	inertias[SUN] = geo_sun.disc_inertia(masses[SUN])
	inertias[CARRIER] = masses[CARRIER] * carrier_radius * carrier_radius
	inertias[RING] = geo_ring.ring_inertia(masses[RING])
	for p in range(3):
		inertias[P0 + p] = geo_planet.disc_inertia(masses[P0 + p])
	# Armillary rings — approximate as thin rings
	for r_idx in range(4):
		var r: float = 0.3 + float(r_idx) * 0.15
		inertias[HOUR + r_idx] = masses[HOUR + r_idx] * r * r
	inertias[ESC] = geo_escape.disc_inertia(masses[ESC])
	inertias[BAL] = 0.5 * masses[BAL] * 0.04 * 0.04

	# Friction
	frictions = PackedFloat64Array()
	frictions.resize(N)
	frictions[SUN] = 0.008
	frictions[CARRIER] = 0.012
	frictions[RING] = 0.010
	for p in range(3):
		frictions[P0 + p] = 0.004
	frictions[HOUR] = 0.005
	frictions[DAY] = 0.004
	frictions[MONTH] = 0.003
	frictions[YEAR] = 0.002
	frictions[ESC] = 0.005
	frictions[BAL] = 0.002

	contact = ContactSolverClass.new()
	ring_speeds = PackedFloat64Array()
	ring_speeds.resize(4)

func reset() -> void:
	theta = PackedFloat64Array()
	theta.resize(N)
	omega = PackedFloat64Array()
	omega.resize(N)
	for i in range(N):
		theta[i] = 0.0
		omega[i] = 0.0
	sim_time = 0.0
	for i in range(4):
		ring_speeds[i] = 0.0

func step(delta: float) -> void:
	if paused:
		return
	var h: float = min(delta, 0.05) / 8.0
	for _s in range(8):
		_substep(h)

func _substep(dt: float) -> void:
	sim_time += dt

	# ── 1. External torques ──
	var torques: PackedFloat64Array = PackedFloat64Array()
	torques.resize(N)
	for i in range(N):
		torques[i] = -frictions[i] * omega[i]  # bearing friction

	torques[SUN] += drive_torque
	torques[BAL] += -balance_k * theta[BAL] - balance_c * omega[BAL]

	# Escapement gate
	var gate: float = clampf(1.0 - abs(theta[BAL]) / escape_gate_angle, 0.0, 1.0)
	gate *= gate
	if gate > 0.01:
		var dir: float = -sign(theta[BAL]) if abs(theta[BAL]) > 1e-6 else -sign(omega[ESC])
		var tick: float = 0.25 * gate * dir
		torques[BAL] += tick / inertias[BAL] * inertias[ESC]
		torques[ESC] -= tick * 0.4

	# ── 2. Half-step velocity ──
	for i in range(N):
		omega[i] += torques[i] * dt / inertias[i]

	# ── 3. Contact constraints ──
	for _iter in range(iterations):
		# Sun-planet external meshes (carrier frame)
		for p in range(3):
			var pi: int = P0 + p
			var r: PackedFloat64Array = contact.solve_external(
				geo_sun.pitch_radius, omega[SUN] - omega[CARRIER], inertias[SUN],
				geo_planet.pitch_radius, omega[pi], inertias[pi],
				stiffness, damping, dt)
			omega[SUN] += r[0]
			omega[pi] += r[1]

		# Planet-ring internal meshes (carrier frame)
		for p in range(3):
			var pi: int = P0 + p
			var r: PackedFloat64Array = contact.solve_internal(
				geo_planet.pitch_radius, omega[pi], inertias[pi],
				geo_ring.pitch_radius, omega[RING] - omega[CARRIER], inertias[RING],
				stiffness, damping, dt)
			omega[pi] += r[0]
			omega[RING] += r[1]

		# Carrier reaction
		var c_react: float = 0.0
		for p in range(3):
			c_react += omega[P0 + p] * inertias[P0 + p]
		omega[CARRIER] += c_react * 0.008 / inertias[CARRIER]

		# Hour ring locked to carrier
		omega[HOUR] = lerpf(omega[HOUR], omega[CARRIER], 0.4)

		# Bevel pairs: hour→day, day→month, month→year
		for b in range(3):
			var from_idx: int = HOUR + b
			var to_idx: int = HOUR + b + 1
			var angles: Array = bevel_angles[b]
			var da: float = float(angles[0])
			var db: float = float(angles[1])
			var r: PackedFloat64Array = BevelGeometryClass.solve(
				omega[from_idx], da, inertias[from_idx],
				omega[to_idx], db, inertias[to_idx],
				stiffness, damping)
			omega[from_idx] += r[0]
			omega[to_idx] += r[1]

		# Escapement coupled to sun
		var esc_ratio: float = float(T_sun) / float(T_escape)
		omega[ESC] = lerpf(omega[ESC], omega[SUN] * esc_ratio, 0.25)

	# ── 4. Integrate ──
	for i in range(N):
		theta[i] += omega[i] * dt
		omega[i] = clampf(omega[i], -80.0, 80.0)
		if is_nan(omega[i]) or is_inf(omega[i]):
			omega[i] = 0.0
		if is_nan(theta[i]) or is_inf(theta[i]):
			theta[i] = 0.0

	# ── 5. Diagnostics ──
	willis_error = ContactSolverClass.willis_error(
		omega[SUN], omega[RING], omega[CARRIER], T_sun, T_ring)
	total_energy = 0.0
	for i in range(N):
		total_energy += 0.5 * inertias[i] * omega[i] * omega[i]
	for i in range(4):
		ring_speeds[i] = omega[HOUR + i]

func get_snapshot() -> Dictionary:
	var planet_theta: Array = []
	var planet_omega: Array = []
	for p in range(3):
		planet_theta.append(theta[P0 + p])
		planet_omega.append(omega[P0 + p])
	return {
		"sun": {"theta": theta[SUN], "omega": omega[SUN]},
		"carrier": {"theta": theta[CARRIER], "omega": omega[CARRIER]},
		"ring": {"theta": theta[RING], "omega": omega[RING]},
		"planets": {"theta": planet_theta, "omega": planet_omega},
		"hour": {"theta": theta[HOUR], "omega": omega[HOUR]},
		"day": {"theta": theta[DAY], "omega": omega[DAY]},
		"month": {"theta": theta[MONTH], "omega": omega[MONTH]},
		"year": {"theta": theta[YEAR], "omega": omega[YEAR]},
		"escapement": {"theta": theta[ESC], "omega": omega[ESC]},
		"balance": {"theta": theta[BAL], "omega": omega[BAL]},
		"willis_error": willis_error,
		"total_energy": total_energy,
		"ring_speeds": ring_speeds.duplicate(),
		"carrier_radius": carrier_radius,
		"sim_time": sim_time,
		"bevel_ratios": [
			float(T_bevel[0][1]) / float(T_bevel[0][0]),
			float(T_bevel[1][1]) / float(T_bevel[1][0]),
			float(T_bevel[2][1]) / float(T_bevel[2][0]),
		],
	}

func get_report() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Orrery Mechanism — all ratios from tooth counts")
	lines.append("Epicyclic: Sun(%dT) + 3xPlanet(%dT) + Ring(%dT)" % [T_sun, T_planet, T_ring])
	lines.append("  Willis: (ws-wc)/(wr-wc) = -%d/%d = %.2f" % [T_ring, T_sun, float(T_ring)/float(T_sun)])
	lines.append("  Constraint: %d = %d + 2x%d  %s" % [T_ring, T_sun, T_planet, "OK" if T_ring == T_sun + 2*T_planet else "FAIL"])
	lines.append("Bevel chain:")
	for i in range(3):
		var ta: int = int(T_bevel[i][0])
		var tb: int = int(T_bevel[i][1])
		var names: Array = ["Hour->Day", "Day->Month", "Month->Year"]
		lines.append("  %s: %dT:%dT = %.1f:1" % [str(names[i]), ta, tb, float(tb)/float(ta)])
	lines.append("Cumulative ratios from carrier:")
	var cumul: float = 1.0
	lines.append("  Hour:  %.1f:1" % cumul)
	for i in range(3):
		cumul *= float(T_bevel[i][1]) / float(T_bevel[i][0])
		var names: Array = ["Day", "Month", "Year"]
		lines.append("  %s: %.1f:1" % [str(names[i]), cumul])
	lines.append("Escapement: %dT (ratio to sun: %.2f)" % [T_escape, float(T_sun)/float(T_escape)])
	return "\n".join(lines)
