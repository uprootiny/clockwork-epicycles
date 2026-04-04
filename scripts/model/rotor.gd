class_name Rotor
extends RefCounted

var name := ""
var inertia := 1.0
var radius := 1.0
var display_radius := 32.0
var color := Color.WHITE
var spoke_count := 4
var tooth_count := 20
var damping := 0.02
var orbit_radius := 0.0
var orbit_phase := 0.0
var is_internal := false
var center := Vector2.ZERO
var theta := 0.0
var omega := 0.0
var torque := 0.0
var max_seen_omega := 0.0

func _init(p_config: Dictionary = {}) -> void:
	name = p_config.get("name", "")
	inertia = max(float(p_config.get("inertia", 1.0)), 0.001)
	radius = max(float(p_config.get("radius", 1.0)), 0.001)
	display_radius = float(p_config.get("display_radius", 32.0))
	color = p_config.get("color", Color.WHITE)
	spoke_count = max(int(p_config.get("spoke_count", 4)), 1)
	tooth_count = max(int(p_config.get("tooth_count", 20)), 2)
	damping = max(float(p_config.get("damping", 0.02)), 0.0)
	orbit_radius = float(p_config.get("orbit_radius", 0.0))
	orbit_phase = float(p_config.get("orbit_phase", 0.0))
	is_internal = bool(p_config.get("is_internal", false))

func apply_torque(dt: float) -> void:
	omega += dt * torque / inertia

func apply_damping(dt: float) -> void:
	# Use exponential decay for stability at large dt
	# exp(-damping*dt) ≈ 1-damping*dt for small dt, but never overshoots
	if damping * dt > 0.5:
		omega *= exp(-damping * dt)
	else:
		omega *= max(0.0, 1.0 - damping * dt)

func integrate(dt: float, wrap_span: float) -> void:
	theta = wrapf(theta + omega * dt, -wrap_span, wrap_span)
	max_seen_omega = max(max_seen_omega, abs(omega))

func kinetic_energy() -> float:
	return 0.5 * inertia * omega * omega

func sanitize(max_allowed_omega: float) -> bool:
	var ok := true
	if is_nan(theta) or is_inf(theta):
		theta = 0.0
		ok = false
	if is_nan(omega) or is_inf(omega):
		omega = 0.0
		ok = false
	if is_nan(torque) or is_inf(torque):
		torque = 0.0
		ok = false
	omega = clampf(omega, -max_allowed_omega, max_allowed_omega)
	return ok
