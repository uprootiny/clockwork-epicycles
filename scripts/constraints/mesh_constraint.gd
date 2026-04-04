class_name MeshConstraint
extends BaseConstraint

const EPSILON := 0.000001

var a: String = ""
var b: String = ""
var carrier: String = ""
var internal_mesh: bool = false
var compliance: float = 1.0

func _init(p_a: String = "", p_b: String = "", p_carrier: String = "", p_internal_mesh: bool = false, p_compliance: float = 1.0) -> void:
	a = p_a
	b = p_b
	carrier = p_carrier
	internal_mesh = p_internal_mesh
	compliance = p_compliance

func solve(rotors: Dictionary, _dt: float) -> void:
	var ra: Rotor = rotors[a]
	var rb: Rotor = rotors[b]
	var omega_c: float = 0.0
	var ic: float = 1.0e18
	var jc: float = 0.0
	var sign_b: float = -1.0 if internal_mesh else 1.0
	if carrier != "":
		var rc: Rotor = rotors[carrier]
		omega_c = rc.omega
		ic = rc.inertia
		jc = -(ra.radius + sign_b * rb.radius)
	var c_dot: float = ra.radius * (ra.omega - omega_c) + sign_b * rb.radius * (rb.omega - omega_c)
	if is_nan(c_dot) or is_inf(c_dot):
		return
	var denom: float = (ra.radius * ra.radius) / ra.inertia + (rb.radius * rb.radius) / rb.inertia
	if carrier != "":
		denom += (jc * jc) / ic
	if denom <= EPSILON:
		return
	var impulse: float = -compliance * c_dot / denom
	ra.omega += (ra.radius / ra.inertia) * impulse
	rb.omega += (sign_b * rb.radius / rb.inertia) * impulse
	if carrier != "":
		var rc_apply: Rotor = rotors[carrier]
		rc_apply.omega += (jc / rc_apply.inertia) * impulse

func measure_error(rotors: Dictionary) -> float:
	var ra: Rotor = rotors[a]
	var rb: Rotor = rotors[b]
	var omega_c: float = 0.0
	var sign_b: float = -1.0 if internal_mesh else 1.0
	if carrier != "":
		omega_c = (rotors[carrier] as Rotor).omega
	var err: float = abs(ra.radius * (ra.omega - omega_c) + sign_b * rb.radius * (rb.omega - omega_c))
	if is_nan(err):
		return 0.0
	return err
