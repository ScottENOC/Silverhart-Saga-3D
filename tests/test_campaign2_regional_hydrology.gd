extends SceneTree

const HYDROLOGY = preload("res://data/world/regions/silverhart_heartland/hydrology.gd")

func _initialize() -> void:
	for q in [-90, -30, 0, 100, 220]:
		var centre := roundi(HYDROLOGY.stream_centre_r(float(q)))
		assert(HYDROLOGY.is_stream_hex(Vector2i(q, centre)), "Regional stream centre must remain water at q=%d" % q)
	assert(HYDROLOGY.is_stream_hex(Vector2i(100, -27)), "Known Hollowmere outflow cell must remain water")
	assert(not HYDROLOGY.is_stream_hex(Vector2i(100, -30)), "Stream width must remain bounded")
	assert(not HYDROLOGY.is_stream_hex(Vector2i(-91, -25)), "Stream must not extend west of its authored region span")
	assert(not HYDROLOGY.is_stream_hex(Vector2i(221, -25)), "Stream must not extend east of its authored region span")
	print("Campaign 2 regional hydrology tests passed.")
	quit(0)
