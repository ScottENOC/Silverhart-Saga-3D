class_name Campaign2SettlementBuilder
extends RefCounted
## Builds source-described settlement structures and NPC presentation inside streamed chunks.
## The data layout is separate from the reusable 3D construction routines.

const HEX_RADIUS := HexGrid.DEFAULT_RADIUS_M
const CHARACTER_ACTOR_FACTORY = preload("res://scripts/presentation/campaign_character_actor_factory.gd")
const WORLD_BUILDING_FACTORY = preload("res://scripts/world/world_building_factory.gd")

var settlements: Array = []

func _init(source_layouts: Array = []) -> void:
	settlements = source_layouts.duplicate(true)

## Each building and NPC is attached only to the chunk containing its source anchor.
## When a chunk unloads, its settlement presentation unloads with it.
func add_settlements_in_chunk(parent: Node3D, chunk_min: Vector2i, chunk_size: int) -> void:
	for settlement in settlements:
		for building in settlement.get("buildings", []):
			var centre := _read_hex(building.get("center", {}))
			if _contains_chunk(centre, chunk_min, chunk_size):
				_build_building(parent, settlement, building)
		for npc in settlement.get("npcs", []):
			var position := _read_hex(npc.get("position", {}))
			if _contains_chunk(position, chunk_min, chunk_size):
				_add_npc(parent, npc)

## Settlement definitions are passed to the shared world factory. This class
## only handles chunk membership and actor presentation.
func _build_building(parent: Node3D, settlement: Dictionary, building: Dictionary) -> void:
	if not WORLD_BUILDING_FACTORY.supports_definition(building):
		push_warning("Unsupported building definition: %s" % String(building.get("id", "<missing id>")))
		return
	WORLD_BUILDING_FACTORY.create_building(parent, settlement, building)

func _add_npc(parent: Node3D, npc: Dictionary) -> void:
	var hex := _read_hex(npc.get("position", {}))
	var actor := CHARACTER_ACTOR_FACTORY.create_settlement_actor(
		npc,
		HexGrid.axial_to_world(hex, HEX_RADIUS)
	)
	if actor == null:
		return
	parent.add_child(actor)

func _contains_chunk(hex: Vector2i, chunk_min: Vector2i, chunk_size: int) -> bool:
	return hex.x >= chunk_min.x and hex.x < chunk_min.x + chunk_size and hex.y >= chunk_min.y and hex.y < chunk_min.y + chunk_size

func _read_hex(value: Dictionary) -> Vector2i:
	return Vector2i(int(value.get("q", 0)), int(value.get("r", 0)))
