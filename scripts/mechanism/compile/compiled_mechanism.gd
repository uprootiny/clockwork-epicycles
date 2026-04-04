class_name CompiledMechanism
extends RefCounted
## Compiled mechanism: immutable after construction.
## Compile strictly — dense arrays, integer indices, no runtime derivation.

var rotor_count: int = 0
var mesh_count: int = 0
var belt_count: int = 0
var escapement_count: int = 0

# Rotor tables (indexed by rotor index)
var rotor_name: PackedStringArray = PackedStringArray()
var rotor_inertia: PackedFloat64Array = PackedFloat64Array()
var rotor_radius: PackedFloat64Array = PackedFloat64Array()
var rotor_display_radius: PackedFloat64Array = PackedFloat64Array()
var rotor_damping: PackedFloat64Array = PackedFloat64Array()
var rotor_teeth: PackedInt32Array = PackedInt32Array()
var rotor_orbit_radius: PackedFloat64Array = PackedFloat64Array()
var rotor_orbit_phase: PackedFloat64Array = PackedFloat64Array()
var rotor_is_internal: PackedByteArray = PackedByteArray()

# Gear mesh tables (indexed by mesh index)
var mesh_a: PackedInt32Array = PackedInt32Array()
var mesh_b: PackedInt32Array = PackedInt32Array()
var mesh_carrier: PackedInt32Array = PackedInt32Array()  # -1 = no carrier
var mesh_internal: PackedByteArray = PackedByteArray()
var mesh_stiffness: PackedFloat64Array = PackedFloat64Array()
var mesh_damping: PackedFloat64Array = PackedFloat64Array()
var mesh_backlash: PackedFloat64Array = PackedFloat64Array()
# Precomputed: effective mass denominators
var mesh_denom: PackedFloat64Array = PackedFloat64Array()

# Belt tables
var belt_a: PackedInt32Array = PackedInt32Array()
var belt_b: PackedInt32Array = PackedInt32Array()
var belt_stiffness: PackedFloat64Array = PackedFloat64Array()
var belt_damping: PackedFloat64Array = PackedFloat64Array()
var belt_slack: PackedFloat64Array = PackedFloat64Array()

# Escapement tables
var esc_wheel: PackedInt32Array = PackedInt32Array()
var esc_balance: PackedInt32Array = PackedInt32Array()
var esc_engage_angle: PackedFloat64Array = PackedFloat64Array()
var esc_impulse_scale: PackedFloat64Array = PackedFloat64Array()

# Name lookup
var name_to_index: Dictionary = {}

func index_of(rotor_name_str: String) -> int:
	return name_to_index.get(rotor_name_str, -1)
