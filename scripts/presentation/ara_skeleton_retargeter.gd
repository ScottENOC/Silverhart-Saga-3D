extends SkeletonModifier3D
## Transfers animation deltas from the shared Ara animation rig onto a
## character's own skeleton. Bone rests remain owned by the character asset.

var source_skeleton: Skeleton3D
var _bone_pairs: Array[Vector2i] = []


func configure(source: Skeleton3D, target: Skeleton3D) -> int:
	source_skeleton = source
	_bone_pairs.clear()
	if source_skeleton == null or target == null:
		return 0
	for target_index in range(target.get_bone_count()):
		var bone_name := target.get_bone_name(target_index)
		var source_index := source_skeleton.find_bone(bone_name)
		if source_index < 0:
			continue
		if _parent_bone_name(source_skeleton, source_index) != _parent_bone_name(target, target_index):
			continue
		_bone_pairs.append(Vector2i(source_index, target_index))
	print("ARA_RETARGET_MAP source_bones=%d target_bones=%d mapped_bones=%d" % [
		source_skeleton.get_bone_count(), target.get_bone_count(), _bone_pairs.size()
	])
	return _bone_pairs.size()


func _process_modification_with_delta(_delta: float) -> void:
	var target := get_skeleton()
	if target == null or not is_instance_valid(source_skeleton):
		return
	for pair in _bone_pairs:
		var source_rest := source_skeleton.get_bone_rest(pair.x)
		var source_pose := source_skeleton.get_bone_pose(pair.x)
		var target_rest := target.get_bone_rest(pair.y)
		# Godot 4 bone poses include their rest transform. Transfer only the
		# animated delta, then compose it with the target character's own rest.
		var animation_delta := source_rest.affine_inverse() * source_pose
		target.set_bone_pose(pair.y, target_rest * animation_delta)


func _parent_bone_name(skeleton: Skeleton3D, bone_index: int) -> String:
	var parent_index := skeleton.get_bone_parent(bone_index)
	return skeleton.get_bone_name(parent_index) if parent_index >= 0 else ""
