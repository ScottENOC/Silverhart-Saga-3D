extends SceneTree

const ANATOMY_SCRIPT = preload("res://scripts/characters/character_anatomy.gd")

var _failures := 0

func _initialize() -> void:
    call_deferred("_run_tests")


func _run_tests() -> void:
    await process_frame
    _test_semantic_bone_resolution()
    _test_missing_landmarks_are_not_fabricated()
    if _failures > 0:
        push_error("Character anatomy tests failed: %d assertion(s)." % _failures)
        quit(1)
        return
    print("CHARACTER_ANATOMY_TEST: PASS")
    quit(0)


func _check(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error(message)


func _test_semantic_bone_resolution() -> void:
    var character_root := Node3D.new()
    root.add_child(character_root)
    var body_root := Node3D.new()
    character_root.add_child(body_root)
    var skeleton := Skeleton3D.new()
    body_root.add_child(skeleton)
    skeleton.add_bone("Hips")
    skeleton.add_bone("Spine")
    skeleton.add_bone("Spine1")
    skeleton.add_bone("Spine2")
    skeleton.add_bone("Neck")
    skeleton.add_bone("Head")
    skeleton.add_bone("LeftArm")
    skeleton.add_bone("LeftForeArm")
    skeleton.add_bone("LeftHand")
    skeleton.add_bone("RightArm")
    skeleton.add_bone("RightForeArm")
    skeleton.add_bone("RightHand")
    skeleton.add_bone("LeftUpLeg")
    skeleton.add_bone("LeftLeg")
    skeleton.add_bone("LeftFoot")
    skeleton.add_bone("RightUpLeg")
    skeleton.add_bone("RightLeg")
    skeleton.add_bone("RightFoot")

    var anatomy: CharacterAnatomy = ANATOMY_SCRIPT.new() as CharacterAnatomy
    _check(anatomy.configure(character_root, body_root), "Anatomy interface should bind to a body skeleton")
    for landmark_id in [
        "pelvis", "spine_lower", "spine_mid", "chest", "neck", "head",
        "upper_arm_left", "elbow_left", "wrist_left",
        "upper_arm_right", "elbow_right", "wrist_right",
        "hip_left", "knee_left", "ankle_left",
        "hip_right", "knee_right", "ankle_right"
    ]:
        _check(anatomy.has_landmark(landmark_id), "Semantic landmark did not resolve: " + landmark_id)
    var head_transform: Transform3D = anatomy.get_landmark_transform("head")
    _check(head_transform.origin == Vector3.ZERO, "Synthetic head landmark should resolve in character-local coordinates")
    character_root.free()


func _test_missing_landmarks_are_not_fabricated() -> void:
    var character_root := Node3D.new()
    root.add_child(character_root)
    var body_root := Node3D.new()
    character_root.add_child(body_root)
    var skeleton := Skeleton3D.new()
    body_root.add_child(skeleton)
    skeleton.add_bone("Hips")
    var anatomy = ANATOMY_SCRIPT.new()
    _check(anatomy.configure(character_root, body_root), "Minimal test skeleton should configure")
    _check(not anatomy.has_landmark("head"), "Missing head landmark must remain unavailable")
    _check(anatomy.resolve_bone_index("unknown_region") == -1, "Unknown anatomy labels must not map to arbitrary bones")
    character_root.free()
