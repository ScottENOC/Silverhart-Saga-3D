extends RefCounted
## Writes a solved arm pose onto a Skeleton3D by rotating bones (never moving or scaling them).
## Positions in the pose are skeleton model space, matching ArmRigBuilder.
##
## Each bone is rotated by the shortest arc that turns its current direction-to-child onto the
## solved direction, working shoulder -> elbow -> wrist. This works for any rest orientation.
## Hand roll about the finger axis is left as it was; roll control is a later feature.
## The Skeleton3D must be inside the scene tree (see tests/posing_fixtures.gd for why).

const ArmRigBuilder := preload("res://scripts/posing/arm_rig_builder.gd")


static func apply_arm(skeleton: Skeleton3D, side: StringName, pose: Dictionary) -> bool:
	var bones := ArmRigBuilder.arm_bones(skeleton, side)
	if bones.is_empty():
		push_warning("PoseApplier: skeleton lacks the %s arm bones." % side)
		return false
	var upper: int = bones["upper"]
	var fore: int = bones["fore"]
	var hand: int = bones["hand"]
	var tip: int = bones["finger_tip"]

	_aim(skeleton, upper, fore, (pose["elbow"] as Vector3) - skeleton.get_bone_global_pose(upper).origin)
	_aim(skeleton, fore, hand, (pose["wrist"] as Vector3) - skeleton.get_bone_global_pose(fore).origin)
	if tip >= 0:
		_aim(skeleton, hand, tip, pose["hand_dir"])
	else:
		push_warning("PoseApplier: no finger chain; hand orientation not applied.")
	return true


static func _aim(skeleton: Skeleton3D, bone: int, child: int, target_dir: Vector3) -> void:
	var global := skeleton.get_bone_global_pose(bone)
	var current := skeleton.get_bone_global_pose(child).origin - global.origin
	if current.length_squared() < 1e-12 or target_dir.length_squared() < 1e-12:
		return
	var turn := Quaternion(current.normalized(), target_dir.normalized())
	skeleton.set_bone_global_pose(bone, Transform3D(Basis(turn) * global.basis, global.origin))
