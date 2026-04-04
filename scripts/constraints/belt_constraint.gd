class_name BeltConstraint
extends BaseConstraint

const EPSILON := 0.000001

var a := ""
var b := ""
var stiffness := 0.62
var min_tension := 0.18
var max_slip := 5.0
var ratio_bias := 0.08
var last_impulse := 0.0
var last_slip := 0.0

func _init(p_a: String = "", p_b: String = "", p_stiffness: float = 0.62, p_min_tension: float = 0.18, p_max_slip: float = 5.0, p_ratio_bias: float = 0.08) -> void:
	a = p_a
	b = p_b
	stiffness = p_stiffness
	min_tension = p_min_tension
	max_slip = p_max_slip
	ratio_bias = p_ratio_bias

func solve(rotors: Dictionary, dt: float) -> void:
	var ra: Rotor = rotors[a]
	var rb: Rotor = rotors[b]
	last_slip = ra.radius * ra.omega - rb.radius * rb.omega
	if is_nan(last_slip) or is_inf(last_slip):
		last_slip = 0.0
		last_impulse = 0.0
		return
	var tension := clampf(1.0 - abs(last_slip) / max(max_slip, EPSILON), min_tension, 1.0)
	var denom := (ra.radius * ra.radius) / ra.inertia + (rb.radius * rb.radius) / rb.inertia
	if denom <= EPSILON:
		last_impulse = 0.0
		return
	last_impulse = -stiffness * tension * last_slip / denom
	ra.omega += (ra.radius / ra.inertia) * last_impulse
	rb.omega -= (rb.radius / rb.inertia) * last_impulse
	var ratio := ra.radius / rb.radius
	# Clamp lerp factor to prevent overshoot at large dt
	var lerp_t := clampf(ratio_bias * dt, 0.0, 0.5)
	rb.omega = lerpf(rb.omega, ra.omega * ratio, lerp_t)

func measure_error(rotors: Dictionary) -> float:
	var ra: Rotor = rotors[a]
	var rb: Rotor = rotors[b]
	var err := abs(ra.radius * ra.omega - rb.radius * rb.omega)
	if is_nan(err):
		return 0.0
	return err
