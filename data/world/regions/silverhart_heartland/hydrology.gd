extends RefCounted
## Regional hydrology for the Silverhart heartland.
## This stream belongs to the region, not to Hollowmere's settlement definition.

const STREAM_Q_MIN := -90
const STREAM_Q_MAX := 220
const STREAM_HALF_WIDTH := 1.5

static func stream_centre_r(q: float) -> float:
	return -25.0 + sin(q * 0.045) * 1.8 + sin(q * 0.11) * 0.7

static func is_stream_hex(hex: Vector2i) -> bool:
	if hex.x < STREAM_Q_MIN or hex.x > STREAM_Q_MAX:
		return false
	return absf(float(hex.y) - stream_centre_r(float(hex.x))) <= STREAM_HALF_WIDTH
