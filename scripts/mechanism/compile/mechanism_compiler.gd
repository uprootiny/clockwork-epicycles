class_name MechanismCompiler
extends RefCounted
## Compiles a MechanismSpec into a CompiledMechanism.
## Validates topology, assigns indices, precomputes constants.

const EPSILON := 1e-9

func compile(spec: MechanismSpec) -> CompiledMechanism:
	var cm := CompiledMechanism.new()

	# Assign rotor indices
	cm.rotor_count = spec.rotors.size()
	cm.rotor_name.resize(cm.rotor_count)
	cm.rotor_inertia.resize(cm.rotor_count)
	cm.rotor_radius.resize(cm.rotor_count)
	cm.rotor_display_radius.resize(cm.rotor_count)
	cm.rotor_damping.resize(cm.rotor_count)
	cm.rotor_teeth.resize(cm.rotor_count)
	cm.rotor_orbit_radius.resize(cm.rotor_count)
	cm.rotor_orbit_phase.resize(cm.rotor_count)
	cm.rotor_is_internal.resize(cm.rotor_count)

	for i in range(cm.rotor_count):
		var r: Dictionary = spec.rotors[i]
		var rname: String = str(r.get("name", "rotor_%d" % i))
		cm.rotor_name[i] = rname
		cm.rotor_inertia[i] = max(float(r.get("inertia", 1.0)), 0.001)
		cm.rotor_radius[i] = max(float(r.get("radius", 1.0)), 0.001)
		cm.rotor_display_radius[i] = float(r.get("display_radius", 32.0))
		cm.rotor_damping[i] = max(float(r.get("damping", 0.02)), 0.0)
		cm.rotor_teeth[i] = max(int(r.get("teeth", 20)), 2)
		cm.rotor_orbit_radius[i] = float(r.get("orbit_radius", 0.0))
		cm.rotor_orbit_phase[i] = float(r.get("orbit_phase", 0.0))
		cm.rotor_is_internal[i] = 1 if bool(r.get("is_internal", false)) else 0
		cm.name_to_index[rname] = i

	# Compile meshes
	cm.mesh_count = spec.meshes.size()
	cm.mesh_a.resize(cm.mesh_count)
	cm.mesh_b.resize(cm.mesh_count)
	cm.mesh_carrier.resize(cm.mesh_count)
	cm.mesh_internal.resize(cm.mesh_count)
	cm.mesh_stiffness.resize(cm.mesh_count)
	cm.mesh_damping.resize(cm.mesh_count)
	cm.mesh_backlash.resize(cm.mesh_count)
	cm.mesh_denom.resize(cm.mesh_count)

	for k in range(cm.mesh_count):
		var m: Dictionary = spec.meshes[k]
		var ai: int = cm.index_of(str(m["a"]))
		var bi: int = cm.index_of(str(m["b"]))
		var ci: int = cm.index_of(str(m.get("carrier", ""))) if str(m.get("carrier", "")) != "" else -1
		cm.mesh_a[k] = ai
		cm.mesh_b[k] = bi
		cm.mesh_carrier[k] = ci
		cm.mesh_internal[k] = 1 if bool(m.get("internal", false)) else 0
		cm.mesh_stiffness[k] = float(m.get("stiffness", 1e5))
		cm.mesh_damping[k] = float(m.get("damping", 50.0))
		cm.mesh_backlash[k] = float(m.get("backlash", 0.0))
		# Precompute effective mass denominator
		var ra: float = cm.rotor_radius[ai]
		var rb: float = cm.rotor_radius[bi]
		var ia: float = cm.rotor_inertia[ai]
		var ib: float = cm.rotor_inertia[bi]
		var denom: float = (ra * ra) / ia + (rb * rb) / ib
		if ci >= 0:
			var ic: float = cm.rotor_inertia[ci]
			var sign_b: float = -1.0 if bool(m.get("internal", false)) else 1.0
			var jc: float = -(ra + sign_b * rb)
			denom += (jc * jc) / ic
		cm.mesh_denom[k] = max(denom, EPSILON)

	# Compile belts
	cm.belt_count = spec.belts.size()
	cm.belt_a.resize(cm.belt_count)
	cm.belt_b.resize(cm.belt_count)
	cm.belt_stiffness.resize(cm.belt_count)
	cm.belt_damping.resize(cm.belt_count)
	cm.belt_slack.resize(cm.belt_count)

	for k in range(cm.belt_count):
		var b: Dictionary = spec.belts[k]
		cm.belt_a[k] = cm.index_of(str(b["a"]))
		cm.belt_b[k] = cm.index_of(str(b["b"]))
		cm.belt_stiffness[k] = float(b.get("stiffness", 500.0))
		cm.belt_damping[k] = float(b.get("damping", 20.0))
		cm.belt_slack[k] = float(b.get("slack", 0.0))

	# Compile escapements
	cm.escapement_count = spec.escapements.size()
	cm.esc_wheel.resize(cm.escapement_count)
	cm.esc_balance.resize(cm.escapement_count)
	cm.esc_engage_angle.resize(cm.escapement_count)
	cm.esc_impulse_scale.resize(cm.escapement_count)

	for k in range(cm.escapement_count):
		var e: Dictionary = spec.escapements[k]
		cm.esc_wheel[k] = cm.index_of(str(e["wheel"]))
		cm.esc_balance[k] = cm.index_of(str(e["balance"]))
		cm.esc_engage_angle[k] = float(e.get("engage_angle", 0.32))
		cm.esc_impulse_scale[k] = float(e.get("impulse_scale", 0.72))

	return cm
