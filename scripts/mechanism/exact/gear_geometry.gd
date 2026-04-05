class_name GearGeometry
extends RefCounted
## Derives all gear geometry from first principles.
## Input: tooth count + module. Everything else follows.
##
## Terminology:
##   module (m) = reference diameter / tooth count
##   pitch radius = m * N / 2
##   base radius = pitch_radius * cos(pressure_angle)
##   addendum = m (tooth tip above pitch circle)
##   dedendum = 1.25 * m (tooth root below pitch circle)
##   pressure angle = 20° standard (involute profile)
##
## For a meshing pair to work:
##   - same module
##   - center distance = (r_a + r_b) for external, (r_a - r_b) for internal

const PRESSURE_ANGLE: float = deg_to_rad(20.0)  # standard involute
const COS_PA: float = 0.9397  # cos(20°)
const SIN_PA: float = 0.3420  # sin(20°)
const TAN_PA: float = 0.3640  # tan(20°)

var teeth: int
var module: float
var pitch_radius: float
var base_radius: float
var outer_radius: float  # addendum circle
var root_radius: float   # dedendum circle
var tooth_thickness: float  # arc length at pitch circle
var circular_pitch: float
var is_internal: bool

func _init(p_teeth: int, p_module: float, p_internal: bool = false) -> void:
	teeth = max(p_teeth, 4)
	module = max(p_module, 0.001)
	is_internal = p_internal
	pitch_radius = module * float(teeth) / 2.0
	base_radius = pitch_radius * COS_PA
	if is_internal:
		outer_radius = pitch_radius - module  # internal: tips point inward
		root_radius = pitch_radius + 1.25 * module
	else:
		outer_radius = pitch_radius + module
		root_radius = pitch_radius - 1.25 * module
	root_radius = max(root_radius, 0.001)
	circular_pitch = PI * module
	tooth_thickness = circular_pitch / 2.0

## Moment of inertia for a solid disc of given mass
func disc_inertia(mass: float) -> float:
	return 0.5 * mass * pitch_radius * pitch_radius

## Moment of inertia for a ring (annular) of given mass
func ring_inertia(mass: float, inner_frac: float = 0.7) -> float:
	var r_inner: float = pitch_radius * inner_frac
	return 0.5 * mass * (pitch_radius * pitch_radius + r_inner * r_inner)

## Contact ratio: how many teeth are in contact simultaneously
## Must be > 1.0 for continuous transmission
func contact_ratio_with(other: GearGeometry) -> float:
	var a_a: float = sqrt(outer_radius * outer_radius - base_radius * base_radius)
	var a_b: float = sqrt(other.outer_radius * other.outer_radius - other.base_radius * other.base_radius)
	var center_dist: float = pitch_radius + other.pitch_radius
	if other.is_internal:
		center_dist = abs(pitch_radius - other.pitch_radius)
	var length_of_action: float = a_a + a_b - center_dist * SIN_PA
	var base_pitch: float = PI * module * COS_PA
	return length_of_action / base_pitch

## Exact gear ratio (tooth count ratio, no approximation)
static func ratio(teeth_a: int, teeth_b: int) -> float:
	return float(teeth_a) / float(teeth_b)

## Center distance for external mesh
static func center_distance_external(geo_a: GearGeometry, geo_b: GearGeometry) -> float:
	return geo_a.pitch_radius + geo_b.pitch_radius

## Center distance for internal mesh
static func center_distance_internal(geo_a: GearGeometry, geo_b: GearGeometry) -> float:
	return abs(geo_a.pitch_radius - geo_b.pitch_radius)

## Involute function: inv(phi) = tan(phi) - phi
static func involute(angle: float) -> float:
	return tan(angle) - angle

## Point on involute curve at parameter t (0=base circle, 1=pitch circle)
func involute_point(t: float) -> Vector2:
	var angle: float = t * PRESSURE_ANGLE * 2.0
	var r: float = base_radius / cos(angle) if cos(angle) > 0.001 else base_radius
	return Vector2(r * cos(angle), r * sin(angle))
