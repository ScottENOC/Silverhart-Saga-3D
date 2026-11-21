extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
var failures: int = 0

func _initialize() -> void:
	var terrain = TERRAIN_DATA.new()
	var entries: Array = terrain.settlement_layouts
	_check(entries.size() == 2, "Canonical registry should expose Hollowmere and Millbrook")
	var millbrook_entry := _entry_by_id(entries, "millbrook")
	_check(not millbrook_entry.is_empty(), "Canonical Millbrook definition must be available")
	if millbrook_entry.is_empty():
		quit(1)
		return
	var definition: Dictionary = millbrook_entry.get("definition", {})
	var layout: Dictionary = definition.get("layout", {})
	var origin: Vector2i = millbrook_entry.get("origin", Vector2i.ZERO)
	_check(origin == Vector2i.ZERO, "Millbrook origin must preserve its existing global axial coordinates")
	_check(String(definition.get("presentation", {}).get("mode", "")) == "chunked", "Millbrook must be owned by the streamed chunk presenter")
	_check(String(definition.get("id", "")) == "millbrook", "Settlement ID must remain stable")
	_assert_axial(definition.get("origin", {}), Vector2i.ZERO, "Millbrook origin")

	var buildings: Array = layout.get("buildings", [])
	_check(buildings.size() == 1, "Millbrook should retain its single source-authored house")
	if not buildings.is_empty():
		var house: Dictionary = buildings[0]
		_assert_axial(house.get("center", {}), Vector2i(1, -366), "Millbrook house centre")
		_check(int(house.get("half_q", 0)) == 3 and int(house.get("half_r", 0)) == 3, "House footprint must remain 7x7 axial cells")
		_assert_axial(house.get("door", {}), Vector2i(4, -366), "Millbrook house door")
		_check(house.get("features", []).has("fireplace"), "Millbrook house must retain its fireplace")

	var paths: Array = layout.get("paths", [])
	_check(paths.size() == 1, "Millbrook should retain its authored house spur")
	if not paths.is_empty():
		_assert_axial(paths[0].get("from", {}), Vector2i(5, -366), "Millbrook path start")
		_assert_axial(paths[0].get("to", {}), Vector2i(6, -366), "Millbrook path end")

	var placements: Dictionary = definition.get("placements", {})
	var characters: Array = placements.get("characters", [])
	_check(characters.size() == 2, "Millbrook should retain Petra and the quartermaster as placements")
	var character_ids: Dictionary = {}
	for placement in characters:
		character_ids[String(placement.get("character_id", ""))] = placement
	_check(character_ids.has("petra_hollis"), "Petra Hollis placement must be present")
	_check(character_ids.has("border_war_quartermaster"), "Quartermaster Rurik Voss placement must be present")
	if character_ids.has("petra_hollis"):
		_assert_axial(character_ids["petra_hollis"].get("position", {}), Vector2i(2, -366), "Petra's source position")
	if character_ids.has("border_war_quartermaster"):
		_assert_axial(character_ids["border_war_quartermaster"].get("position", {}), Vector2i(5, -366), "Quartermaster's source position")
	_check(not characters.is_empty() and not characters[0].has("appearance"), "Settlement placements must not duplicate character appearance")
	_check(not characters.is_empty() and not characters[0].has("dialogue_id"), "Settlement placements must not own dialogue identity")

	_check(terrain.terrain_for_hex(Vector2i(1, -366)) == "authored", "Millbrook's building footprint must not receive procedural terrain")
	_check(terrain.gameplay_terrain_for_hex(Vector2i(1, -366)) == "building", "Millbrook building footprint must be blocked gameplay terrain")
	_check(terrain.terrain_for_hex(Vector2i(5, -366)) == "path", "Millbrook's door spur must be rendered as a path")
	_check(terrain.settlement_building_cells.has("1,-366"), "Canonical building occupancy must be indexed")
	_check(terrain.settlement_path_cells.has("5,-366"), "Canonical path occupancy must be indexed")

	var hollowmere_entry := _entry_by_id(entries, "hollowmere")
	_check(not hollowmere_entry.is_empty(), "Canonical Hollowmere definition must remain available")
	if not hollowmere_entry.is_empty():
		var hollowmere: Dictionary = hollowmere_entry.get("definition", {})
		_check(String(hollowmere.get("presentation", {}).get("mode", "")) == "location_presenter", "Hollowmere must remain owned by its location presenter")
		_check(hollowmere.get("layout", {}).get("buildings", []).size() > 0, "Hollowmere authored buildings must survive adaptation")
		_check(hollowmere.get("placements", {}).get("characters", []).size() >= 10, "Hollowmere authored character placements must survive adaptation")

	if failures > 0:
		push_error("%d canonical settlement layout test(s) failed." % failures)
		quit(1)
		return
	print("Canonical Campaign 2 settlement layout tests passed.")
	quit(0)

func _entry_by_id(entries: Array, settlement_id: String) -> Dictionary:
	for entry in entries:
		if String(entry.get("id", "")) == settlement_id:
			return entry
	return {}

func _assert_axial(value: Variant, expected: Vector2i, label: String) -> void:
	if value is Vector2i:
		_check(value == expected, "%s should be %s, got %s" % [label, expected, value])
	elif value is Dictionary:
		var actual := Vector2i(int(value.get("q", 999999)), int(value.get("r", 999999)))
		_check(actual == expected, "%s should be %s, got %s" % [label, expected, actual])
	else:
		_check(false, "%s must be an axial coordinate" % label)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
