extends SceneTree

const HYDROLOGY = preload("res://data/world/regions/silverhart_heartland/hydrology.gd")


func _test_stream_network_is_continuous() -> void:
	var stream_cells: Dictionary = {}
	for q in range(HYDROLOGY.STREAM_Q_MIN, HYDROLOGY.STREAM_Q_MAX + 1):
		for r in range(-100, 101):
			var hex := Vector2i(q, r)
			if HYDROLOGY.is_stream_hex(hex):
				stream_cells[hex] = true
	assert(not stream_cells.is_empty(), "The authored regional stream network must contain water cells")
	var directions := [
		Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
		Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
	]
	var visited: Dictionary = {}
	var first_cell: Vector2i = stream_cells.keys()[0]
	var queue: Array[Vector2i] = [first_cell]
	visited[first_cell] = true
	var cursor := 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		for direction_variant in directions:
			var direction: Vector2i = direction_variant
			var neighbour := current + direction
			if stream_cells.has(neighbour) and not visited.has(neighbour):
				visited[neighbour] = true
				queue.append(neighbour)
	assert(visited.size() == stream_cells.size(), "Every authored stream, moat and downstream waterway cell must join one continuous network (reached %d of %d)" % [visited.size(), stream_cells.size()])

func _initialize() -> void:
	_test_stream_network_is_continuous()
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
