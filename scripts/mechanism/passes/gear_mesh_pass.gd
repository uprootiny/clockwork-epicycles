class_name GearMeshPass
extends RefCounted
## Computes gear mesh impulses over dense arrays.
## Reads: compiled geometry, state. Writes: forces, state (omega).

const EPSILON := 1e-9

func execute(cm: CompiledMechanism, state: StateTables, forces: ForceTables,
		_events: EventTables, _dt: float) -> void:
	for k in range(cm.mesh_count):
		var ai: int = cm.mesh_a[k]
		var bi: int = cm.mesh_b[k]
		var ci: int = cm.mesh_carrier[k]
		var ra: float = cm.rotor_radius[ai]
		var rb: float = cm.rotor_radius[bi]
		var sign_b: float = -1.0 if cm.mesh_internal[k] == 1 else 1.0

		var omega_c := 0.0
		if ci >= 0:
			omega_c = state.omega[ci]

		var c_dot: float = ra * (state.omega[ai] - omega_c) + sign_b * rb * (state.omega[bi] - omega_c)
		var denom: float = cm.mesh_denom[k]

		# Compliance factor derived from stiffness (higher stiffness = harder coupling)
		var compliance: float = clampf(cm.mesh_stiffness[k] / 1e5, 0.5, 1.0)
		var impulse: float = -compliance * c_dot / denom

		state.omega[ai] += (ra / cm.rotor_inertia[ai]) * impulse
		state.omega[bi] += (sign_b * rb / cm.rotor_inertia[bi]) * impulse

		if ci >= 0:
			var jc: float = -(ra + sign_b * rb)
			state.omega[ci] += (jc / cm.rotor_inertia[ci]) * impulse
