extends SceneTree

const MechanismModel = preload("res://scripts/mechanism_model.gd")

var failures: Array[String] = []
var model: MechanismModel
var elapsed := 0.0
var phase := 0
var baseline: Dictionary = {}
var energy_after_warmup := 0.0

func _initialize() -> void:
	print("[TEST] starting expanded mechanism suite")
	model = MechanismModel.new()
	baseline = model.get_snapshot()

func _process(delta: float) -> bool:
	elapsed += delta
	model.step(delta)
	if phase == 0 and elapsed >= 2.0:
		_run_midpoint_checks()
		energy_after_warmup = model.total_energy()
		phase = 1
	elif phase == 1 and elapsed >= 6.0:
		_run_final_checks()
		_finish()
	return false

func _run_midpoint_checks() -> void:
	var snap: Dictionary = model.get_snapshot()
	var mods: Dictionary = model.get_modality_snapshot()
	_assert(abs(float(snap["sun"]["theta"]) - float(baseline["sun"]["theta"])) > 0.25, "sun should rotate measurably")
	_assert(abs(float(snap["carrier"]["theta"]) - float(baseline["carrier"]["theta"])) > 0.06, "carrier should move")
	_assert(float(mods["belt"]["energy"]) > 0.001, "belt should transmit energy")
	_assert(float(mods["cam_follower"]["height"]) > 4.0, "cam follower should lift")
	_assert(float(snap["constraint_error"]) < 8.0, "constraint error should remain bounded at midpoint")
	_assert(bool(snap["sanitize_ok"]), "state sanitization should hold at midpoint")

func _run_final_checks() -> void:
	var snap: Dictionary = model.get_snapshot()
	var mods: Dictionary = model.get_modality_snapshot()
	_assert(model.has_method("get_constraint_error"), "model should expose constraint error")
	_assert(model.has_method("total_energy"), "model should expose total energy")
	_assert(model.has_method("get_input_energy"), "model should expose input energy")
	_assert(model.has_method("get_output_energy"), "model should expose output energy")
	_assert(model.has_physics_activity(), "mechanism should register activity")
	_assert(float(mods["hammer_bell"]["energy"]) > 0.01, "hammer should strike bell")
	_assert(int(mods["ratchet"]["index"]) >= 1, "ratchet should advance")
	_assert(float(mods["geneva"]["energy"]) >= 1.0, "geneva should step")
	_assert(float(snap["constraint_error"]) < 8.0, "constraint error should remain bounded")
	_assert(float(snap["max_abs_omega"]) < 120.0, "max omega should stay below clamp")
	_assert(bool(snap["sanitize_ok"]), "state sanitization should hold")
	_assert(model.get_output_energy() > 0.01, "output energy should be positive")
	_assert(model.total_energy() < max(energy_after_warmup * 8.0, 40.0), "energy should not explode catastrophically")
	_assert(abs(model.get_measured_ratio() - model.get_expected_ratio()) < 0.05, "measured ratio should stay near expected band")

func _assert(cond: bool, message: String) -> void:
	if cond:
		print("[PASS] ", message)
	else:
		print("[FAIL] ", message)
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("[TEST] ALL PASSED")
		quit(0)
	else:
		push_error("[TEST] FAIL: %s" % str(failures))
		quit(1)
