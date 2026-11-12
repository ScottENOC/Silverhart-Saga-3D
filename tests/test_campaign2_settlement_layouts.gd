extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
var failures: int = 0

func _initialize() -> void:
	var terrain = TERRAIN_DATA.new()
	var settlements: Array = terrain.settlement_layouts
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
	var npcs: Array = millbrook.get("npcs", [])
	_check(npcs.size() == 2, "Millbrook should contain Petra and the Border War quartermaster")
	var npc_by_id: Dictionary = {}
	for npc in npcs:
		npc_by_id[String(npc.get("id", ""))] = npc
	_check(npc_by_id.has("petra_hollis"), "Petra Hollis must be present")
	_check(npc_by_id.has("border_war_quartermaster"), "Quartermaster Rurik Voss must be present")
	if npc_by_id.has("petra_hollis"):
		var petra: Dictionary = npc_by_id["petra_hollis"]
		_check(petra.get("name", "") == "Petra Hollis", "Petra's name must match Campaign 2")
		_check(petra.get("dialogue_id", "") == "petra_hollis", "Petra's dialogue ID must be preserved")
		_assert_hex(petra, "position", Vector2i(2, -366), "Petra's source position")
	if npc_by_id.has("border_war_quartermaster"):
		var quartermaster: Dictionary = npc_by_id["border_war_quartermaster"]
		_check(quartermaster.get("name", "") == "Quartermaster Rurik Voss", "Quartermaster identity must be preserved")
		_check(quartermaster.get("dialogue_id", "") == "border_war_quartermaster", "Border War dialogue hook must be preserved")
		_check(quartermaster.get("quest_hooks", []).has("border_war"), "Quartermaster must retain the Border War hook")
		_assert_hex(quartermaster, "position", Vector2i(5, -366), "Quartermaster's source position")
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
