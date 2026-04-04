extends SceneTree

var elapsed := 0.0
var scene_root: Node = null
var baseline: Dictionary = {}

func _initialize() -> void:
	print("[TEST] booting clockwork scene")
	var scene := load("res://main.tscn")
	if scene == null:
		push_error("[TEST] FAIL: unable to load main.tscn")
		quit(1)
		return
	scene_root = scene.instantiate()
	root.add_child(scene_root)
	if scene_root.has_method("get_activity_snapshot"):
		baseline = scene_root.get_activity_snapshot()

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 7.0:
		_validate_and_quit()
	return false

func _validate_and_quit() -> void:
	if scene_root == null:
		push_error("[TEST] FAIL: scene root missing")
		quit(1)
		return
	for method_name in ["has_physics_activity", "get_activity_snapshot", "get_modality_snapshot"]:
		if not scene_root.has_method(method_name):
			push_error("[TEST] FAIL: scene missing %s()" % method_name)
			quit(1)
			return
	var snapshot: Dictionary = scene_root.get_activity_snapshot()
	var modality: Dictionary = scene_root.get_modality_snapshot()
	var carrier_delta: float = abs(float(snapshot["carrier"]["theta"]) - float(baseline["carrier"]["theta"]))
	var sun_delta: float = abs(float(snapshot["sun"]["theta"]) - float(baseline["sun"]["theta"]))
	var dial_delta: float = abs(float(snapshot["dial"]["theta"]) - float(baseline["dial"]["theta"]))
	var flywheel_delta: float = abs(float(snapshot["flywheel"]["theta"]) - float(baseline["flywheel"]["theta"]))
	var bell_ok: bool = abs(float(snapshot["bell_omega"])) > 0.03 or float(snapshot["strike_energy"]) > 0.02
	var planets_ok: bool = abs(float(snapshot["planet_a"]["omega"])) > 0.20 and abs(float(snapshot["planet_b"]["omega"])) > 0.20
	var transmission_ok: bool = float(snapshot["momentum_score"]) > 2.1 and float(snapshot["ring_to_dial_power"]) > 0.003
	var escapement_ok: bool = abs(float(snapshot["balance"]["theta"]) - float(baseline["balance"]["theta"])) > 0.08 and abs(float(snapshot["last_escape_impulse"])) > 0.01
	var belt_ok: bool = float(modality["belt"]["energy"]) > 0.002 and float(modality["belt"]["flywheel_speed"]) > 0.05
	var cam_ok: bool = float(modality["cam_follower"]["height"]) > 6.0 and float(modality["cam_follower"]["energy"]) > 0.02
	var hammer_ok: bool = float(modality["hammer_bell"]["energy"]) > 0.01 and bell_ok
	var ratchet_ok: bool = int(modality["ratchet"]["index"]) >= 1 and float(modality["ratchet"]["energy"]) >= 1.0
	var geneva_ok: bool = float(modality["geneva"]["energy"]) >= 1.0 and abs(float(snapshot["geneva"]["theta"]) - float(baseline["geneva"]["theta"])) > 0.10
	var stable_ok: bool = float(snapshot["max_abs_omega"]) < 120.0 and float(snapshot["constraint_error"]) < 8.0 and bool(snapshot["sanitize_ok"])
	if scene_root.has_physics_activity() and carrier_delta > 0.12 and sun_delta > 0.35 and dial_delta > 0.08 and flywheel_delta > 0.05 and planets_ok and transmission_ok and escapement_ok and belt_ok and cam_ok and hammer_ok and ratchet_ok and geneva_ok and stable_ok:
		print("[TEST] PASS: expanded mechanism activity detected")
		print(snapshot)
		quit(0)
	else:
		push_error("[TEST] FAIL: insufficient motion or weak transmission in expanded mechanism")
		print({
			"carrier_delta": carrier_delta,
			"sun_delta": sun_delta,
			"dial_delta": dial_delta,
			"flywheel_delta": flywheel_delta,
			"planets_ok": planets_ok,
			"transmission_ok": transmission_ok,
			"escapement_ok": escapement_ok,
			"belt_ok": belt_ok,
			"cam_ok": cam_ok,
			"hammer_ok": hammer_ok,
			"ratchet_ok": ratchet_ok,
			"geneva_ok": geneva_ok,
			"stable_ok": stable_ok,
			"snapshot": snapshot,
			"modality": modality,
		})
		quit(1)
