extends SceneTree

const LOCATION_LOADER = preload("res://scripts/world/campaign2_location_loader.gd")
const KRAGMOOR_LOCATION = preload("res://data/world/locations/kragmoor.gd")
const FLOOR_PRESENTER = preload("res://scripts/world/campaign2_multistory_floor_presenter.gd")
const SIMULATION = preload("res://scripts/simulation/world_simulation.gd")
var failures: int = 0

func _initialize() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var simulation := SIMULATION.new() as WorldSimulation
	root.add_child(simulation)
	var loaded: Dictionary = LOCATION_LOADER.load_location(
		root,
		KRAGMOOR_LOCATION.DEFINITION,
		simulation,
		{},
		{}
	)
	_check(bool(loaded.get("ok", false)), "Kragmoor must load through the generic location component loader")
	await process_frame
	var components: Dictionary = loaded.get("components", {})
	var presenter := components.get("multi_story_floor_presenter") as Campaign2MultiStoryFloorPresenter
	_check(presenter != null, "Kragmoor location must instantiate its multi-story floor presenter")
	if presenter == null:
		root.queue_free()
		quit(1)
		return
	_check(presenter.get_current_floor() == 0, "A new Kragmoor visit must present the surface Gate Hall")
	_check(presenter.get_map_data() != null and not presenter.get_map_data().cells.is_empty(), "The presenter must render a real logical floor map")
	_check(presenter.get_node_or_null("HexTerrainRenderer") != null, "The presenter must create the shared 3D hex terrain renderer")
	_check(presenter.get_node_or_null("StoneWallGeometry") != null and presenter.get_node("StoneWallGeometry").get_child_count() > 0, "The presenter must render the source room wall ring as 3D stone walls")
	_check(presenter.get_node_or_null("TileObjectVisuals") != null, "The presenter must render source stair and door markers")

	var route := [
		{"floor": -1, "stair": Vector2i(908, -610)},
		{"floor": -2, "stair": Vector2i(908, -626)},
		{"floor": -3, "stair": Vector2i(890, -627)},
		{"floor": -4, "stair": Vector2i(890, -617)}
	]
	for step in route:
		var transition: Dictionary = presenter.try_use_stair(step["stair"])
		_check(bool(transition.get("ok", false)) and presenter.get_current_floor() == int(step["floor"]), "Kragmoor must switch floors through each source stair")
	var sealed := presenter.try_use_stair(Vector2i(890, -605))
	_check(not bool(sealed.get("ok", false)) and String(sealed.get("reason", "")) == "no_stair_at_position", "The Sunken Deep stair must be absent before the quest event")

	simulation.campaign_journal.journal_event.emit({"event_type": "quest_completed", "quest_id": "deepholds_infestation"})
	_check(_has_object(presenter.get_tile_objects(), "transition_-4_-5"), "The campaign journal quest event must reveal the Sunken Deep stair")
	var descent := presenter.try_use_stair(Vector2i(890, -605))
	_check(bool(descent.get("ok", false)) and presenter.get_current_floor() == -5, "The revealed stair must enter the Sunken Deep")
	_check(presenter.get_actor_placements().is_empty(), "Sunken Deep must not invent NPCs absent from the source")
	_check(presenter.get_creature_placements().size() == 1, "Sunken Deep must expose the source Horror placement")

	var saved_state: Dictionary = presenter.to_dict()
	var restored_root := Node3D.new()
	get_root().add_child(restored_root)
	var restored_simulation := SIMULATION.new() as WorldSimulation
	restored_root.add_child(restored_simulation)
	var restored_location := LOCATION_LOADER.load_location(
		restored_root,
		KRAGMOOR_LOCATION.DEFINITION,
		restored_simulation,
		{},
		{"multi_story_locations": {"kragmoor": saved_state}}
	)
	await process_frame
	var restored_components: Dictionary = restored_location.get("components", {})
	var restored := restored_components.get("multi_story_floor_presenter") as Campaign2MultiStoryFloorPresenter
	_check(bool(restored_location.get("ok", false)) and restored != null, "Kragmoor floor state must load through the location loader")
	if restored != null:
		_check(restored.get_current_floor() == -5, "Save data must restore the current Deepholds floor")
		_check(_has_object(restored.get_tile_objects(), "transition_-4_-5"), "Save data must preserve the revealed Sunken Deep passage")

	root.queue_free()
	restored_root.queue_free()
	if failures > 0:
		push_error("%d Kragmoor floor presentation test(s) failed." % failures)
		quit(1)
		return
	print("Kragmoor floor presentation, transitions, quest event and location save state validated.")
	quit(0)

func _has_object(objects: Array[Dictionary], object_id: String) -> bool:
	for object in objects:
		if String(object.get("id", "")) == object_id:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
