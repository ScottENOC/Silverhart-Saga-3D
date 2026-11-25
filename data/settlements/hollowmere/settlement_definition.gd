extends RefCounted

## Settlement identity and reference point in the campaign-wide axial coordinate frame.
const SETTLEMENT_ID := "hollowmere"
const DISPLAY_NAME := "Hollowmere"
const COORDINATE_SYSTEM := "campaign2_local_axial_qr"
const WORLD_REFERENCE_HEX := Vector2i(8, 24)



const MAP_RADIUS: int = 96

const STREAM_R: int = -25

const STREAM_Q_MIN: int = -30

const STREAM_Q_MAX: int = 30

const CROSSROADS := Vector2i(8, 24)

const BRIDGE := Vector2i(8, STREAM_R)

const FARMHOUSE := Vector2i(12, 54)

const FARM_BARN := Vector2i(22, 51)

const FARMHOUSE_DOOR := Vector2i(12, 57)

const FARM_BARN_DOOR := Vector2i(22, 49)
