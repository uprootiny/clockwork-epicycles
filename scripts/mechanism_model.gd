class_name MechanismModel
extends RefCounted

const RotorClass = preload("res://scripts/model/rotor.gd")
const MeshConstraintClass = preload("res://scripts/constraints/mesh_constraint.gd")
const BeltConstraintClass = preload("res://scripts/constraints/belt_constraint.gd")
const EscapementConstraintClass = preload("res://scripts/constraints/escapement_constraint.gd")
const MechanismSolverClass = preload("res://scripts/solver/mechanism_solver.gd")

const TAU_F := PI * 2.0
const EPSILON := 0.000001
const CENTER := Vector2(720.0, 450.0)
const BALANCE_CENTER := Vector2(1084.0, 470.0)
const FLYWHEEL_CENTER := Vector2(1090.0, 212.0)
const CLICK_CENTER := Vector2(1218.0, 206.0)
const GENEVA_CENTER := Vector2(1292.0, 334.0)
const BELL_CENTER := Vector2(1212.0, 606.0)
const SPRING_REST_ANGLE := -0.55
const SPRING_STIFFNESS := 8.6
const BALANCE_STIFFNESS := 8.2
const BALANCE_DAMPING := 0.52
const ESCAPEMENT_ENGAGE_ANGLE := 0.32
const MAX_SAFE_OMEGA := 120.0

var rotors: Dictionary = {}
var constraints: Array = []
var solver: MechanismSolver
var belt_constraint: BeltConstraint
var escapement_constraint: EscapementConstraint

var sim_time := 0.0
var activity_detected := false
var activity_measure := 0.0
var spring_extension := 1.25
var brake_fraction := 0.0
var test_drive_enabled := true
var paused := false
var last_escape_impulse := 0.0
var last_ring_to_dial_power := 0.0
var last_belt_slip := 0.0
var last_geneva_step := 0.0
var last_cam_lift := 0.0
var last_hammer_impulse := 0.0
var last_click_impulse := 0.0
var momentum_score := 0.0
var drive_torque := 40.0
var solver_iterations := 20
var microsteps := 4
var max_abs_omega := 0.0
var last_sanitize_ok := true

var follower_height := 0.0
var follower_velocity := 0.0
var hammer_angle := -0.18
var hammer_omega := 0.0
var bell_angle := 0.0
var bell_omega := 0.0
var click_phase := 0.0
var clickwheel_index := 0
var geneva_target_phase := 0.0
var belt_energy_accum := 0.0
var cam_energy_accum := 0.0
var strike_energy_accum := 0.0
var ratchet_energy_accum := 0.0
var geneva_energy_accum := 0.0
var bell_energy_accum := 0.0
var total_constraint_error := 0.0
var total_energy_value := 0.0
var input_power_estimate := 0.0
var output_power_estimate := 0.0
var measured_ratio_value := 0.0
var expected_ratio_value := 0.0

func _init() -> void:
	reset()

func reset() -> void:
	rotors.clear()
	constraints.clear()
	solver = MechanismSolverClass.new(solver_iterations, 0.001)
	belt_constraint = null
	escapement_constraint = null
	sim_time = 0.0
	activity_detected = false
	activity_measure = 0.0
	spring_extension = 1.25
	brake_fraction = 0.0
	paused = false
	last_escape_impulse = 0.0
	last_ring_to_dial_power = 0.0
	last_belt_slip = 0.0
	last_geneva_step = 0.0
	last_cam_lift = 0.0
	last_hammer_impulse = 0.0
	last_click_impulse = 0.0
	momentum_score = 0.0
	drive_torque = 40.0
	max_abs_omega = 0.0
	last_sanitize_ok = true
	follower_height = 0.0
	follower_velocity = 0.0
	hammer_angle = -0.18
	hammer_omega = 0.0
	bell_angle = 0.0
	bell_omega = 0.0
	click_phase = 0.0
	clickwheel_index = 0
	geneva_target_phase = 0.0
	belt_energy_accum = 0.0
	cam_energy_accum = 0.0
	strike_energy_accum = 0.0
	ratchet_energy_accum = 0.0
	geneva_energy_accum = 0.0
	bell_energy_accum = 0.0
	total_constraint_error = 0.0
	total_energy_value = 0.0
	input_power_estimate = 0.0
	output_power_estimate = 0.0
	measured_ratio_value = 0.0
	expected_ratio_value = 0.0

	_add_rotor({"name":"sun","inertia":0.34,"radius":1.0,"display_radius":74.0,"color":Color("d6b25e"),"spoke_count":6,"tooth_count":28,"damping":0.018})
	_add_rotor({"name":"carrier","inertia":2.55,"radius":2.9,"display_radius":184.0,"color":Color("6f7f97"),"spoke_count":2,"tooth_count":2,"damping":0.024})
	_add_rotor({"name":"planet_a","inertia":0.18,"radius":0.95,"display_radius":62.0,"color":Color("9ccfd8"),"spoke_count":5,"tooth_count":24,"damping":0.018,"orbit_radius":144.0,"orbit_phase":0.0})
	_add_rotor({"name":"planet_b","inertia":0.18,"radius":0.95,"display_radius":62.0,"color":Color("a6da95"),"spoke_count":5,"tooth_count":24,"damping":0.018,"orbit_radius":144.0,"orbit_phase":PI})
	_add_rotor({"name":"ring","inertia":9.8,"radius":3.85,"display_radius":250.0,"color":Color("c4a7e7"),"spoke_count":12,"tooth_count":80,"damping":0.020,"is_internal":true})
	_add_rotor({"name":"dial","inertia":0.46,"radius":0.72,"display_radius":52.0,"color":Color("f6c177"),"spoke_count":4,"tooth_count":20,"damping":0.016})
	_add_rotor({"name":"escapement","inertia":0.11,"radius":0.54,"display_radius":44.0,"color":Color("ebbcba"),"spoke_count":8,"tooth_count":16,"damping":0.016})
	_add_rotor({"name":"balance","inertia":0.76,"radius":1.0,"display_radius":88.0,"color":Color("7dcfff"),"spoke_count":4,"tooth_count":4,"damping":0.008})
	_add_rotor({"name":"flywheel","inertia":1.65,"radius":0.95,"display_radius":72.0,"color":Color("8bd5ca"),"spoke_count":6,"tooth_count":24,"damping":0.010})
	_add_rotor({"name":"clickwheel","inertia":0.28,"radius":0.45,"display_radius":36.0,"color":Color("f2cdcd"),"spoke_count":8,"tooth_count":12,"damping":0.024})
	_add_rotor({"name":"geneva","inertia":1.05,"radius":0.82,"display_radius":58.0,"color":Color("89b4fa"),"spoke_count":4,"tooth_count":4,"damping":0.020})

	(rotors["sun"] as Rotor).omega = 1.2
	(rotors["ring"] as Rotor).omega = -0.08
	(rotors["carrier"] as Rotor).omega = 0.06
	(rotors["balance"] as Rotor).theta = 0.42
	(rotors["flywheel"] as Rotor).omega = 0.15

	constraints.append(MeshConstraintClass.new("sun", "planet_a", "carrier", false, 0.93))
	constraints.append(MeshConstraintClass.new("sun", "planet_b", "carrier", false, 0.93))
	constraints.append(MeshConstraintClass.new("planet_a", "ring", "carrier", true, 0.97))
	constraints.append(MeshConstraintClass.new("planet_b", "ring", "carrier", true, 0.97))
	constraints.append(MeshConstraintClass.new("ring", "dial", "", true, 0.88))
	constraints.append(MeshConstraintClass.new("dial", "escapement", "", false, 0.86))
	belt_constraint = BeltConstraintClass.new("dial", "flywheel", 0.62, 0.18, 5.0, 0.08)
	escapement_constraint = EscapementConstraintClass.new("escapement", "balance", ESCAPEMENT_ENGAGE_ANGLE, 0.42, 0.72, 0.42)
	constraints.append(escapement_constraint)
	constraints.append(belt_constraint)
	_update_positions()
	_update_metrics()

func step(delta: float) -> void:
	if paused:
		return
	var substeps := max(microsteps, 1)
	var h := delta / float(substeps)
	for _i in range(substeps):
		_step_simulation(h)
	_update_positions()
	_update_metrics()
	_update_activity(delta)

func _step_simulation(h: float) -> void:
	sim_time += h
	for rotor in rotors.values():
		(rotor as Rotor).torque = 0.0
	last_geneva_step = 0.0
	last_hammer_impulse = 0.0
	last_click_impulse = 0.0
	_apply_drive_and_loads(h)
	for rotor in rotors.values():
		var r := rotor as Rotor
		r.apply_torque(h)
		r.apply_damping(h)
	solver.solve(rotors, constraints, h)
	_apply_cam_and_follower(h)
	_apply_hammer_and_bell(h)
	_apply_ratchet_and_geneva(h)
	last_sanitize_ok = true
	for rotor in rotors.values():
		var r2 := rotor as Rotor
		r2.integrate(h, TAU_F * 1000.0)
		last_sanitize_ok = r2.sanitize(MAX_SAFE_OMEGA) and last_sanitize_ok
		max_abs_omega = max(max_abs_omega, abs(r2.omega))
	if is_nan(follower_height) or is_inf(follower_height):
		follower_height = 0.0
		last_sanitize_ok = false
	if is_nan(bell_omega) or is_inf(bell_omega):
		bell_omega = 0.0
		last_sanitize_ok = false

func _apply_drive_and_loads(h: float) -> void:
	var sun: Rotor = rotors["sun"]
	var ring: Rotor = rotors["ring"]
	var carrier: Rotor = rotors["carrier"]
	var dial: Rotor = rotors["dial"]
	var escapement: Rotor = rotors["escapement"]
	var balance: Rotor = rotors["balance"]
	var flywheel: Rotor = rotors["flywheel"]
	var clickwheel: Rotor = rotors["clickwheel"]
	var geneva: Rotor = rotors["geneva"]

	var spring_target := 1.1 + 0.2 * sin(sim_time * 0.33)
	spring_extension = lerpf(spring_extension, spring_target, 0.18 * h)
	var spring_torque := drive_torque * spring_extension * (1.0 if test_drive_enabled else 0.0)
	sun.torque += spring_torque
	sun.torque += -SPRING_STIFFNESS * (sun.theta - SPRING_REST_ANGLE) * 0.08
	input_power_estimate = abs(spring_torque * sun.omega)

	var ring_sign := 0.0
	if abs(ring.omega) > EPSILON:
		ring_sign = sign(ring.omega)
	var ring_load := -1.9 * ring.omega - 12.0 * brake_fraction * ring_sign
	ring.torque += ring_load

	carrier.torque += -4.4 * carrier.omega
	dial.torque += -0.8 * dial.omega
	balance.torque += -BALANCE_STIFFNESS * balance.theta - BALANCE_DAMPING * balance.omega
	flywheel.torque += -0.22 * flywheel.omega
	clickwheel.torque += -0.05 * clickwheel.omega
	geneva.torque += -0.18 * geneva.omega - 0.45 * _wrap_pi(geneva.theta - geneva_target_phase)

	var escape_window := _smoothstep(ESCAPEMENT_ENGAGE_ANGLE + 0.18, ESCAPEMENT_ENGAGE_ANGLE - 0.02, abs(balance.theta))
	escapement.torque += -0.6 * escapement.omega * escape_window

	last_ring_to_dial_power = abs((ring.omega - dial.omega) * dial.omega)
	momentum_score += h * (abs(dial.omega) + abs(escapement.omega) + 0.2 * abs(balance.omega) + 0.15 * abs(flywheel.omega) + 0.12 * abs(geneva.omega))

func _apply_cam_and_follower(h: float) -> void:
	var flywheel: Rotor = rotors["flywheel"]
	var cam_phase := wrapf(flywheel.theta, 0.0, TAU_F)
	var lobe := 0.5 + 0.5 * sin(cam_phase)
	var secondary := 0.5 + 0.5 * sin(2.0 * cam_phase + 0.7)
	var target_height := 24.0 + 58.0 * pow(lobe, 1.8) + 16.0 * pow(secondary, 2.4)
	var spring_force := 9.8 * (target_height - follower_height)
	follower_velocity += spring_force * h
	follower_velocity *= max(0.0, 1.0 - 4.2 * h)
	follower_height += follower_velocity * h
	follower_height = clampf(follower_height, 0.0, 108.0)
	last_cam_lift = follower_height
	cam_energy_accum += h * abs(spring_force * follower_velocity)

	var hammer_target := -0.28 + follower_height / 108.0 * 0.92
	var hammer_torque := 18.0 * (hammer_target - hammer_angle) - 2.8 * hammer_omega
	hammer_omega += hammer_torque * h
	hammer_omega *= max(0.0, 1.0 - 1.5 * h)
	hammer_angle += hammer_omega * h
	hammer_angle = clampf(hammer_angle, -0.48, 1.12)

func _apply_hammer_and_bell(h: float) -> void:
	var bell_restoring := -7.4 * bell_angle - 0.85 * bell_omega
	bell_omega += bell_restoring * h
	bell_angle += bell_omega * h
	if hammer_angle > 0.86 and hammer_omega > 0.0:
		var strike := min(hammer_omega * 0.18, 2.4)
		bell_omega += strike
		hammer_omega *= -0.22
		hammer_angle = 0.82
		last_hammer_impulse = strike
		strike_energy_accum += abs(strike)
		bell_energy_accum += abs(bell_omega) * h

func _apply_ratchet_and_geneva(h: float) -> void:
	var clickwheel: Rotor = rotors["clickwheel"]
	var geneva: Rotor = rotors["geneva"]
	var stroke_phase := _smoothstep(0.58, 0.96, hammer_angle)
	var drive_direction := max(hammer_omega, 0.0)
	if stroke_phase > 0.65 and drive_direction > 0.02:
		var tooth_angle := TAU_F / 12.0
		click_phase += drive_direction * h * 0.74
		if click_phase >= tooth_angle:
			click_phase -= tooth_angle
			clickwheel.theta += tooth_angle
			clickwheel.omega += 2.2
			clickwheel_index = (clickwheel_index + 1) % 12
			last_click_impulse = 1.0
			ratchet_energy_accum += 1.0
			if clickwheel_index % 3 == 0:
				geneva_target_phase += PI / 2.0
				last_geneva_step = 1.0
				geneva_energy_accum += 1.0
	else:
		clickwheel.omega *= max(0.0, 1.0 - 2.5 * h)
	clickwheel.theta = lerpf(clickwheel.theta, float(clickwheel_index) * TAU_F / 12.0, 0.22)
	var geneva_error := _wrap_pi(geneva_target_phase - geneva.theta)
	geneva.omega += 4.4 * geneva_error * h
	geneva.omega *= max(0.0, 1.0 - 1.1 * h)

func _update_positions() -> void:
	rotors["carrier"].center = CENTER
	rotors["ring"].center = CENTER
	rotors["sun"].center = CENTER
	rotors["dial"].center = CENTER + Vector2(308.0, -112.0)
	rotors["escapement"].center = rotors["dial"].center + Vector2(132.0, 0.0)
	rotors["balance"].center = BALANCE_CENTER
	rotors["flywheel"].center = FLYWHEEL_CENTER
	rotors["clickwheel"].center = CLICK_CENTER
	rotors["geneva"].center = GENEVA_CENTER
	for name in ["planet_a", "planet_b"]:
		var rotor: Rotor = rotors[name]
		var orbit_angle := (rotors["carrier"] as Rotor).theta + rotor.orbit_phase
		rotor.center = CENTER + Vector2(cos(orbit_angle), sin(orbit_angle)) * rotor.orbit_radius

func _update_activity(delta: float) -> void:
	var carrier_speed := abs((rotors["carrier"] as Rotor).omega)
	var planet_speed := abs((rotors["planet_a"] as Rotor).omega) + abs((rotors["planet_b"] as Rotor).omega)
	var dial_speed := abs((rotors["dial"] as Rotor).omega) + abs((rotors["escapement"] as Rotor).omega)
	var balance_motion := abs((rotors["balance"] as Rotor).theta) + 0.4 * abs((rotors["balance"] as Rotor).omega)
	var aux_motion := 0.20 * abs((rotors["flywheel"] as Rotor).omega) + 0.14 * abs((rotors["geneva"] as Rotor).omega) + 0.02 * follower_height + 0.25 * abs(bell_omega)
	activity_measure += delta * (carrier_speed + 0.25 * planet_speed + 0.33 * dial_speed + 0.22 * balance_motion + aux_motion)
	if activity_measure > 2.2 and momentum_score > 0.9 and (belt_energy_accum + cam_energy_accum + strike_energy_accum) > 0.4 and total_constraint_error < 6.0 and last_sanitize_ok:
		activity_detected = true

func _update_metrics() -> void:
	total_constraint_error = get_constraint_error()
	total_energy_value = total_energy()
	output_power_estimate = abs((rotors["geneva"] as Rotor).omega * 0.18) + abs(bell_omega * 0.12) + abs((rotors["flywheel"] as Rotor).omega * 0.08)
	var sun_omega := abs((rotors["sun"] as Rotor).omega)
	var geneva_omega := abs((rotors["geneva"] as Rotor).omega)
	measured_ratio_value = geneva_omega / max(sun_omega, EPSILON)
	expected_ratio_value = 0.015
	if belt_constraint != null:
		last_belt_slip = belt_constraint.last_slip
	if escapement_constraint != null:
		last_escape_impulse = escapement_constraint.last_impulse

func has_physics_activity() -> bool:
	return activity_detected

func get_constraint_error() -> float:
	var total := 0.0
	for c in constraints:
		total += c.measure_error(rotors)
	return total

func total_energy() -> float:
	var e := 0.0
	for rotor in rotors.values():
		e += (rotor as Rotor).kinetic_energy()
	e += 0.5 * BALANCE_STIFFNESS * pow((rotors["balance"] as Rotor).theta, 2.0)
	e += 0.5 * 7.4 * bell_angle * bell_angle
	return e

func get_input_energy() -> float:
	return input_power_estimate

func get_output_energy() -> float:
	return output_power_estimate

func get_measured_ratio() -> float:
	return measured_ratio_value

func get_expected_ratio() -> float:
	return expected_ratio_value

func get_max_velocity() -> float:
	return max_abs_omega

func get_snapshot() -> Dictionary:
	return {
		"sun": {"theta": rotors["sun"].theta, "omega": rotors["sun"].omega},
		"carrier": {"theta": rotors["carrier"].theta, "omega": rotors["carrier"].omega},
		"ring": {"theta": rotors["ring"].theta, "omega": rotors["ring"].omega},
		"planet_a": {"theta": rotors["planet_a"].theta, "omega": rotors["planet_a"].omega},
		"planet_b": {"theta": rotors["planet_b"].theta, "omega": rotors["planet_b"].omega},
		"dial": {"theta": rotors["dial"].theta, "omega": rotors["dial"].omega},
		"escapement": {"theta": rotors["escapement"].theta, "omega": rotors["escapement"].omega},
		"balance": {"theta": rotors["balance"].theta, "omega": rotors["balance"].omega},
		"flywheel": {"theta": rotors["flywheel"].theta, "omega": rotors["flywheel"].omega},
		"clickwheel": {"theta": rotors["clickwheel"].theta, "omega": rotors["clickwheel"].omega, "index": clickwheel_index},
		"geneva": {"theta": rotors["geneva"].theta, "omega": rotors["geneva"].omega},
		"activity": activity_measure,
		"momentum_score": momentum_score,
		"last_escape_impulse": last_escape_impulse,
		"ring_to_dial_power": last_ring_to_dial_power,
		"last_belt_slip": last_belt_slip,
		"last_cam_lift": last_cam_lift,
		"last_hammer_impulse": last_hammer_impulse,
		"last_click_impulse": last_click_impulse,
		"last_geneva_step": last_geneva_step,
		"follower_height": follower_height,
		"hammer_angle": hammer_angle,
		"hammer_omega": hammer_omega,
		"bell_angle": bell_angle,
		"bell_omega": bell_omega,
		"belt_energy": belt_energy_accum,
		"cam_energy": cam_energy_accum,
		"strike_energy": strike_energy_accum,
		"ratchet_energy": ratchet_energy_accum,
		"geneva_energy": geneva_energy_accum,
		"bell_energy": bell_energy_accum,
		"drive_torque": drive_torque,
		"brake_fraction": brake_fraction,
		"sim_time": sim_time,
		"max_abs_omega": max_abs_omega,
		"constraint_error": total_constraint_error,
		"total_energy": total_energy_value,
		"input_energy": input_power_estimate,
		"output_energy": output_power_estimate,
		"measured_ratio": measured_ratio_value,
		"expected_ratio": expected_ratio_value,
		"sanitize_ok": last_sanitize_ok,
	}

func get_modality_snapshot() -> Dictionary:
	return {
		"gear_train": {
			"carrier_speed": abs(rotors["carrier"].omega),
			"sun_speed": abs(rotors["sun"].omega),
			"ring_to_dial_power": last_ring_to_dial_power,
			"constraint_error": total_constraint_error,
		},
		"belt": {
			"flywheel_speed": abs(rotors["flywheel"].omega),
			"slip": abs(last_belt_slip),
			"energy": belt_energy_accum,
		},
		"cam_follower": {
			"height": follower_height,
			"energy": cam_energy_accum,
		},
		"hammer_bell": {
			"impulse": last_hammer_impulse,
			"bell_speed": abs(bell_omega),
			"energy": strike_energy_accum,
		},
		"ratchet": {
			"index": clickwheel_index,
			"impulse": last_click_impulse,
			"energy": ratchet_energy_accum,
		},
		"geneva": {
			"step": last_geneva_step,
			"theta": rotors["geneva"].theta,
			"energy": geneva_energy_accum,
		},
	}

func _add_rotor(config: Dictionary) -> void:
	var rotor := RotorClass.new(config)
	rotors[rotor.name] = rotor

func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	if abs(edge1 - edge0) <= EPSILON:
		return 0.0
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _wrap_pi(angle: float) -> float:
	return wrapf(angle + PI, 0.0, TAU_F) - PI
