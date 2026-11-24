extends SceneTree

const TERRAIN_DATA = preload("res://scripts/world/campaign2_world_terrain_data.gd")
const FEATURES = preload("res://data/world/regions/silverhart_heartland/features.gd")

func _initialize() -> void:
	var terrain = TERRAIN_DATA.new()
	# Source buildPlayerCottagePlot paints five eastbound cells, then three
	# northbound cells; the final path hex also carries the vacant plot marker.
	assert(FEATURES.PLAYER_COTTAGE_PLOT == Vector2i(13, 27), "Plot must retain crossroads + (5,3)")
	for q in range(9, 14):
		var hex := Vector2i(q, 24)
		assert(FEATURES.is_player_cottage_plot_path(hex), "Eastbound approach cell %s must be authored" % hex)
		assert(terrain.terrain_for_hex(hex) == "path", "Eastbound approach cell %s must be walkable path" % hex)
	for r in range(25, 28):
		var hex := Vector2i(13, r)
		assert(FEATURES.is_player_cottage_plot_path(hex), "Northbound approach cell %s must be authored" % hex)
		assert(terrain.terrain_for_hex(hex) == "path", "Northbound approach cell %s must be walkable path" % hex)
	assert(FEATURES.feature_id_at(Vector2i(13, 27)) == "player_cottage_plot", "Endpoint must retain vacant cottage plot marker")
	assert(not FEATURES.is_player_cottage_plot_path(Vector2i(14, 27)), "Approach must stop at source endpoint")
	print("Player cottage plot map tests passed.")
	quit(0)
