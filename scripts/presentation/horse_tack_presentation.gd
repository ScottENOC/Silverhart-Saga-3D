class_name HorseTackPresentation
extends RefCounted
## Modular horse tack assets fitted to the Quaternius horse.
## Saddle and bridle are separate imported meshes and can be replaced independently.

const SADDLE_SCENE_PATH := "res://art/creatures/quaternius/tack/horse_saddle.glb"
const BRIDLE_SCENE_PATH := "res://art/creatures/quaternius/tack/horse_bridle.glb"


static func attach_to_horse(model_root: Node3D) -> Node3D:
	if model_root == null:
		return null
	var existing := model_root.get_node_or_null("HorseTack")
	if existing != null:
		return existing as Node3D

	var tack := Node3D.new()
	tack.name = "HorseTack"
	model_root.add_child(tack)

	_add_tack_asset(tack, "SaddleAsset", SADDLE_SCENE_PATH)
	_add_tack_asset(tack, "BridleAsset", BRIDLE_SCENE_PATH)
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
