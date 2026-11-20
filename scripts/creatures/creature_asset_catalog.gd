class_name CreatureAssetCatalog
extends RefCounted
## Registry for reusable source creature assets. Add one definition per source
## model; size, colour and animation choices are instance configuration.

const SIZE_MULTIPLIERS: Dictionary = {
	"tiny": 0.35,
	"small": 0.65,
	"medium": 1.0,
	"large": 1.55,
	"huge": 2.2,
	"ancient": 3.0
}

const COLOUR_PALETTE: Dictionary = {
	"natural": Color.WHITE,
	"red": Color(1.0, 0.24, 0.18),
	"crimson": Color(0.72, 0.055, 0.075),
	"orange": Color(1.0, 0.34, 0.08),
	"gold": Color(1.0, 0.68, 0.20),
	"green": Color(0.22, 0.72, 0.27),
	"blue": Color(0.18, 0.42, 0.95),
	"ice_blue": Color(0.42, 0.78, 1.0),
	"purple": Color(0.48, 0.20, 0.78),
	"black": Color(0.16, 0.17, 0.21),
	"white": Color(0.92, 0.94, 0.98)
}

const ASSETS: Dictionary = {
	"ashwing_drake_lite": {
		"species": "dragon",
		"variant": "ashwing_drake_lite",
		"display_name": "Ashwing Drake",
		"model_path": "res://art/creatures/dragons/Ashwing_Drake_Lite.glb",
		"source_file": "Ashwing_Drake_Lite.glb",
		"source_license": "unverified — record the source licence before distribution",
		"default_scale": 1.0,
		"animation_map": {
			"idle": "idle_loop",
			"walk": "walk_loop",
			"fly": "fly_loop",
			"takeoff": "takeoff",
			"bite": "bite",
			"roar": "roar"
		}
	}
}

static func get_definition(asset_id: String) -> Dictionary:
	if not ASSETS.has(asset_id):
		return {}
	return (ASSETS[asset_id] as Dictionary).duplicate(true)

static func has_asset(asset_id: String) -> bool:
	return ASSETS.has(asset_id)

static func scale_for(asset_id: String, size_name: String) -> float:
	var definition := get_definition(asset_id)
	if definition.is_empty():
		return 1.0
	var multiplier := float(SIZE_MULTIPLIERS.get(size_name.to_lower(), 1.0))
	return float(definition.get("default_scale", 1.0)) * multiplier

static func colour_for(colour_name: String) -> Color:
	return COLOUR_PALETTE.get(colour_name.to_lower(), Color.WHITE)

static func default_asset_for_species(species_name: String) -> String:
	var normalized_species := species_name.to_lower()
	for asset_id in ASSETS:
		var definition: Dictionary = ASSETS[asset_id]
		if String(definition.get("species", "")).to_lower() == normalized_species:
			return String(asset_id)
	return ""
