class_name EscapementConstraint
extends BaseConstraint

const EPSILON := 0.000001

var wheel: String = ""
var balance: String = ""
var engage_angle: float = 0.32
var coupling_ratio: float = 0.42
var impulse_scale: float = 0.72
var tick_scale: float = 0.42
var last_impulse: float = 0.0

func _init(p_wheel: String = "", p_balance: String = "", p_engage_angle: float = 0.32, p_coupling_ratio: float = 0.42, p_impulse_scale: float = 0.72, p_tick_scale: float = 0.42) -> void:
	wheel = p_wheel
	balance = p_balance
	engage_angle = p_engage_angle
	coupling_ratio = p_coupling_ratio
	impulse_scale = p_impulse_scale
	tick_scale = p_tick_scale

func solve(rotors: Dictionary, _dt: float) -> void:
	var rw: Rotor = rotors[wheel]
	var rb: Rotor = rotors[balance]
	var gate: float = clampf(1.0 - abs(rb.theta) / engage_angle, 0.0, 1.0)
	var engage: float = gate * gate
	if engage <= 0.001:
		last_impulse = 0.0
		return
	var c_dot: float = rw.omega + coupling_ratio * rb.omega
	if is_nan(c_dot) or is_inf(c_dot):
		last_impulse = 0.0
		return
	var denom: float = 1.0 / rw.inertia + (coupling_ratio * coupling_ratio) / rb.inertia
	if denom <= EPSILON:
		last_impulse = 0.0
		return
	var impulse: float = -impulse_scale * engage * c_dot / denom
	rw.omega += impulse / rw.inertia
	rb.omega += coupling_ratio * impulse / rb.inertia
	var directional_input: float = -rb.theta
	if abs(directional_input) <= EPSILON:
		directional_input = -rw.omega
	var tick_strength: float = tick_scale * engage * sign(directional_input)
	rb.omega += tick_strength / rb.inertia
	rw.omega -= tick_strength * 0.68 / rw.inertia
	last_impulse = tick_strength

func measure_error(rotors: Dictionary) -> float:
	var rw: Rotor = rotors[wheel]
	var rb: Rotor = rotors[balance]
	var gate: float = clampf(1.0 - abs(rb.theta) / engage_angle, 0.0, 1.0)
	var err: float = gate * abs(rw.omega + coupling_ratio * rb.omega)
	if is_nan(err):
		return 0.0
	return err
