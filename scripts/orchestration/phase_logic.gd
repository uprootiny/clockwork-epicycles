class_name PhaseLogic
extends RefCounted
## Phase analysis for orchestration decisions.
## Determines when subsystems align and when events should fire.

const TAU_F := PI * 2.0

## Check if two angular phases are within a window of alignment.
static func phases_aligned(theta_a: float, theta_b: float, window: float) -> bool:
	var diff: float = wrapf(theta_a - theta_b, -PI, PI)
	return abs(diff) < window

## Compute phase diversity: how spread out are N phase values.
## Returns 0 for perfect alignment, 1 for maximum spread.
static func phase_diversity(phases: PackedFloat64Array) -> float:
	if phases.size() < 2:
		return 0.0
	var sum_cos := 0.0
	var sum_sin := 0.0
	for p in phases:
		sum_cos += cos(p)
		sum_sin += sin(p)
	var n: float = float(phases.size())
	var r: float = sqrt(sum_cos * sum_cos + sum_sin * sum_sin) / n
	return 1.0 - r

## Detect zero-crossing of an oscillator (for event timing).
static func zero_crossing(theta_prev: float, theta_curr: float) -> bool:
	return theta_prev * theta_curr < 0.0 and abs(theta_curr - theta_prev) < PI

## Compute a "dwell ratio": fraction of recent time spent near rest.
## Higher values mean the system has been calm.
static func dwell_ratio(omega_history: PackedFloat64Array, threshold: float) -> float:
	if omega_history.size() == 0:
		return 1.0
	var dwell_count := 0
	for omega in omega_history:
		if abs(omega) < threshold:
			dwell_count += 1
	return float(dwell_count) / float(omega_history.size())
