extends SceneTree

const REGISTRY = preload("res://scripts/world/campaign2_settlement_definition_registry.gd")

func _initialize() -> void:
	_test_catalogue_loads_both_source_formats()
	_test_resolution_uses_explicit_origin_and_bounds()
	_test_invalid_catalogue_is_atomic()
	if failures > 0:
		push_error("%d canonical settlement registry test(s) failed." % failures)
		quit(1)
		return
	print("Canonical settlement definition registry tests passed.")
	quit(0)

var failures := 0

func _test_catalogue_loads_both_source_formats() -> void:
	var registry = REGISTRY.new()
	_check(registry.validation_errors.is_empty(), "Unified settlement catalogue should validate: %s" % str(registry.validation_errors))
	_check(registry.settlement_ids() == ["hollowmere", "silverhart", "millbrook", "emberlode", "reddale", "old_mac_farmstead", "skarnaks_hold", "skarn_tooth_camp"], "Catalogue should load all eight canonical settlements in deterministic priority order")
	var hollowmere: Dictionary = registry.get_definition("hollowmere")
	var millbrook: Dictionary = registry.get_definition("millbrook")
	var silverhart: Dictionary = registry.get_definition("silverhart")
	var goblin_camp: Dictionary = registry.get_definition("skarn_tooth_camp")
	var orc_hold: Dictionary = registry.get_definition("skarnaks_hold")
	_check(not hollowmere.is_empty() and not millbrook.is_empty() and not silverhart.is_empty() and not goblin_camp.is_empty() and not orc_hold.is_empty(), "All canonical definitions should be retrievable")
	_check(hollowmere.get("layout", {}).get("buildings", []).size() == 7, "Hollowmere canonical definition should include all buildings")
	_check(millbrook.get("layout", {}).get("buildings", []).size() == 1, "Millbrook canonical definition should include its authored house")
	_check(millbrook.get("placements", {}).get("characters", []).size() == 2, "Millbrook canonical definition should expose placements only")
	_check(silverhart.get("layout", {}).get("buildings", []).size() == 40, "Silverhart canonical definition should expose the current palace, districts, middle ring and Warrens building set")
	_check(goblin_camp.get("layout", {}).get("buildings", []).size() == 7, "Skarn-tooth Camp should expose its six huts and central campfire")
	_check(orc_hold.get("layout", {}).get("buildings", []).size() == 9, "Skarnak's Hold should expose its warlord hut, seven huts and central fire")

func _test_resolution_uses_explicit_origin_and_bounds() -> void:
	var registry = REGISTRY.new()
	var hollowmere: Dictionary = registry.resolve(Vector2i(-2, 1))
	_check(hollowmere.get("id", "") == "hollowmere", "Hollowmere local authored area should resolve")
	_check(hollowmere.get("local_hex", Vector2i.ZERO) == Vector2i(-2, 1), "Hollowmere origin transform must preserve existing coordinates")
	var millbrook: Dictionary = registry.resolve(Vector2i(1, -366))
	_check(millbrook.get("id", "") == "millbrook", "Millbrook authored footprint should resolve")
	_check(millbrook.get("local_hex", Vector2i.ZERO) == Vector2i(1, -366), "Millbrook origin transform must preserve existing coordinates")
	_check(registry.resolve(Vector2i(500, 500)).is_empty(), "Hexes outside all settlement bounds must not resolve")

func _test_invalid_catalogue_is_atomic() -> void:
	var registry = REGISTRY.new()
	var result: Dictionary = registry.configure({
		"schema_version": 1,
		"coordinate_system": "campaign2_local_axial_qr",
		"settlements": [
			{"id": "hollowmere", "adapter_script": "res://scripts/world/settlement_definition_source_adapters.gd", "adapter_method": "adapt_hollowmere"},
			{"id": "hollowmere", "adapter_script": "res://scripts/world/settlement_definition_source_adapters.gd", "adapter_method": "adapt_hollowmere"}
		]
	})
	_check(not bool(result.get("ok", false)), "Duplicate catalogue IDs must be rejected")
	_check(registry.settlement_ids().is_empty(), "Invalid catalogue must not retain partially loaded entries")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
