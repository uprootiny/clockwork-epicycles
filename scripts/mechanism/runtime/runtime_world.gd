class_name RuntimeWorld
extends RefCounted
## Orchestrates compiled mechanism simulation via ordered passes.
## Author richly. Compile strictly. Simulate densely.

var compiled: CompiledMechanism
var state: StateTables
var forces: ForceTables
var events: EventTables

var gear_mesh_pass := GearMeshPass.new()
var belt_pass := BeltPass.new()
var escapement_pass := EscapementPass.new()
var integrate_pass := IntegratePass.new()
var diagnostics_pass := DiagnosticsPass.new()

var solver_iterations := 20
var microsteps := 4
var drive_torque := 40.0
var brake_fraction := 0.0
var paused := false

func init_from_spec(spec: MechanismSpec) -> void:
	var compiler := MechanismCompiler.new()
	compiled = compiler.compile(spec)
	state = StateTables.new()
	state.init_from(compiled, spec)
	forces = ForceTables.new()
	forces.init_from(compiled)
	events = EventTables.new()
	events.init_from(compiled)

func step(delta: float) -> void:
	if paused:
		return
	var substeps: int = max(microsteps, 1)
	var h: float = delta / float(substeps)
	for _i in range(substeps):
		_step_once(h)

func _step_once(dt: float) -> void:
	# Clear scratch buffers
	forces.clear()
	events.clear()

	# Apply external drives
	_apply_drives(dt)

	# Ordered passes
	for _iter in range(solver_iterations):
		gear_mesh_pass.execute(compiled, state, forces, events, dt)
		belt_pass.execute(compiled, state, forces, events, dt)

	escapement_pass.execute(compiled, state, forces, events, dt)
	integrate_pass.execute(compiled, state, forces, events, dt)
	diagnostics_pass.execute(compiled, state, forces, events, dt)

func _apply_drives(dt: float) -> void:
	var sun_i: int = compiled.index_of("sun")
	var ring_i: int = compiled.index_of("ring")
	var carrier_i: int = compiled.index_of("carrier")
	var balance_i: int = compiled.index_of("balance")

	if sun_i >= 0:
		var spring_target: float = 1.1 + 0.2 * sin(state.sim_time * 0.33)
		var spring_ext: float = lerpf(1.25, spring_target, 0.18 * dt)
		forces.torque[sun_i] += drive_torque * spring_ext
		forces.torque[sun_i] += -8.6 * (state.theta[sun_i] - (-0.55)) * 0.08

	if ring_i >= 0:
		var ring_sign := 0.0
		if abs(state.omega[ring_i]) > 1e-6:
			ring_sign = sign(state.omega[ring_i])
		forces.torque[ring_i] += -1.9 * state.omega[ring_i] - 12.0 * brake_fraction * ring_sign

	if carrier_i >= 0:
		forces.torque[carrier_i] += -4.4 * state.omega[carrier_i]

	if balance_i >= 0:
		forces.torque[balance_i] += -8.2 * state.theta[balance_i] - 0.52 * state.omega[balance_i]

	# Additional damping loads
	var dial_i: int = compiled.index_of("dial")
	var flywheel_i: int = compiled.index_of("flywheel")
	var clickwheel_i: int = compiled.index_of("clickwheel")
	var geneva_i: int = compiled.index_of("geneva")

	if dial_i >= 0:
		forces.torque[dial_i] += -0.8 * state.omega[dial_i]
	if flywheel_i >= 0:
		forces.torque[flywheel_i] += -0.22 * state.omega[flywheel_i]
	if clickwheel_i >= 0:
		forces.torque[clickwheel_i] += -0.05 * state.omega[clickwheel_i]
	if geneva_i >= 0:
		forces.torque[geneva_i] += -0.18 * state.omega[geneva_i]

func get_diagnostics() -> Dictionary:
	return diagnostics_pass.get_report()
