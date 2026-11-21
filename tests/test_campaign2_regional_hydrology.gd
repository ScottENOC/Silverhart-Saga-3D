extends SceneTree

const HYDROLOGY = preload("res://data/world/regions/silverhart_heartland/hydrology.gd")

func _initialize() -> void:
	for q in [-90, -30, 0, 100, 220]:
		var centre := roundi(HYDROLOGY.stream_centre_r(float(q)))
		assert(HYDROLOGY.is_stream_hex(Vector2i(q, centre)), "Source stream centre must remain water at q=%d" % q)
	assert(HYDROLOGY.is_stream_hex(Vector2i(100, -27)), "Source stream must retain the known q=100 connector cell")
	assert(HYDROLOGY.is_stream_hex(Vector2i(100, -28)), "Source stream must retain its q=100 centreline")
	assert(not HYDROLOGY.is_stream_hex(Vector2i(100, -30)), "Source stream width must remain bounded")
	assert(HYDROLOGY.is_stream_hex(Vector2i(220, -25)), "Source stream must reach its eastern endpoint")
	assert(HYDROLOGY.is_stream_hex(Vector2i(-90, -24)), "Source stream must reach its western endpoint")
	assert(not HYDROLOGY.is_stream_hex(Vector2i(-91, -25)), "Stream must not extend west of its authored region span")
	for r in range(-26, -44, -1):
		assert(HYDROLOGY.is_stream_hex(Vector2i(246, r)), "Northwatch connector must close the source gap at q=246,r=%d" % r)
	assert(HYDROLOGY.is_stream_hex(Vector2i(268, -43)), "Northwatch moat north run must cross the fort's northern edge")
	assert(HYDROLOGY.is_stream_hex(Vector2i(291, 0)), "Northwatch moat east run must reach its southern exit")
	assert(HYDROLOGY.is_stream_hex(Vector2i(290, 1)), "Ridgehold waterway must begin at the Northwatch moat exit")
	assert(HYDROLOGY.is_stream_hex(Vector2i(462, 25)), "Ridgehold waterway must reach its eastern endpoint")
	assert(not HYDROLOGY.is_stream_hex(Vector2i(463, 25)), "Stream must not extend east of its authored region span")
	print("Campaign 2 source regional hydrology tests passed.")
	quit(0)
