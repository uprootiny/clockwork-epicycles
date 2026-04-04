class_name EventTables
extends RefCounted
## Discrete event flags. Rebuilt each step.

var escapement_impulse: PackedFloat64Array = PackedFloat64Array()
var ratchet_click: PackedByteArray = PackedByteArray()
var impact_fire: PackedByteArray = PackedByteArray()

func init_from(cm: CompiledMechanism) -> void:
	escapement_impulse.resize(cm.escapement_count)
	ratchet_click.resize(1)
	impact_fire.resize(1)
	clear()

func clear() -> void:
	for i in range(escapement_impulse.size()):
		escapement_impulse[i] = 0.0
	for i in range(ratchet_click.size()):
		ratchet_click[i] = 0
	for i in range(impact_fire.size()):
		impact_fire[i] = 0
