class_name LightConductor
extends RefCounted
## Maps orchestration state to lighting parameters.
## Light as interpretation of state, not mere illumination.

# Lighting parameters (updated each frame)
var key_intensity := 0.8
var key_warmth := 0.0         # [0, 1] warm shift
var rim_intensity := 0.3
var ambient_rotation := 0.0   # slow environmental rotation (radians)
var bloom_intensity := 0.0
var vignette_strength := 0.15

# Internal
var _time := 0.0

func update(orch_snapshot: Dictionary, material_snapshot: Dictionary, dt: float) -> void:
	_time += dt

	var stored_energy: float = float(orch_snapshot.get("stored_energy", 0.0))
	var coherence: float = float(orch_snapshot.get("coherence", 0.0))
	var breathing: float = float(orch_snapshot.get("breathing_phase", 0.5))
	var torque_warmth: float = float(material_snapshot.get("torque_warmth", 0.0))
	var event_bloom: float = float(material_snapshot.get("event_bloom", 0.0))

	# Key light: brighter when system is energized, warmer with torque
	key_intensity = 0.6 + stored_energy * 0.15 + breathing * 0.05
	key_warmth = torque_warmth * 0.4

	# Rim light: stronger when coherent (alignment creates edge definition)
	rim_intensity = 0.2 + coherence * 0.15 + torque_warmth * 0.05

	# Slow ambient rotation for contemplative feel
	ambient_rotation = _time * 0.02

	# Bloom: minimal normally, pulses on events
	bloom_intensity = 0.02 + event_bloom * 0.12 + breathing * 0.01

	# Vignette: slightly stronger when quiet (draws focus inward)
	var quietness: float = float(orch_snapshot.get("quietness_index", 0.5))
	vignette_strength = 0.10 + quietness * 0.08

func get_key_color() -> Color:
	var cool := Color(0.85, 0.88, 0.95)
	var warm := Color(0.95, 0.85, 0.72)
	return cool.lerp(warm, key_warmth) * key_intensity

func get_rim_color() -> Color:
	return Color(0.95, 0.80, 0.65) * rim_intensity

func get_ambient_color() -> Color:
	var base := Color(0.06, 0.07, 0.10)
	var rotated := Color(
		0.06 + 0.01 * sin(ambient_rotation),
		0.07 + 0.01 * cos(ambient_rotation * 0.7),
		0.10 + 0.01 * sin(ambient_rotation * 1.3)
	)
	return rotated

func get_lighting_snapshot() -> Dictionary:
	return {
		"key_intensity": key_intensity,
		"key_warmth": key_warmth,
		"key_color": get_key_color(),
		"rim_intensity": rim_intensity,
		"rim_color": get_rim_color(),
		"ambient_color": get_ambient_color(),
		"bloom_intensity": bloom_intensity,
		"vignette_strength": vignette_strength,
	}
