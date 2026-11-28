extends SkeletonModifier3D
## Probe helper: forces one bone to a fixed local rotation. Not for production use.

var bone := -1
var rotation_target := Quaternion.IDENTITY


func _process_modification_with_delta(_delta: float) -> void:
	get_skeleton().set_bone_pose_rotation(bone, rotation_target)
