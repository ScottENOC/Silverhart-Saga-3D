extends SceneTree

const ADAPTERS = preload("res://scripts/world/settlement_definition_source_adapters.gd")
const LAYOUT_PATH := "res://data/world/campaign2_settlement_layouts.json"
var adapters = ADAPTERS.new()

func _initialize() -> void:
	_test_hollowmere_adapter()
	_test_campaign2_layout_adapter()
	if failures > 0:
		push_error("%d settlement source adapter test(s) failed." % failures)
		quit(1)
		return
	print("Settlement source adapter tests passed.")
	quit(0)

var failures := 0

func _test_hollowmere_adapter() -> void:
	var canonical: Dictionary = adapters.adapt_hollowmere()
	var validation: Dictionary = adapters.validate_adapted(canonical)
	_check(bool(validation.get("ok", false)), "Hollowmere canonical envelope should validate: %s" % validation.get("errors", []))
	_check(canonical.get("id", "") == "hollowmere", "Hollowmere ID must remain stable")
	_check(canonical.get("origin", {}) == {"q": 0, "r": 0}, "Hollowmere legacy coordinates must retain their existing zero transform")
	_check(canonical.get("layout", {}).get("buildings", []).size() == 7, "All seven Hollowmere buildings must adapt")
	_check(canonical.get("layout", {}).get("paths", []).size() == 12, "All twelve Hollowmere presentation routes must adapt")
	_check(canonical.get("placements", {}).get("characters", []).size() == 15, "Player start and fourteen authored character placements must adapt")
	var wren := _find_record(canonical.placements.characters, "wren_talbot")
	_check(wren.get("position", {}) == {"q": -2, "r": 1}, "Wren's authored start must remain unchanged")
	var player := _find_record(canonical.placements.characters, "player_start")
	_check(player.get("position", {}) == {"q": -1, "r": 2}, "Player start must remain unchanged")
	_check(canonical.get("terrain", {}).get("id", "") == "hollowmere", "Hollowmere terrain rules must remain part of its canonical envelope")

func _test_campaign2_layout_adapter() -> void:
	var file := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	_check(file != null, "Campaign 2 settlement layout source must be readable")
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_check(parsed is Dictionary, "Campaign 2 settlement layout source must parse")
	if not parsed is Dictionary:
		return
	var settlements: Array = parsed.get("settlements", [])
	_check(not settlements.is_empty(), "Campaign 2 source must include Millbrook")
	for layout in settlements:
		var canonical: Dictionary = adapters.adapt_campaign2_layout(layout)
		var validation: Dictionary = ADAPTERS.validate_adapted(canonical)
		_check(bool(validation.get("ok", false)), "%s canonical envelope should validate: %s" % [canonical.get("id", ""), validation.get("errors", [])])
		_check(canonical.get("id", "") == "millbrook", "Millbrook ID must remain stable")
		_check(canonical.get("layout", {}).get("buildings", []).size() == 1, "Millbrook house must be retained")
		_check(canonical.get("placements", {}).get("characters", []).size() == 2, "Millbrook must retain two character placement references")
		var house := _find_record(canonical.layout.buildings, "millbrook_house")
		_check(house.get("center", {}) == {"q": 1, "r": -366}, "Millbrook house coordinate must remain unchanged")
		var petra := _find_record(canonical.placements.characters, "petra_hollis")
		_check(petra.get("position", {}) == {"q": 2, "r": -366}, "Petra's placement must remain unchanged")
		_check(not petra.has("appearance") and not petra.has("class_levels") and not petra.has("visual_equipment") and not petra.has("dialogue_id"), "Character identity and progression must not leak into settlement placement records")

func _find_record(records: Array, record_id: String) -> Dictionary:
	for record in records:
		if record is Dictionary and String(record.get("id", "")) == record_id:
			return record
	return {}

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
