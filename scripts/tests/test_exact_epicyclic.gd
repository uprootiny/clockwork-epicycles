extends SceneTree

const ExactEpicyclicClass = preload("res://scripts/mechanism/exact/exact_epicyclic.gd")
const ContactSolverClass = preload("res://scripts/mechanism/exact/contact_solver.gd")
const GearGeometryClass = preload("res://scripts/mechanism/exact/gear_geometry.gd")

var failures: Array[String] = []

func _initialize() -> void:
	print("[TEST] Exact epicyclic mechanism — geometry, contacts, Willis, energy")
	_test_geometry()
	_test_tooth_constraint()
	_test_full_mechanism()
	_finish()

func _process(_delta: float) -> bool:
	return true

func _test_geometry() -> void:
	print("\n-- Geometry --")
	var g: GearGeometry = GearGeometryClass.new(24, 0.04)
	_assert(abs(g.pitch_radius - 0.48) < 0.001, "pitch_radius = m*N/2 = 0.48")
	_assert(g.base_radius < g.pitch_radius, "base < pitch")
	_assert(g.outer_radius > g.pitch_radius, "outer > pitch")
	_assert(abs(g.outer_radius - g.pitch_radius - 0.04) < 0.001, "addendum = 1 module")
	var g_int: GearGeometry = GearGeometryClass.new(48, 0.04, true)
	_assert(g_int.is_internal, "internal flag")
	_assert(g_int.outer_radius < g_int.pitch_radius, "internal: outer < pitch")
	# Contact ratio for external pair
	var g12: GearGeometry = GearGeometryClass.new(12, 0.04)
	var cr: float = g.contact_ratio_with(g12)
	print("[DIAG] contact_ratio 24T-12T external = %.3f" % cr)
	_assert(cr > 1.0, "contact ratio 24-12 external > 1")

func _test_tooth_constraint() -> void:
	print("\n-- Tooth counts --")
	_assert(ContactSolverClass.epicyclic_compatible(24, 12, 48), "24+2x12=48")
	_assert(not ContactSolverClass.epicyclic_compatible(24, 12, 50), "24+2x12!=50")
	var wr: float = ContactSolverClass.willis_ratio(24, 48)
	_assert(abs(wr - (-2.0)) < 0.001, "Willis ratio = -2.0")

func _test_full_mechanism() -> void:
	print("\n-- Full mechanism --")
	var mech: RefCounted = ExactEpicyclicClass.new()
	print(mech.get_report())

	# Run for 4 seconds
	var dt: float = 1.0 / 240.0
	var energy_samples: Array[float] = []
	for i in range(960):
		mech.step(dt)
		if i % 240 == 0:
			energy_samples.append(mech.total_energy)

	var snap: Dictionary = mech.get_snapshot()
	print("[DIAG] sun=%.3f carrier=%.3f ring=%.3f" % [
		float(snap["sun"]["omega"]),
		float(snap["carrier"]["omega"]),
		float(snap["ring"]["omega"])])
	print("[DIAG] balance_theta=%.4f escape_omega=%.3f" % [
		float(snap["balance"]["theta"]),
		float(snap["escapement"]["omega"])])
	print("[DIAG] output_b_omega=%.4f (dial)" % float(snap["output_b"]["omega"]))
	print("[DIAG] willis_error=%.4f energy=%.2f power_in=%.3f" % [
		float(snap["willis_error"]),
		float(snap["total_energy"]),
		float(snap["power_in"])])

	_assert(abs(float(snap["sun"]["omega"])) > 0.1, "sun is rotating")
	_assert(abs(float(snap["carrier"]["omega"])) > 0.01, "carrier is rotating")
	_assert(float(snap["total_energy"]) > 0.0, "energy positive")
	_assert(float(snap["total_energy"]) < 5000.0, "energy bounded")
	_assert(float(snap["willis_error"]) < 2.0, "Willis error reasonable")
	_assert(abs(float(snap["balance"]["theta"])) < 5.0, "balance oscillating within bounds")

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("[PASS] ", msg)
	else:
		print("[FAIL] ", msg)
		failures.append(msg)

func _finish() -> void:
	print("")
	if failures.is_empty():
		print("[TEST] ALL PASSED")
		quit(0)
	else:
		push_error("[TEST] FAIL: %s" % str(failures))
		quit(1)
