class_name MechanismSpec
extends RefCounted
## Declarative mechanism specification. Immutable after construction.
## Author richly — this is the human-facing layer.

var rotors: Array[Dictionary] = []
var meshes: Array[Dictionary] = []
var belts: Array[Dictionary] = []
var escapements: Array[Dictionary] = []
var initial_state: Dictionary = {}

func add_rotor(config: Dictionary) -> MechanismSpec:
	rotors.append(config)
	return self

func add_mesh(a: String, b: String, carrier: String = "", internal: bool = false,
		stiffness: float = 1e5, damping: float = 50.0, backlash: float = 0.0) -> MechanismSpec:
	meshes.append({
		"a": a, "b": b, "carrier": carrier,
		"internal": internal, "stiffness": stiffness,
		"damping": damping, "backlash": backlash,
	})
	return self

func add_belt(a: String, b: String, stiffness: float = 500.0,
		damping: float = 20.0, slack: float = 0.0) -> MechanismSpec:
	belts.append({
		"a": a, "b": b, "stiffness": stiffness,
		"damping": damping, "slack": slack,
	})
	return self

func add_escapement(wheel: String, balance: String,
		engage_angle: float = 0.32, impulse_scale: float = 0.72) -> MechanismSpec:
	escapements.append({
		"wheel": wheel, "balance": balance,
		"engage_angle": engage_angle, "impulse_scale": impulse_scale,
	})
	return self

func set_initial(rotor_name: String, theta: float = 0.0, omega: float = 0.0) -> MechanismSpec:
	initial_state[rotor_name] = {"theta": theta, "omega": omega}
	return self

static func clockwork_default() -> MechanismSpec:
	var spec := MechanismSpec.new()
	spec.add_rotor({"name":"sun","inertia":0.34,"radius":1.0,"display_radius":74.0,"teeth":28,"damping":0.018})
	spec.add_rotor({"name":"carrier","inertia":2.55,"radius":2.9,"display_radius":184.0,"teeth":2,"damping":0.024})
	spec.add_rotor({"name":"planet_a","inertia":0.18,"radius":0.95,"display_radius":62.0,"teeth":24,"damping":0.018,"orbit_radius":144.0,"orbit_phase":0.0})
	spec.add_rotor({"name":"planet_b","inertia":0.18,"radius":0.95,"display_radius":62.0,"teeth":24,"damping":0.018,"orbit_radius":144.0,"orbit_phase":PI})
	spec.add_rotor({"name":"ring","inertia":9.8,"radius":3.85,"display_radius":250.0,"teeth":80,"damping":0.020,"is_internal":true})
	spec.add_rotor({"name":"dial","inertia":0.46,"radius":0.72,"display_radius":52.0,"teeth":20,"damping":0.016})
	spec.add_rotor({"name":"escapement","inertia":0.11,"radius":0.54,"display_radius":44.0,"teeth":16,"damping":0.016})
	spec.add_rotor({"name":"balance","inertia":0.76,"radius":1.0,"display_radius":88.0,"teeth":4,"damping":0.008})
	spec.add_rotor({"name":"flywheel","inertia":1.65,"radius":0.95,"display_radius":72.0,"teeth":24,"damping":0.010})
	spec.add_rotor({"name":"clickwheel","inertia":0.28,"radius":0.45,"display_radius":36.0,"teeth":12,"damping":0.024})
	spec.add_rotor({"name":"geneva","inertia":1.05,"radius":0.82,"display_radius":58.0,"teeth":4,"damping":0.020})
	spec.add_mesh("sun", "planet_a", "carrier", false, 1e5, 50.0)
	spec.add_mesh("sun", "planet_b", "carrier", false, 1e5, 50.0)
	spec.add_mesh("planet_a", "ring", "carrier", true, 1e5, 50.0)
	spec.add_mesh("planet_b", "ring", "carrier", true, 1e5, 50.0)
	spec.add_mesh("ring", "dial", "", true, 8e4, 40.0)
	spec.add_mesh("dial", "escapement", "", false, 7e4, 35.0)
	spec.add_belt("dial", "flywheel", 500.0, 20.0)
	spec.add_escapement("escapement", "balance", 0.32, 0.72)
	spec.set_initial("sun", 0.0, 1.2)
	spec.set_initial("ring", 0.0, -0.08)
	spec.set_initial("carrier", 0.0, 0.06)
	spec.set_initial("balance", 0.42, 0.0)
	spec.set_initial("flywheel", 0.0, 0.15)
	return spec
