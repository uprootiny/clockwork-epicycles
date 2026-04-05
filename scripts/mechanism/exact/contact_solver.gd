class_name ContactSolver
extends RefCounted
## Gear contact mechanics.
##
## For a meshing gear pair, the kinematic constraint is:
##   external: ω_a · N_a + ω_b · N_b = 0
##   internal: ω_a · N_a - ω_b · N_b = 0
##
## We enforce this via stiff spring-damper at the pitch point:
##   velocity_error = ω_a · r_a ± ω_b · r_b
##   force = -k · vel_error - c · vel_error
##   (this is a velocity-level Baumgarte stabilization)
##
## Torques on each gear from the contact force:
##   τ_a = -F · r_a,  τ_b = ±F · r_b

const COS_PA: float = 0.93969
const MU: float = 0.04  # sliding friction

var last_force: float = 0.0
var last_vel_error: float = 0.0

## External mesh: ω_a·r_a + ω_b·r_b should be zero.
## Returns [delta_omega_a, delta_omega_b].
func solve_external(
	r_a: float, omega_a: float, I_a: float,
	r_b: float, omega_b: float, I_b: float,
	stiffness: float, damping: float, _dt: float
) -> PackedFloat64Array:
	last_vel_error = omega_a * r_a + omega_b * r_b

	# Effective mass at the contact point
	var m_eff: float = 1.0 / (r_a * r_a / I_a + r_b * r_b / I_b)

	# Contact impulse (velocity-level correction)
	last_force = -m_eff * (stiffness * last_vel_error + damping * last_vel_error)

	var result: PackedFloat64Array = PackedFloat64Array()
	result.resize(2)
	result[0] = last_force * r_a / I_a   # delta_omega_a
	result[1] = last_force * r_b / I_b   # delta_omega_b
	return result

## Internal mesh: ω_a·r_a - ω_b·r_b should be zero.
func solve_internal(
	r_a: float, omega_a: float, I_a: float,
	r_b: float, omega_b: float, I_b: float,
	stiffness: float, damping: float, _dt: float
) -> PackedFloat64Array:
	last_vel_error = omega_a * r_a - omega_b * r_b

	var m_eff: float = 1.0 / (r_a * r_a / I_a + r_b * r_b / I_b)
	last_force = -m_eff * (stiffness * last_vel_error + damping * last_vel_error)

	var result: PackedFloat64Array = PackedFloat64Array()
	result.resize(2)
	result[0] = last_force * r_a / I_a
	result[1] = -last_force * r_b / I_b  # sign flip for internal
	return result

## Willis equation for epicyclic: (ω_s - ω_c)/(ω_r - ω_c) = -N_r/N_s
static func willis_ratio(N_sun: int, N_ring: int) -> float:
	return -float(N_ring) / float(N_sun)

static func willis_error(
	omega_s: float, omega_r: float, omega_c: float,
	N_sun: int, N_ring: int
) -> float:
	var denom: float = omega_r - omega_c
	if abs(denom) < 1e-10:
		return abs(omega_s - omega_c)
	var measured: float = (omega_s - omega_c) / denom
	var expected: float = -float(N_ring) / float(N_sun)
	return abs(measured - expected)

static func epicyclic_compatible(N_sun: int, N_planet: int, N_ring: int) -> bool:
	return N_ring == N_sun + 2 * N_planet
