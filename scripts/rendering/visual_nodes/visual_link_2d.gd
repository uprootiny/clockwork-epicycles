extends Node2D

var style: BlueprintStyle
var data: Dictionary = {}
var renderer: Node2D

func _draw() -> void:
	if renderer == null or style == null:
		return

	var a_id: String = str(data.get("a", ""))
	var b_id: String = str(data.get("b", ""))
	var kind: String = str(data.get("kind", "link"))

	var a_node: Node2D = renderer.get_rotor_node(a_id)
	var b_node: Node2D = renderer.get_rotor_node(b_id)

	if a_node == null or b_node == null:
		return

	var a: Vector2 = a_node.position
	var b: Vector2 = b_node.position

	match kind:
		"gear_mesh":
			_draw_mesh_link(a, b, style.line_color, style.major_line_width)
		"belt":
			_draw_belt_link(a, b, style.accent_color)
		"linkage":
			_draw_rod(a, b, style.secondary_line_color, style.minor_line_width)
		_:
			_draw_dashed(a, b, style.secondary_line_color)

func _draw_mesh_link(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(a, b, color, width)
	var mid: Vector2 = a.lerp(b, 0.5)
	draw_circle(mid, 3.0, color)

func _draw_belt_link(a: Vector2, b: Vector2, color: Color) -> void:
	var mid: Vector2 = a.lerp(b, 0.5)
	var normal: Vector2 = (b - a).orthogonal().normalized()
	var control: Vector2 = mid + normal * 20.0

	var points := PackedVector2Array()
	var steps := 24
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var u: float = 1.0 - t
		var p: Vector2 = u * u * a + 2.0 * u * t * control + t * t * b
		points.append(p)

	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], color, style.minor_line_width)

func _draw_rod(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(a, b, color, width)
	draw_circle(a, 4.0, color)
	draw_circle(b, 4.0, color)

func _draw_dashed(a: Vector2, b: Vector2, color: Color) -> void:
	var segments := 12
	for i in range(segments):
		if i % 2 == 0:
			var t0: float = float(i) / float(segments)
			var t1: float = float(i + 1) / float(segments)
			draw_line(a.lerp(b, t0), a.lerp(b, t1), color, 1.0)
