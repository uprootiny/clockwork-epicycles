class_name MechanismToBlueprintAdapter
extends RefCounted

const MeshConstraintClass = preload("res://scripts/constraints/mesh_constraint.gd")
const BeltConstraintClass = preload("res://scripts/constraints/belt_constraint.gd")
const EscapementConstraintClass = preload("res://scripts/constraints/escapement_constraint.gd")

func build_snapshot(model: RefCounted) -> BlueprintSnapshot:
	var snap := BlueprintSnapshot.new()

	for rotor_name in model.rotors:
		var rotor: RefCounted = model.rotors[rotor_name]
		snap.rotors.append({
			"id": rotor.name,
			"theta": rotor.theta,
			"omega": rotor.omega,
			"radius": rotor.display_radius,
			"position": rotor.center,
			"layer": _layer_for_rotor(rotor.name),
			"kind": "gear",
			"teeth": rotor.tooth_count,
		})

	for c in model.constraints:
		var link_data: Dictionary = _constraint_to_link(c)
		if not link_data.is_empty():
			snap.links.append(link_data)

	snap.annotations = _build_annotations()
	snap.energy = model.total_energy()
	snap.constraint_error = model.get_constraint_error()

	return snap

func _constraint_to_link(c: RefCounted) -> Dictionary:
	if c is MeshConstraint:
		return {
			"id": "mesh_%s_%s" % [c.a, c.b],
			"a": c.a,
			"b": c.b,
			"kind": "gear_mesh",
		}
	elif c is BeltConstraint:
		return {
			"id": "belt_%s_%s" % [c.a, c.b],
			"a": c.a,
			"b": c.b,
			"kind": "belt",
		}
	elif c is EscapementConstraint:
		return {
			"id": "esc_%s_%s" % [c.wheel, c.balance],
			"a": c.wheel,
			"b": c.balance,
			"kind": "linkage",
		}
	return {}

func _layer_for_rotor(rotor_name: String) -> int:
	match rotor_name:
		"sun": return 0
		"carrier": return 0
		"planet_a", "planet_b": return 1
		"ring": return 0
		"dial": return 2
		"escapement": return 2
		"balance": return 3
		"flywheel": return 3
		"clickwheel": return 4
		"geneva": return 4
	return 0

func _build_annotations() -> Array:
	return [
		{
			"label": "Epicyclic core",
			"position": Vector2(32, 48),
		},
		{
			"label": "Constraint network active",
			"position": Vector2(32, 76),
		},
	]
