class_name CharacterAttachmentRig
extends Node3D

## Reusable bone-mounted attachment points. Local offsets are deliberately loaded
## from calibrated per-body data; uncalibrated sockets are not silently guessed.

const SOCKETS := {
    "ear.left": {"bone": "Head", "group": "head"},
    "ear.right": {"bone": "Head", "group": "head"},
    "nose.ring": {"bone": "Head", "group": "head"},
    "necklace": {"bone": "Spine2", "group": "torso"},
    "nipple.left": {"bone": "Spine2", "group": "torso_surface"},
    "nipple.right": {"bone": "Spine2", "group": "torso_surface"},
    "clitoral_hood": {"bone": "Hips", "group": "pelvis_surface"},
    "hand.right": {"bone": "HandR", "group": "hand"},
    "hand.left": {"bone": "HandL", "group": "hand"}
}

var _attachments: Dictionary = {}
var _skeleton: Skeleton3D

func configure(skeleton: Skeleton3D, calibration: Dictionary) -> bool:
    clear()
    _skeleton = skeleton
    if _skeleton == null:
        return false
    var all_valid := true
    var socket_calibration: Dictionary = calibration.get("sockets", calibration)
    for socket_id in SOCKETS:
        var definition: Dictionary = SOCKETS[socket_id]
        var bone_name := str(definition.bone)
        if _skeleton.find_bone(bone_name) < 0:
            push_warning("Attachment socket %s references missing bone %s." % [socket_id, bone_name])
            all_valid = false
            continue
        var socket_data: Dictionary = socket_calibration.get(socket_id, {})
        if not bool(socket_data.get("calibrated", false)):
            # Keep an explicit empty socket so equipment data can be validated
            # before final Blender calibration, but do not render guessed placement.
            _attachments[socket_id] = null
            continue
        var bone_attachment := BoneAttachment3D.new()
        bone_attachment.name = socket_id.replace(".", "_")
        bone_attachment.bone_name = bone_name
        _skeleton.add_child(bone_attachment)
        bone_attachment.transform = Transform3D(
            Basis.from_euler(Vector3(
                float(socket_data.get("rot_x", 0.0)),
                float(socket_data.get("rot_y", 0.0)),
                float(socket_data.get("rot_z", 0.0))
            )),
            Vector3(
                float(socket_data.get("x", 0.0)),
                float(socket_data.get("y", 0.0)),
                float(socket_data.get("z", 0.0))
            )
        )
        _attachments[socket_id] = bone_attachment
    return all_valid

func get_socket(socket_id: String) -> Node3D:
    var value: Variant = _attachments.get(socket_id)
    return value as Node3D if value is Node3D else null

func attach(socket_id: String, accessory: Node3D) -> bool:
    var socket := get_socket(socket_id)
    if socket == null or accessory == null:
        return false
    for child in socket.get_children():
        child.queue_free()
    socket.add_child(accessory)
    return true

func clear() -> void:
    for value in _attachments.values():
        if value is Node3D and is_instance_valid(value):
            value.queue_free()
    _attachments.clear()
    _skeleton = null
