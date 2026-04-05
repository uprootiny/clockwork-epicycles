class_name GearGeometry
extends RefCounted
## All gear geometry from tooth count + module. Nothing else.
##
##   module (m) = pitch_diameter / teeth
##   pitch_radius = m * N / 2
##   base_radius = pitch_radius * cos(pressure_angle)
##   addendum = m
##   dedendum = 1.25 * m
##   pressure_angle = 20° (standard involute)

const PA: float = 0.34907  # 20° in radians
const COS_PA: float = 0.93969
const SIN_PA: float = 0.34202

var teeth: int
var module: float
var is_internal: bool
var pitch_radius: float
var base_radius: float
var outer_radius: float
var root_radius: float
var circular_pitch: float

func _init(p_teeth: int, p_module: float, p_internal: bool = false) -> void:
	teeth = max(p_teeth, 4)
	module = max(p_module, 0.0001)
	is_internal = p_internal
	pitch_radius = module * float(teeth) / 2.0
	base_radius = pitch_radius * COS_PA
	if is_internal:
		outer_radius = pitch_radius - module
		root_radius = pitch_radius + 1.25 * module
	else:
		outer_radius = pitch_radius + module
		root_radius = max(pitch_radius - 1.25 * module, module)
	circular_pitch = PI * module

func disc_inertia(mass: float) -> float:
	return 0.5 * mass * pitch_radius * pitch_radius

func ring_inertia(mass: float, inner_frac: float = 0.7) -> float:
	var r_in: float = pitch_radius * inner_frac
	return 0.5 * mass * (pitch_radius * pitch_radius + r_in * r_in)

func contact_ratio_with(other: GearGeometry) -> float:
	# Length of path of contact / base pitch
	var ra_a: float = outer_radius if not is_internal else root_radius
	var ra_b: float = other.outer_radius if not other.is_internal else other.root_radius
	var term_a: float = max(ra_a * ra_a - base_radius * base_radius, 0.0)
	var term_b: float = max(ra_b * ra_b - other.base_radius * other.base_radius, 0.0)
	var center_dist: float
	if is_internal or other.is_internal:
		center_dist = abs(pitch_radius - other.pitch_radius)
	else:
		center_dist = pitch_radius + other.pitch_radius
	var contact_length: float = sqrt(term_a) + sqrt(term_b) - center_dist * SIN_PA
	var base_pitch: float = circular_pitch * COS_PA
	if base_pitch < 0.0001:
		return 0.0
	return abs(contact_length) / base_pitch

static func ratio(teeth_a: int, teeth_b: int) -> float:
	return float(teeth_a) / float(teeth_b)
