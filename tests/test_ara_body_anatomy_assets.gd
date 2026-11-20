extends SceneTree

const ANATOMY_SCRIPT = preload("res://scripts/characters/character_anatomy.gd")
const BODY_ASSETS := [
    "res://art/characters/ara_runtime/ara_person_body_anatomy.glb",
    "res://art/characters/ara_runtime/ara_person_male_body.glb"
]
const REQUIRED_LANDMARKS := [
    "pelvis", "spine_lower", "chest", "neck", "head",
    "shoulder_left", "shoulder_right",
    "upper_arm_left", "upper_arm_right",
    "elbow_left", "elbow_right",
    "wrist_left", "wrist_right",
    "hip_left", "hip_right",
    "knee_left", "knee_right",
    "ankle_left", "ankle_right"
]

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    for asset_path in BODY_ASSETS:
        var packed := load(asset_path) as PackedScene
        assert(packed != null, "Canonical Ara body failed to load: " + asset_path)
        var character_root := Node3D.new()
        root.add_child(character_root)
        var body_root := packed.instantiate() as Node3D
        assert(body_root != null, "Canonical Ara body root is not Node3D: " + asset_path)
        character_root.add_child(body_root)
        var anatomy: CharacterAnatomy = ANATOMY_SCRIPT.new() as CharacterAnatomy
        assert(anatomy.configure(character_root, body_root), "Canonical Ara body has no compatible skeleton: " + asset_path)
        for landmark_id in REQUIRED_LANDMARKS:
            assert(anatomy.has_landmark(landmark_id),
                "Canonical Ara body %s is missing semantic landmark %s" % [asset_path, landmark_id])
            var point: Vector3 = anatomy.get_landmark_position(landmark_id)
            assert(point.is_finite(), "Landmark returned a non-finite position: " + landmark_id)
        print("ARA_BODY_ANATOMY_CONTRACT: PASS asset=%s landmarks=%d" % [asset_path, REQUIRED_LANDMARKS.size()])
        character_root.free()
    quit(0)
