class_name Campaign2SettlementBuilder
extends RefCounted
## Presents canonical settlement layout and placement data in streamed chunks.
## Character identity/profile resolution is delegated to the character catalogue.

const HEX_RADIUS := HexGrid.DEFAULT_RADIUS_M
const CHARACTER_ACTOR_FACTORY = preload("res://scripts/presentation/campaign_character_actor_factory.gd")
const FEATURE_COMPOSER = preload("res://scripts/world/world_settlement_feature_composer.gd")
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
		var composition := FEATURE_COMPOSER.compose_chunk(
			parent,
			entry,
			chunk_min,
			chunk_size,
			HEX_RADIUS
		)
		if not bool(composition.get("ok", false)):
			push_warning("Settlement feature composition failed for %s: %s" % [settlement_id, composition])

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
