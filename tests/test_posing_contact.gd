extends "res://tests/posing_test_base.gd"

const ContactResolver := preload("res://scripts/posing/contact_resolver.gd")
const GoalSequence := preload("res://scripts/posing/goal_sequence.gd")
const Fixtures := preload("res://tests/posing_fixtures.gd")

const SURFACE := Vector3(0.0, 1.6, -0.105)
const NORMAL := Vector3(0, 0, -1)
const FORCE := 4.0

var _materials: Dictionary
var _pad: Dictionary
var _nose: Dictionary
var _helm: Dictionary


func _run() -> void:
	_materials = ContactResolver.load_materials(Fixtures.MATERIALS_PATH)
	_check(not _materials.is_empty(), "materials file loads and validates")
	if _materials.is_empty():
		return
	_pad = _materials["pads"]["fingertip_pad"]
	_nose = ContactResolver.layer_from_material(&"nose_tissue", _materials["layers"]["nose_tissue"])
	_helm = ContactResolver.layer_from_material(&"helm_closed_steel", _materials["layers"]["helm_closed_steel"])
	_test_bare_series_springs()
	_test_helmet_bears_the_load()
	_test_bottom_out()
	_test_approach_applies_no_force()
	_test_unloaded_geometry()
	_test_sequence_reach()
	_test_sequence_force_and_release()


func _test_bare_series_springs() -> void:
	var r := ContactResolver.resolve(SURFACE, NORMAL, [_nose], _pad, 0.0, FORCE)
	var x_pad := FORCE / float(_pad["stiffness_n_per_m"])
	var x_nose := FORCE / float(_nose["stiffness_n_per_m"])
	_near(float(r["pad_compression_m"]), x_pad, 1e-6, "pad compresses by F/k")
	_near(float(r["target_compression_m"]), x_nose, 1e-6, "nose compresses by F/k")
	_near(float(r["pad_compression_m"]) / float(r["target_compression_m"]), float(_nose["stiffness_n_per_m"]) / float(_pad["stiffness_n_per_m"]), 1e-6, "softer element moves further, in inverse stiffness ratio")
	var expected_tip := SURFACE + NORMAL * (float(_pad["thickness_m"]) - x_pad - x_nose)
	_near_v(r["bone_tip"], expected_tip, 1e-6, "fingertip bone position")
	_check(r["bottomed_out"].is_empty(), "no bottoming at 4 N")


func _test_helmet_bears_the_load() -> void:
	var bare := ContactResolver.resolve(SURFACE, NORMAL, [_nose], _pad, 0.0, FORCE)
	var helmed := ContactResolver.resolve(SURFACE, NORMAL, [_nose, _helm], _pad, 0.0, FORCE)
	_check(float(helmed["layer_compression"][&"helm_closed_steel"]) < 1e-6, "steel barely moves")
	_check(not helmed["layer_compression"].has(&"nose_tissue"), "tissue beneath a bearing shell is not loaded")
	_near(float(helmed["pad_compression_m"]), FORCE / float(_pad["stiffness_n_per_m"]), 1e-6, "finger takes the full compression")
	var finger_share := float(helmed["pad_compression_m"]) / (float(helmed["pad_compression_m"]) + float(helmed["target_compression_m"]))
	_check(finger_share > 0.99, "finger takes more than 99%% of the deformation against steel (got %.4f)" % finger_share)
	var bare_share := float(bare["pad_compression_m"]) / (float(bare["pad_compression_m"]) + float(bare["target_compression_m"]))
	_check(bare_share > 0.3 and bare_share < 0.7, "bare nose shares deformation with the finger (got %.4f)" % bare_share)
	# The fingertip bone stops short of the nose by the shell offset (plus the nose compression it no longer causes).
	var difference: float = (helmed["bone_tip"] - bare["bone_tip"]).dot(NORMAL)
	_near(difference, float(_helm["thickness_m"]) + float(bare["target_compression_m"]), 1e-6, "standoff from the helmet")


func _test_bottom_out() -> void:
	var r := ContactResolver.resolve(SURFACE, NORMAL, [_nose], _pad, 0.0, 50.0)
	_near(float(r["target_compression_m"]), float(_nose["max_compression_m"]), 1e-6, "nose compression is capped")
	_near(float(r["pad_compression_m"]), float(_pad["max_compression_m"]), 1e-6, "pad compression is capped")
	_check(r["bottomed_out"].has(&"nose_tissue") and r["bottomed_out"].has(&"pad"), "bottomed-out elements are reported")


func _test_approach_applies_no_force() -> void:
	var r := ContactResolver.resolve(SURFACE, NORMAL, [_nose], _pad, 0.05, 10.0)
	_near(float(r["force_n"]), 0.0, 1e-12, "no force while approaching")
	_near(float(r["target_compression_m"]), 0.0, 1e-12, "no target compression while approaching")
	_near((r["pad_surface_point"] - r["outer_point"]).dot(NORMAL), 0.05, 1e-6, "pad hovers at the approach height")


func _test_unloaded_geometry() -> void:
	var r := ContactResolver.resolve(SURFACE, NORMAL, [_nose, _helm], _pad, 0.0, 0.0)
	_near_v(r["outer_point"], SURFACE + NORMAL * 0.025, 1e-6, "outer surface sits at the stacked thickness")
	_near_v(r["pad_surface_point"], r["outer_point"], 1e-6, "unloaded pad rests on the surface")


func _test_sequence_reach() -> void:
	var seq: RefCounted = GoalSequence.new()
	var start: Dictionary = seq.sample(0.0)
	_check(start["phase"] == &"reach", "starts in reach")
	_near(float(start["approach_m"]), seq.start_distance_m, 1e-6, "starts at the start distance")
	var previous := INF
	var steps := 200
	for i in range(steps + 1):
		var state: Dictionary = seq.sample(seq.reach_s * float(i) / float(steps) * 0.99999)
		_check(float(state["approach_m"]) <= previous + 1e-12, "approach never increases during reach")
		_check(float(state["force_n"]) == 0.0, "no force during reach")
		previous = float(state["approach_m"])
	_check(previous < 1e-6, "reach ends at the surface")
	var dt := 0.001
	var early := float(seq.sample(0.0)["approach_m"]) - float(seq.sample(dt)["approach_m"])
	_check(early < 1e-7, "reach starts with zero velocity (minimum jerk)")


func _test_sequence_force_and_release() -> void:
	var seq: RefCounted = GoalSequence.new()
	var t_press: float = seq.reach_s
	var last_force := -1.0
	for i in range(101):
		var s: Dictionary = seq.sample(t_press + seq.press_s * float(i) / 100.0 * 0.99999)
		_check(s["phase"] == &"press" and float(s["approach_m"]) == 0.0, "press stays on the surface")
		_check(float(s["force_n"]) >= last_force - 1e-12 and float(s["force_n"]) <= seq.peak_force_n + 1e-6, "force ramps up without overshoot")
		last_force = float(s["force_n"])
	_near(float(seq.sample(t_press + seq.press_s + 0.01)["force_n"]), seq.peak_force_n, 1e-6, "hold at peak force")
	var t_release: float = seq.reach_s + seq.press_s + seq.hold_s
	var forces: Array = []
	for i in range(101):
		var s: Dictionary = seq.sample(t_release + seq.release_s * float(i) / 100.0 * 0.99999)
		_check(float(s["force_n"]) >= 0.0 and float(s["approach_m"]) >= 0.0 and float(s["approach_m"]) <= seq.start_distance_m + 1e-6, "release stays in range")
		_check(float(s["force_n"]) == 0.0 or float(s["approach_m"]) == 0.0, "never lifts while still loaded")
		forces.append(float(s["force_n"]))
	var done: Dictionary = seq.sample(seq.total_duration_s() + 1.0)
	_check(done["phase"] == &"done", "finishes")
	_near(float(done["approach_m"]), seq.start_distance_m, 1e-6, "withdraws to the start distance")
	_near(float(done["force_n"]), 0.0, 1e-12, "no force at the end")
