extends SkeletonModifier3D
## Probe helper: records one bone's local rotation at the moment this modifier runs,
## i.e. after every modifier earlier in the Skeleton3D's child order.

var bone := -1
var last := Quaternion.IDENTITY


func _process_modification_with_delta(_delta: float) -> void:
	last = get_skeleton().get_bone_pose_rotation(bone)
