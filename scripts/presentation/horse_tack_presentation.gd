class_name HorseTackPresentation
extends RefCounted
## Modular horse tack assets fitted to the Quaternius horse.
## Source and target body bounds indicate a ~2.4x size difference and a
## +0.61 model-space Z-origin offset. Tack assets are fitted independently
## beneath the imported horse model, so CreatureActor's model scale applies
## equally to horse and tack.

const SADDLE_SCENE_PATH := "res://art/creatures/quaternius/tack/horse_saddle.glb"
const BRIDLE_SCENE_PATH := "res://art/creatures/quaternius/tack/horse_bridle.glb"

# Ratios derived from source/target body bounds:
# source body: X +/-0.290, Y 0..1.953, Z +/-1.294
# target body: X -0.703..0.703, Y -0.011..4.813, Z -2.223..3.453
const TACK_FIT_SCALE := Vector3(2.43, 2.47, 2.20)
const TACK_FIT_ORIGIN := Vector3(0.0, 0.0, 0.615)


static func attach_to_horse(model_root: Node3D) -> Node3D:
	if model_root == null:
		return null
	var existing := model_root.get_node_or_null("HorseTack")
	if existing != null:
		return existing as Node3D

	var tack := Node3D.new()
	tack.name = "HorseTack"
	model_root.add_child(tack)

	var saddle := _add_tack_asset(tack, "SaddleAsset", SADDLE_SCENE_PATH)
	if saddle != null:
		saddle.scale = TACK_FIT_SCALE
		saddle.position = TACK_FIT_ORIGIN

	var bridle := _add_tack_asset(tack, "BridleAsset", BRIDLE_SCENE_PATH)
	if bridle != null:
		bridle.scale = TACK_FIT_SCALE
		bridle.position = TACK_FIT_ORIGIN
	return tack


static func _add_tack_asset(parent: Node3D, instance_name: String, scene_path: String) -> Node3D:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("Horse tack asset could not be loaded: %s" % scene_path)
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_error("Horse tack asset root is not Node3D: %s" % scene_path)
		return null
	instance.name = instance_name
	parent.add_child(instance)
	return instance
