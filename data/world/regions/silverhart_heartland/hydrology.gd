extends RefCounted
## Source-backed regional hydrology for the Silverhart heartland.
## Ports paintStreamSegment from Hex-crpg/campaign2World.js. The stream is
## generated once into a compact q-column lookup, not recomputed per terrain query.

const STREAM_Q_MIN := -90
const STREAM_Q_MAX := 462
const NORTHWATCH_CENTRE := Vector2i(268, -21)
const RIDGEHOLD_CENTRE := Vector2i(426, 43)
const FORT_MOAT_RADIUS := 22
const FORT_MOAT_WIDTH := 3

static var _stream_cells_by_q: Dictionary = {}
static var _stream_centres: Dictionary = {}
static var _stream_built := false

static func stream_centre_r(q: float) -> float:
	_ensure_stream()
	var key := str(roundi(q))
	return float(_stream_centres.get(key, -25))

static func is_stream_hex(hex: Vector2i) -> bool:
	if hex.x < STREAM_Q_MIN or hex.x > STREAM_Q_MAX:
		return false
	_ensure_stream()
	var column: Dictionary = _stream_cells_by_q.get(str(hex.x), {})
	return column.has(str(hex.y))

static func _ensure_stream() -> void:
	if _stream_built:
		return
	_stream_cells_by_q.clear()
	_stream_centres.clear()
	for q in range(-20, 29):
		_add_stream_cell(q, -25)
	var east_end := _paint_stream_segment(29, 70, 1, -25)
	east_end = _paint_stream_segment(70, 130, 1, int(east_end.r))
	_paint_stream_segment(130, 220, 1, int(east_end.r), -25, 0.6)
	_paint_stream_segment(-21, -90, -1, -25)
	_build_fort_waterways()
	_stream_built = true

static func _paint_stream_segment(start_q: int, end_q: int, q_step: int, start_r: int, target_r: int = -999999, drift_bias: float = 0.0) -> Dictionary:
	var r := start_r
	var width := 1
	var resolved_target := start_r if target_r == -999999 else target_r
	for q in range(start_q, end_q + q_step, q_step):
		_stream_centres[str(q)] = r
		_add_stream_cell(q, r)
		var connector_painted := 0
		if _source_pseudo_random(float(q) * 0.41, 5.0) < 0.35:
			var roll := _source_pseudo_random(float(q) * 0.77, 13.0)
			if drift_bias > 0.0 and resolved_target != r:
				var toward_sign := 1 if resolved_target > r else -1
				r += toward_sign if roll < (0.5 + drift_bias / 2.0) else -toward_sign
			else:
				r += -1 if roll < 0.5 else 1
			_add_stream_cell(q, r)
			connector_painted = 1
		if _source_pseudo_random(float(q) * 0.53, 19.0) < 0.15:
			width = 1 + floori(_source_pseudo_random(float(q) * 0.29, 43.0) * 3.0)
		var extra := maxi(0, width - 1 - connector_painted)
		for w in range(1, extra + 1):
			_add_stream_cell(q, r + w)
	return {"q": end_q, "r": r}


## The source's Northwatch connector leg ends at r=-26, while its L-shaped
## moat starts at r=-43. The original comment says they connect, but the
## authored algorithm leaves a 17-hex gap. Preserve the source meander and
## moat, then fill that short axial connector so the intended waterway is
## genuinely continuous in the streamed 3D world.
static func _build_fort_waterways() -> void:
	var moat_north_r := NORTHWATCH_CENTRE.y - FORT_MOAT_RADIUS
	var moat_east_q := NORTHWATCH_CENTRE.x + FORT_MOAT_RADIUS
	var connector_end := _paint_stream_segment(
		220,
		NORTHWATCH_CENTRE.x - FORT_MOAT_RADIUS,
		1,
		-25,
		moat_north_r,
		0.5
	)
	var connector_r := int(connector_end.get("r", -25))
	for r in range(mini(connector_r, moat_north_r), maxi(connector_r, moat_north_r) + 1):
		_add_stream_cell(int(connector_end.q), r)
	for q in range(int(connector_end.q), moat_east_q + 1):
		for width in range(FORT_MOAT_WIDTH):
			_add_stream_cell(q, moat_north_r - width)
	for r in range(moat_north_r, NORTHWATCH_CENTRE.y + FORT_MOAT_RADIUS + 1):
		for width in range(FORT_MOAT_WIDTH):
			_add_stream_cell(moat_east_q + width, r)

	var moat_exit := Vector2i(moat_east_q, NORTHWATCH_CENTRE.y + FORT_MOAT_RADIUS)
	var to_ridgehold := _paint_stream_segment(
		moat_exit.x,
		RIDGEHOLD_CENTRE.x - 24,
		1,
		moat_exit.y,
		RIDGEHOLD_CENTRE.y - 6,
		0.5
	)
	_paint_stream_segment(
		int(to_ridgehold.q),
		int(to_ridgehold.q) + 60,
		1,
		int(to_ridgehold.r)
	)

static func _add_stream_cell(q: int, r: int) -> void:
	var key := str(q)
	if not _stream_cells_by_q.has(key):
		_stream_cells_by_q[key] = {}
	var column: Dictionary = _stream_cells_by_q[key]
	column[str(r)] = true

static func _source_pseudo_random(x: float, y: float) -> float:
	var value := sin(x * 12.9898 + y * 78.233) * 43758.5453
	return value - floorf(value)
