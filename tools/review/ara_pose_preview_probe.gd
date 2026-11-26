extends SceneTree
## Headless acceptance check for the real-character pose preview.
## Runs PoseApplier from the late SkeletonModifier3D on four committed GLBs.

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _find_skeleton(node: Node) -> Skeleton3D:
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
		var skeleton := _find_skeleton(model_root) if model_root != null else null
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
		print("ARA_POSE_PREVIEW actor=%s bones=%d modifier=%s tip_error_m=%.6f" % [
			actor_name, skeleton.get_bone_count(), status, error_m
		])
	preview.queue_free()
	await process_frame
	print("ARA REAL POSE PREVIEW: %s" % ("PASS" if _failures == 0 else "%d failure(s)" % _failures))
	quit(1 if _failures > 0 else 0)
