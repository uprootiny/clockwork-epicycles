class_name BeltPass
extends RefCounted
## Belt tension pass: compliant coupling with slip model.

const EPSILON := 1e-9

func execute(cm: CompiledMechanism, state: StateTables, forces: ForceTables,
		_events: EventTables, dt: float) -> void:
	for k in range(cm.belt_count):
		var ai: int = cm.belt_a[k]
		var bi: int = cm.belt_b[k]
		var ra: float = cm.rotor_radius[ai]
		var rb: float = cm.rotor_radius[bi]
		var ia: float = cm.rotor_inertia[ai]
		var ib: float = cm.rotor_inertia[bi]

		var slip: float = ra * state.omega[ai] - rb * state.omega[bi]
		state.belt_slip[k] = slip

		var max_slip := 5.0
		var tension: float = clampf(1.0 - abs(slip) / max(max_slip, EPSILON), 0.18, 1.0)
		var denom: float = (ra * ra) / ia + (rb * rb) / ib
		if denom <= EPSILON:
			continue

		var stiff_norm: float = cm.belt_stiffness[k] / 500.0
		var impulse: float = -0.62 * stiff_norm * tension * slip / denom

		state.omega[ai] += (ra / ia) * impulse
		state.omega[bi] -= (rb / ib) * impulse

		var ratio: float = ra / rb
		state.omega[bi] = lerpf(state.omega[bi], state.omega[ai] * ratio, 0.08 * dt)
