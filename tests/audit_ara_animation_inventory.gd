extends SceneTree
## Prints the real animation inventory embedded in the Ara benchmark GLB.
## Run with:
## godot --headless --path . --script res://tests/audit_ara_animation_inventory.gd

const CARRIER_PATH := "res://art/characters/ara_runtime/ara_person_benchmark.glb"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists(CARRIER_PATH):
		push_error("Ara animation carrier is missing: " + CARRIER_PATH)
		quit(1)
		return

	var packed := load(CARRIER_PATH) as PackedScene
	if packed == null:
		push_error("Could not load Ara animation carrier as PackedScene.")
		quit(1)
		return

	var instance := packed.instantiate()
	var animation_player := _find_animation_player(instance)
	if animation_player == null:
		push_error("No AnimationPlayer found in Ara animation carrier.")
		instance.free()
		quit(1)
		return

	print("=== ARA ANIMATION INVENTORY ===")
	print("Asset: %s" % CARRIER_PATH)
	print("AnimationPlayer: %s" % str(instance.get_path_to(animation_player)))
	var skeleton := _find_skeleton(instance)
	print("Skeleton: %s" % (str(instance.get_path_to(skeleton)) if skeleton != null else "<none>"))
	print("Clip count: %d" % animation_player.get_animation_list().size())

	var names := animation_player.get_animation_list()
	names.sort()
	var totals := {
		"locomotion": 0,
		"idle": 0,
		"attack": 0,
		"defence": 0,
		"hit_or_death": 0,
		"gesture_or_social": 0,
		"other": 0
	}

	for clip_name in names:
		var animation := animation_player.get_animation(clip_name)
		var category := _classify(String(clip_name).to_lower())
		totals[category] += 1
		var bone_tracks := 0
		var property_tracks := 0
		var other_tracks := 0
		for track_index in range(animation.get_track_count()):
			var track_path := str(animation.track_get_path(track_index)).to_lower()
			var track_type := animation.track_get_type(track_index)
			if track_path.contains("skeleton") or track_path.contains("armature") or track_path.contains("bone"):
				bone_tracks += 1
			elif track_type == Animation.TYPE_VALUE:
				property_tracks += 1
			else:
				other_tracks += 1
		print("CLIP | %s | category=%s | duration=%.3fs | tracks=%d | bone_paths=%d | property=%d | other=%d | loop_mode=%d" % [
			String(clip_name), category, animation.length, animation.get_track_count(),
			bone_tracks, property_tracks, other_tracks, animation.loop_mode
		])

	print("=== CATEGORY TOTALS ===")
	for category in totals:
		print("%s: %d" % [category, totals[category]])
	print("=== END INVENTORY ===")
	instance.free()
	quit(0)

func _classify(name: String) -> String:
	if _has_any(name, ["walk", "run", "jog", "locomotion", "sprint", "strafe"]):
		return "locomotion"
	if _has_any(name, ["idle", "stand", "breath", "look", "shift", "wait"]):
		return "idle"
	if _has_any(name, ["attack", "sword", "slash", "thrust", "stab", "swing", "cast", "shoot", "fire"]):
		return "attack"
	if _has_any(name, ["block", "guard", "parry", "dodge", "evade", "defend"]):
		return "defence"
	if _has_any(name, ["hit", "hurt", "damage", "death", "die", "fall", "stagger", "knock"]):
		return "hit_or_death"
	if _has_any(name, ["talk", "speak", "wave", "point", "sit", "cheer", "laugh", "gesture", "greet"]):
		return "gesture_or_social"
	return "other"

func _has_any(value: String, tokens: Array[String]) -> bool:
	for token in tokens:
		if value.contains(token):
			return true
	return false

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
