extends Node2D

var style: BlueprintStyle
var data: Dictionary = {}

func _ready() -> void:
	position = data.get("position", Vector2.ZERO)

func _draw() -> void:
	if style == null or not style.show_labels:
		return

	var label: String = str(data.get("label", ""))
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	draw_string(font, Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_LEFT, -1, style.annotation_font_size, style.accent_color)
	draw_line(Vector2(0, 6), Vector2(120, 6), style.secondary_line_color, 1.0)
