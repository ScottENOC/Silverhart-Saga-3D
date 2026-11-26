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
	_remove_modifiers(export_root)
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
	_expect(true, "%s GLB exported (%d bytes)" % [actor_name, FileAccess.get_file_as_bytes(output_path).size()])
	var verify_document := GLTFDocument.new()
	var verify_state := GLTFState.new()
	var read_error := verify_document.append_from_file(output_path, verify_state)
	if read_error != OK:
		_expect(false, "%s exported GLB re-imports (%s)" % [actor_name, error_string(read_error)])
		return
	var imported_root := verify_document.generate_scene(verify_state) as Node3D
	var imported_skeleton := _find_skeleton(imported_root)
	if imported_skeleton == null:
		_expect(false, "%s exported GLB contains a skeleton" % actor_name)
		imported_root.free()
		return
	var imported_tip := ArmRigBuilder.find_bone(imported_skeleton, [source_tip_name])
	if imported_tip < 0:
		_expect(false, "%s exported GLB retains fingertip bone %s" % [actor_name, source_tip_name])
	else:
		var imported_tip_position := imported_skeleton.get_bone_global_pose(imported_tip).origin
		var error_m := imported_tip_position.distance_to(source_tip_position)
		_expect(error_m < 0.003, "%s exported pose retained (fingertip delta %.4f m)" % [actor_name, error_m])
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
			_export_and_verify(actor_name, model_root, skeleton)
	preview.queue_free()
	await process_frame
	print("ARA REAL POSE PREVIEW: %s" % ("PASS" if _failures == 0 else "%d failure(s)" % _failures))
	quit(1 if _failures > 0 else 0)
