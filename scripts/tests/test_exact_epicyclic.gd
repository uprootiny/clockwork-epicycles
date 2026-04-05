extends SceneTree
## Test: exact epicyclic gear train from first principles.
## Validates geometry derivation, Willis equation, energy conservation.

const ExactEpicyclicClass = preload("res://scripts/mechanism/exact/exact_epicyclic.gd")
const ContactSolverClass = preload("res://scripts/mechanism/exact/contact_solver.gd")
const GearGeometryClass = preload("res://scripts/mechanism/exact/gear_geometry.gd")

var failures: Array[String] = []

func _initialize() -> void:
	print("[TEST] Exact epicyclic gear train")
	_test_geometry()
	_test_tooth_constraint()
	_test_contact_ratios()
	_test_willis_equation()
	_test_energy_bounded()
	_test_gear_ratios()
	_finish()

func _process(_delta: float) -> bool:
	return true

func _test_geometry() -> void:
	print("\n── Geometry derivation ──")
	var g: GearGeometry = GearGeometryClass.new(24, 0.04)
	_assert(abs(g.pitch_radius - 0.48) < 0.001, "pitch_radius = m*N/2 = 0.04*24/2 = 0.48")
	_assert(g.base_radius < g.pitch_radius, "base_radius < pitch_radius")
	_assert(g.outer_radius > g.pitch_radius, "outer_radius > pitch_radius (addendum)")
	_assert(g.root_radius < g.pitch_radius, "root_radius < pitch_radius (dedendum)")
	_assert(abs(g.outer_radius - g.pitch_radius - 0.04) < 0.001, "addendum = 1 module")

	var g_int: GearGeometry = GearGeometryClass.new(48, 0.04, true)
	_assert(g_int.is_internal, "internal gear flag set")
	_assert(g_int.outer_radius < g_int.pitch_radius, "internal: tips point inward")

func _test_tooth_constraint() -> void:
	print("\n── Tooth count constraint ──")
	_assert(ContactSolverClass.epicyclic_compatible(24, 12, 48), "24 + 2×12 = 48 ✓")
	_assert(ContactSolverClass.epicyclic_compatible(20, 15, 50), "20 + 2×15 = 50 ✓")
	_assert(not ContactSolverClass.epicyclic_compatible(24, 12, 50), "24 + 2×12 ≠ 50 ✗")
	_assert(not ContactSolverClass.epicyclic_compatible(20, 10, 45), "20 + 2×10 ≠ 45 ✗")

func _test_contact_ratios() -> void:
	print("\n── Contact ratios ──")
	var train: RefCounted = ExactEpicyclicClass.new()
	print(train.get_geometry_report())
	_assert(train.contact_ratio_sp > 1.0, "sun-planet contact ratio > 1 (continuous mesh)")
	_assert(train.contact_ratio_pr > 1.0, "planet-ring contact ratio > 1 (continuous mesh)")

func _test_willis_equation() -> void:
	print("\n── Willis equation ──")
	var train: RefCounted = ExactEpicyclicClass.new()
	train.drive_torque = 2.0
	var dt: float = 1.0 / 240.0
	# Run for 3 seconds to reach steady state
	for _i in range(720):
		train.step(dt)
	var snap: Dictionary = train.get_snapshot()
	print("[DIAG] omega_sun=%.4f carrier=%.4f ring=%.4f" % [
		float(snap["omega_sun"]), float(snap["omega_carrier"]), float(snap["omega_ring"])])
	print("[DIAG] willis_error=%.6f" % float(snap["willis_error"]))
	_assert(float(snap["willis_error"]) < 0.5, "Willis equation error < 0.5 after settling")

func _test_energy_bounded() -> void:
	print("\n── Energy boundedness ──")
	var train: RefCounted = ExactEpicyclicClass.new()
	train.drive_torque = 2.0
	var dt: float = 1.0 / 240.0
	var max_energy: float = 0.0
	for _i in range(1440):  # 6 seconds
		train.step(dt)
		if train.total_energy > max_energy:
			max_energy = train.total_energy
	print("[DIAG] final_energy=%.4f max_energy=%.4f" % [train.total_energy, max_energy])
	_assert(train.total_energy < 1000.0, "energy bounded (< 1000 J)")
	_assert(train.total_energy > 0.0, "energy positive (system is moving)")

func _test_gear_ratios() -> void:
	print("\n── Gear ratios from tooth counts ──")
	var ratio_sr: float = GearGeometryClass.ratio(24, 48)
	_assert(abs(ratio_sr - 0.5) < 0.001, "sun/ring ratio = 24/48 = 0.5")
	var ratio_sp: float = GearGeometryClass.ratio(24, 12)
	_assert(abs(ratio_sp - 2.0) < 0.001, "sun/planet ratio = 24/12 = 2.0")
	# Willis: (ω_s - ω_c)/(ω_r - ω_c) = -N_r/N_s = -48/24 = -2
	var willis: float = ContactSolverClass.willis_ratio(24, 48)
	_assert(abs(willis - (-2.0)) < 0.001, "Willis ratio = -N_ring/N_sun = -2.0")

func _assert(cond: bool, message: String) -> void:
	if cond:
		print("[PASS] ", message)
	else:
		print("[FAIL] ", message)
		failures.append(message)

func _finish() -> void:
	print("")
	if failures.is_empty():
		print("[TEST] ALL PASSED")
		quit(0)
	else:
		push_error("[TEST] FAIL: %s" % str(failures))
		quit(1)
