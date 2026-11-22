class_name CharacterAnatomy
extends RefCounted
## Shared semantic anatomy access for characters built from the canonical Ara bodies.
##
## This first layer resolves animated skeleton landmarks and authored surface
## sockets into character-local space. Surface regions and deformation-aware
## volumes are deliberately separate layers; they are not approximated by bones.

const BONE_ALIASES := {
    "root": ["Hips", "Hip", "Pelvis", "Root"],
    "pelvis": ["Hips", "Hip", "Pelvis"],
    "spine_lower": ["Spine", "Spine1", "Spine_01"],
    "spine_mid": ["Spine1", "Spine2", "Spine_02"],
    "chest": ["Spine2", "Spine3", "Chest"],
    "neck": ["Neck", "Neck1"],
    "head": ["Head", "HeadTop_End"],
    "shoulder_left": ["LeftShoulder", "Shoulder_L", "LeftShoulderJoint"],
    "shoulder_right": ["RightShoulder", "Shoulder_R", "RightShoulderJoint"],
    "upper_arm_left": ["LeftArm", "UpperArm_L", "LeftUpperArm"],
    "upper_arm_right": ["RightArm", "UpperArm_R", "RightUpperArm"],
    "elbow_left": ["LeftForeArm", "ForeArm_L", "LeftLowerArm"],
    "elbow_right": ["RightForeArm", "ForeArm_R", "RightLowerArm"],
    "wrist_left": ["LeftHand", "Hand_L", "LeftWrist"],
    "wrist_right": ["RightHand", "Hand_R", "RightWrist"],
    "hip_left": ["LeftUpLeg", "UpLeg_L", "LeftUpperLeg"],
    "hip_right": ["RightUpLeg", "UpLeg_R", "RightUpperLeg"],
    "knee_left": ["LeftLeg", "Leg_L", "LeftLowerLeg"],
    "knee_right": ["RightLeg", "Leg_R", "RightLowerLeg"],
    "ankle_left": ["LeftFoot", "Foot_L"],
    "ankle_right": ["RightFoot", "Foot_R"],
    "toe_left": ["LeftToeBase", "Toe_L", "LeftToe"],
    "toe_right": ["RightToeBase", "Toe_R", "RightToe"],
    "hand_middle_left_1": ["LeftHandMiddle1", "LeftHandMiddle1"],
    "hand_middle_right_1": ["RightHandMiddle1", "RightHandMiddle1"]
}

const SURFACE_ANCHORS := {
    "ear_left": ["SOCKET_Earring_L"],
    "ear_right": ["SOCKET_Earring_R"],
    "nose": ["SOCKET_NoseRing"],
    "necklace": ["SOCKET_Necklace"],
    "nipple_left": ["SOCKET_Nipple_L"],
    "nipple_right": ["SOCKET_Nipple_R"],
    "clitoral_hood": ["SOCKET_ClitoralHood"]
}

var _character_root: Node3D
var _body_root: Node3D
var _skeleton: Skeleton3D


func configure(character_root: Node3D, body_root: Node3D) -> bool:
    _character_root = character_root
    _body_root = body_root
    _skeleton = _find_skeleton(body_root) if body_root != null else null
    return _character_root != null and _body_root != null and _skeleton != null


func is_configured() -> bool:
    return is_instance_valid(_character_root) and is_instance_valid(_body_root) and is_instance_valid(_skeleton)


func has_landmark(landmark_id: String) -> bool:
    return resolve_bone_index(landmark_id) >= 0


func resolve_bone_index(landmark_id: String) -> int:
    if not is_configured():
        return -1
    var candidates: Array = BONE_ALIASES.get(landmark_id, [])
    for candidate in candidates:
        var exact := _skeleton.find_bone(String(candidate))
        if exact >= 0:
            return exact
    # Imported Ara variants may differ only by namespace or separators.
    for candidate in candidates:
        var wanted := _normalise_bone_name(String(candidate))
        for index in range(_skeleton.get_bone_count()):
            var actual := _normalise_bone_name(_skeleton.get_bone_name(index))
            if actual == wanted or actual.ends_with(wanted) or wanted.ends_with(actual):
                return index
    return -1


## Returns the current animated landmark transform in character-root local space.
## The transform origin is the corresponding rig joint, not a body-surface point.
func get_landmark_transform(landmark_id: String) -> Transform3D:
    var index := resolve_bone_index(landmark_id)
    if index < 0:
        return Transform3D.IDENTITY
    var skeleton_space: Transform3D = _skeleton.get_bone_global_pose(index)
    return _character_root.global_transform.affine_inverse() * _skeleton.global_transform * skeleton_space


func get_landmark_position(landmark_id: String) -> Vector3:
    return get_landmark_transform(landmark_id).origin


func has_surface_anchor(anchor_id: String) -> bool:
    return _find_surface_anchor(anchor_id) != null


## Returns an authored surface socket in character-root local space.
## This is an attachment point; it is not a segmented anatomical region.
func get_surface_anchor_transform(anchor_id: String) -> Transform3D:
    var anchor := _find_surface_anchor(anchor_id)
    if anchor == null:
        return Transform3D.IDENTITY
    return _character_root.global_transform.affine_inverse() * anchor.global_transform


func available_landmarks() -> PackedStringArray:
    var result := PackedStringArray()
    for landmark_id in BONE_ALIASES:
        if has_landmark(landmark_id):
            result.append(landmark_id)
    return result


func available_surface_anchors() -> PackedStringArray:
    var result := PackedStringArray()
    for anchor_id in SURFACE_ANCHORS:
        if has_surface_anchor(anchor_id):
            result.append(anchor_id)
    return result


func _find_surface_anchor(anchor_id: String) -> Node3D:
    if not is_configured():
        return null
    var names: Array = SURFACE_ANCHORS.get(anchor_id, [])
    for node_name in names:
        var found := _find_named_node(_body_root, String(node_name))
        if found is Node3D:
            return found as Node3D
    return null


func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null


func _find_named_node(node: Node, requested_name: String) -> Node:
    if node.name == requested_name:
        return node
    for child in node.get_children():
        var found := _find_named_node(child, requested_name)
        if found != null:
            return found
    return null


func _normalise_bone_name(value: String) -> String:
    return value.to_lower().replace("_", "").replace("-", "").replace(" ", "").replace(":", "")
