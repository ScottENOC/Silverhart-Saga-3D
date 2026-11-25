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
	_check(bool(validation.get("ok", false)), "Hollowmere canonical envelope should validate: %s" % str(validation.get("errors", [])))
	_check(canonical.get("id", "") == "hollowmere", "Hollowmere ID must remain stable")
	_check(canonical.get("origin", {}) == {"q": 0, "r": 0}, "Hollowmere legacy coordinates must retain their existing zero transform")
	_check(canonical.get("layout", {}).get("buildings", []).size() == 7, "All seven Hollowmere buildings must adapt")
	_check(canonical.get("layout", {}).get("paths", []).size() == 13, "All thirteen Hollowmere presentation routes, including the cottage-plot access spur, must adapt")
	_check(canonical.get("layout", {}).get("fields", []).size() == 22, "Fields, crop rows and fences must be represented once in the canonical layout")
	_check(canonical.get("layout", {}).get("props", []).size() == 6, "All six authored prop groups, including the cottage-plot marker, must be represented once")
	_check(canonical.get("presentation", {}).has("materials") and not canonical.get("presentation", {}).has("feature_data"), "Presentation material bindings must not duplicate the authored feature payload")
	_check(canonical.get("placements", {}).get("characters", []).size() == 14, "Player start and thirteen remaining Hollowmere character placements must adapt after Reyna moves to Old Mac’s Farmstead")
	var wren := _find_record(canonical.placements.characters, "wren_talbot")
	_check(wren.get("position", Vector2i.ZERO) == Vector2i(-2, 1), "Wren's authored start must remain unchanged")
	var player := _find_record(canonical.placements.characters, "player_start")
	_check(player.get("position", Vector2i.ZERO) == Vector2i(-1, 2), "Player start must remain unchanged")
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
	var required_settlements := ["millbrook", "emberlode", "reddale", "old_mac_farmstead", "silverhart"]
	var settlement_ids: Array[String] = []
	for layout in settlements:
		settlement_ids.append(String(layout.get("id", "")))
	for required_id in required_settlements:
		_check(settlement_ids.has(required_id), "Campaign 2 source must include required settlement: %s" % required_id)
	for layout in settlements:
		var canonical: Dictionary = adapters.adapt_campaign2_layout(layout)
		var validation: Dictionary = adapters.validate_adapted(canonical)
		_check(bool(validation.get("ok", false)), "%s canonical envelope should validate: %s" % [canonical.get("id", ""), str(validation.get("errors", []))])
		_check(canonical.get("id", "") == String(layout.get("id", "")), "Adapted settlement ID must remain stable")
		_check(canonical.get("layout", {}).get("buildings", []).size() == layout.get("buildings", []).size(), "All source buildings must survive adaptation")
		_check(canonical.get("placements", {}).get("characters", []).size() == layout.get("npcs", []).size(), "All source character placement references must survive adaptation")
		_check(canonical.get("interiors", []).size() == layout.get("interiors", []).size(), "All source interior records must survive adaptation")
		_check(canonical.get("layout", {}).get("fields", []).size() == layout.get("fields", []).size() + layout.get("crop_rows", []).size() + layout.get("fences", []).size(), "All source agricultural fields, crop rows and fences must survive adaptation")
		_check(canonical.get("layout", {}).get("props", []).size() == layout.get("props", []).size(), "All source quest props must survive adaptation")
		if String(layout.get("id", "")) == "silverhart":
			var courtyard := _find_record(canonical.layout.paths, "silverhart_barracks_courtyard")
			var points: Array = courtyard.get("points", [])
			_check(points.size() == 3, "Silverhart polyline points must survive canonical adaptation")
			if points.size() == 3:
				_check(points[0] == {"q": 9, "r": -487}, "Silverhart polyline first point must be canonical axial coordinates")
				_check(points[2] == {"q": 17, "r": -494}, "Silverhart polyline last point must be canonical axial coordinates")
			var bounds: Dictionary = canonical.get("bounds", {})
			_check(int(bounds.get("min_q", 0)) < 0 and int(bounds.get("max_q", 0)) > 20, "Silverhart bounds must include the full palace wings")
			_check(int(bounds.get("max_r", 0)) < 0, "Silverhart bounds must remain in the authored negative-r region; points-only paths must not inject a false origin")
		if String(layout.get("id", "")) != "millbrook":
			continue
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
