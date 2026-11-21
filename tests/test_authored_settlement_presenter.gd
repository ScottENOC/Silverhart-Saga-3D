extends SceneTree

const PRESENTER = preload("res://scripts/world/authored_settlement_presenter.gd")
const SETTLEMENT = preload("res://data/settlements/hollowmere/settlement_definition.gd")
const BUILDINGS = preload("res://data/settlements/hollowmere/buildings.gd")
const ROUTES = preload("res://data/settlements/hollowmere/routes.gd")
const BRIDGES = preload("res://data/settlements/hollowmere/bridges.gd")
const AGRICULTURE = preload("res://data/settlements/hollowmere/agriculture.gd")
const PROPS = preload("res://data/settlements/hollowmere/props.gd")

func _initialize() -> void:
	_test_hollowmere_uses_shared_authored_presenter()
	print("Authored settlement presenter tests passed.")
	quit(0)

func _material(colour: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = colour
	return result

func _test_hollowmere_uses_shared_authored_presenter() -> void:
	var parent := Node3D.new()
	var materials := {
		"routes": {
			"path": _material(Color("#765b3b")),
			"water": _material(Color("#315c70")),
			"bank": _material(Color("#39402b"))
		},
		"bridge": {
			"timber": _material(Color("#765b3b")),
			"dark_wood": _material(Color("#30251d"))
		},
		"agriculture": {
			"field": _material(Color("#59603a")),
			"pasture": _material(Color("#425b36")),
			"crop": _material(Color("#9b8748")),
			"fence": _material(Color("#60452f"))
		},
		"props": {
			"dark_wood": _material(Color("#30251d")),
			"stone": _material(Color("#77736b")),
			"timber": _material(Color("#765b3b"))
		},
		"quest_props": {
			"fence": _material(Color("#60452f")),
			"dark_wood": _material(Color("#30251d")),
			"blood": _material(Color("#6b1711"))
		},
		"wayfinding_props": {
			"dark_wood": _material(Color("#30251d")),
			"timber": _material(Color("#765b3b"))
		}
	}
	var data := {
		"buildings": BUILDINGS.BUILDINGS,
		"routes": ROUTES.PRESENTATION_ROUTES,
		"bridge": BRIDGES.BRIDGE_PRESENTATION,
		"fields": AGRICULTURE.FARM_FIELDS,
		"crop_rows": AGRICULTURE.FARM_CROP_ROWS,
		"fences": AGRICULTURE.FARM_FENCES,
		"landmark_props": PROPS.LANDMARK_PROPS,
		"quest_props": PROPS.QUEST_PROPS,
		"wayfinding_props": PROPS.WAYFINDING_PROPS
	}
	var result: Dictionary = PRESENTER.present(
		parent,
		{"id": SETTLEMENT.SETTLEMENT_ID, "name": SETTLEMENT.DISPLAY_NAME},
		data,
		materials,
		HexGrid.DEFAULT_RADIUS_M
	)
	assert(bool(result.get("ok", false)), "All Hollowmere authored features should render: %s" % result)
	assert(int(result.get("buildings", 0)) == BUILDINGS.BUILDINGS.size())
	assert(int(result.get("routes", 0)) == ROUTES.PRESENTATION_ROUTES.size())
	assert(bool(result.get("bridge", false)))
	assert(parent.get_node_or_null("GeneralStore") != null)
	assert(parent.get_node_or_null("Chapel") != null)
	assert(parent.get_node_or_null("OldMacFarmhouse") != null)
	assert(parent.get_node_or_null("OldMacBarn") != null)
	assert(parent.get_node_or_null("GeneralStore/StoreSignPresentation") != null)
	assert(parent.get_node_or_null("Chapel/ChapelBellTowerPresentation") != null)
	assert(parent.get_node_or_null("NarrowRiverBridge") != null)
	parent.free()
