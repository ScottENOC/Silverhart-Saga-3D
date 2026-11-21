class_name Campaign2SettlementBuilder
extends RefCounted
## Presents canonical settlement layout and placement data in streamed chunks.
## Character identity/profile resolution is delegated to the character catalogue.

const HEX_RADIUS := HexGrid.DEFAULT_RADIUS_M
const CHARACTER_ACTOR_FACTORY = preload("res://scripts/presentation/campaign_character_actor_factory.gd")
const WORLD_BUILDING_FACTORY = preload("res://scripts/world/world_building_factory.gd")
const CHARACTER_REGISTRY_SCRIPT = preload("res://scripts/world/campaign2_character_definition_registry.gd")

var settlements: Array = []
var character_registry: Campaign2CharacterDefinitionRegistry

func _init(canonical_entries: Array = [], source_character_registry: Campaign2CharacterDefinitionRegistry = null) -> void:
	settlements = canonical_entries.duplicate(true)
	character_registry = source_character_registry
	if character_registry == null:
		character_registry = CHARACTER_REGISTRY_SCRIPT.new()

## Each building and character is attached only to the chunk containing its
## canonical world anchor. Chunk unloads retire presentation, not authored data.
func add_settlements_in_chunk(parent: Node3D, chunk_min: Vector2i, chunk_size: int) -> void:
	for entry in settlements:
		if not entry is Dictionary:
			continue
		var settlement_id := String(entry.get("id", ""))
		var origin: Vector2i = entry.get("origin", Vector2i.ZERO)
		var definition: Dictionary = entry.get("definition", {})
		var presentation: Dictionary = definition.get("presentation", {})
		if String(presentation.get("mode", "chunked")) != "chunked":
			continue
		var layout: Dictionary = definition.get("layout", {})
		var settlement_context := {"id": settlement_id}
		for source_building in layout.get("buildings", []):
			if not source_building is Dictionary:
				continue
			var building := _world_building(source_building, origin)
			var centre := _read_hex(building.get("center", {}))
			if _contains_chunk(centre, chunk_min, chunk_size):
				_build_building(parent, settlement_context, building)
		var placements: Dictionary = definition.get("placements", {})
		for placement in placements.get("characters", []):
			if not placement is Dictionary:
				continue
			var character_id := String(placement.get("character_id", placement.get("id", "")))
			if character_id.is_empty() or character_id == "player":
				continue
			var world_hex := _read_hex(placement.get("position", Vector2i.ZERO)) + origin
			if _contains_chunk(world_hex, chunk_min, chunk_size):
				_add_character(parent, character_id, world_hex)

func _world_building(source: Dictionary, origin: Vector2i) -> Dictionary:
	var building := source.duplicate(true)
	for coordinate_key in ["center", "door"]:
		if building.has(coordinate_key):
			building[coordinate_key] = _read_hex(building[coordinate_key]) + origin
	return building

func _build_building(parent: Node3D, settlement: Dictionary, building: Dictionary) -> void:
	if not WORLD_BUILDING_FACTORY.supports_definition(building):
		push_warning("Unsupported building definition: %s" % String(building.get("id", "<missing id>")))
		return
	WORLD_BUILDING_FACTORY.create_building(parent, settlement, building)

func _add_character(parent: Node3D, character_id: String, world_hex: Vector2i) -> void:
	var character := character_registry.get_character(character_id)
	if character.is_empty():
		push_warning("Settlement placement references missing character definition: %s" % character_id)
		return
	character["id"] = character_id
	var actor := CHARACTER_ACTOR_FACTORY.create_settlement_actor(
		character,
		HexGrid.axial_to_world(world_hex, HEX_RADIUS)
	)
	if actor == null:
		return
	parent.add_child(actor)

func _contains_chunk(hex: Vector2i, chunk_min: Vector2i, chunk_size: int) -> bool:
	return hex.x >= chunk_min.x and hex.x < chunk_min.x + chunk_size and hex.y >= chunk_min.y and hex.y < chunk_min.y + chunk_size

func _read_hex(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		return Vector2i(int(value.get("q", 0)), int(value.get("r", 0)))
	return Vector2i.ZERO
