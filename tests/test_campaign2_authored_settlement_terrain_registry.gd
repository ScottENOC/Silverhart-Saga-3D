extends SceneTree

const REGISTRY = preload("res://scripts/world/campaign2_authored_settlement_terrain_registry.gd")
const WORLD_TERRAIN = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const TERRAIN_PROVIDER = preload("res://scripts/world/authored_settlement_terrain_provider.gd")
const HOLLOWMERE_TERRAIN = preload("res://data/settlements/hollowmere/terrain.gd")

func _initialize() -> void:
	_test_manifest_loads_authored_definitions()
	_test_registry_rejects_invalid_manifests()
	_test_world_terrain_uses_registry_without_location_branches()
	print("Campaign 2 authored settlement terrain registry tests passed.")
	quit(0)

func _test_manifest_loads_authored_definitions() -> void:
	var registry := REGISTRY.new()
	assert(registry.validation_errors.is_empty(), "The authored terrain manifest should validate")
	assert(registry.settlement_ids() == [ "hollowmere" ], "The manifest should expose stable settlement IDs")
	var inside := registry.resolve(Vector2i(0, 18))
	assert(String(inside.get("id", "")) == "hollowmere", "The registry should resolve cells inside an authored settlement")
	assert(inside.get("definition", {}) == HOLLOWMERE_TERRAIN.DEFINITION, "The registry should return the loaded authored definition")
	assert(registry.resolve(Vector2i(97, 0)).is_empty(), "The registry should not claim cells outside authored settlement bounds")
	var overlap_result := registry.configure({
		"schema_version": 1,
		"coordinate_system": "campaign2_local_axial_qr",
		"settlements": [
			{"id": "hollowmere", "definition_script": "res://data/settlements/hollowmere/terrain.gd", "priority": 100},
			{"id": "overlap_test", "definition_script": "res://tests/fixtures/test_overlapping_settlement_terrain.gd", "priority": 200}
		]
	})
	assert(bool(overlap_result.get("ok", false)), "Valid overlapping settlement definitions should be accepted")
	assert(String(registry.resolve(Vector2i.ZERO).get("id", "")) == "overlap_test", "Higher-priority authored settlement terrain must win overlaps")
	assert(is_equal_approx(TERRAIN_PROVIDER.elevation_for_hex(Vector2i.ZERO, registry.resolve(Vector2i.ZERO).definition), 0.25), "Resolved terrain should retain the winning definition's elevation")

func _test_registry_rejects_invalid_manifests() -> void:
	var registry := REGISTRY.new()
	var duplicate_result := registry.configure({
		"schema_version": 1,
		"coordinate_system": "campaign2_local_axial_qr",
		"settlements": [
			{"id": "hollowmere", "definition_script": "res://data/settlements/hollowmere/terrain.gd"},
			{"id": "hollowmere", "definition_script": "res://data/settlements/hollowmere/terrain.gd"}
		]
	})
	assert(not bool(duplicate_result.get("ok", true)), "Duplicate settlement IDs must be rejected")
	assert(not registry.validation_errors.is_empty(), "Invalid manifests should retain actionable validation errors")
	assert(registry.settlement_ids().is_empty(), "Invalid manifests must not leave a partially active registry")
	var missing_script_result := registry.configure({
		"schema_version": 1,
		"coordinate_system": "campaign2_local_axial_qr",
		"settlements": [
			{"id": "missing_location", "definition_script": "res://data/settlements/missing/terrain.gd"}
		]
	})
	assert(not bool(missing_script_result.get("ok", true)), "Missing terrain scripts must be rejected")

func _test_world_terrain_uses_registry_without_location_branches() -> void:
	var terrain := WORLD_TERRAIN.new()
	assert(terrain.terrain_for_hex(Vector2i(0, 18)) == "building", "Authored building terrain should be resolved through the registry")
	assert(terrain.gameplay_terrain_for_hex(Vector2i(0, 18)) == "building", "Gameplay terrain should preserve authored building precedence")
	assert(terrain.terrain_for_hex(Vector2i(0, 15)) == "path", "Authored entrances should remain paths")
	assert(terrain.is_walkable_for_hex(Vector2i(0, 15)), "Authored entrances should remain walkable")
	assert(not terrain.is_walkable_for_hex(Vector2i(0, HOLLOWMERE_TERRAIN.SETTLEMENT.STREAM_R)), "Authored stream cells should remain blocked")
	assert(is_zero_approx(terrain.elevation_for_hex(Vector2i(0, 18))), "Settlement elevation should come from its authored terrain definition")
	assert(not terrain.has_tree(Vector2i(10, 60)), "Regional vegetation queries should respect authored farm exclusions")
	terrain.free()
