class_name BevelGeometry
extends RefCounted
## Bevel gear geometry from cone angles and tooth counts.
##
## A bevel gear pair transmits rotation between intersecting axes.
## The cone half-angles must sum to the shaft angle (usually 90°).
##
## Kinematic law:
##   ω_a · sin(δ_a) = ω_b · sin(δ_b)
##   ω_a / ω_b = sin(δ_b) / sin(δ_a) = N_b / N_a
##
## For a 90° shaft angle: δ_a + δ_b = π/2
##   so sin(δ_b) = cos(δ_a), giving:
##   ω_a / ω_b = cos(δ_a) / sin(δ_a) = 1/tan(δ_a) = N_b / N_a

var teeth: int
var module: float
var cone_half_angle: float  # δ — half angle of the pitch cone
var pitch_radius: float     # at the large end
var face_width: float
var shaft_angle: float      # angle between the two axes (usually π/2)

func _init(p_teeth: int, p_module: float, p_cone_angle: float) -> void:
	teeth = max(p_teeth, 4)
	module = max(p_module, 0.001)
	cone_half_angle = clampf(p_cone_angle, 0.05, PI * 0.48)
	pitch_radius = module * float(teeth) / 2.0
	face_width = pitch_radius * 0.3

## Compute the cone half-angle from tooth counts for a 90° shaft.
## tan(δ_a) = N_a / N_b
static func cone_angle_for_90deg(teeth_self: int, teeth_mate: int) -> float:
	return atan2(float(teeth_self), float(teeth_mate))

## Exact gear ratio from the kinematic law.
static func ratio_from_cones(delta_a: float, delta_b: float) -> float:
	if abs(sin(delta_a)) < 1e-10:
		return 0.0
	return sin(delta_b) / sin(delta_a)

## Velocity constraint error for a bevel pair.
static func velocity_error(omega_a: float, delta_a: float, omega_b: float, delta_b: float) -> float:
	return omega_a * sin(delta_a) - omega_b * sin(delta_b)

## Solve bevel contact: returns [delta_omega_a, delta_omega_b]
static func solve(
	omega_a: float, delta_a: float, I_a: float,
	omega_b: float, delta_b: float, I_b: float,
	stiffness: float, damping: float
) -> PackedFloat64Array:
	var sa: float = sin(delta_a)
	var sb: float = sin(delta_b)
	var vel_err: float = omega_a * sa - omega_b * sb
	var m_eff: float = 1.0 / (sa * sa / I_a + sb * sb / I_b)
	var impulse: float = -m_eff * (stiffness * vel_err + damping * vel_err)
	var result: PackedFloat64Array = PackedFloat64Array()
	result.resize(2)
	result[0] = impulse * sa / I_a
	result[1] = -impulse * sb / I_b
	return result
