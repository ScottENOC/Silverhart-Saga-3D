extends Node3D
## Review scene: four actual game GLBs, each with the production carrier retargeter
## and a late procedural nose-touch modifier. This scene is not used by gameplay.

const ACTOR_SCRIPT := preload("res://scripts/presentation/ara_character_actor.gd")
const POSE_MODIFIER := preload("res://tools/review/ara_pose_preview_modifier.gd")

const SUBJECTS := [
	{"label": "Female player", "path": "res://art/characters/ara_runtime/ara_player_female_body.glb"},
	{"label": "Male player", "path": "res://art/characters/ara_runtime/ara_player_male_body.glb"},
	{"label": "Aldric", "path": "res://art/characters/companions/aldric.glb"},
	{"label": "Tavern patron", "path": "res://art/characters/hollowmere/tavern_patron.glb"},
]


func _ready() -> void:
	for i in range(SUBJECTS.size()):
		var subject: Dictionary = SUBJECTS[i]
		var actor := ACTOR_SCRIPT.new() as Node3D
		actor.name = String(subject["label"]).replace(" ", "")
		add_child(actor)
		actor.position = Vector3((i - 1.5) * 1.65, 0.0, 0.0)
		if not actor.configure(subject["path"]):
			push_error("ARA POSE PREVIEW: failed to load %s" % subject["label"])
			continue
		var skeleton := _find_skeleton(actor)
		if skeleton == null:
			push_error("ARA POSE PREVIEW: no skeleton for %s" % subject["label"])
			continue
		var modifier := POSE_MODIFIER.new() as SkeletonModifier3D
		modifier.name = "ReviewNoseTouchPose"
		skeleton.add_child(modifier) # Deliberately after AraAnimationRetargeter.
		var label := Label3D.new()
		label.text = String(subject["label"])
		label.position = Vector3(0.0, 2.0, 0.0)
		label.font_size = 48
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		actor.add_child(label)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
