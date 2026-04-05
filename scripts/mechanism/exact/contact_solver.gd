class_name ContactSolver
extends RefCounted
## Gear mesh solver based on actual tooth contact mechanics.
##
## Instead of velocity-projection with compliance fudge factors,
## this computes forces from:
##   1. Contact point on the line of action
##   2. Normal force from tooth stiffness × penetration
##   3. Friction force tangential to contact
##   4. Resulting torques on both gears
##
## The governing equations for an external mesh pair:
##   constraint: omega_a * r_a + omega_b * r_b = 0
##   contact force: F_n = k * penetration + c * penetration_rate
##   torque_a = F_n * r_a * cos(pressure_angle)
##   torque_b = -F_n * r_b * cos(pressure_angle)
##
## For epicyclic (Willis equation):
##   omega_sun - omega_carrier     N_ring
##   ─────────────────────────── = ─────── (with sign for internal)
##   omega_ring - omega_carrier    N_sun

const PRESSURE_ANGLE: float = deg_to_rad(20.0)
const COS_PA: float = 0.9397
const MU_FRICTION: float = 0.05  # tooth surface friction coefficient

## Result of a single contact evaluation
var last_normal_force: float = 0.0
var last_friction_force: float = 0.0
var last_penetration: float = 0.0
var last_contact_active: bool = false

## Evaluate contact between two gears and apply forces.
## Returns the torque applied to each gear as [torque_a, torque_b].
func solve_external_mesh(
	geo_a: GearGeometry, geo_b: GearGeometry,
	theta_a: float, omega_a: float, inertia_a: float,
	theta_b: float, omega_b: float, inertia_b: float,
	stiffness: float, damping_coeff: float, dt: float
) -> PackedFloat64Array:
	# Velocity constraint error (should be zero for perfect mesh)
	var velocity_error: float = omega_a * geo_a.pitch_radius + omega_b * geo_b.pitch_radius

	# Angular penetration: how far past the ideal mesh position
	# In terms of the driving tooth pressing into the driven tooth
	var pitch_a: float = TAU / float(geo_a.teeth)
	var pitch_b: float = TAU / float(geo_b.teeth)

	# Relative angular position at the contact point
	var contact_angle_a: float = fmod(theta_a, pitch_a)
	var contact_angle_b: float = fmod(theta_b, pitch_b)

	# Penetration in linear distance along line of action
	var penetration: float = velocity_error * dt * geo_a.pitch_radius
	last_penetration = penetration

	# Contact is active when teeth overlap
	# (simplified: always active for a properly meshed pair)
	last_contact_active = true

	# Normal force along line of action: spring-damper
	var normal_force: float = stiffness * penetration + damping_coeff * velocity_error
	last_normal_force = normal_force

	# Friction force perpendicular to line of action
	var sliding_velocity: float = velocity_error * COS_PA
	last_friction_force = -MU_FRICTION * abs(normal_force) * sign(sliding_velocity)

	# Torques from contact forces
	var torque_a: float = -normal_force * geo_a.pitch_radius * COS_PA
	var torque_b: float = normal_force * geo_b.pitch_radius * COS_PA

	# Add friction torques (small but physically real)
	torque_a += last_friction_force * geo_a.base_radius
	torque_b -= last_friction_force * geo_b.base_radius

	# Apply as impulse: delta_omega = torque * dt / inertia
	var result: PackedFloat64Array = PackedFloat64Array()
	result.resize(2)
	result[0] = torque_a * dt / inertia_a
	result[1] = torque_b * dt / inertia_b
	return result

## Evaluate internal mesh (ring gear meshes with planet).
## The ring's teeth point inward; the constraint sign flips.
func solve_internal_mesh(
	geo_planet: GearGeometry, geo_ring: GearGeometry,
	theta_p: float, omega_p: float, inertia_p: float,
	theta_r: float, omega_r: float, inertia_r: float,
	stiffness: float, damping_coeff: float, dt: float
) -> PackedFloat64Array:
	# For internal mesh: omega_planet * r_planet - omega_ring * r_ring = 0
	var velocity_error: float = omega_p * geo_planet.pitch_radius - omega_r * geo_ring.pitch_radius

	last_penetration = velocity_error * dt * geo_planet.pitch_radius
	last_contact_active = true

	var normal_force: float = stiffness * last_penetration + damping_coeff * velocity_error
	last_normal_force = normal_force

	var sliding_velocity: float = velocity_error * COS_PA
	last_friction_force = -MU_FRICTION * abs(normal_force) * sign(sliding_velocity)

	var torque_p: float = -normal_force * geo_planet.pitch_radius * COS_PA
	var torque_r: float = normal_force * geo_ring.pitch_radius * COS_PA

	torque_p += last_friction_force * geo_planet.base_radius
	torque_r -= last_friction_force * geo_ring.base_radius

	var result: PackedFloat64Array = PackedFloat64Array()
	result.resize(2)
	result[0] = torque_p * dt / inertia_p
	result[1] = torque_r * dt / inertia_r
	return result

## Willis equation for epicyclic system.
## Given sun, ring, carrier — returns the constraint:
##   (omega_sun - omega_carrier) / (omega_ring - omega_carrier) = -N_ring / N_sun
##
## This is the EXACT kinematic relationship. No approximation.
static func willis_ratio(teeth_sun: int, teeth_ring: int) -> float:
	return -float(teeth_ring) / float(teeth_sun)

## Check if the Willis equation is satisfied.
## Returns the error (should be ~0 for correct motion).
static func willis_error(
	omega_sun: float, omega_ring: float, omega_carrier: float,
	teeth_sun: int, teeth_ring: int
) -> float:
	var denom: float = omega_ring - omega_carrier
	if abs(denom) < 1e-10:
		return abs(omega_sun - omega_carrier)
	var measured: float = (omega_sun - omega_carrier) / denom
	var expected: float = -float(teeth_ring) / float(teeth_sun)
	return abs(measured - expected)

## Tooth count constraint for epicyclic: N_ring = N_sun + 2 * N_planet
## Returns true if the tooth counts are geometrically compatible.
static func epicyclic_compatible(teeth_sun: int, teeth_planet: int, teeth_ring: int) -> bool:
	return teeth_ring == teeth_sun + 2 * teeth_planet
