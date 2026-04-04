extends Node2D

var style: BlueprintStyle
var data: Dictionary = {}

func _draw() -> void:
	if style == null:
		return
	var radius: float = float(data.get("radius", 32.0))
	var theta: float = float(data.get("theta", 0.0))
	var omega: float = abs(float(data.get("omega", 0.0)))
	var kind: String = str(data.get("kind", "gear"))
	var teeth: int = int(data.get("teeth", 20))
	var glow: float = clampf(omega * style.glow_energy_scale, 0.0, 1.0)

	var main_color: Color = style.line_color.lerp(style.accent_color, glow)
	var secondary: Color = style.secondary_line_color

	if kind == "gear":
		_draw_gear(radius, teeth, theta, main_color, secondary)
	else:
		_draw_disc(radius, theta, main_color, secondary)

	_draw_shaft(main_color)
	_draw_axis_ticks(radius, theta, secondary)

	if style.show_motion_arrows and omega > 0.05:
		_draw_motion_arrow(radius, theta, float(data.get("omega", 0.0)), main_color)

func _draw_disc(radius: float, theta: float, main_color: Color, secondary: Color) -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, main_color, style.major_line_width)
	draw_arc(Vector2.ZERO, radius * 0.72, 0.0, TAU, 96, secondary, style.minor_line_width)
	var spoke_count := 6
	for i in range(spoke_count):
		var a: float = theta + TAU * float(i) / float(spoke_count)
		draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(a) * radius * 0.92, secondary, style.minor_line_width)

func _draw_gear(radius: float, teeth: int, theta: float, main_color: Color, secondary: Color) -> void:
	var pts := PackedVector2Array()
	var tooth_depth: float = style.gear_tooth_depth
	var outer: float = radius
	var inner: float = max(radius - tooth_depth, 4.0)

	for i in range(teeth * 2):
		var t: float = theta + TAU * float(i) / float(teeth * 2)
		var r: float = outer if i % 2 == 0 else inner
		pts.append(Vector2.RIGHT.rotated(t) * r)
	pts.append(pts[0])

	for i in range(pts.size() - 1):
		draw_line(pts[i], pts[i + 1], main_color, style.minor_line_width)

	draw_arc(Vector2.ZERO, radius * 0.68, 0.0, TAU, 96, secondary, style.minor_line_width)

	var spoke_count: int = max(3, mini(8, teeth / 4))
	for i in range(spoke_count):
		var a: float = theta + TAU * float(i) / float(spoke_count)
		draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(a) * radius * 0.64, secondary, style.minor_line_width)

func _draw_shaft(main_color: Color) -> void:
	draw_circle(Vector2.ZERO, style.shaft_radius, main_color)
	draw_arc(Vector2.ZERO, style.shaft_radius + 3.0, 0.0, TAU, 48, main_color, 1.0)

func _draw_axis_ticks(radius: float, theta: float, secondary: Color) -> void:
	for i in range(4):
		var a: float = theta + TAU * float(i) / 4.0
		var p1: Vector2 = Vector2.RIGHT.rotated(a) * (radius + 4.0)
		var p2: Vector2 = Vector2.RIGHT.rotated(a) * (radius + 12.0)
		draw_line(p1, p2, secondary, 1.0)

func _draw_motion_arrow(radius: float, theta: float, omega_signed: float, color: Color) -> void:
	var arrow_radius: float = radius + 18.0
	var arrow_span: float = clampf(abs(omega_signed) * 0.3, 0.2, 1.2)
	var direction: float = sign(omega_signed)
	var start_angle: float = theta
	var end_angle: float = theta + arrow_span * direction
	var arrow_color: Color = color * Color(1, 1, 1, 0.6)

	draw_arc(Vector2.ZERO, arrow_radius, start_angle, end_angle, 24, arrow_color, style.minor_line_width)

	var tip: Vector2 = Vector2.RIGHT.rotated(end_angle) * arrow_radius
	var perp: Vector2 = Vector2.RIGHT.rotated(end_angle + PI / 2.0 * direction) * 8.0
	var back: Vector2 = Vector2.RIGHT.rotated(end_angle - 0.15 * direction) * arrow_radius
	draw_line(tip, back + perp, arrow_color, style.minor_line_width)
	draw_line(tip, back - perp, arrow_color, style.minor_line_width)
