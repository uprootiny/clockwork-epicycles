extends Node2D

const MechanismModel = preload("res://scripts/mechanism_model.gd")
const RotorClass = preload("res://scripts/model/rotor.gd")

var model: MechanismModel
@export var draw_debug_text := true

func _ready() -> void:
	model = MechanismModel.new()
	model.reset()
	set_physics_process(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	_handle_continuous_input(delta)
	model.step(delta)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		model.paused = not model.paused
	elif event.is_action_pressed("debug_toggle"):
		draw_debug_text = not draw_debug_text
	elif event.is_action_pressed("mechanism_reset"):
		model.reset()
	queue_redraw()

func _handle_continuous_input(delta: float) -> void:
	if Input.is_action_pressed("drive_up"):
		model.drive_torque = min(model.drive_torque + 16.0 * delta, 80.0)
	elif Input.is_action_pressed("drive_down"):
		model.drive_torque = max(model.drive_torque - 16.0 * delta, 4.0)
	if Input.is_action_pressed("brake_more"):
		model.brake_fraction = clampf(model.brake_fraction + 0.35 * delta, 0.0, 0.9)
	elif Input.is_action_pressed("brake_less"):
		model.brake_fraction = clampf(model.brake_fraction - 0.35 * delta, 0.0, 0.9)

func has_physics_activity() -> bool:
	return model.activity_detected

func get_activity_snapshot() -> Dictionary:
	return model.get_snapshot()

func get_modality_snapshot() -> Dictionary:
	return model.get_modality_snapshot()

func _draw() -> void:
	if model == null:
		return
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("101319"), true)
	_draw_grid()
	_draw_mechanism_base()
	_draw_energy_spring()
	var ring: Rotor = model.rotors["ring"]
	var carrier: Rotor = model.rotors["carrier"]
	var sun: Rotor = model.rotors["sun"]
	var planet_a: Rotor = model.rotors["planet_a"]
	var planet_b: Rotor = model.rotors["planet_b"]
	var dial: Rotor = model.rotors["dial"]
	var escapement: Rotor = model.rotors["escapement"]
	var balance: Rotor = model.rotors["balance"]
	_draw_gear(ring)
	_draw_carrier(carrier)
	_draw_gear(sun)
	_draw_gear(planet_a)
	_draw_gear(planet_b)
	_draw_gear(dial)
	_draw_gear(escapement)
	_draw_linkage(dial.center + Vector2(52.0, 0.0), escapement.center - Vector2(44.0, 0.0), Color("5b6078"), 10.0)
	_draw_balance(balance)
	_draw_anchor()
	_draw_belt_and_flywheel()
	_draw_cam_follower_and_hammer()
	_draw_clickwheel_and_geneva()
	_draw_bell()
	_draw_clock_hand(MechanismModel.CENTER, 198.0, carrier.theta, Color("eb6f92"), 8.0)
	_draw_clock_hand(dial.center, 72.0, dial.theta, Color("f6c177"), 6.0)
	_draw_clock_hand(MechanismModel.CENTER, 148.0, -ring.theta * 0.7, Color("9ccfd8"), 5.0)
	if draw_debug_text:
		_draw_debug_overlay()

func _draw_grid() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	for x in range(0, int(vp_size.x), 64):
		draw_line(Vector2(x, 0), Vector2(x, vp_size.y), Color(1, 1, 1, 0.03), 1.0)
	for y in range(0, int(vp_size.y), 64):
		draw_line(Vector2(0, y), Vector2(vp_size.x, y), Color(1, 1, 1, 0.03), 1.0)

func _draw_mechanism_base() -> void:
	draw_circle(MechanismModel.CENTER, 286.0, Color("1a1d28"))
	draw_arc(MechanismModel.CENTER, 286.0, 0.0, MechanismModel.TAU_F, 96, Color("2e3446"), 10.0)
	draw_arc(MechanismModel.CENTER, 214.0, 0.0, MechanismModel.TAU_F, 96, Color("2a3040"), 6.0)
	draw_rect(Rect2(MechanismModel.BALANCE_CENTER + Vector2(-126.0, -134.0), Vector2(252.0, 268.0)), Color(0.08, 0.09, 0.13, 0.42), false, 4.0)
	var esc: Rotor = model.rotors["escapement"]
	draw_line(esc.center, MechanismModel.BALANCE_CENTER, Color("444b61"), 12.0)
	draw_rect(Rect2(MechanismModel.FLYWHEEL_CENTER + Vector2(-154.0, -102.0), Vector2(280.0, 204.0)), Color(0.06, 0.10, 0.11, 0.26), false, 3.0)
	draw_rect(Rect2(MechanismModel.GENEVA_CENTER + Vector2(-84.0, -64.0), Vector2(168.0, 128.0)), Color(0.08, 0.10, 0.16, 0.24), false, 3.0)
	draw_rect(Rect2(MechanismModel.BELL_CENTER + Vector2(-102.0, -86.0), Vector2(170.0, 172.0)), Color(0.10, 0.08, 0.05, 0.22), false, 3.0)

func _draw_energy_spring() -> void:
	var start: Vector2 = MechanismModel.CENTER + Vector2(-364.0, 0.0)
	var ending: Vector2 = MechanismModel.CENTER + Vector2(-210.0, 0.0)
	var points := PackedVector2Array()
	var turns := 11
	for i in range(turns + 1):
		var t: float = float(i) / float(turns)
		var x: float = lerpf(start.x, ending.x, t)
		var y: float = start.y + sin(t * MechanismModel.TAU_F * 5.5 + model.sim_time * 1.5) * (14.0 + 4.0 * model.spring_extension)
		points.append(Vector2(x, y))
	draw_polyline(points, Color("d6b25e"), 5.0)
	draw_circle(start, 18.0, Color("473b1f"))
	draw_circle(ending, 18.0, Color("6a5830"))
	draw_line(ending, MechanismModel.CENTER + Vector2(-74.0, 0.0), Color("7f6f3e"), 8.0)

func _draw_carrier(rotor: Rotor) -> void:
	var arm_angles: Array[float] = [rotor.theta, rotor.theta + PI]
	for angle in arm_angles:
		var p1: Vector2 = MechanismModel.CENTER + Vector2(cos(angle), sin(angle)) * 28.0
		var p2: Vector2 = MechanismModel.CENTER + Vector2(cos(angle), sin(angle)) * 146.0
		draw_line(p1, p2, Color("6f7f97"), 18.0)
		draw_circle(p2, 18.0, Color("565f73"))
	draw_circle(MechanismModel.CENTER, 24.0, Color("3e4558"))
	draw_arc(MechanismModel.CENTER, 148.0, rotor.theta - 0.5, rotor.theta + 0.5, 32, Color("75809c"), 8.0)
	draw_arc(MechanismModel.CENTER, 148.0, rotor.theta + PI - 0.5, rotor.theta + PI + 0.5, 32, Color("75809c"), 8.0)

func _draw_gear(rotor: Rotor) -> void:
	if rotor.is_internal:
		_draw_internal_ring(rotor)
		return
	var outer: float = rotor.display_radius
	var inner: float = outer * 0.84
	var center: Vector2 = rotor.center
	for tooth in range(rotor.tooth_count):
		var base_angle: float = rotor.theta + MechanismModel.TAU_F * float(tooth) / float(rotor.tooth_count)
		var p1: Vector2 = center + Vector2(cos(base_angle), sin(base_angle)) * inner
		var p2: Vector2 = center + Vector2(cos(base_angle), sin(base_angle)) * outer
		draw_line(p1, p2, rotor.color.lightened(0.18), 3.0)
	draw_circle(center, inner, rotor.color)
	draw_arc(center, outer, 0.0, MechanismModel.TAU_F, rotor.tooth_count, rotor.color.lightened(0.10), 10.0)
	_draw_spokes(rotor)
	draw_circle(center, max(10.0, outer * 0.16), Color(0.95, 0.95, 0.95, 0.22))
	draw_circle(center, max(5.0, outer * 0.07), Color("0f1118"))

func _draw_internal_ring(rotor: Rotor) -> void:
	var center: Vector2 = rotor.center
	var outer: float = rotor.display_radius
	var inner: float = outer - 46.0
	draw_circle(center, outer, rotor.color.darkened(0.56))
	draw_circle(center, inner, Color("101319"))
	draw_arc(center, outer, 0.0, MechanismModel.TAU_F, rotor.tooth_count, rotor.color, 14.0)
	for tooth in range(rotor.tooth_count):
		var angle: float = -rotor.theta + MechanismModel.TAU_F * float(tooth) / float(rotor.tooth_count)
		var p1: Vector2 = center + Vector2(cos(angle), sin(angle)) * inner
		var p2: Vector2 = center + Vector2(cos(angle), sin(angle)) * (inner + 18.0)
		draw_line(p1, p2, rotor.color.lightened(0.22), 2.0)
	draw_arc(center, inner - 34.0, 0.0, MechanismModel.TAU_F, 64, Color("11131b"), 4.0)

func _draw_spokes(rotor: Rotor) -> void:
	var center: Vector2 = rotor.center
	var hub: float = max(14.0, rotor.display_radius * 0.16)
	var spoke_length: float = rotor.display_radius * 0.62
	if rotor.spoke_count <= 0:
		return
	for i in range(rotor.spoke_count):
		var angle: float = rotor.theta + MechanismModel.TAU_F * float(i) / float(rotor.spoke_count)
		var p1: Vector2 = center + Vector2(cos(angle), sin(angle)) * hub
		var p2: Vector2 = center + Vector2(cos(angle), sin(angle)) * spoke_length
		draw_line(p1, p2, rotor.color.lightened(0.32), 5.0)

func _draw_balance(balance: Rotor) -> void:
	draw_circle(MechanismModel.BALANCE_CENTER, balance.display_radius, Color(0.06, 0.09, 0.12, 0.28))
	draw_arc(MechanismModel.BALANCE_CENTER, balance.display_radius, 0.0, MechanismModel.TAU_F, 64, balance.color, 8.0)
	for i in range(4):
		var angle: float = balance.theta + MechanismModel.TAU_F * float(i) / 4.0
		var p1: Vector2 = MechanismModel.BALANCE_CENTER + Vector2(cos(angle), sin(angle)) * 24.0
		var p2: Vector2 = MechanismModel.BALANCE_CENTER + Vector2(cos(angle), sin(angle)) * (balance.display_radius - 10.0)
		draw_line(p1, p2, balance.color.lightened(0.24), 6.0)
		var weight: Vector2 = MechanismModel.BALANCE_CENTER + Vector2(cos(angle), sin(angle)) * (balance.display_radius - 18.0)
		draw_circle(weight, 8.0, Color("a6e3ff"))
	draw_circle(MechanismModel.BALANCE_CENTER, 18.0, Color("163543"))
	var spring_end: Vector2 = MechanismModel.BALANCE_CENTER + Vector2(cos(balance.theta - PI / 2.0), sin(balance.theta - PI / 2.0)) * 20.0
	draw_polyline(PackedVector2Array([
		MechanismModel.BALANCE_CENTER + Vector2(-34.0, -120.0),
		MechanismModel.BALANCE_CENTER + Vector2(-16.0, -86.0),
		spring_end + Vector2(-10.0, -38.0),
		spring_end
	]), Color("7dcfff"), 3.0)

func _draw_anchor() -> void:
	var escapement: Rotor = model.rotors["escapement"]
	var balance: Rotor = model.rotors["balance"]
	var anchor_root: Vector2 = (escapement.center + MechanismModel.BALANCE_CENTER) * 0.5 + Vector2(-18.0, 0.0)
	var swing: float = clampf(balance.theta / MechanismModel.ESCAPEMENT_ENGAGE_ANGLE, -1.0, 1.0) * 0.46
	var left_tip: Vector2 = anchor_root + Vector2(cos(PI * 0.72 + swing), sin(PI * 0.72 + swing)) * 56.0
	var right_tip: Vector2 = anchor_root + Vector2(cos(-PI * 0.72 + swing), sin(-PI * 0.72 + swing)) * 56.0
	draw_line(anchor_root, left_tip, Color("b7bdf8"), 8.0)
	draw_line(anchor_root, right_tip, Color("b7bdf8"), 8.0)
	draw_circle(anchor_root, 12.0, Color("616d94"))
	draw_circle(left_tip, 8.0, Color("c6d0f5"))
	draw_circle(right_tip, 8.0, Color("c6d0f5"))
	draw_line(anchor_root, MechanismModel.BALANCE_CENTER + Vector2(-balance.display_radius + 6.0, 0.0), Color("5b6078"), 6.0)

func _draw_belt_and_flywheel() -> void:
	var dial: Rotor = model.rotors["dial"]
	var flywheel: Rotor = model.rotors["flywheel"]
	var offset := Vector2(0.0, 14.0)
	draw_line(dial.center + offset, flywheel.center + offset, Color("8bd5ca"), 6.0)
	draw_line(dial.center - offset, flywheel.center - offset, Color("8bd5ca"), 6.0)
	_draw_gear(flywheel)
	var slip: float = clampf(abs(model.last_belt_slip) * 0.12, 0.0, 1.0)
	draw_arc((dial.center + flywheel.center) * 0.5 + Vector2(0.0, -32.0), 24.0, PI * 0.1, PI * (0.1 + slip), 16, Color("f9e2af"), 4.0)

func _draw_cam_follower_and_hammer() -> void:
	var flywheel: Rotor = model.rotors["flywheel"]
	var cam_dir: Vector2 = Vector2(cos(flywheel.theta), sin(flywheel.theta))
	var cam_tip: Vector2 = flywheel.center + cam_dir * (flywheel.display_radius - 12.0)
	draw_line(flywheel.center, cam_tip, Color("d3c6aa"), 6.0)
	var follower_base: Vector2 = flywheel.center + Vector2(124.0, 88.0)
	var follower_top: Vector2 = follower_base + Vector2(0.0, -model.follower_height)
	draw_rect(Rect2(follower_base + Vector2(-10.0, -120.0), Vector2(20.0, 124.0)), Color("313848"), false, 3.0)
	draw_line(cam_tip, follower_top, Color("cba6f7"), 4.0)
	draw_line(follower_base, follower_top, Color("cba6f7"), 10.0)
	draw_circle(follower_top, 10.0, Color("f5c2e7"))
	var hammer_pivot: Vector2 = MechanismModel.BELL_CENTER + Vector2(-108.0, -22.0)
	var hammer_len := 94.0
	var hammer_tip: Vector2 = hammer_pivot + Vector2(cos(-0.8 + model.hammer_angle), sin(-0.8 + model.hammer_angle)) * hammer_len
	draw_line(follower_top, hammer_pivot, Color("fab387"), 5.0)
	draw_line(hammer_pivot, hammer_tip, Color("fab387"), 9.0)
	draw_circle(hammer_pivot, 11.0, Color("eba0ac"))
	draw_circle(hammer_tip, 10.0, Color("f38ba8"))

func _draw_clickwheel_and_geneva() -> void:
	var clickwheel: Rotor = model.rotors["clickwheel"]
	var geneva: Rotor = model.rotors["geneva"]
	_draw_gear(clickwheel)
	_draw_geneva(geneva)
	var pawl_start: Vector2 = MechanismModel.BELL_CENTER + Vector2(-32.0, -62.0)
	var pawl_end: Vector2 = clickwheel.center + Vector2(-26.0, 22.0)
	draw_line(pawl_start, pawl_end, Color("94e2d5"), 5.0)
	var geneva_driver: Vector2 = clickwheel.center + Vector2(cos(clickwheel.theta), sin(clickwheel.theta)) * 32.0
	draw_line(clickwheel.center, geneva_driver, Color("f9e2af"), 6.0)
	draw_line(geneva_driver, geneva.center, Color("45475a"), 2.0)

func _draw_geneva(rotor: Rotor) -> void:
	var center: Vector2 = rotor.center
	draw_circle(center, rotor.display_radius * 0.24, Color("0f1118"))
	for i in range(4):
		var angle: float = rotor.theta + MechanismModel.TAU_F * float(i) / 4.0
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var tangent: Vector2 = Vector2(-dir.y, dir.x)
		var a: Vector2 = center + dir * 16.0 - tangent * 10.0
		var b: Vector2 = center + dir * (rotor.display_radius - 8.0) - tangent * 10.0
		var c: Vector2 = center + dir * (rotor.display_radius - 8.0) + tangent * 10.0
		var d: Vector2 = center + dir * 16.0 + tangent * 10.0
		draw_colored_polygon(PackedVector2Array([a, b, c, d]), rotor.color)
	draw_arc(center, rotor.display_radius, 0.0, MechanismModel.TAU_F, 48, rotor.color.lightened(0.12), 8.0)
	draw_circle(center, 12.0, Color("11131b"))

func _draw_bell() -> void:
	var center: Vector2 = MechanismModel.BELL_CENTER
	var arc_start: float = PI * 0.14 + model.bell_angle * 0.18
	var arc_end: float = PI * 0.86 + model.bell_angle * 0.18
	draw_arc(center, 56.0, arc_start, arc_end, 48, Color("f9e2af"), 14.0)
	draw_line(center + Vector2(-42.0, 8.0), center + Vector2(42.0, 8.0), Color("f9e2af"), 14.0)
	draw_line(center + Vector2(0.0, -52.0), center + Vector2(0.0, -82.0), Color("c6a05b"), 6.0)
	var clapper: Vector2 = center + Vector2(sin(model.bell_angle) * 18.0, 36.0)
	draw_line(center + Vector2(0.0, 0.0), clapper, Color("f38ba8"), 4.0)
	draw_circle(clapper, 8.0, Color("eba0ac"))

func _draw_linkage(start: Vector2, ending: Vector2, color: Color, width: float) -> void:
	draw_line(start, ending, color, width)
	draw_circle(start, width * 0.7, color)
	draw_circle(ending, width * 0.7, color)

func _draw_clock_hand(center: Vector2, length: float, angle: float, color: Color, width: float) -> void:
	var tip: Vector2 = center + Vector2(cos(angle), sin(angle)) * length
	draw_line(center, tip, color, width)
	draw_circle(center, width * 0.8, color)

func _draw_debug_overlay() -> void:
	var sun: Rotor = model.rotors["sun"]
	var carrier: Rotor = model.rotors["carrier"]
	var ring: Rotor = model.rotors["ring"]
	var dial: Rotor = model.rotors["dial"]
	var flywheel: Rotor = model.rotors["flywheel"]
	var escapement: Rotor = model.rotors["escapement"]
	var balance: Rotor = model.rotors["balance"]
	var geneva: Rotor = model.rotors["geneva"]
	var stats: Array[String] = [
		"Clockwork epicyclic train + belt + cam + hammer + ratchet + Geneva",
		"sun w = %.3f | carrier w = %.3f | ring w = %.3f" % [sun.omega, carrier.omega, ring.omega],
		"dial w = %.3f | flywheel w = %.3f | belt slip = %.3f" % [dial.omega, flywheel.omega, model.last_belt_slip],
		"esc w = %.3f | bal t = %.3f w = %.3f" % [escapement.omega, balance.theta, balance.omega],
		"follower = %.1f | hammer = %.2f | bell w = %.2f" % [model.follower_height, model.hammer_angle, model.bell_omega],
		"click idx = %d | geneva t = %.2f | geneva step = %.1f" % [model.clickwheel_index, geneva.theta, model.last_geneva_step],
		"activity = %.2f | momentum = %.2f | max |w| = %.2f" % [model.activity_measure, model.momentum_score, model.max_abs_omega],
		"controls: space pause | up/down torque | left/right brake | d overlay | r reset",
	]
	var y := 24.0
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	for line in stats:
		draw_string(font, Vector2(26.0, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, Color("f0f0f0"))
		y += 24.0
