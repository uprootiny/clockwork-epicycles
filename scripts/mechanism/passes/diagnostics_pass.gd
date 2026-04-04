class_name DiagnosticsPass
extends RefCounted
## Diagnostics: read-only analysis. Never mutates physics state.

var total_kinetic_energy: float = 0.0
var max_omega: float = 0.0
var mesh_error: float = 0.0
var belt_error: float = 0.0
var total_error: float = 0.0

func execute(cm: CompiledMechanism, state: StateTables, _forces: ForceTables,
		_events: EventTables, _dt: float) -> void:
	total_kinetic_energy = 0.0
	max_omega = 0.0
	mesh_error = 0.0
	belt_error = 0.0

	# Energy and max omega
	for i in range(cm.rotor_count):
		total_kinetic_energy += 0.5 * cm.rotor_inertia[i] * state.omega[i] * state.omega[i]
		max_omega = max(max_omega, abs(state.omega[i]))

	# Mesh constraint error
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
		mesh_error += abs(ra * (state.omega[ai] - omega_c) + sign_b * rb * (state.omega[bi] - omega_c))

	# Belt constraint error
	for k in range(cm.belt_count):
		belt_error += abs(state.belt_slip[k])

	total_error = mesh_error + belt_error

func get_report() -> Dictionary:
	return {
		"kinetic_energy": total_kinetic_energy,
		"max_omega": max_omega,
		"mesh_error": mesh_error,
		"belt_error": belt_error,
		"total_error": total_error,
	}
