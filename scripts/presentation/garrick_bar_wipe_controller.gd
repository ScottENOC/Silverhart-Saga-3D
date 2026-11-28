class_name GarrickBarWipeController
extends Node
## Owns the Hollow Tankard innkeeper's ambient bar-cleaning activity.
## Scene-specific placement and interruption live here, not in HollowTankard.

const BAR_WIPE_MODIFIER := preload("res://scripts/presentation/garrick_bar_wipe_modifier.gd")

const BAR_STATION_POSITION := Vector3(1.875, 0.0, -3.65)
const BAR_STATION_FACING_Y := 0.0
const BAR_TOP_SURFACE_Y := 1.33
const BAR_WIPE_TIP_HEIGHT := BAR_TOP_SURFACE_Y + 0.015
const BAR_WIPE_START_LOCAL := Vector3(1.55, BAR_WIPE_TIP_HEIGHT, -4.08)
const BAR_WIPE_END_LOCAL := Vector3(2.15, BAR_WIPE_TIP_HEIGHT, -4.08)

var modifier: GarrickBarWipeModifier
var _actor_root: Node3D
var _ara_actor: AraCharacterActor
var _interruption_source: Callable
var _return_to_station_source: Callable
var _was_interrupted: bool = false
var _warned_missing_actor: bool = false


func configure(actor_root: Node3D, interruption_source: Callable, return_to_station_source: Callable = Callable()) -> void:
	_actor_root = actor_root
	_interruption_source = interruption_source
	_return_to_station_source = return_to_station_source
	if _actor_root != null:
		_actor_root.position = BAR_STATION_POSITION
		_actor_root.rotation.y = BAR_STATION_FACING_Y
	_try_attach_modifier()


func _process(_delta: float) -> void:
	if modifier == null:
		_try_attach_modifier()
		if modifier == null:
			return
	var interrupted := _is_interrupted()
	if interrupted:
		modifier.active = false
	else:
		if _was_interrupted and not _return_to_bar_station():
			modifier.active = false
			return
		modifier.active = true
	_was_interrupted = interrupted


func _try_attach_modifier() -> void:
	if _actor_root == null or not is_instance_valid(_actor_root):
		return
	_ara_actor = _actor_root.get_node_or_null("CharacterModel") as AraCharacterActor
	if _ara_actor == null or _ara_actor.model_root == null:
		if not _warned_missing_actor:
			_warned_missing_actor = true
			push_warning("Garrick bar wipe: CharacterModel or its Ara model is not ready yet.")
		return
	var skeleton := _find_skeleton(_ara_actor.model_root)
	if skeleton == null:
		if not _warned_missing_actor:
			_warned_missing_actor = true
			push_warning("Garrick bar wipe: Garrick's Ara model has no Skeleton3D.")
		return
	modifier = BAR_WIPE_MODIFIER.new() as GarrickBarWipeModifier
	modifier.name = "GarrickBarWipePose"
	skeleton.add_child(modifier) # Runs after AraAnimationRetargeter.
	modifier.configure(to_global(BAR_WIPE_START_LOCAL), to_global(BAR_WIPE_END_LOCAL), Vector3.DOWN, 3.2)
	modifier.active = not _is_interrupted()
	_ara_actor.play_idle()


func _is_interrupted() -> bool:
	return _interruption_source.is_valid() and bool(_interruption_source.call())


func _return_to_bar_station() -> bool:
	if _actor_root == null or not is_instance_valid(_actor_root):
		return false
	if _return_to_station_source.is_valid() and not bool(_return_to_station_source.call()):
		return false
	if _actor_root.has_method("stop_moving"):
		_actor_root.call("stop_moving")
	_actor_root.position = BAR_STATION_POSITION
	_actor_root.rotation.y = BAR_STATION_FACING_Y
	if _ara_actor != null and is_instance_valid(_ara_actor):
		_ara_actor.play_idle()
	return true


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null
