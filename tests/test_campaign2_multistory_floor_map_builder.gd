extends SceneTree

const REGISTRY = preload("res://scripts/world/campaign2_multistory_location_registry.gd")
const LOCATION_STATE = preload("res://scripts/simulation/campaign2_multistory_location_state.gd")
const FLOOR_BUILDER = preload("res://scripts/world/campaign2_multistory_floor_map_builder.gd")
var failures: int = 0

func _initialize() -> void:
	var registry = REGISTRY.new()
	var definition: Dictionary = registry.get_definition("kragmoor")
	_check(not definition.is_empty(), "Kragmoor source floor definition must be available")
	var state = LOCATION_STATE.new()
	_check(bool(state.configure(definition).get("ok", false)), "Kragmoor traversal state must configure")

	for floor_number in [0, -1, -2, -3, -4, -5]:
		var result: Dictionary = FLOOR_BUILDER.build_floor_map(definition, floor_number, state)
		_check(bool(result.get("ok", false)), "Every Kragmoor floor must build a logical map: %d" % floor_number)
		if not bool(result.get("ok", false)):
			continue
		var map_data: HexMapData = result.get("map_data") as HexMapData
		_check(map_data != null and not map_data.cells.is_empty(), "Each floor must contain walkable and wall cells")
		for actor in result.get("actors", []):
			var position: Dictionary = actor.get("position", {})
			_check(map_data.is_walkable(Vector2i(int(position.get("q", 0)), int(position.get("r", 0)))), "Every source actor must stand on a walkable floor hex")
		for creature in result.get("creatures", []):
			var position: Dictionary = creature.get("position", {})
			_check(map_data.is_walkable(Vector2i(int(position.get("q", 0)), int(position.get("r", 0)))), "Every source creature must stand on a walkable floor hex")
		for tile_object in result.get("tile_objects", []):
			var position: Dictionary = tile_object.get("position", {})
			_check(map_data.is_walkable(Vector2i(int(position.get("q", 0)), int(position.get("r", 0)))), "Every tile object must be placed on a walkable floor hex")

	var guild_definition: Dictionary = registry.get_definition("silverhart_thieves_guild")
	var guild_state = LOCATION_STATE.new()
	_check(bool(guild_state.configure(guild_definition).get("ok", false)), "Thieves' Guild state must configure with its hidden vault")
	var concealed_guild: Dictionary = FLOOR_BUILDER.build_floor_map(guild_definition, 0, guild_state)
	var concealed_map: HexMapData = concealed_guild.get("map_data") as HexMapData
	_check(not _has_object(concealed_guild.get("tile_objects", []), "guild_hidden_vault_door"), "Undiscovered secret door must not be presented")
	_check(not _has_object(concealed_guild.get("tile_objects", []), "guild_vault_chest"), "Undiscovered vault contents must not be presented")
	_check(concealed_map.is_walkable(Vector2i(18, -426)), "The Guild's dead-end corridor must reach the concealed wall")
	_check(not concealed_map.is_walkable(Vector2i(19, -426)) and not concealed_map.is_walkable(Vector2i(20, -426)), "Undiscovered vault must remain sealed and absent from the walkable map")
	_check(bool(guild_state.discover_secret("guild_hidden_vault_door").get("ok", false)), "The Guild secret door must be discoverable in persistent location state")
	var revealed_guild: Dictionary = FLOOR_BUILDER.build_floor_map(guild_definition, 0, guild_state)
	var revealed_map: HexMapData = revealed_guild.get("map_data") as HexMapData
	_check(_has_object(revealed_guild.get("tile_objects", []), "guild_hidden_vault_door"), "Discovered secret door must be presented")
	_check(_has_object(revealed_guild.get("tile_objects", []), "guild_vault_chest"), "Discovered vault contents must be presented")
	_check(revealed_map.is_walkable(Vector2i(19, -426)) and revealed_map.is_walkable(Vector2i(20, -426)), "Discovered vault must become walkable through its hidden door")

	var gate_hall: Dictionary = FLOOR_BUILDER.build_floor_map(definition, 0, state)
	var gate_map: HexMapData = gate_hall.get("map_data") as HexMapData
	_check(gate_map.is_walkable(Vector2i(908, -605)), "The source Gate Hall entrance door must be walkable")
	_check(gate_map.is_walkable(Vector2i(908, -610)), "The Gate Hall stair must be walkable")

	var great_hall: Dictionary = FLOOR_BUILDER.build_floor_map(definition, -1, state)
	var great_map: HexMapData = great_hall.get("map_data") as HexMapData
	_check(great_map.has_cell(Vector2i(908, -630)) and not great_map.is_walkable(Vector2i(908, -630)), "The Great Hall must retain its source wall ring")

	var sealed: Dictionary = FLOOR_BUILDER.build_floor_map(definition, -4, state)
	_check(not _has_object(sealed.get("tile_objects", []), "transition_-4_-5"), "The final stair must not exist before the quest")
	_check((sealed.get("map_data") as HexMapData).is_walkable(Vector2i(890, -605)), "The hidden stair location remains part of the existing tunnel floor")
	_check(not _has_object(sealed.get("tile_objects", []), "transition_-4_-5"), "The hidden floor hex must not expose a stair object before the quest")
	state.complete_quest("deepholds_infestation")
	var revealed: Dictionary = FLOOR_BUILDER.build_floor_map(definition, -4, state)
	_check(_has_object(revealed.get("tile_objects", []), "transition_-4_-5"), "The quest must add the stair-down object to the Lower Tunnels")
	_check((revealed.get("map_data") as HexMapData).is_walkable(Vector2i(890, -605)), "The revealed stair hex must be walkable")

	if failures > 0:
		push_error("%d multi-story floor map test(s) failed." % failures)
		quit(1)
		return
	print("Kragmoor source-authored floor maps validated.")
	quit(0)

func _has_object(objects: Array, object_id: String) -> bool:
	for object in objects:
		if object is Dictionary and String(object.get("id", "")) == object_id:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
