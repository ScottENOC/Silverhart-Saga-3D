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
		var source_index: int = pair.x
		var target_index: int = pair.y
		var source_rest := source_skeleton.get_bone_rest(source_index)
		var source_pose := source_skeleton.get_bone_pose(source_index)
		var target_rest := target.get_bone_rest(target_index)
		var source_parent_index := source_skeleton.get_bone_parent(source_index)
		var target_parent_index := target.get_bone_parent(target_index)
		var source_parent_basis := Basis.IDENTITY
		var target_parent_basis := Basis.IDENTITY
		if source_parent_index >= 0:
			source_parent_basis = source_skeleton.get_bone_global_rest(source_parent_index).basis
		if target_parent_index >= 0:
			target_parent_basis = target.get_bone_global_rest(target_parent_index).basis

		# Convert the source pose delta through model space into the target
		# parent's rest basis. This is the same rest-aware transform used by
		# Godot's realtime retargeting implementation, without rewriting either
		# skeleton's rest data or requiring a shared bind pose.
		var target_parent_inverse := target_parent_basis.inverse()
		var retargeted_basis := (
			target_parent_inverse
			* source_parent_basis
			* source_pose.basis
			* source_rest.basis.inverse()
			* source_parent_basis.inverse()
			* target_parent_basis
			* target_rest.basis
		)
		var retargeted_origin := (
			target_parent_inverse
			* source_parent_basis
			* (source_pose.origin - source_rest.origin)
			+ target_rest.origin
		)
		target.set_bone_pose(target_index, Transform3D(retargeted_basis, retargeted_origin))


func _parent_bone_name(skeleton: Skeleton3D, bone_index: int) -> String:
	var parent_index := skeleton.get_bone_parent(bone_index)
	return skeleton.get_bone_name(parent_index) if parent_index >= 0 else ""
