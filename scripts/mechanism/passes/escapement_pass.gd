class_name EscapementPass
extends RefCounted
## Escapement event pass: lock/unlock transitions and impulses.

const EPSILON := 1e-9

func execute(cm: CompiledMechanism, state: StateTables, _forces: ForceTables,
		events: EventTables, _dt: float) -> void:
	for k in range(cm.escapement_count):
		var wi: int = cm.esc_wheel[k]
		var bi: int = cm.esc_balance[k]
		var engage_angle: float = cm.esc_engage_angle[k]
		var impulse_scale: float = cm.esc_impulse_scale[k]

		var gate: float = clampf(1.0 - abs(state.theta[bi]) / engage_angle, 0.0, 1.0)
		var engage: float = gate * gate

		if engage <= 0.001:
			events.escapement_impulse[k] = 0.0
			continue

		var coupling := 0.42
		var c_dot: float = state.omega[wi] + coupling * state.omega[bi]
		var denom: float = 1.0 / cm.rotor_inertia[wi] + (coupling * coupling) / cm.rotor_inertia[bi]
		if denom <= EPSILON:
			events.escapement_impulse[k] = 0.0
			continue

		var impulse: float = -impulse_scale * engage * c_dot / denom
		state.omega[wi] += impulse / cm.rotor_inertia[wi]
		state.omega[bi] += coupling * impulse / cm.rotor_inertia[bi]

		var directional: float = -state.theta[bi]
		if abs(directional) <= EPSILON:
			directional = -state.omega[wi]
		var tick: float = 0.42 * engage * sign(directional)
		state.omega[bi] += tick / cm.rotor_inertia[bi]
		state.omega[wi] -= tick * 0.68 / cm.rotor_inertia[wi]
		events.escapement_impulse[k] = tick
