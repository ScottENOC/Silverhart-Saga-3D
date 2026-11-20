extends SceneTree

const BIOMES = preload("res://data/world/regions/silverhart_heartland/biomes.gd")

func _initialize() -> void:
	var clear_context := {
		"in_bounds": true,
		"farm_land": false,
		"distance_from_centre": 17,
		"water": false,
		"building": false,
		"path": false
	}
	var candidate := Vector2i.ZERO
	var found_candidate := false
	for q in range(-96, 97):
		for r in range(-96, 97):
			var hex := Vector2i(q, r)
			if BIOMES.is_forest_candidate(hex, clear_context):
				candidate = hex
				found_candidate = true
				break
		if found_candidate:
			break
	assert(found_candidate, "Regional woodland rules should admit deterministic forest candidates")
	assert(not BIOMES.is_forest_candidate(candidate, {"in_bounds": false}), "Settlement bounds must exclude woodland")
	assert(not BIOMES.is_forest_candidate(candidate, {"in_bounds": true, "farm_land": true}), "Farm land must remain clear")
	assert(not BIOMES.is_forest_candidate(candidate, {"in_bounds": true, "distance_from_centre": 16}), "The settlement clearing must remain free of trees")
	assert(not BIOMES.is_forest_candidate(candidate, {"in_bounds": true, "water": true}), "Water must exclude woodland")
	assert(not BIOMES.is_forest_candidate(candidate, {"in_bounds": true, "building": true}), "Building footprints must exclude woodland")
	assert(not BIOMES.is_forest_candidate(candidate, {"in_bounds": true, "path": true}), "Paths must exclude woodland")

	assert(not BIOMES.has_tree(Vector2i(1, 1), true), "Tree placement must preserve the four-hex lattice")
	var found_tree := false
	for q in range(-96, 97, 4):
		for r in range(-96, 97, 4):
			if BIOMES.has_tree(Vector2i(q, r), true):
				found_tree = true
				break
		if found_tree:
			break
	assert(found_tree, "The regional tree occupancy rule should select deterministic canopy cells")
	assert(not BIOMES.has_tree(Vector2i.ZERO, false), "Non-forest cells must never receive canopy trees")

	assert(BIOMES.is_near_stream(Vector2i(34, -25), 7.0, -25.0), "The stream influence zone must include its authored q boundary")
	assert(not BIOMES.is_near_stream(Vector2i(35, -25), 7.0, -25.0), "The stream influence zone must stop beyond its authored q boundary")
	assert(BIOMES.select_understorey_family(true, 0.80) == "tree_fern")
	assert(BIOMES.select_understorey_family(false, 0.95) == "low_poly_bush")
	assert(BIOMES.select_understorey_family(false, 0.50) == "bush")

	var stream_families := ["willow", "ash", "laurel", "cherry", "spruce"]
	var woodland_families := ["ash", "cherry", "laurel", "pine", "spruce", "winter_oak", "low_poly_tree"]
	for q in range(-24, 25, 3):
		for r in range(-30, -18, 3):
			var hex := Vector2i(q, r)
			var stream_family := BIOMES.select_tree_family(hex, true)
			var woodland_family := BIOMES.select_tree_family(hex, false)
			assert(stream_families.has(stream_family), "Stream-edge tree selector returned an unknown family")
			assert(woodland_families.has(woodland_family), "Woodland tree selector returned an unknown family")
			assert(stream_family == BIOMES.select_tree_family(hex, true), "Species selection must be deterministic")

	print("Silverhart heartland biome tests passed.")
	quit(0)
