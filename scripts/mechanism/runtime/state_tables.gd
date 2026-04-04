class_name StateTables
extends RefCounted
## Mutable state: only integration pass writes theta/omega.

var theta: PackedFloat64Array = PackedFloat64Array()
var omega: PackedFloat64Array = PackedFloat64Array()
var max_seen_omega: PackedFloat64Array = PackedFloat64Array()
var belt_slip: PackedFloat64Array = PackedFloat64Array()
var sim_time: float = 0.0

func init_from(cm: CompiledMechanism, spec: MechanismSpec) -> void:
	var n: int = cm.rotor_count
	theta.resize(n)
	omega.resize(n)
	max_seen_omega.resize(n)
	belt_slip.resize(cm.belt_count)
	for i in range(n):
		theta[i] = 0.0
		omega[i] = 0.0
		max_seen_omega[i] = 0.0
		var rname: String = cm.rotor_name[i]
		if spec.initial_state.has(rname):
			var init: Dictionary = spec.initial_state[rname]
			theta[i] = float(init.get("theta", 0.0))
			omega[i] = float(init.get("omega", 0.0))
	for k in range(cm.belt_count):
		belt_slip[k] = 0.0
	sim_time = 0.0
