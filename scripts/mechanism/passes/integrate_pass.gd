class_name IntegratePass
extends RefCounted
## Time integration: the only pass that writes theta.
## Applies torque, damping, integrates, sanitizes.

const MAX_OMEGA := 120.0
const WRAP_SPAN := PI * 2.0 * 1000.0

var sanitize_ok := true

func execute(cm: CompiledMechanism, state: StateTables, forces: ForceTables,
		_events: EventTables, dt: float) -> void:
	sanitize_ok = true
	state.sim_time += dt

	for i in range(cm.rotor_count):
		# Apply accumulated torque
		state.omega[i] += dt * forces.torque[i] / cm.rotor_inertia[i]

		# Apply damping
		state.omega[i] *= max(0.0, 1.0 - cm.rotor_damping[i] * dt)

		# Integrate position
		state.theta[i] = wrapf(state.theta[i] + state.omega[i] * dt, -WRAP_SPAN, WRAP_SPAN)

		# Sanitize
		if is_nan(state.theta[i]) or is_inf(state.theta[i]):
			state.theta[i] = 0.0
			sanitize_ok = false
		if is_nan(state.omega[i]) or is_inf(state.omega[i]):
			state.omega[i] = 0.0
			sanitize_ok = false

		# Clamp
		state.omega[i] = clampf(state.omega[i], -MAX_OMEGA, MAX_OMEGA)
		state.max_seen_omega[i] = max(state.max_seen_omega[i], abs(state.omega[i]))
