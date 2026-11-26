extends SceneTree
const ArmRigBuilder := preload("res://scripts/posing/arm_rig_builder.gd")
const OUTPUT_DIR := "res://artifacts/ara-pose-preview"
var _failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _find_skeleton(node: Node) -> Skeleton3D:
	if node == null:
		return null
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _expect(condition: bool, message: String) -> void:
	print(("PASS  " if condition else "FAIL  ") + message)
	if not condition:
		_failures += 1

func _remove_modifiers(node: Node) -> void:
	for child in node.get_children():
		if child is SkeletonModifier3D:
			child.free()
		else:
			_remove_modifiers(child)

func _collect_mesh_instances(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_mesh_instances(child, output)

func _collect_skeletons(node: Node, output: Array[Skeleton3D]) -> void:
	if node is Skeleton3D:
		output.append(node as Skeleton3D)
	for child in node.get_children():
		_collect_skeletons(child, output)

func _bake_mesh_instance(mesh_instance: MeshInstance3D) -> float:
	var source_mesh := mesh_instance.mesh
	if source_mesh == null:
		return 0.0
	var baked := mesh_instance.bake_mesh_from_current_skeleton_pose()
	if baked == null or baked.get_surface_count() == 0:
		return 0.0
	var max_vertex_delta := 0.0
	var surfaces := mini(source_mesh.get_surface_count(), baked.get_surface_count())
	for surface in range(surfaces):
		var material := mesh_instance.get_active_material(surface)
		if material != null:
			baked.surface_set_material(surface, material)
		var original_arrays := source_mesh.surface_get_arrays(surface)
		var baked_arrays := baked.surface_get_arrays(surface)
		var original_vertices: PackedVector3Array = original_arrays[Mesh.ARRAY_VERTEX]
		var baked_vertices: PackedVector3Array = baked_arrays[Mesh.ARRAY_VERTEX]
		if original_vertices.size() == baked_vertices.size():
			for vertex_index in range(original_vertices.size()):
				max_vertex_delta = maxf(max_vertex_delta, original_vertices[vertex_index].distance_to(baked_vertices[vertex_index]))
	mesh_instance.mesh = baked
	mesh_instance.skin = null
	mesh_instance.skeleton = NodePath()
	return max_vertex_delta

func _bake_character_pose(export_root: Node3D, source_skeleton: Skeleton3D) -> Dictionary:
	var pose_snapshot: Array[Transform3D] = []
	for bone_index in range(source_skeleton.get_bone_count()):
		pose_snapshot.append(source_skeleton.get_bone_global_pose(bone_index))
	_remove_modifiers(export_root)
	var export_skeleton := _find_skeleton(export_root)
	if export_skeleton == null:
		return {"ok": false, "reason": "duplicated skeleton missing"}
	if export_skeleton.get_bone_count() != pose_snapshot.size():
		return {"ok": false, "reason": "duplicated skeleton bone count changed"}
	for bone_index in range(pose_snapshot.size()):
		export_skeleton.set_bone_global_pose(bone_index, pose_snapshot[bone_index])
	export_skeleton.force_update_all_bone_transforms()
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(export_root, mesh_instances)
	var baked_count := 0
	var maximum_delta := 0.0
	for mesh_instance in mesh_instances:
		if mesh_instance.skin == null:
			continue
		var vertex_delta := _bake_mesh_instance(mesh_instance)
		if mesh_instance.mesh is ArrayMesh and (mesh_instance.mesh as ArrayMesh).get_surface_count() > 0:
			baked_count += 1
			maximum_delta = maxf(maximum_delta, vertex_delta)
	var skeletons: Array[Skeleton3D] = []
	_collect_skeletons(export_root, skeletons)
	for skeleton_node in skeletons:
		skeleton_node.free()
	return {
		"ok": baked_count > 0,
		"baked_meshes": baked_count,
		"max_vertex_delta": maximum_delta,
		"reason": "no skinned meshes could be baked" if baked_count == 0 else ""
	}

func _export_and_verify(actor_name: String, model_root: Node3D, source_skeleton: Skeleton3D) -> void:
	var source_bones := ArmRigBuilder.arm_bones(source_skeleton, &"right")
	if source_bones.is_empty() or int(source_bones["finger_tip"]) < 0:
		_expect(false, "%s has a named right fingertip bone for export verification" % actor_name)
		return
	var source_tip_name := source_skeleton.get_bone_name(int(source_bones["finger_tip"]))
	var source_tip_position := source_skeleton.get_bone_global_pose(int(source_bones["finger_tip"])).origin
	var export_root := model_root.duplicate() as Node3D
	if export_root == null:
		_expect(false, "%s model duplicated for GLB export" % actor_name)
		return
	export_root.name = actor_name
	root.add_child(export_root)
	await process_frame
	await RenderingServer.frame_post_draw
	var bake_result := _bake_character_pose(export_root, source_skeleton)
	_expect(bool(bake_result["ok"]), "%s skinned meshes baked (%s)" % [actor_name, str(bake_result.get("reason", ""))])
	if not bool(bake_result["ok"]):
		export_root.free()
		return
	_expect(float(bake_result["max_vertex_delta"]) > 0.001, "%s baked geometry differs from bind-pose mesh (max vertex delta %.4f m)" % [actor_name, float(bake_result["max_vertex_delta"])])
	var output_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if dir_error != OK:
		_expect(false, "%s output directory created (%s)" % [actor_name, error_string(dir_error)])
		export_root.free()
		return
	var output_path := output_dir.path_join(actor_name.to_snake_case() + "_nose_touch.glb")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	state.create_animations = false
	var append_error := document.append_from_scene(export_root, state)
	if append_error != OK:
		_expect(false, "%s GLTF scene conversion (%s)" % [actor_name, error_string(append_error)])
		export_root.free()
		return
	var write_error := document.write_to_filesystem(state, output_path)
	export_root.free()
	if write_error != OK or not FileAccess.file_exists(output_path):
		_expect(false, "%s GLB written (%s)" % [actor_name, error_string(write_error)])
		return
	_expect(true, "%s static GLB exported (%d bytes)" % [actor_name, FileAccess.get_file_as_bytes(output_path).size()])
	var verify_document := GLTFDocument.new()
	var verify_state := GLTFState.new()
	var read_error := verify_document.append_from_file(output_path, verify_state)
	if read_error != OK:
		_expect(false, "%s exported GLB re-imports (%s)" % [actor_name, error_string(read_error)])
		return
	var imported_root := verify_document.generate_scene(verify_state) as Node3D
	var imported_skeleton := _find_skeleton(imported_root)
	_expect(imported_skeleton == null, "%s exported GLB is static (no skeleton dependency)" % actor_name)
	var imported_meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(imported_root, imported_meshes)
	var imported_surface_count := 0
	for mesh_instance in imported_meshes:
		if mesh_instance.mesh != null:
			imported_surface_count += mesh_instance.mesh.get_surface_count()
	_expect(imported_surface_count > 0, "%s exported GLB retains visible mesh surfaces (%d)" % [actor_name, imported_surface_count])
	imported_root.free()

func _run() -> void:
	var packed := load("res://scenes/review/ara_pose_preview.tscn") as PackedScene
	if packed == null:
		_expect(false, "preview scene loads")
		quit(1)
		return
	var preview := packed.instantiate()
	root.add_child(preview)
	for i in range(30):
		await process_frame
	for actor_name in ["Femaleplayer", "Maleplayer", "Aldric", "Tavernpatron"]:
		var actor := preview.get_node_or_null(actor_name)
		_expect(actor != null, "%s actor instantiated" % actor_name)
		if actor == null:
			continue
		var model_root := actor.get("model_root") as Node3D
		var skeleton := _find_skeleton(model_root)
		_expect(skeleton != null, "%s visible skeleton found" % actor_name)
		if skeleton == null:
			continue
		var modifier := skeleton.get_node_or_null("ReviewNoseTouchPose")
		_expect(modifier != null, "%s late pose modifier attached" % actor_name)
		if modifier == null:
			continue
		var status := String(modifier.get("last_status"))
		var error_m := float(modifier.get("last_tip_error_m"))
		_expect(status == "nose touch active", "%s real-rig pose applied in modifier pass (%s)" % [actor_name, status])
		_expect(error_m >= 0.0 and error_m < 0.003, "%s fingertip tracks solved target (%.4f m)" % [actor_name, error_m])
		print("ARA_POSE_PREVIEW actor=%s bones=%d modifier=%s tip_error_m=%.6f" % [actor_name, skeleton.get_bone_count(), status, error_m])
		if status == "nose touch active" and error_m >= 0.0 and error_m < 0.003:
			await _export_and_verify(actor_name, model_root, skeleton)
	preview.queue_free()
	await process_frame
	print("ARA REAL POSE PREVIEW: %s" % ("PASS" if _failures == 0 else "%d failure(s)" % _failures))
	quit(1 if _failures > 0 else 0)
