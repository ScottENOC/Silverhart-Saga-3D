extends SceneTree

const REGISTRY = preload("res://scripts/world/campaign2_settlement_definition_registry.gd")
const WORLD_TERRAIN = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const TERRAIN_PROVIDER = preload("res://scripts/world/authored_settlement_terrain_provider.gd")
const HOLLOWMERE_TERRAIN = preload("res://data/settlements/hollowmere/terrain.gd")

func _initialize() -> void:
	_test_catalogue_owns_authored_terrain()
	_test_world_terrain_uses_canonical_registry()
	if failures > 0:
		push_error("%d canonical settlement terrain test(s) failed." % failures)
		quit(1)
		return
	print("Campaign 2 canonical settlement terrain tests passed.")
	quit(0)

var failures := 0

func _test_catalogue_owns_authored_terrain() -> void:
	var registry = REGISTRY.new()
	_check(registry.validation_errors.is_empty(), "Unified settlement catalogue should validate: " + str(registry.validation_errors))
	_check(registry.settlement_ids() == ["hollowmere", "silverhart", "millbrook", "emberlode", "reddale", "old_mac_farmstead", "emberwood_grove"], "Terrain and layout settlements must share one catalogue")
	var inside := registry.resolve(Vector2i(0, 18))
	var canonical: Dictionary = inside.get("definition", {})
	var terrain: Dictionary = canonical.get("terrain", {})
	_check(String(inside.get("id", "")) == "hollowmere", "Hollowmere cells should resolve through the canonical registry")
	_check(terrain == HOLLOWMERE_TERRAIN.DEFINITION, "Canonical Hollowmere definition should retain its authored terrain domain")
	_check(is_equal_approx(TERRAIN_PROVIDER.elevation_for_hex(Vector2i(0, 18), terrain), 0.0), "Terrain elevation should remain sourced from the canonical terrain domain")
	_check(registry.resolve(Vector2i(97, 0)).is_empty(), "Cells outside settlement bounds must not resolve")
	_check(registry.resolve(Vector2i(96, 96)).is_empty(), "Hollowmere's circular terrain radius must be honoured inside its rectangular envelope")

func _test_world_terrain_uses_canonical_registry() -> void:
	var terrain = WORLD_TERRAIN.new()
	_check(terrain.settlement_definition_registry.settlement_ids() == ["hollowmere", "silverhart", "millbrook", "emberlode", "reddale", "old_mac_farmstead", "emberwood_grove"], "World terrain must use the shared settlement catalogue")
	_check(terrain.terrain_for_hex(Vector2i(0, 18)) == "authored", "Authored building terrain should be resolved through canonical terrain data")
	_check(terrain.gameplay_terrain_for_hex(Vector2i(0, 18)) == "building", "Gameplay terrain should preserve authored building precedence")
	_check(terrain.terrain_for_hex(Vector2i(0, 15)) == "path", "Authored entrances should remain paths")
	_check(terrain.is_walkable_for_hex(Vector2i(0, 15)), "Authored entrances should remain walkable")
	_check(not terrain.is_walkable_for_hex(Vector2i(0, HOLLOWMERE_TERRAIN.SETTLEMENT.STREAM_R)), "Authored stream cells should remain blocked")
	_check(is_zero_approx(terrain.elevation_for_hex(Vector2i(0, 18))), "Settlement elevation should come from its canonical terrain definition")
	_check(not terrain.has_tree(Vector2i(10, 60)), "Regional vegetation queries should respect authored farm exclusions")
	_check(terrain.terrain_for_hex(Vector2i(1, -366)) == "authored", "Millbrook's canonical layout entry must not be mistaken for a terrain definition")
	_check(terrain.terrain_for_hex(Vector2i(5, -366)) == "path", "Millbrook path occupancy should remain intact without authored terrain data")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
