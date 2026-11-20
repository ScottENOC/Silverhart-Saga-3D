extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const CHARACTER_DEFINITIONS = preload("res://scripts/simulation/campaign_character_definitions.gd")
var failures: int = 0

func _initialize() -> void:
	var terrain = TERRAIN_DATA.new()
	var settlements: Array = terrain.settlement_layouts
	var characters: Dictionary = CHARACTER_DEFINITIONS.load_campaign2()
	_check(settlements.size() == 1, "First settlement layout should define Millbrook")
	if settlements.is_empty():
		quit(1)
		return
	var millbrook: Dictionary = settlements[0]
	_check(millbrook.get("id", "") == "millbrook", "Settlement ID must remain stable")
	_assert_hex(millbrook, "center", Vector2i(1, -366), "Millbrook building centre")
	_assert_hex(millbrook, "road_endpoint", Vector2i(7, -366), "Millbrook road endpoint")
	var buildings: Array = millbrook.get("buildings", [])
	_check(buildings.size() == 1, "Millbrook should retain its single source-authored house")
	if not buildings.is_empty():
		var house: Dictionary = buildings[0]
		_assert_hex(house, "center", Vector2i(1, -366), "Millbrook house centre")
		_check(int(house.get("half_q", 0)) == 3 and int(house.get("half_r", 0)) == 3, "House footprint must remain 7x7 axial cells")
		_assert_hex(house, "door", Vector2i(4, -366), "Millbrook house door")
		_check(house.get("features", []).has("fireplace"), "Millbrook house must retain its fireplace")
	var placements: Array = millbrook.get("npcs", [])
	_check(placements.size() == 2, "Millbrook should retain Petra and the Border War quartermaster placements")
	var placement_by_id: Dictionary = {}
	for placement in placements:
		var character_id := String(placement.get("character_id", ""))
		placement_by_id[character_id] = placement
		_check(not placement.has("appearance") and not placement.has("body_base") and not placement.has("body_variant"), "Settlement placement must not own character construction data")
		_check(not placement.has("name") and not placement.has("visual_equipment"), "Settlement placement must reference, not define, a character")
	_check(placement_by_id.has("petra_hollis"), "Petra Hollis placement must be present")
	_check(placement_by_id.has("border_war_quartermaster"), "Quartermaster Rurik Voss placement must be present")
	_check(characters.has("petra_hollis"), "Petra's character definition must be present")
	_check(characters.has("border_war_quartermaster"), "Quartermaster's character definition must be present")
	if placement_by_id.has("petra_hollis") and characters.has("petra_hollis"):
		var petra: Dictionary = characters["petra_hollis"]
		_check(petra.get("name", "") == "Petra Hollis", "Petra's name must match Campaign 2")
		_check(petra.get("dialogue_id", "") == "petra_hollis", "Petra's dialogue ID must be preserved")
		_check(petra.get("body_base", "") == "female", "Petra must explicitly select the female shared body base")
		_assert_hex(placement_by_id["petra_hollis"], "position", Vector2i(2, -366), "Petra's source position")
	if placement_by_id.has("border_war_quartermaster") and characters.has("border_war_quartermaster"):
		var quartermaster: Dictionary = characters["border_war_quartermaster"]
		_check(quartermaster.get("name", "") == "Quartermaster Rurik Voss", "Quartermaster identity must be preserved")
		_check(quartermaster.get("dialogue_id", "") == "border_war_quartermaster", "Border War dialogue hook must be preserved")
		_check(quartermaster.get("quest_hooks", []).has("border_war"), "Quartermaster must retain the Border War hook")
		_check(quartermaster.get("body_base", "") == "male", "Quartermaster must explicitly select the male shared body base")
		_assert_hex(placement_by_id["border_war_quartermaster"], "position", Vector2i(5, -366), "Quartermaster's source position")
	_check(terrain.terrain_for_hex(Vector2i(1, -366)) == "authored", "Millbrook's building footprint must not receive procedural terrain")
	_check(terrain.terrain_for_hex(Vector2i(5, -366)) == "path", "Millbrook's door spur must be rendered as a path")
	if failures > 0:
		push_error("%d Campaign 2 settlement test(s) failed." % failures)
		quit(1)
		return
	print("Campaign 2 settlement layout tests passed.")
	quit(0)

func _assert_hex(source: Dictionary, key: String, expected: Vector2i, label: String) -> void:
	_check(source.has(key), "%s is missing" % label)
	if not source.has(key):
		return
	var raw: Variant = source[key]
	_check(raw is Dictionary, "%s must be an axial coordinate object" % label)
	if not raw is Dictionary:
		return
	var actual := Vector2i(int(raw.get("q", 999999)), int(raw.get("r", 999999)))
	_check(actual == expected, "%s should be %s, got %s" % [label, expected, actual])

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
