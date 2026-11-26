class_name CampaignQuestEventRouter
extends RefCounted
## Bridges simulation lifecycle events to campaign quest services. Location
## scenes only bind this router; quest consequences stay in simulation services.

const GOBLIN_RUNTIME_SERVICE = preload("res://scripts/simulation/goblin_threat_campaign_runtime_service.gd")

var _simulation: WorldSimulation
var _scene_tree: SceneTree
var _local_actor_by_id: Dictionary = {}


func bind(simulation: WorldSimulation, scene_tree: SceneTree = null, local_actor_by_id: Dictionary = {}) -> void:
	_simulation = simulation
	_scene_tree = scene_tree
	_local_actor_by_id = local_actor_by_id
	if _simulation == null:
		return
	var tick_callback := Callable(self, "_on_world_tick")
	if not _simulation.world_tick.is_connected(tick_callback):
		_simulation.world_tick.connect(tick_callback)
	_track_characters()


func _on_world_tick(_tick_index: int, _world_seconds: float) -> void:
	_track_characters()


func _track_characters() -> void:
	if _simulation == null:
		return
	var callback := Callable(self, "_on_character_lifecycle_changed")
	for state in _simulation.character_states():
		if state != null and not state.lifecycle_changed.is_connected(callback):
			state.lifecycle_changed.connect(callback)


func _on_character_lifecycle_changed(character_id: String, transition: String) -> void:
	if _simulation == null or transition not in ["died", "died_from_poison"]:
		return
	if character_id != "chief_skarnub":
		return
	if bool(_simulation.campaign_journal.world_campaign_flag("skarnub_assassinated", false)):
		return
	GOBLIN_RUNTIME_SERVICE.resolve_threat(
		_simulation,
		"assault",
		null,
		_scene_tree,
		_local_actor_by_id
	)
