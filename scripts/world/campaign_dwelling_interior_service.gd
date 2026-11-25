class_name CampaignDwellingInteriorService
extends RefCounted
## Opens the source-authored floor map for an owned player dwelling.
## Ownership/layout identity remains in CampaignDwellingState; this service
## converts that selected layout into the shared multi-story runtime.

const MULTISTORY_RUNTIME = preload("res://scripts/world/campaign2_multistory_location_runtime.gd")
const LOCATION_REGISTRY = preload("res://scripts/world/campaign2_multistory_location_registry.gd")

static func load_owned_dwelling(
	parent: Node,
	dwelling_state: CampaignDwellingState,
	simulation: WorldSimulation,
	dwelling_id: String,
	save_data: Dictionary = {}
) -> Dictionary:
	if parent == null or dwelling_state == null or simulation == null or dwelling_id.strip_edges().is_empty():
		return {"ok": false, "reason": "invalid_dwelling_interior_arguments"}
	var profile := dwelling_state.camp_profile_for(dwelling_id)
	if profile.is_empty():
		return {"ok": false, "reason": "dwelling_not_owned"}
	var layout_id := String(profile.get("layout_id", ""))
	var definition := _definition_for_layout(layout_id)
	if definition.is_empty():
		return {"ok": false, "reason": "unknown_dwelling_layout", "layout_id": layout_id}
	var runtime_name := "DwellingInterior_" + dwelling_id
	if parent.get_node_or_null(runtime_name) != null:
		return {"ok": false, "reason": "dwelling_interior_already_loaded", "dwelling_id": dwelling_id}
	definition["id"] = "dwelling_" + dwelling_id
	definition["name"] = String(definition.get("name", dwelling_id.replace("_", " ").capitalize()))
	definition["dwelling_id"] = dwelling_id
	definition["layout_id"] = layout_id
	var runtime := MULTISTORY_RUNTIME.new() as Campaign2MultiStoryLocationRuntime
	runtime.name = runtime_name
	runtime.configure_location(definition)
	runtime.configure_campaign(simulation, {}, save_data)
	if runtime.location_state == null:
		runtime.free()
		return {"ok": false, "reason": "could_not_configure_dwelling_interior", "dwelling_id": dwelling_id}
	parent.add_child(runtime)
	return {
		"ok": true,
		"dwelling_id": dwelling_id,
		"layout_id": layout_id,
		"location_id": String(definition.get("id", "")),
		"runtime": runtime
	}


static func _definition_for_layout(layout_id: String) -> Dictionary:
	match layout_id:
		"cottage_one_room":
			return _cottage_definition(false)
		"country_house_three_room":
			return _cottage_definition(true)
		"restored_roadside_house":
			return _restored_roadside_house_definition()
		"silverhart_manor_ruined":
			return _silverhart_manor_definition(false)
		"silverhart_manor_livable":
			return _silverhart_manor_definition(true)
	return {}


static func _cottage_definition(upgraded: bool) -> Dictionary:
	var centre := Vector2i(13, 27)
	var door := Vector2i(centre.x, centre.y + (3 if upgraded else 2))
	var suffix := "country_house" if upgraded else "cottage"
	var objects: Array[Dictionary] = [
		{"id": "crossroads_%s_south_door" % suffix, "type": "door_open", "position": _position(door), "light_radius": 0},
		{"id": "crossroads_%s_player_bed" % suffix, "type": "player_bed", "position": _position(centre), "light_radius": 0},
		{"id": "crossroads_%s_fireplace" % suffix, "type": "fireplace", "position": _position(centre + Vector2i(-1, 0)), "light_radius": 5}
	]
	if upgraded:
		objects.append({"id": "crossroads_country_house_table", "type": "table", "position": _position(centre + Vector2i(1, 0))})
		objects.append({"id": "crossroads_country_house_bench", "type": "bench", "position": _position(centre + Vector2i(1, -1))})
	else:
		objects.append({"id": "crossroads_cottage_storage_chest", "type": "storage_chest", "position": _position(centre + Vector2i(1, 0))})
	return {
		"id": "dwelling_crossroads_cottage",
		"name": "Crossroads Country House" if upgraded else "Crossroads Cottage",
		"anchor": _position(centre),
		"source": "Hex-crpg/campaign2World.js:buildPlayerCottage%s" % ("; upgradePlayerCottage" if upgraded else ""),
		"floors": [{
			"floor": 0,
			"name": "Ground Floor",
			"terrain": "wood_floor",
			"rooms": [{
				"id": "crossroads_%s_room" % suffix,
				"center": _position(centre),
				"half_width": 3 if upgraded else 2,
				"half_height": 3 if upgraded else 2,
				"row_shift_mode": "source_building"
			}],
			"corridors": [],
			"tile_objects": objects,
			"actors": [],
			"creatures": []
		}],
		"transitions": [],
		"quest_gates": [],
		"source_notes": [
			"The cottage is instantiated only after the player claims the surveyed crossroads plot.",
			"Room dimensions, source-building row shift, south doorway and furniture positions follow buildPlayerCottage%s." % (" and upgradePlayerCottage" if upgraded else "")
		]
	}


static func _restored_roadside_house_definition() -> Dictionary:
	var registry := LOCATION_REGISTRY.new() as Campaign2MultiStoryLocationRegistry
	if not registry.validation_errors.is_empty():
		return {}
	var definition := registry.get_definition("abandoned_house")
	if definition.is_empty():
		return {}
	var floor := _surface_floor(definition)
	if floor.is_empty():
		return {}
	var objects: Array = floor.get("tile_objects", [])
	objects.append({
		"id": "abandoned_house_player_bed",
		"type": "player_bed",
		"position": {"q": 13, "r": -176},
		"light_radius": 0
	})
	floor["tile_objects"] = objects
	definition["name"] = "Restored Roadside House"
	definition["source_notes"] = [
		"Uses the source Abandoned House room, entrance, journal and altar.",
		"Adds the player bed at centre.q - 1 only after renovateAbandonedHouse completes."
	]
	return definition


static func _silverhart_manor_definition(livable: bool) -> Dictionary:
	var registry := LOCATION_REGISTRY.new() as Campaign2MultiStoryLocationRegistry
	if not registry.validation_errors.is_empty():
		return {}
	var definition := registry.get_definition("silverhart_corstane_manor")
	if definition.is_empty():
		return {}
	if livable:
		var floor := _surface_floor(definition)
		if floor.is_empty():
			return {}
		var objects: Array = floor.get("tile_objects", [])
		objects.append({"id": "silverhart_manor_player_bed", "type": "player_bed", "position": {"q": 39, "r": -502}, "light_radius": 0})
		objects.append({"id": "silverhart_manor_fireplace", "type": "fireplace", "position": {"q": 38, "r": -502}, "light_radius": 5})
		floor["tile_objects"] = objects
	definition["name"] = "Livable Silverhart Manor" if livable else "Ruined Silverhart Manor"
	definition["source_notes"] = [
		"Uses the source Corstane manor floor and its irregular floor/wall masks.",
		"Fortification adds the player bed and fireplace at the source fortifySilverhartManor coordinates." if livable else "The royal grant conveys ownership but leaves the manor structurally ruined and without a bed."
	]
	return definition


static func _surface_floor(definition: Dictionary) -> Dictionary:
	for floor_variant in definition.get("floors", []):
		if floor_variant is Dictionary and int(floor_variant.get("floor", 999999)) == 0:
			return floor_variant
	return {}


static func _position(hex: Vector2i) -> Dictionary:
	return {"q": hex.x, "r": hex.y}
