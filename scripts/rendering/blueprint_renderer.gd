class_name BlueprintRenderer
extends Node2D

@export var style: BlueprintStyle
@export var exploded_view: bool = false
@export var exploded_amount: float = 0.0
@export var show_debug_metrics: bool = true

var snapshot: BlueprintSnapshot
var _rotor_nodes: Dictionary = {}
var _link_nodes: Array = []
var _annotation_nodes: Array = []
var _grid_node: Node2D

func _ready() -> void:
	if style == null:
		style = BlueprintStyle.new()
	queue_redraw()

func set_snapshot(new_snapshot: BlueprintSnapshot) -> void:
	snapshot = new_snapshot
	_rebuild_scene()

func clear_snapshot() -> void:
	snapshot = null
	_clear_children()
	queue_redraw()

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
	_rotor_nodes.clear()
	_link_nodes.clear()
	_annotation_nodes.clear()
	_grid_node = null

func _rebuild_scene() -> void:
	_clear_children()

	if snapshot == null:
		return

	if style.show_grid:
		_grid_node = preload("res://scripts/rendering/visual_nodes/visual_grid_2d.gd").new()
		_grid_node.style = style
		add_child(_grid_node)

	for rotor_data in snapshot.rotors:
		var node: Node2D = preload("res://scripts/rendering/visual_nodes/visual_rotor_2d.gd").new()
		node.style = style
		node.data = rotor_data.duplicate(true)
		node.position = _exploded_position(rotor_data)
		add_child(node)
		var rid: String = str(rotor_data.get("id", ""))
		_rotor_nodes[rid] = node

	for link_data in snapshot.links:
		var node: Node2D = preload("res://scripts/rendering/visual_nodes/visual_link_2d.gd").new()
		node.style = style
		node.data = link_data.duplicate(true)
		node.renderer = self
		add_child(node)
		_link_nodes.append(node)

	for ann_data in snapshot.annotations:
		var node: Node2D = preload("res://scripts/rendering/visual_nodes/visual_annotation_2d.gd").new()
		node.style = style
		node.data = ann_data.duplicate(true)
		add_child(node)
		_annotation_nodes.append(node)

	queue_redraw()

func update_snapshot_data(new_snapshot: BlueprintSnapshot) -> void:
	if snapshot == null:
		set_snapshot(new_snapshot)
		return

	snapshot = new_snapshot

	for rotor_data in snapshot.rotors:
		var rid: String = str(rotor_data.get("id", ""))
		if _rotor_nodes.has(rid):
			var node: Node2D = _rotor_nodes[rid]
			node.data = rotor_data
			node.position = _exploded_position(rotor_data)
			node.queue_redraw()

	for node in _link_nodes:
		node.queue_redraw()

	queue_redraw()

func _draw() -> void:
	if style == null:
		return
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), style.background_color, true)

	if snapshot != null and show_debug_metrics:
		var text: String = "E=%.3f   C=%.4f" % [snapshot.energy, snapshot.constraint_error]
		var font: Font = ThemeDB.fallback_font
		if font != null:
			draw_string(font, Vector2(24, 28), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, style.accent_color)

func _exploded_position(rotor_data: Dictionary) -> Vector2:
	var base: Vector2 = rotor_data.get("position", Vector2.ZERO)
	if not exploded_view or exploded_amount <= 0.0:
		return base

	var layer: float = float(rotor_data.get("layer", 0))
	var offset: Vector2 = Vector2(0, -1).rotated(layer * 0.7 + 0.4) * style.exploded_offset_scale * exploded_amount
	return base + offset

func get_rotor_node(id: String) -> Node2D:
	return _rotor_nodes.get(id, null)
