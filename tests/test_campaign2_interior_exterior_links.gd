extends SceneTree

const REGISTRY = preload("res://scripts/world/campaign2_interior_exterior_link_registry.gd")
const LOCATION_REGISTRY = preload("res://scripts/world/campaign2_multistory_location_registry.gd")
const SETTLEMENT_LAYOUTS_PATH := "res://data/world/campaign2_settlement_layouts.json"
const HOLLOWMERE_BUILDINGS_PATH := "res://data/settlements/hollowmere/buildings.gd"
const LINK_MANIFEST_PATH := "res://data/world/campaign2_interior_exterior_links.json"

var failures: int = 0

func _initialize() -> void:
	var registry = REGISTRY.new()
	_check(registry.validation_errors.is_empty(), "Authored interior/exterior identity links must validate")
	var locations = LOCATION_REGISTRY.new()
	_check(locations.validation_errors.is_empty(), "Source interior locations must validate")
	_check(registry.location_ids() == locations.location_ids(), "Every interior location must have exactly one explicit reconciliation record")
	_check(registry.location_ids().size() == 71, "All 71 current interior locations must be classified")

	var settlement_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTLEMENT_LAYOUTS_PATH))
	_check(settlement_data is Dictionary, "Canonical settlement layout manifest must parse")
	var settlement_building_ids: Dictionary = {}
	if settlement_data is Dictionary:
		for settlement in settlement_data.get("settlements", []):
			for building in settlement.get("buildings", []):
				settlement_building_ids[String(building.get("id", ""))] = building
	var hollowmere_building_centres := {
		"chapel": Vector2i(-14, 0),
		"general_store": Vector2i(0, 18),
		"elder_house": Vector2i(0, -12),
		"mira_house": Vector2i(12, 9),
		"oskar_house": Vector2i(-6, 9)
	}
	var hollowmere_source := FileAccess.get_file_as_string(HOLLOWMERE_BUILDINGS_PATH)

	var all_building_ids: Dictionary = {}
	for location_id in registry.location_ids():
		var link: Dictionary = registry.get_link(location_id)
		for building_id_variant in link.get("building_ids", []):
			var building_id := String(building_id_variant)
			_check(not all_building_ids.has(building_id), "An exterior building may only be owned by one interior location: " + building_id)
			all_building_ids[building_id] = location_id
			if settlement_building_ids.has(building_id):
				_check(true, "Settlement catalogue ID resolves: " + building_id)
			else:
				_check(hollowmere_source.contains('"id": "' + building_id + '"'), "Hollowmere building ID must resolve to its authored building definition: " + building_id)
		for room_link_variant in link.get("room_links", []):
			var room_link: Dictionary = room_link_variant
			var floor_definition := locations.get_floor_definition(location_id, int(room_link.get("floor", 999999)))
			var room_found := false
			var room_centre := Vector2i.ZERO
			for room in floor_definition.get("rooms", []):
				if String(room.get("id", "")) == String(room_link.get("room_id", "")):
					room_found = true
					var centre: Dictionary = room.get("center", {})
					room_centre = Vector2i(int(centre.get("q", 0)), int(centre.get("r", 0)))
					break
			_check(room_found, "Room link must resolve to a source-authored room: %s/%s" % [location_id, room_link.get("room_id", "")])
			var building_id := String(room_link.get("building_id", ""))
			if settlement_building_ids.has(building_id):
				var exterior_centre: Dictionary = settlement_building_ids[building_id].get("center", {})
				_check(room_centre == Vector2i(int(exterior_centre.get("q", 0)), int(exterior_centre.get("r", 0))), "Stable-ID room join must retain its authored centre alignment: %s/%s" % [location_id, building_id])
			elif hollowmere_building_centres.has(building_id):
				_check(room_centre == hollowmere_building_centres[building_id], "Hollowmere stable-ID room join must retain its authored centre alignment: %s/%s" % [location_id, building_id])

	var palace := registry.get_link("silverhart_palace")
	_check(palace.get("building_ids", []).has("silverhart_grand_hall"), "Palace grand hall must link by stable ID")
	_check(palace.get("building_ids", []).has("silverhart_queens_bedroom"), "Palace queen's chambers must link to their own exterior building ID")
	_check(palace.get("room_links", []).size() == 3, "Palace floor rooms must each have an explicit building join")
	var guild := registry.get_link("silverhart_thieves_guild")
	_check(guild.get("building_ids", []).has("silverhart_thieves_guild") and guild.get("building_ids", []).has("silverhart_thieves_guild_vault"), "Guild and hidden vault must retain separate stable exterior IDs")
	_check(guild.get("room_links", []).size() == 2, "Guild and vault rooms must each have an explicit building join")
	_check(registry.get_link("emberlode_mine").get("building_ids", []).has("emberlode_mine_entrance"), "Mine floors must remain linked to the physical surface entrance building")
	_check(registry.get_link("silverhart_corstane_manor").get("status", "") == "geometry_incomplete", "Corstane identity may be linked while its missing room geometry remains explicit")
	_check(registry.get_link("silverhart_corvane_embassy").get("status", "") == "review_required", "Corvane's one-hex offset must remain unresolved")
	_check(registry.get_link("silverhart_builder_house").get("status", "") == "review_required", "Builder's House offset and empty room must remain unresolved")
	for location_id in ["hollowmere_store", "hollowmere_tavern", "hollowmere_guild_den"]:
		_check(registry.get_link(location_id).get("status", "") == "exterior_missing", "Unpaired Hollowmere building must remain visible for reconciliation: " + location_id)
	_check(registry.get_link("silverhart_palace_tunnel").get("transition_policy", "") == "named_secret_tunnel_network_exception", "Secret tunnel network must remain an explicit special-case exception")
	for location_id in ["kragmoor", "emberlode_mine", "thieves_cove"]:
		_check(registry.get_link(location_id).get("transition_policy", "") == "physical_surface_entrance_streamed_deep_floors", "Deep cave sites may retain streamed lower floors: " + location_id)

	var invalid := registry.configure({
		"schema_version": 1,
		"coordinate_system": "campaign2_local_axial_qr",
		"links": [
			{"location_id": "duplicate", "integration_kind": "building", "status": "linked", "building_ids": ["same"], "room_links": [], "transition_policy": "physical_continuous_world"},
			{"location_id": "duplicate", "integration_kind": "building", "status": "linked", "building_ids": ["other"], "room_links": [], "transition_policy": "physical_continuous_world"}
		]
	})
	_check(not bool(invalid.get("ok", true)), "Registry must reject duplicate interior location IDs")
	if failures > 0:
		push_error("%d interior/exterior identity test(s) failed." % failures)
		quit(1)
		return
	print("Campaign 2 interior/exterior identity tests passed.")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
