extends SceneTree

const SETTLEMENT = preload("res://data/settlements/hollowmere/settlement_definition.gd")
const BUILDINGS = preload("res://data/settlements/hollowmere/buildings.gd")
const ROUTES = preload("res://data/settlements/hollowmere/routes.gd")
const BRIDGES = preload("res://data/settlements/hollowmere/bridges.gd")
const PROPS = preload("res://data/settlements/hollowmere/props.gd")
const AGRICULTURE = preload("res://data/settlements/hollowmere/agriculture.gd")
const PLACEMENTS = preload("res://data/settlements/hollowmere/placements.gd")
const ENCOUNTER = preload("res://scripts/simulation/hollowmere_encounter.gd")
const FARM_WOLVES = preload("res://scripts/simulation/farm_wolves_quest.gd")

func _initialize() -> void:
	assert(SETTLEMENT.SETTLEMENT_ID == "hollowmere")
	assert(SETTLEMENT.COORDINATE_SYSTEM == "campaign2_local_axial_qr")
	assert(SETTLEMENT.WORLD_REFERENCE_HEX == Vector2i(8, 24), "Hollowmere reference point must remain in campaign axial world coordinates")

	assert(BUILDINGS.BUILDINGS.size() == 7, "All seven authored Hollowmere buildings must remain in the building data module")
	var building_ids: Dictionary = {}
	for building in BUILDINGS.BUILDINGS:
		var id := String(building.get("id", ""))
		assert(not id.is_empty() and not building_ids.has(id), "Building IDs must be stable and unique")
		building_ids[id] = true
		assert(building.get("center") is Vector2i and building.get("door") is Vector2i, "Building footprint and entrance must use axial world coordinates")

	assert(ROUTES.PRESENTATION_ROUTES.size() == 12, "All authored presentation routes must remain present")
	assert(ROUTES.FARMYARD_CENTRELINE.front() == SETTLEMENT.FARMHOUSE_DOOR)
	assert(ROUTES.FARMYARD_CENTRELINE.back() == SETTLEMENT.FARM_BARN_DOOR)
	assert(BRIDGES.BRIDGE_PRESENTATION.parts.size() == 9)
	assert(PROPS.LANDMARK_PROPS.size() == 2 and PROPS.QUEST_PROPS.size() == 2 and PROPS.WAYFINDING_PROPS.size() == 1)
	assert(AGRICULTURE.FARM_FIELDS.size() == 3 and AGRICULTURE.FARM_CROP_ROWS.size() == 17 and AGRICULTURE.FARM_FENCES.size() == 2)

	# Only characters who actually belong in the opening settlement receive
	# Hollowmere starts. Other companions wait for their recruitment regions.
	assert(PLACEMENTS.CHARACTER_STARTS.has("wren_talbot"), "Starting party member Wren must be present")
	assert(not PLACEMENTS.CHARACTER_STARTS.has("reyna_fletcher"), "Reyna belongs at Old Mac's Farmstead, not in Hollowmere's opening placements")
	assert(PLACEMENTS.CHARACTER_STARTS["wren_talbot"] == Vector2i(-2, 1))
	assert(PLACEMENTS.CHARACTER_STARTS["garrick_holt"] == Vector2i(-3, -2))
		assert(PLACEMENTS.OLD_MAC_START_HEX == Vector2i(12, 58))
	assert(PLACEMENTS.REYNA_SHELTER_HEX == Vector2i(27, 62))
	assert(PLACEMENTS.MISSING_CHILD_START_HEX == PLACEMENTS.REYNA_SHELTER_HEX)
	assert(PLACEMENTS.REYNA_CLUE_HEX == Vector2i(22, 61))
	assert(PLACEMENTS.FARMSTEAD_DIRE_WOLF_HEX == Vector2i(30, 58))
	assert(PLACEMENTS.FARM_WOLF_DEN_HEX == Vector2i(-59, 204), "Farm quest must use the source-authored global wolf-den coordinate")
	assert(PLACEMENTS.FARM_WOLF_SPAWN_OFFSETS.size() == 3)
	assert(PLACEMENTS.SHAKEDOWN_SOLDIER_WAIT_HEXES.size() == 3)
	assert(PLACEMENTS.SHAKEDOWN_SOLDIER_INTERIOR_PREFERRED_HEXES.size() == 3)
	assert(PLACEMENTS.SHAKEDOWN_SOLDIER_INTERIOR_FALLBACK_HEXES.size() == 5)
	assert(PLACEMENTS.SHAKEDOWN_SOLDIER_WAIT_HEXES.size() == ENCOUNTER.ENEMY_IDS.size(),
		"Every shakedown soldier needs an authored outside destination")
	assert(PLACEMENTS.SHAKEDOWN_SOLDIER_INTERIOR_PREFERRED_HEXES.size() == ENCOUNTER.ENEMY_IDS.size(),
		"Every shakedown soldier needs an authored preferred interior destination")
	assert(PLACEMENTS.FARM_WOLF_SPAWN_OFFSETS.size() == FARM_WOLVES.WOLF_IDS.size(),
		"Every farm-quest wolf needs an authored formation offset")
	var animal_ids: Dictionary = {}
	for animal_placement in PLACEMENTS.FARM_ANIMALS + PLACEMENTS.WILDERNESS_ANIMALS:
		var animal_id := String(animal_placement.get("id", ""))
		assert(not animal_id.is_empty() and not animal_ids.has(animal_id), "Authored animal IDs must be unique")
		assert(animal_placement.get("hex") is Vector2i, "Every authored animal must have an axial placement")
		animal_ids[animal_id] = true
	assert(not PLACEMENTS.CHARACTER_STARTS.has("ser_aldric_thorne"))
	assert(not PLACEMENTS.CHARACTER_STARTS.has("nix_sharpear"))
	assert(not PLACEMENTS.CHARACTER_STARTS.has("warlord_grukk_ironhide"))
	assert(not PLACEMENTS.CHARACTER_STARTS.has("mirabel_quill"))
	assert(not PLACEMENTS.CHARACTER_STARTS.has("fenn_oakheart"))
	assert(not PLACEMENTS.CHARACTER_STARTS.has("brother_alden"))
	assert(not PLACEMENTS.CHARACTER_STARTS.has("snik_fangtooth"))
	assert(PLACEMENTS.DEFERRED_COMPANIONS.size() == 7, "Unbuilt recruitment regions must not be assigned fabricated local starts")
	var manifest_file := FileAccess.open("res://data/characters/hollowmere_npcs.json", FileAccess.READ)
	assert(manifest_file != null, "Hollowmere character manifest must be readable")
	var manifest: Dictionary = JSON.parse_string(manifest_file.get_as_text())
	for profile_value in manifest.get("characters", []):
		var profile: Dictionary = profile_value
		if String(profile.get("role", "")) == "player avatar":
			continue
		var model_id := String(profile.get("id", ""))
		assert(PLACEMENTS.CHARACTER_STARTS.has(model_id) or PLACEMENTS.DEFERRED_COMPANIONS.has(model_id),
			"Every manifested character must be explicitly placed locally or deferred: " + model_id)
	for companion_id in PLACEMENTS.DEFERRED_COMPANIONS:
		assert(not PLACEMENTS.CHARACTER_STARTS.has(companion_id), "Deferred companions cannot also have local coordinates")

	print("Hollowmere modular settlement data tests passed.")
	quit(0)
