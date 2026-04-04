extends Node2D

var style: BlueprintStyle
var from_pos: Vector2 = Vector2.ZERO
var to_pos: Vector2 = Vector2(100, 0)
var arrow_color: Color = Color.WHITE

func _draw() -> void:
	if style == null:
		return

	var dir: Vector2 = (to_pos - from_pos).normalized()
	var perp: Vector2 = dir.orthogonal()
	var head_size := 10.0

	draw_line(from_pos, to_pos, arrow_color, style.minor_line_width)
	draw_line(to_pos, to_pos - dir * head_size + perp * head_size * 0.5, arrow_color, style.minor_line_width)
	draw_line(to_pos, to_pos - dir * head_size - perp * head_size * 0.5, arrow_color, style.minor_line_width)
