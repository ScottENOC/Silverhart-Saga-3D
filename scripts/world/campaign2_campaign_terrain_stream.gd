extends "res://scripts/world/campaign2_regional_world_preview.gd"
class_name Campaign2CampaignTerrainStream
## Reuses the regional terrain renderer inside the authoritative main campaign.
## It deliberately does not create a second simulation, player, camera or UI.
## Hollowmere itself remains owned by its existing location presenter; all
## surrounding chunks are rendered against the campaign's shared WorldSimulation.

var campaign_simulation: WorldSimulation


func configure_campaign(
	source_simulation: WorldSimulation,
	_profile: Dictionary = {},
	_save_data: Dictionary = {}
) -> void:
	campaign_simulation = source_simulation


func _ready() -> void:
	if campaign_simulation == null:
		push_error("Campaign2CampaignTerrainStream requires the WorldRoot campaign simulation.")
		return

	terrain_data = TERRAIN_DATA_SCRIPT.new() as Campaign2WorldTerrainData
	ecology_simulation = campaign_simulation

	# Hollowmere is already presented by its authored location component in the
	# main campaign. Do not spawn a second copy of its buildings, vegetation or
	# presentation-only actors when its surrounding terrain chunks are streamed.
	var streamed_settlements: Array = []
	for entry in terrain_data.settlement_layouts:
		if not entry is Dictionary:
			continue
		if String(entry.get("id", "")) == "hollowmere":
			continue
		streamed_settlements.append(entry)
	settlement_builder = SETTLEMENT_BUILDER_SCRIPT.new(
		streamed_settlements,
		null,
		campaign_simulation
	) as Campaign2SettlementBuilder

	_create_materials()

	var player_id := campaign_simulation.player_character_id
	var player_state := campaign_simulation.get_character(player_id)
	if player_state == null:
		push_error("Campaign2CampaignTerrainStream could not find the campaign player: %s" % player_id)
		return

	target = _world_position_for_hex(player_state.axial)
	if not campaign_simulation.character_moved.is_connected(_on_campaign_character_moved):
		campaign_simulation.character_moved.connect(_on_campaign_character_moved)
	_update_streamed_chunks(true)


func _on_campaign_character_moved(character_id: String, _from_hex: Vector2i, to_hex: Vector2i) -> void:
	if campaign_simulation == null or character_id != campaign_simulation.player_character_id:
		return
	# Multi-storey interiors use virtual coordinates. Keep the exterior stream
	# resident while the player is upstairs; resume following on exit.
	if _is_virtual_interior_hex(to_hex):
		return
	target = _world_position_for_hex(to_hex)
	_update_streamed_chunks(false)


func _is_virtual_interior_hex(hex: Vector2i) -> bool:
	if campaign_simulation == null or campaign_simulation.building_registry == null:
		return false
	for definition_value in campaign_simulation.building_registry.definitions.values():
		if not definition_value is Dictionary:
			continue
		var bounds: Variant = definition_value.get("virtual_floor_bounds", [])
		if bounds is Array and bounds.size() == 4:
			if (
				hex.x >= int(bounds[0])
				and hex.x <= int(bounds[1])
				and hex.y >= int(bounds[2])
				and hex.y <= int(bounds[3])
			):
				return true
	return false


# The regional preview's floating location labels are useful for map inspection,
# but are not part of the main campaign's in-world presentation.
func _add_chunk_locations(_parent: Node3D, _chunk: Vector2i) -> void:
	pass


func _unhandled_input(_event: InputEvent) -> void:
	# Do not inherit the regional preview's Escape/menu, camera or movement input.
	# The campaign's existing camera and HollowTankard controller remain in charge.
	pass
