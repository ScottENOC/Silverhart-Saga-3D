extends SceneTree
## Native Wren/Aldric paired contact-pose review.
## Loads the same native GLBs used by anatomy CI, poses both rigs with IK,
## and exports a reviewable GLB plus a machine-readable pose report.
##
## This is a pose/fit review, not a validated collision or pressure simulation.
## The hand targets are authored in character-local proportions; the report
## deliberately distinguishes target placement from measured mesh contact.

const WREN_GLB := "res://build/wren-native/Wren.glb"
const ALDRIC_GLB := "res://build/aldric-native/Aldric.glb"
const OUTPUT_DIR := "res://build/aldric-wren-kiss-contact"
const OUTPUT_GLB := OUTPUT_DIR + "/aldric-wren-kiss-contact.glb"
const OUTPUT_REPORT := OUTPUT_DIR + "/pose-report.json"
const EXPORT_SCALE := 1.0

const BONE_ALIASES := {
    "shoulder_left": ["LeftShoulder", "Shoulder_L", "LeftShoulderJoint"],
    "shoulder_right": ["RightShoulder", "Shoulder_R", "RightShoulderJoint"],
    "upper_arm_left": ["LeftArm", "UpperArm_L", "LeftUpperArm"],
    "upper_arm_right": ["RightArm", "UpperArm_R", "RightUpperArm"],
    "forearm_left": ["LeftForeArm", "ForeArm_L", "LeftLowerArm"],
    "forearm_right": ["RightForeArm", "ForeArm_R", "RightLowerArm"],
    "hand_left": ["LeftHand", "Hand_L", "LeftWrist"],
    "hand_right": ["RightHand", "Hand_R", "RightWrist"],
    "neck": ["Neck", "Neck1"],
    "head": ["Head", "HeadTop_End"]
}

var stage: Node3D
var report: Dictionary = {"scene": "Aldric and Wren paired kiss/contact pose", "pose_targets": {}, "rigs": {}, "validation": {}}

func _initialize() -> void:
    call_deferred("_build")

func _build() -> void:
    var args := OS.get_cmdline_user_args()
    var export_path := OUTPUT_GLB
    if not args.is_empty():
        export_path = args[0]
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

    stage = Node3D.new()
    stage.name = "AldricWrenKissContact"
    root.add_child(stage)
    _add_environment()

    var aldric := _load_actor("Aldric", ALDRIC_GLB, Vector3(-0.02, 0.0, -0.16), 0.0)
    var wren := _load_actor("Wren", WREN_GLB, Vector3(0.02, 0.0, 0.16), PI)
    if aldric.is_empty() or wren.is_empty():
        quit(1)
        return

    await process_frame
    await process_frame

    # World-space contact targets, authored relative to the standing pair.
    # Front of the imported Ara bodies is local +Z. The pair face one another.
    var targets := _create_targets(aldric, wren)
    _configure_arm_ik(aldric, "left", targets["aldric_left_breast"])
    _configure_arm_ik(aldric, "right", targets["aldric_right_cheek"])
    _configure_arm_ik(wren, "right", targets["wren_right_buttock"])
    _configure_arm_ik(wren, "left", targets["wren_left_shoulder"])
    _configure_head_pose(aldric, 0.06)
    _configure_head_pose(wren, -0.06)
    _splay_hand_fingers(aldric, "left")
    _splay_hand_fingers(wren, "right")

    await process_frame
    await process_frame
    await process_frame
    for actor in [aldric, wren]:
        var skeleton: Skeleton3D = actor["skeleton"]
        skeleton.force_update_all_bone_transforms()
        report["rigs"][actor["id"]] = _rig_report(skeleton, actor["model"])

    report["pose_targets"] = {
        "aldric_left_hand": "Wren right breast; palm-facing contact, fingers spread",
        "aldric_right_hand": "Wren left cheek",
        "wren_right_hand": "Aldric left buttock",
        "wren_left_hand": "Across Aldric's back to his right shoulder",
        "face_pose": "Standing face-to-face, leaning together for a kiss"
    }
    report["validation"] = {
        "ik_targets_created": targets.size(),
        "all_four_arm_ik_created": _count_ik_nodes(stage) == 4,
        "mesh_collision_measured": false,
        "anatomy_region_contact_resolved": false,
        "pressure_deformation_applied": false,
        "note": "This export validates rig posing and visual hand placement only. It does not claim measured surface collision, 145-region contact assignment, or pressure deformation."
    }

    var file := FileAccess.open(OUTPUT_REPORT, FileAccess.WRITE)
    file.store_string(JSON.stringify(report, "\t"))
    file.close()

    var gltf := GLTFDocument.new()
    var state := GLTFState.new()
    var append_error := gltf.append_from_scene(stage, state)
    if append_error != OK:
        push_error("Could not convert paired pose to glTF: " + str(append_error))
        quit(1)
        return
    var absolute_output := ProjectSettings.globalize_path(export_path)
    var write_error := gltf.write_to_filesystem(state, absolute_output)
    if write_error != OK:
        push_error("Could not write paired pose GLB: " + str(write_error))
        quit(1)
        return

    print("ALDRIC_WREN_CONTACT_POSE_EXPORTED path=%s" % absolute_output)
    print("ALDRIC_WREN_CONTACT_POSE_REPORT %s" % JSON.stringify(report))
    quit(0)

func _load_actor(actor_id: String, asset_path: String, position: Vector3, yaw: float) -> Dictionary:
    var packed := load(asset_path) as PackedScene
    if packed == null:
        push_error("Missing native character GLB: " + asset_path)
        return {}
    var actor := Node3D.new()
    actor.name = actor_id
    actor.position = position
    actor.rotation.y = yaw
    stage.add_child(actor)
    var model := packed.instantiate() as Node3D
    if model == null:
        push_error("Native character root is not Node3D: " + asset_path)
        return {}
    actor.add_child(model)
    var skeleton := _find_skeleton(model)
    if skeleton == null:
        push_error("No Skeleton3D in " + asset_path)
        return {}
    return {"id": actor_id, "actor": actor, "model": model, "skeleton": skeleton}

func _create_targets(aldric: Dictionary, wren: Dictionary) -> Dictionary:
    var result := {}
    # Coordinates are scaled against each character's actual mesh bounds.
    var wb := _model_bounds(wren["model"])
    var ab := _model_bounds(aldric["model"])
    var wsize: Vector3 = wb.size
    var asize: Vector3 = ab.size
    var wcentre: Vector3 = wb.get_center()
    var acentre: Vector3 = ab.get_center()
    var wactor: Node3D = wren["actor"]
    var aactor: Node3D = aldric["actor"]

    # Wren faces -Z. Her anatomical right is her local -X before yaw.
    result["aldric_left_breast"] = _add_target(
        "AldricLeftHand_to_WrenRightBreast",
        wactor.to_global(Vector3(-wsize.x * 0.105, wb.position.y + wsize.y * 0.665, wsize.z * 0.46)),
        Color("#e6a04b")
    )
    result["aldric_right_cheek"] = _add_target(
        "AldricRightHand_to_WrenLeftCheek",
        wactor.to_global(Vector3(wsize.x * 0.075, wb.position.y + wsize.y * 0.855, wsize.z * 0.43)),
        Color("#e6a04b")
    )
    # Aldric faces +Z; the rear of his body is -Z.
    result["wren_right_buttock"] = _add_target(
        "WrenRightHand_to_AldricLeftButtock",
        aactor.to_global(Vector3(asize.x * 0.105, ab.position.y + asize.y * 0.405, -asize.z * 0.43)),
        Color("#55b9a6")
    )
    result["wren_left_shoulder"] = _add_target(
        "WrenLeftHand_to_AldricRightShoulder",
        aactor.to_global(Vector3(-asize.x * 0.20, ab.position.y + asize.y * 0.785, -asize.z * 0.40)),
        Color("#55b9a6")
    )
    return result

func _add_target(target_name: String, world_position: Vector3, colour: Color) -> Node3D:
    var target := Node3D.new()
    target.name = target_name
    target.position = world_position
    stage.add_child(target)
    # Small visible target marker is intentionally retained in the review GLB.
    var marker := MeshInstance3D.new()
    marker.name = "ContactTargetMarker"
    var sphere := SphereMesh.new()
    sphere.radius = 0.012
    sphere.height = 0.024
    sphere.radial_segments = 12
    sphere.rings = 6
    marker.mesh = sphere
    var material := StandardMaterial3D.new()
    material.albedo_color = colour
    material.emission_enabled = true
    material.emission = colour
    marker.material_override = material
    target.add_child(marker)
    return target

func _configure_arm_ik(actor: Dictionary, side: String, target: Node3D) -> void:
    var skeleton: Skeleton3D = actor["skeleton"]
    var root_index := _resolve_bone(skeleton, "upper_arm_" + side)
    var middle_index := _resolve_bone(skeleton, "forearm_" + side)
    var end_index := _resolve_bone(skeleton, "hand_" + side)
    var result := {"root": root_index, "middle": middle_index, "tip": end_index, "ik_created": false, "ik_type": "TwoBoneIK3D"}
    if root_index < 0 or middle_index < 0 or end_index < 0:
        report["rigs"][actor["id"] + "_" + side + "_arm"] = result
        push_warning("Could not resolve complete " + actor["id"] + " " + side + " arm IK chain")
        return

    var pole := Node3D.new()
    pole.name = actor["id"] + "_" + side + "_ElbowPole"
    var actor_node: Node3D = actor["actor"]
    var side_sign := 1.0 if side == "left" else -1.0
    pole.global_position = actor_node.global_position + actor_node.global_basis.x * side_sign * 0.24 + actor_node.global_basis.z * 0.28 + Vector3.UP * 0.92
    stage.add_child(pole)

    var ik := TwoBoneIK3D.new()
    ik.name = actor["id"] + "_" + side + "_ArmIK"
    ik.setting_count = 1
    ik.set_root_bone_name(0, skeleton.get_bone_name(root_index))
    ik.set_middle_bone_name(0, skeleton.get_bone_name(middle_index))
    ik.set_end_bone_name(0, skeleton.get_bone_name(end_index))
    ik.set_target_node(0, skeleton.get_path_to(target))
    ik.set_pole_node(0, skeleton.get_path_to(pole))
    ik.active = true
    skeleton.add_child(ik)
    result["ik_created"] = true
    result["root_name"] = skeleton.get_bone_name(root_index)
    result["middle_name"] = skeleton.get_bone_name(middle_index)
    result["tip_name"] = skeleton.get_bone_name(end_index)
    report["rigs"][actor["id"] + "_" + side + "_arm"] = result

func _configure_head_pose(actor: Dictionary, tilt: float) -> void:
    var skeleton: Skeleton3D = actor["skeleton"]
    for key in ["neck", "head"]:
        var index := _resolve_bone(skeleton, key)
        if index >= 0:
            var current := skeleton.get_bone_pose_rotation(index)
            skeleton.set_bone_pose_rotation(index, current * Quaternion(Vector3.RIGHT, tilt))

func _splay_hand_fingers(actor: Dictionary, side: String) -> void:
    var skeleton: Skeleton3D = actor["skeleton"]
    var prefixes := ["Thumb", "Index", "Middle", "Ring", "Little", "Pinky"]
    var side_prefix := "Left" if side == "left" else "Right"
    var changed := 0
    for bone_index in range(skeleton.get_bone_count()):
        var raw := skeleton.get_bone_name(bone_index)
        var normal := _normalise(raw)
        if not normal.begins_with(_normalise(side_prefix)):
            continue
        for finger in prefixes:
            var token := _normalise(finger)
            if normal.contains(token) and (normal.ends_with("1") or normal.ends_with("01")):
                var current := skeleton.get_bone_pose_rotation(bone_index)
                var direction := -1.0 if finger in ["Thumb", "Index"] else 1.0
                skeleton.set_bone_pose_rotation(bone_index, current * Quaternion(Vector3.FORWARD, direction * 0.16))
                changed += 1
                break
    report["rigs"][actor["id"] + "_" + side + "_finger_splay_bones"] = changed

func _rig_report(skeleton: Skeleton3D, model: Node3D) -> Dictionary:
    var bone_names := PackedStringArray()
    for i in range(skeleton.get_bone_count()):
        bone_names.append(skeleton.get_bone_name(i))
    var bounds := _model_bounds(model)
    return {
        "bone_count": skeleton.get_bone_count(),
        "has_neck": _resolve_bone(skeleton, "neck") >= 0,
        "has_head": _resolve_bone(skeleton, "head") >= 0,
        "has_left_arm": _resolve_bone(skeleton, "upper_arm_left") >= 0 and _resolve_bone(skeleton, "hand_left") >= 0,
        "has_right_arm": _resolve_bone(skeleton, "upper_arm_right") >= 0 and _resolve_bone(skeleton, "hand_right") >= 0,
        "model_bounds": {"position": [bounds.position.x, bounds.position.y, bounds.position.z], "size": [bounds.size.x, bounds.size.y, bounds.size.z]},
        "bone_names": Array(bone_names)
    }

func _resolve_bone(skeleton: Skeleton3D, key: String) -> int:
    var candidates: Array = BONE_ALIASES.get(key, [])
    for candidate in candidates:
        var found := skeleton.find_bone(String(candidate))
        if found >= 0:
            return found
    for candidate in candidates:
        var wanted := _normalise(String(candidate))
        for i in range(skeleton.get_bone_count()):
            var actual := _normalise(skeleton.get_bone_name(i))
            if actual == wanted or actual.ends_with(wanted) or wanted.ends_with(actual):
                return i
    return -1

func _normalise(value: String) -> String:
    return value.to_lower().replace("_", "").replace("-", "").replace(" ", "").replace(":", "")

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _model_bounds(model: Node3D) -> AABB:
    var result := AABB()
    var found := false
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(model, meshes)
    var inverse := model.global_transform.affine_inverse()
    for mesh_instance in meshes:
        var local := mesh_instance.mesh.get_aabb()
        var transform := inverse * mesh_instance.global_transform
        for corner in [
            local.position,
            local.position + Vector3(local.size.x, 0, 0),
            local.position + Vector3(0, local.size.y, 0),
            local.position + Vector3(0, 0, local.size.z),
            local.position + Vector3(local.size.x, local.size.y, 0),
            local.position + Vector3(local.size.x, 0, local.size.z),
            local.position + Vector3(0, local.size.y, local.size.z),
            local.end
        ]:
            var point: Vector3 = transform * Vector3(corner)
            if not found:
                result = AABB(point, Vector3.ZERO)
                found = true
            else:
                result = result.expand(point)
    return result

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D and node.mesh != null:
        output.append(node)
    for child in node.get_children():
        _collect_meshes(child, output)

func _count_ik_nodes(node: Node) -> int:
    var total := 1 if node is TwoBoneIK3D else 0
    for child in node.get_children():
        total += _count_ik_nodes(child)
    return total

func _add_environment() -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#252a30")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("#c5cbd2")
    environment.ambient_light_energy = 0.75
    var world := WorldEnvironment.new()
    world.environment = environment
    stage.add_child(world)
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-24, -28, 0)
    key.light_energy = 1.35
    stage.add_child(key)
    var fill := OmniLight3D.new()
    fill.position = Vector3(0.0, 1.6, 1.4)
    fill.light_energy = 0.45
    fill.omni_range = 4.0
    stage.add_child(fill)
    var camera := Camera3D.new()
    camera.name = "ReviewCamera"
    camera.position = Vector3(2.8, 1.45, 3.4)
    camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
    camera.fov = 42.0
    camera.current = true
    stage.add_child(camera)
    var floor := MeshInstance3D.new()
    floor.name = "ReviewFloor"
    var plane := PlaneMesh.new()
    plane.size = Vector2(4.0, 4.0)
    floor.mesh = plane
    floor.position.y = -0.015
    var floor_material := StandardMaterial3D.new()
    floor_material.albedo_color = Color("#343b42")
    floor_material.roughness = 0.92
    floor.material_override = floor_material
    stage.add_child(floor)
