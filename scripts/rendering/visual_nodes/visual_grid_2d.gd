extends Node2D

var style: BlueprintStyle

func _draw() -> void:
	if style == null:
		return
	var rect: Rect2 = get_viewport_rect()
	var step := 48.0
	var grid_color: Color = style.secondary_line_color * Color(1, 1, 1, 0.12)

	var x := 0
	while x < int(rect.size.x):
		draw_line(Vector2(x, 0), Vector2(x, rect.size.y), grid_color, 1.0)
		x += int(step)

	var y := 0
	while y < int(rect.size.y):
		draw_line(Vector2(0, y), Vector2(rect.size.x, y), grid_color, 1.0)
		y += int(step)
