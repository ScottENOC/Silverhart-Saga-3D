extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const FEATURES = preload("res://data/world/regions/silverhart_heartland/features.gd")

func _initialize() -> void:
	var terrain = TERRAIN_DATA.new()
	assert(FEATURES.DRUID_GROVE_CENTRE == Vector2i(-266, 10), "Grove centre must derive from the original west-road endpoint")
	assert(terrain.terrain_for_hex(Vector2i(-266, 10)) == "grass", "Grove interior must be a grass clearing")
	assert(terrain.terrain_for_hex(Vector2i(-266, 9)) == "water", "Grove spring must override local terrain as water")
	assert(terrain.terrain_for_hex(Vector2i(-266, 5)) == "forest", "Outer grove ring must be woodland")
	assert(terrain.terrain_for_hex(Vector2i(-266, 4)) != "forest", "Grove foliage must stop beyond the authored radius")
	assert(FEATURES.is_herb_patch(Vector2i(-265, 9)), "Eastern herb patch must retain its source coordinate")
	assert(FEATURES.is_herb_patch(Vector2i(-267, 11)), "South-western herb patch must retain its source coordinate")
	assert(not FEATURES.is_herb_patch(Vector2i(-266, 10)), "Clearing centre must not be misidentified as an herb patch")
	assert(FEATURES.DRUID_GROVE_DEN == Vector2i(-269, 2), "Druid trial den anchor must be retained as separate encounter metadata")
	print("Campaign 2 regional authored terrain feature tests passed.")
	quit(0)
