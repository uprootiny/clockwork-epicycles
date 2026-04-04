class_name Envelopes
extends RefCounted
## Temporal envelopes for smooth orchestration transitions.
## Each envelope is a function of time that shapes intensity.

## Attack-sustain-decay envelope for event accents.
static func asd(t: float, attack: float, sustain: float, decay: float) -> float:
	if t < 0.0:
		return 0.0
	if t < attack:
		return t / attack
	var post_attack: float = t - attack
	if post_attack < sustain:
		return 1.0
	var post_sustain: float = post_attack - sustain
	if post_sustain < decay:
		return 1.0 - post_sustain / decay
	return 0.0

## Smooth pulse: rises and falls once over duration.
static func pulse(t: float, duration: float) -> float:
	if t < 0.0 or t > duration:
		return 0.0
	var phase: float = t / duration
	return sin(phase * PI)

## Breathing: continuous sine modulation.
static func breathe(time: float, period: float, depth: float) -> float:
	return 1.0 - depth * 0.5 * (1.0 - cos(time * PI * 2.0 / period))

## Warmth ramp: maps torque transmission to warmth [0, 1].
static func torque_warmth(torque: float, nominal: float) -> float:
	return clampf(torque / max(nominal, 0.001), 0.0, 1.0)

## Stress emphasis: maps constraint error to line emphasis.
static func stress_emphasis(error: float, threshold: float) -> float:
	return clampf(error / max(threshold, 0.001), 0.0, 1.0)
