extends SceneTree

const MANIFEST_PATH := "res://data/world/campaign2_geography.json"

func _initialize() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert(parsed is Dictionary, "Campaign 2 geography manifest must parse as an object")
	assert(int(parsed.get("campaign_id", 0)) == 2, "Manifest must target Campaign 2")
	assert(int(parsed.get("coordinate_system", {}).get("local_hexes_per_strategic_cell", 0)) == 130)

	var locations: Array = parsed.get("locations", [])
	assert(locations.size() == 24, "The current first-pass geography inventory should contain 24 destinations")
	var ids: Dictionary = {}
	var location_by_id: Dictionary = {}
	for location in locations:
		assert(location is Dictionary, "Every location must be an object")
		var id := String(location.get("id", ""))
		assert(not id.is_empty(), "Every location needs a stable id")
		assert(not String(location.get("name", "")).is_empty(), "Every location needs a display name: " + id)
		assert(not String(location.get("region", "")).is_empty(), "Every location needs a region: " + id)
		assert(not ids.has(id), "Location ids must be unique: " + id)
		ids[id] = true
		location_by_id[id] = location
		assert(location.has("q") and location.has("r"), "Every location needs source local axial coordinates: " + id)
		var column := 6.0 + float(location["q"] - 8) / 130.0
		var row := 6.0 + float(location["r"] - 24) / 130.0
		assert(column >= -0.5 and column <= 15.5, "Location falls outside strategic map horizontally: " + id)
		assert(row >= -0.5 and row <= 15.5, "Location falls outside strategic map vertically: " + id)

	for required_id in [
		"hollowmere", "millbrook", "silverhart", "emberlode", "reddale",
		"old_mac_farmstead", "hollowmere_guild_den", "abandoned_house",
		"skarn_tooth_camp", "northwatch_fort",
		"ridgehold_fort", "skarnaks_hold", "kragmoor", "silthandriel",
		"vessel_seekers_crypt", "corvin_ashgrave_barrow", "ashveil_lair",
		"lich_chapterhouse", "emberwood_grove", "vampire_grave", "thieves_cove",
		"emberlode_mine", "farm_wolf_den", "unicorn_vale"
	]:
		assert(ids.has(required_id), "Missing required campaign destination: " + required_id)

	assert(int(location_by_id["millbrook"]["q"]) == 1, "Millbrook anchor must use the offset village centre")
	assert(int(location_by_id["ashveil_lair"]["q"]) == 101, "Dragon lair must be placed 100 q east of Millbrook centre")
	assert(int(location_by_id["lich_chapterhouse"]["q"]) == -39, "Chapterhouse must be offset west of Millbrook centre")

	var connections: Array = parsed.get("connections", [])
	assert(connections.size() == 22, "The current first-pass travel graph should contain 22 connections")
	for connection in connections:
		assert(ids.has(String(connection.get("from", ""))), "Connection has unknown origin")
		assert(ids.has(String(connection.get("to", ""))), "Connection has unknown destination")

	var river: Array = parsed.get("geography", {}).get("river_path", [])
	assert(river.size() == 15, "Campaign 2 strategic river should retain its 15 source cells")
	print("Campaign 2 geography manifest: %d locations, %d connections, %d river cells — OK" % [locations.size(), connections.size(), river.size()])
	quit()
