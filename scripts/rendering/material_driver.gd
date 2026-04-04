class_name MaterialDriver
extends RefCounted
## Maps mechanical state to visual parameters.
## Rendering consumes these; it never invents motion.
##
## Design: "every visual accent is downstream of state."

# Material palette — restrained, intentional
const BRASS_WARM := Color("d4a84b")
const BRASS_COOL := Color("a08838")
const STEEL_DARK := Color("3a3e48")
const STEEL_LIGHT := Color("6b7080")
const ENAMEL := Color("e8e2d4")
const GLASS_SMOKE := Color("1a2030")
const ACCENT_AMBER := Color("f5a623")
const ACCENT_CYAN := Color("7ec8d9")
const ACCENT_DIM_RED := Color("8b3a3a")

# Derived visual parameters (updated each frame)
var torque_warmth := 0.0        # [0, 1] brass warmth from torque
var constraint_stress := 0.0    # [0, 1] contour emphasis
var phase_harmony := 0.0        # [0, 1] how synchronized subsystems are
var event_bloom := 0.0          # [0, 1] transient pulse from events
var breathing_glow := 0.0       # [0, 1] slow ambient modulation
var energy_luminance := 0.0     # [0, 1] overall brightness from energy

# Event accent state
var _event_bloom_timer := 0.0
var _event_bloom_duration := 1.2

func update(mech_snapshot: Dictionary, orch_snapshot: Dictionary, dt: float) -> void:
	# Torque → warmth
	var sun_omega: float = abs(float(mech_snapshot.get("sun", {}).get("omega", 0.0)))
	var drive_torque: float = float(mech_snapshot.get("drive_torque", 40.0))
	var instantaneous_power: float = sun_omega * drive_torque
	torque_warmth = clampf(instantaneous_power / 80.0, 0.0, 1.0)

	# Constraint error → stress emphasis
	var error: float = float(mech_snapshot.get("constraint_error", 0.0))
	constraint_stress = clampf(error / 6.0, 0.0, 1.0)

	# Phase coherence → harmony
	phase_harmony = float(orch_snapshot.get("coherence", 0.0))

	# Breathing
	breathing_glow = float(orch_snapshot.get("breathing_phase", 0.5))

	# Energy → base luminance
	var stored: float = float(orch_snapshot.get("stored_energy", 0.0))
	energy_luminance = clampf(stored * 0.5, 0.0, 0.8)

	# Event bloom decay
	if _event_bloom_timer > 0.0:
		_event_bloom_timer -= dt
		event_bloom = clampf(_event_bloom_timer / _event_bloom_duration, 0.0, 1.0)
		# Smooth falloff
		event_bloom = event_bloom * event_bloom * (3.0 - 2.0 * event_bloom)
	else:
		event_bloom = 0.0

func trigger_event_bloom() -> void:
	_event_bloom_timer = _event_bloom_duration

func get_brass_color() -> Color:
	return BRASS_COOL.lerp(BRASS_WARM, torque_warmth)

func get_steel_color() -> Color:
	return STEEL_DARK.lerp(STEEL_LIGHT, constraint_stress * 0.3)

func get_accent_color() -> Color:
	if event_bloom > 0.1:
		return ACCENT_AMBER.lerp(Color.WHITE, event_bloom * 0.3)
	return ACCENT_AMBER * Color(1, 1, 1, energy_luminance * 0.5 + 0.5)

func get_edge_glow_intensity() -> float:
	return 0.02 + torque_warmth * 0.08 + event_bloom * 0.15 + breathing_glow * 0.03

func get_contour_width() -> float:
	return 1.0 + constraint_stress * 2.0

func get_ambient_tint() -> Color:
	var base := Color(0.06, 0.08, 0.12)
	var warm_shift := Color(0.03, 0.01, -0.01) * torque_warmth
	var harmony_shift := Color(0.0, 0.01, 0.02) * phase_harmony
	return base + warm_shift + harmony_shift

func get_visual_snapshot() -> Dictionary:
	return {
		"torque_warmth": torque_warmth,
		"constraint_stress": constraint_stress,
		"phase_harmony": phase_harmony,
		"event_bloom": event_bloom,
		"breathing_glow": breathing_glow,
		"energy_luminance": energy_luminance,
		"brass_color": get_brass_color(),
		"accent_color": get_accent_color(),
		"edge_glow": get_edge_glow_intensity(),
		"contour_width": get_contour_width(),
	}
