class_name ForceTables
extends RefCounted
## Scratch buffers for force accumulation. Rebuilt each step.

var torque: PackedFloat64Array = PackedFloat64Array()

func init_from(cm: CompiledMechanism) -> void:
	torque.resize(cm.rotor_count)
	clear()

func clear() -> void:
	for i in range(torque.size()):
		torque[i] = 0.0
