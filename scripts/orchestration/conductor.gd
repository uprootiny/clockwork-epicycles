class_name Conductor
extends RefCounted
## The Conductor modulates the mechanism through controlled influences,
## not direct animation. It reads mechanical state and derives orchestration
## signals that govern when events may fire and how the system breathes.
##
## Design: "every event is downstream of stored tension."

const TAU_F := PI * 2.0

# Orchestration signals (read by rendering and event logic)
var phase_main := 0.0          # primary rotational phase [0, TAU]
var phase_balance := 0.0       # balance oscillation phase [-1, 1]
var stored_energy := 0.0       # accumulated energy above baseline
var event_readiness := 0.0     # 0 = locked out, 1 = primed for release
var quietness_index := 0.0     # 1 = calm, 0 = agitated
var coherence := 0.0           # how aligned are the subsystems [0, 1]
var breathing_phase := 0.0     # slow modulation [0, 1]

# Event gates
var intermittent_permitted := false
var last_event_time := -10.0
var min_event_interval := 4.0  # seconds between ceremonial events

# Internal accumulators
var _energy_baseline := 0.0
var _energy_ewma := 0.0
var _activity_ewma := 0.0
var _quietness_ewma := 1.0
var _phase_history: PackedFloat64Array = PackedFloat64Array()
var _sim_time := 0.0

func update(snapshot: Dictionary, dt: float) -> void:
	_sim_time += dt

	# Extract mechanical state
	var sun_omega: float = abs(float(snapshot.get("sun", {}).get("omega", 0.0)))
	var carrier_theta: float = float(snapshot.get("carrier", {}).get("theta", 0.0))
	var balance_theta: float = float(snapshot.get("balance", {}).get("theta", 0.0))
	var balance_omega: float = float(snapshot.get("balance", {}).get("omega", 0.0))
	var total_energy: float = float(snapshot.get("total_energy", 0.0))
	var constraint_error: float = float(snapshot.get("constraint_error", 0.0))

	# Phase signals
	phase_main = wrapf(carrier_theta, 0.0, TAU_F) / TAU_F
	phase_balance = clampf(balance_theta / 0.5, -1.0, 1.0)
	breathing_phase = 0.5 + 0.5 * sin(_sim_time * 0.15)

	# Energy tracking
	if _energy_baseline <= 0.001:
		_energy_baseline = max(total_energy, 1.0)
	_energy_ewma = lerpf(_energy_ewma, total_energy, 0.05 * dt)
	stored_energy = clampf((_energy_ewma - _energy_baseline * 0.6) / max(_energy_baseline, 0.001), 0.0, 2.0)

	# Activity/quietness
	var instant_activity: float = sun_omega + abs(balance_omega) * 0.3
	_activity_ewma = lerpf(_activity_ewma, instant_activity, 0.1 * dt)
	var target_quiet: float = clampf(1.0 - _activity_ewma / max(sun_omega + 1.0, 1.0), 0.0, 1.0)
	_quietness_ewma = lerpf(_quietness_ewma, target_quiet, 0.08 * dt)
	quietness_index = _quietness_ewma

	# Coherence: how close is the system to a phase alignment
	var phase_spread: float = abs(sin(carrier_theta * 3.0)) + abs(sin(balance_theta * 2.0))
	coherence = clampf(1.0 - phase_spread * 0.3, 0.0, 1.0)

	# Event readiness gate
	var time_since_event: float = _sim_time - last_event_time
	var cooldown_ok: bool = time_since_event > min_event_interval
	var energy_ok: bool = stored_energy > 0.3
	var phase_ok: bool = coherence > 0.5
	var quiet_ok: bool = quietness_index > 0.3
	var error_ok: bool = constraint_error < 6.0

	event_readiness = 0.0
	if cooldown_ok and energy_ok and error_ok:
		event_readiness = stored_energy * coherence * quietness_index
		if phase_ok and quiet_ok:
			event_readiness = clampf(event_readiness * 1.5, 0.0, 1.0)

	intermittent_permitted = event_readiness > 0.6

func record_event() -> void:
	last_event_time = _sim_time
	event_readiness = 0.0
	intermittent_permitted = false

func get_torque_envelope() -> float:
	## Returns a multiplier [0.6, 1.0] for drive torque.
	## Creates breathing: sustained → gentle ebb → sustained.
	return 0.8 + 0.2 * sin(_sim_time * 0.22 + 0.5)

func get_damping_modulation() -> float:
	## Slight damping variation for organic feel.
	return 1.0 + 0.08 * sin(_sim_time * 0.31)

func get_orchestration_snapshot() -> Dictionary:
	return {
		"phase_main": phase_main,
		"phase_balance": phase_balance,
		"stored_energy": stored_energy,
		"event_readiness": event_readiness,
		"quietness_index": quietness_index,
		"coherence": coherence,
		"breathing_phase": breathing_phase,
		"intermittent_permitted": intermittent_permitted,
		"torque_envelope": get_torque_envelope(),
		"damping_modulation": get_damping_modulation(),
	}

## Beauty score: quantifies expressive quality of the current state.
func compute_beauty_score() -> float:
	var score := 0.0
	# Coherence rewards phase alignment
	score += coherence * 0.25
	# Layered timescales: balance and main should differ
	score += clampf(abs(phase_main - abs(phase_balance)), 0.0, 0.5) * 0.2
	# Sparse events are beautiful
	var event_sparsity: float = clampf((_sim_time - last_event_time) / min_event_interval, 0.0, 1.0)
	score += event_sparsity * 0.15
	# Bounded energy (not too hot, not dead)
	score += clampf(1.0 - abs(stored_energy - 0.5), 0.0, 1.0) * 0.2
	# Quietness contributes
	score += quietness_index * 0.1
	# Breathing phase near its peak is slightly more beautiful
	score += breathing_phase * 0.1
	return clampf(score, 0.0, 1.0)
