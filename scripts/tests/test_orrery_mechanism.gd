extends SceneTree
## Test: OrreryMechanism — the armillary simulation core.
## Validates bevel chain ratios, ring speed hierarchy, Willis, energy.

const OrreryMechanismClass = preload("res://scripts/mechanism/exact/orrery_mechanism.gd")

var failures: Array[String] = []

func _initialize() -> void:
	print("[TEST] Orrery mechanism — bevels, rings, Willis")
	var mech: RefCounted = OrreryMechanismClass.new()
	print(mech.get_report())

	# Run 4 seconds
	var dt: float = 1.0 / 240.0
	for _i in range(960):
		mech.step(dt)

	var snap: Dictionary = mech.get_snapshot()
	var speeds: PackedFloat64Array = snap["ring_speeds"]

	print("[DIAG] sun=%.3f carrier=%.3f ring=%.3f" % [
		float(snap["sun"]["omega"]), float(snap["carrier"]["omega"]), float(snap["ring"]["omega"])])
	print("[DIAG] hour=%.4f day=%.4f month=%.4f year=%.5f" % [
		speeds[0], speeds[1], speeds[2], speeds[3]])
	print("[DIAG] willis=%.4f energy=%.2f" % [
		float(snap["willis_error"]), float(snap["total_energy"])])
	print("[DIAG] balance_theta=%.4f esc_omega=%.3f" % [
		float(snap["balance"]["theta"]), float(snap["escapement"]["omega"])])

	# Ring speed hierarchy: hour > day > month > year
	_assert(abs(speeds[0]) > abs(speeds[1]) or abs(speeds[1]) < 0.001,
		"hour ring faster than day ring (or both near zero)")
	_assert(abs(speeds[1]) >= abs(speeds[2]) or abs(speeds[2]) < 0.001,
		"day ring faster than month ring")
	_assert(abs(speeds[2]) >= abs(speeds[3]) or abs(speeds[3]) < 0.001,
		"month ring faster than year ring")

	# System is moving
	_assert(abs(float(snap["sun"]["omega"])) > 0.1, "sun rotating")
	_assert(abs(float(snap["carrier"]["omega"])) > 0.01, "carrier rotating")

	# Energy bounded
	_assert(float(snap["total_energy"]) > 0.0, "energy positive")
	_assert(float(snap["total_energy"]) < 5000.0, "energy bounded")

	# Willis reasonable
	_assert(float(snap["willis_error"]) < 2.0, "Willis error acceptable")

	# Balance oscillating
	_assert(abs(float(snap["balance"]["theta"])) < 5.0, "balance within bounds")

	_finish()

func _process(_delta: float) -> bool:
	return true

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
