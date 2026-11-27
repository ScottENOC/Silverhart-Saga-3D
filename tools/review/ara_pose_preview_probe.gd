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

func _remove_animation_mixers(node: Node) -> void:
	for child in node.get_children():
		if child is AnimationMixer:
			child.free()
		else:
			_remove_animation_mixers(child)

func _bake_mesh_instance(mesh_instance: MeshInstance3D) -> float:
	var started_usec := Time.get_ticks_usec()
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
		if original_vertices.size() == baked_vertices.size() and not original_vertices.is_empty():
			# A bounded sample is enough to prove the exported geometry moved. Scanning
			# every vertex in GDScript added avoidable work to an already expensive bake.
			var sample_count := mini(128, original_vertices.size())
			for sample_index in range(sample_count):
				var vertex_index := int(float(sample_index) * float(original_vertices.size()) / float(sample_count))
				max_vertex_delta = maxf(max_vertex_delta, original_vertices[vertex_index].distance_to(baked_vertices[vertex_index]))
	mesh_instance.mesh = baked
	mesh_instance.skin = null
	mesh_instance.skeleton = NodePath()
	print("ARA_BAKE_MESH name=%s surfaces=%d vertices=%d elapsed_s=%.2f delta_m=%.6f" % [
		mesh_instance.name, source_mesh.get_surface_count(),
		int(source_mesh.surface_get_array_len(0)) if source_mesh.get_surface_count() > 0 else 0,
		float(Time.get_ticks_usec() - started_usec) / 1000000.0, max_vertex_delta
	])
	return max_vertex_delta

func _bake_character_pose(export_root: Node3D, source_skeleton: Skeleton3D) -> Dictionary:
	# Snapshot the evaluated source pose before disabling/removing any modifiers.
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
	# A process frame is sufficient for Skeleton3D to evaluate in headless mode.
	# Waiting for RenderingServer.frame_post_draw can stall indefinitely on CI.
	await process_frame
	print("ARA_BAKE_POSE_READY bones=%d" % export_skeleton.get_bone_count())
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(export_root, mesh_instances)
	var baked_count := 0
	var maximum_delta := 0.0
	print("ARA_BAKE_BEGIN meshes=%d" % mesh_instances.size())
	for mesh_index in range(mesh_instances.size()):
		var mesh_instance := mesh_instances[mesh_index]
		if mesh_instance.skin == null:
			continue
		# The imported GLB's mesh skeleton path is relative to its original actor
		# hierarchy. Re-rooting the model for export can leave that path unresolved.
		var source_skin := mesh_instance.skin
		mesh_instance.skeleton = mesh_instance.get_path_to(export_skeleton)
		if mesh_instance.get_node_or_null(mesh_instance.skeleton) != export_skeleton:
			print("ARA_BAKE_SKIP invalid_skeleton_path mesh=%s path=%s" % [mesh_instance.name, mesh_instance.skeleton])
			continue
		# A duplicated MeshInstance can retain a stale SkinReference whose object
		# exists but whose RenderingServer skeleton RID has already been released.
		# Give this export skeleton its own Skin resource and let the MeshInstance3D
		# setter rebuild its internal SkinReference from the new resource.
		var export_skin := source_skin.duplicate() as Skin
		if export_skin == null:
			print("ARA_BAKE_SKIP skin_duplicate_failed mesh=%s" % mesh_instance.name)
			continue
		mesh_instance.skin = export_skin
		await process_frame
		var skin_ref := mesh_instance.get_skin_reference()
		var skeleton_rid := skin_ref.get_skeleton() if skin_ref != null else RID()
		var rid_valid := skeleton_rid.is_valid()
		var skin_matches := skin_ref != null and skin_ref.get_skin() == mesh_instance.skin
		print("ARA_SKIN_BIND mesh=%s ref=%s rid_valid=%s skin_matches=%s path=%s" % [
			mesh_instance.name, skin_ref != null, rid_valid, skin_matches, mesh_instance.skeleton
		])
		if not rid_valid:
			# Explicit registration is a fallback only after recording the setter's
			# result. Reassign once so MeshInstance3D resolves the registered Skin.
			var registered_ref := export_skeleton.register_skin(export_skin)
			print("ARA_SKIN_REGISTER mesh=%s ref=%s" % [mesh_instance.name, registered_ref != null])
			mesh_instance.skin = export_skin
			await process_frame
			skin_ref = mesh_instance.get_skin_reference()
			skeleton_rid = skin_ref.get_skeleton() if skin_ref != null else RID()
			rid_valid = skeleton_rid.is_valid()
			skin_matches = skin_ref != null and skin_ref.get_skin() == mesh_instance.skin
			print("ARA_SKIN_BIND_RETRY mesh=%s ref=%s rid_valid=%s skin_matches=%s" % [
				mesh_instance.name, skin_ref != null, rid_valid, skin_matches
			])
		if not rid_valid or not skin_matches:
			print("ARA_BAKE_SKIP invalid_skin_binding mesh=%s" % mesh_instance.name)
			continue
		var source_mesh := mesh_instance.mesh
		print("ARA_BAKE_START index=%d/%d name=%s surfaces=%d skeleton_path=%s" % [
			mesh_index + 1, mesh_instances.size(), mesh_instance.name,
			source_mesh.get_surface_count() if source_mesh != null else 0, mesh_instance.skeleton
		])
		var vertex_delta := _bake_mesh_instance(mesh_instance)
		if mesh_instance.mesh != source_mesh and mesh_instance.mesh is ArrayMesh and (mesh_instance.mesh as ArrayMesh).get_surface_count() > 0:
			baked_count += 1
			maximum_delta = maxf(maximum_delta, vertex_delta)
	if baked_count == 0:
		return {"ok": false, "baked_meshes": 0, "max_vertex_delta": 0.0, "reason": "no skinned meshes could be baked"}
	_remove_animation_mixers(export_root)
	var skeletons: Array[Skeleton3D] = []
	_collect_skeletons(export_root, skeletons)
	for skeleton_node in skeletons:
		skeleton_node.free()
	return {
		"ok": baked_count > 0,
		"baked_meshes": baked_count,
		"max_vertex_delta": maximum_delta,
		"reason": ""
	}

func _export_and_verify(actor_name: String, model_root: Node3D, source_skeleton: Skeleton3D) -> void:
	var source_bones := ArmRigBuilder.arm_bones(source_skeleton, &"right")
	if source_bones.is_empty() or int(source_bones["finger_tip"]) < 0:
		_expect(false, "%s has a named right fingertip bone for export verification" % actor_name)
		return
	var export_root := model_root.duplicate() as Node3D
	if export_root == null:
		_expect(false, "%s model duplicated for GLB export" % actor_name)
		return
	export_root.name = actor_name
	export_root.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(export_root)
	await process_frame
	var bake_result := await _bake_character_pose(export_root, source_skeleton)
	_expect(bool(bake_result["ok"]), "%s skinned meshes baked (%s)" % [actor_name, str(bake_result.get("reason", ""))])
	if not bool(bake_result["ok"]):
		export_root.free()
		return
	_expect(float(bake_result["max_vertex_delta"]) > 0.001, "%s baked geometry differs from bind-pose mesh (max vertex delta %.4f m)" % [actor_name, float(bake_result["max_vertex_delta"])])
	var export_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(export_dir)
	if dir_error != OK:
		_expect(false, "%s output directory created (%s)" % [actor_name, error_string(dir_error)])
		export_root.free()
		return
	var output_path := export_dir.path_join(actor_name.to_snake_case() + "_nose_touch.glb")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	state.create_animations = false
	# The pose is already baked into static mesh vertices; imported animation tracks
	# are deliberately excluded from this one-shot preview asset.
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
	# First deliverable is deliberately one character. The previous four-character
	# batch spent >13 minutes inside the first static mesh bake and produced no artifact.
	for actor_name in ["Femaleplayer"]:
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
			var export_started_usec := Time.get_ticks_usec()
			print("ARA_EXPORT_BEGIN actor=%s" % actor_name)
			await _export_and_verify(actor_name, model_root, skeleton)
			print("ARA_EXPORT_END actor=%s elapsed_s=%.2f" % [
				actor_name, float(Time.get_ticks_usec() - export_started_usec) / 1000000.0
			])
	preview.queue_free()
	await process_frame
	print("ARA REAL POSE PREVIEW: %s" % ("PASS" if _failures == 0 else "%d failure(s)" % _failures))
	quit(1 if _failures > 0 else 0)
