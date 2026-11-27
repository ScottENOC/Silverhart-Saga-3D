extends "res://tests/posing_test_base.gd"

const BodyProxy := preload("res://scripts/posing/body_proxy.gd")
const TwoBoneIK := preload("res://scripts/posing/ik_two_bone.gd")
const JointLimits := preload("res://scripts/posing/joint_limits.gd")


func _run() -> void:
	_test_segment_distance()
	_test_capsule_clearance()
	_test_two_bone_geometry()
	_test_two_bone_swivel()
	_test_two_bone_out_of_reach()
	_test_joint_limits()


func _test_segment_distance() -> void:
	_near(BodyProxy.segment_distance(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)), 1.0, 1e-6, "parallel segments")
	_near(BodyProxy.segment_distance(Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(0, -1, 1), Vector3(0, 1, 1)), 1.0, 1e-6, "skew crossing segments")
	_near(BodyProxy.segment_distance(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(3, 0, 0), Vector3(4, 0, 0)), 2.0, 1e-6, "collinear gap")
	_near(BodyProxy.segment_distance(Vector3(0, 0, 0), Vector3(0, 0, 0), Vector3(0, 2, 0), Vector3(1, 2, 0)), 2.0, 1e-6, "point vs segment")
	_near(BodyProxy.segment_distance(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 1, 0)), 0.0, 1e-6, "touching segments")


func _test_capsule_clearance() -> void:
	var proxy := BodyProxy.make(&"torso", Vector3(0, 0, 0), Vector3(0, 1, 0), 0.15)
	_near(BodyProxy.clearance(Vector3(0.30, 0, 0), Vector3(0.30, 1, 0), 0.05, proxy), 0.10, 1e-6, "positive clearance")
	_check(BodyProxy.clearance(Vector3(0.18, 0, 0), Vector3(0.18, 1, 0), 0.05, proxy) < 0.0, "overlap must be negative")
	_check(is_inf(BodyProxy.min_clearance(Vector3.ZERO, Vector3.UP, 0.05, [proxy], [&"torso"])), "ignored proxy is not tested")


func _test_two_bone_geometry() -> void:
	# 3-4-5 triangle: interior angle at the middle joint is 90 degrees, so flexion is 90.
	var result := TwoBoneIK.solve(Vector3.ZERO, Vector3(0.5, 0, 0), 0.3, 0.4, Vector3.UP)
	_check(bool(result["reached"]), "3-4-5 target is reachable")
	_near(float(result["flexion_deg"]), 90.0, 1e-3, "3-4-5 flexion")
	_near((result["mid"] as Vector3).length(), 0.3, 1e-6, "upper length preserved")
	_near((result["end"] as Vector3).distance_to(result["mid"]), 0.4, 1e-6, "lower length preserved")
	_near_v(result["end"], Vector3(0.5, 0, 0), 1e-6, "end reaches target")
	_check((result["mid"] as Vector3).y > 0.0, "pole +Y puts the middle joint above the axis")
	var down := TwoBoneIK.solve(Vector3.ZERO, Vector3(0.5, 0, 0), 0.3, 0.4, Vector3.DOWN)
	_check((down["mid"] as Vector3).y < 0.0, "pole -Y puts the middle joint below the axis")
	var straight := TwoBoneIK.solve(Vector3.ZERO, Vector3(0.69, 0, 0), 0.3, 0.4, Vector3.UP)
	_check(float(straight["flexion_deg"]) < 25.0, "almost-straight chain has small flexion")


func _test_two_bone_swivel() -> void:
	var base := TwoBoneIK.solve(Vector3.ZERO, Vector3(0.5, 0, 0), 0.3, 0.4, Vector3.UP)
	for angle in [0.5, 1.2, 3.0, -2.0]:
		var swung := TwoBoneIK.solve(Vector3.ZERO, Vector3(0.5, 0, 0), 0.3, 0.4, Vector3.UP, angle)
		_near((swung["mid"] as Vector3).length(), 0.3, 1e-6, "swivel keeps upper length")
		_near((swung["mid"] as Vector3).distance_to(swung["end"]), 0.4, 1e-6, "swivel keeps lower length")
		_near_v(swung["end"], Vector3(0.5, 0, 0), 1e-6, "swivel keeps the end fixed")
		_near(float(swung["flexion_deg"]), float(base["flexion_deg"]), 1e-6, "swivel keeps flexion")
	var half_turn := TwoBoneIK.solve(Vector3.ZERO, Vector3(0.5, 0, 0), 0.3, 0.4, Vector3.UP, PI)
	_near((half_turn["mid"] as Vector3).y, -(base["mid"] as Vector3).y, 1e-6, "180 degree swivel mirrors the elbow")


func _test_two_bone_out_of_reach() -> void:
	var far := TwoBoneIK.solve(Vector3.ZERO, Vector3(2, 0, 0), 0.3, 0.4, Vector3.UP)
	_check(not bool(far["reached"]), "far target is not reached")
	_near_v(far["end"], Vector3(0.7, 0, 0), 1e-4, "chain points straight at an unreachable target")
	_near(float(far["distance_error_m"]), 1.3, 1e-3, "reports the shortfall")
	var near := TwoBoneIK.solve(Vector3.ZERO, Vector3(0.02, 0, 0), 0.3, 0.4, Vector3.UP)
	_check(not bool(near["reached"]), "target closer than the minimum reach is not reached")


func _test_joint_limits() -> void:
	var limits: RefCounted = JointLimits.new()
	_check(limits.load_json("res://data/posing/arm_joint_limits.json"), "limits file loads")
	var forward := Vector3(0, 0, -1)
	_near(limits.shoulder_extension_deg(Vector3.DOWN, forward), 0.0, 1e-6, "hanging arm has no extension")
	_near(limits.shoulder_extension_deg(Vector3(0, -1, -1).normalized(), forward), 0.0, 1e-6, "forward swing is not extension")
	_near(limits.shoulder_extension_deg(Vector3(0, -1, 1).normalized(), forward), 45.0, 1e-4, "backward swing of 45 degrees")
	_check(limits.violations(90.0, 10.0, 20.0).is_empty(), "comfortable pose has no violations")
	_check(limits.violations(-5.0, 0.0, 0.0).has("elbow_flexion"), "elbow hyperextension is rejected")
	_check(limits.violations(160.0, 0.0, 0.0).has("elbow_flexion"), "elbow over-flexion is rejected")
	_check(limits.violations(90.0, 75.0, 0.0).has("shoulder_extension"), "excess shoulder extension is rejected")
	_check(limits.violations(90.0, 0.0, 95.0).has("wrist_deviation"), "excess wrist deviation is rejected")
