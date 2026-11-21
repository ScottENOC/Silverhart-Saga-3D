class_name AuthoredSettlementTerrainProvider
extends RefCounted
## Generic interpreter for authored settlement terrain and navigation rules.
## Settlement definitions supply geometry and regional-rule references; this
## provider contains no settlement IDs, coordinates or Hollowmere branches.

static func is_in_bounds(hex: Vector2i, definition: Dictionary) -> bool:
	return HexGrid.distance(Vector2i.ZERO, hex) <= int(definition.get("map_radius", 0))

static func is_water(hex: Vector2i, definition: Dictionary) -> bool:
	var stream: Dictionary = definition.get("stream", {})
	if hex.x < int(stream.get("q_min", 1)) or hex.x > int(stream.get("q_max", -1)):
		return false
	if hex == stream.get("bridge", Vector2i(2147483647, 2147483647)):
		return false
	var centre_r := river_centre_r(hex.x, definition)
	var half_width := river_half_width(hex.x, definition)
	return absf(float(hex.y) - centre_r) <= half_width

static func river_centre_r(q: int, definition: Dictionary) -> float:
	var stream: Dictionary = definition.get("stream", {})
	var samples: Array = stream.get("centre_samples", [])
	if samples.size() < 2:
		return 0.0
	for index in range(samples.size() - 1):
		var first: Vector2i = samples[index]
		var second: Vector2i = samples[index + 1]
		if q <= second.x:
			var t := inverse_lerp(float(first.x), float(second.x), float(q))
			return lerpf(float(first.y), float(second.y), t)
	return float(samples[samples.size() - 1].y)

static func river_half_width(q: int, definition: Dictionary) -> float:
	var stream: Dictionary = definition.get("stream", {})
	var samples: Array = stream.get("centre_samples", [])
	var widths: Variant = stream.get("half_width_samples", [])
	if samples.size() < 2 or not (widths is Array or widths is PackedFloat32Array) or widths.size() != samples.size():
		return 0.0
	for index in range(samples.size() - 1):
		var first: Vector2i = samples[index]
		var second: Vector2i = samples[index + 1]
		if q <= second.x:
			var t := inverse_lerp(float(first.x), float(second.x), float(q))
			return lerpf(widths[index], widths[index + 1], t)
	return widths[widths.size() - 1]

static func is_building(hex: Vector2i, definition: Dictionary) -> bool:
	for building in definition.get("buildings", []):
		if not building is Dictionary:
			continue
		var centre: Vector2i = building.get("center", Vector2i.ZERO)
		if absi(hex.x - centre.x) <= int(building.get("half_q", 0)) and absi(hex.y - centre.y) <= int(building.get("half_r", 0)):
			return true
	return false

static func is_door(hex: Vector2i, definition: Dictionary) -> bool:
	for building in definition.get("buildings", []):
		if building is Dictionary and building.get("door", Vector2i(2147483647, 2147483647)) == hex:
			return true
	return false

static func is_blocked(hex: Vector2i, definition: Dictionary) -> bool:
	if not is_in_bounds(hex, definition):
		return true
	if is_door(hex, definition):
		return false
	if is_water(hex, definition) or is_building(hex, definition) or has_tree(hex, definition):
		return true
	return false

static func terrain_id_at(hex: Vector2i, definition: Dictionary) -> String:
	if is_water(hex, definition):
		return "water"
	if is_path(hex, definition):
		return "path"
	if is_building(hex, definition):
		return "building"
	if has_tree(hex, definition):
		return "forest"
	return "grass"

static func is_path(hex: Vector2i, definition: Dictionary) -> bool:
	# Every authored entrance is also a walkable path cell, including doors
	# on building footprints that are not part of a rectangular lane rule.
	if is_door(hex, definition):
		return true
	var path: Dictionary = definition.get("path", {})
	for rule in path.get("horizontal_ranges", []):
		if hex.y == int(rule.get("r", 2147483647)) and hex.x >= int(rule.get("q_min", 1)) and hex.x <= int(rule.get("q_max", -1)):
			return true
	for rule in path.get("vertical_ranges", []):
		if hex.x == int(rule.get("q", 2147483647)) and hex.y >= int(rule.get("r_min", 1)) and hex.y <= int(rule.get("r_max", -1)):
			return true
	if path.get("cells", []).has(hex):
		return true
	var crossroads: Vector2i = path.get("crossroads", Vector2i.ZERO)
	if hex == crossroads:
		return true
	for route in path.get("segments", []):
		if not route is Array:
			continue
		for index in range(route.size() - 1):
			if _is_near_axial_segment(hex, route[index], route[index + 1], int(path.get("segment_tolerance", 1))):
				return true
	return false

static func path_cells(definition: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var bounds: Dictionary = definition.get("path", {}).get("enumeration_bounds", {})
	var q_min := int(bounds.get("q_min", 0))
	var q_max := int(bounds.get("q_max", -1))
	var r_min := int(bounds.get("r_min", 0))
	var r_max := int(bounds.get("r_max", -1))
	if q_max < q_min or r_max < r_min:
		return result
	for q in range(q_min, q_max + 1):
		for r in range(r_min, r_max + 1):
			var hex := Vector2i(q, r)
			if is_path(hex, definition):
				result.append(hex)
	return result

static func water_cells(definition: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var stream: Dictionary = definition.get("stream", {})
	for q in range(int(stream.get("q_min", 0)), int(stream.get("q_max", -1)) + 1):
		var centre_r := river_centre_r(q, definition)
		var half_width := river_half_width(q, definition)
		for r in range(floori(centre_r - half_width), ceili(centre_r + half_width) + 1):
			var hex := Vector2i(q, r)
			if is_water(hex, definition):
				result.append(hex)
	return result

static func is_farm_land(hex: Vector2i, definition: Dictionary) -> bool:
	var bounds: Dictionary = definition.get("farm_land", {})
	return hex.x >= int(bounds.get("q_min", 1)) and hex.x <= int(bounds.get("q_max", 0)) and hex.y >= int(bounds.get("r_min", 1)) and hex.y <= int(bounds.get("r_max", 0))

static func is_forest_candidate(hex: Vector2i, definition: Dictionary) -> bool:
	var biome: Variant = definition.get("biome_script")
	if not biome is Script:
		return false
	var context := {
		"in_bounds": is_in_bounds(hex, definition),
		"farm_land": is_farm_land(hex, definition),
		"distance_from_centre": HexGrid.distance(Vector2i.ZERO, hex),
		"water": is_water(hex, definition),
		"building": is_building(hex, definition),
		"path": is_path(hex, definition)
	}
	return bool(Callable(biome, "is_forest_candidate").call(hex, context))

static func has_tree(hex: Vector2i, definition: Dictionary) -> bool:
	var biome: Variant = definition.get("biome_script")
	return biome is Script and bool(Callable(biome, "has_tree").call(hex, is_forest_candidate(hex, definition)))

static func is_understorey_candidate(hex: Vector2i, definition: Dictionary) -> bool:
	return is_forest_candidate(hex, definition) and not has_tree(hex, definition)

static func select_tree_family(hex: Vector2i, _density_roll: float, definition: Dictionary) -> String:
	var biome: Variant = definition.get("biome_script")
	if not biome is Script:
		return ""
	var near_stream := bool(Callable(biome, "is_near_stream").call(hex, 7.0, river_centre_r(hex.x, definition)))
	return String(Callable(biome, "select_tree_family").call(hex, near_stream))

static func select_understorey_family(hex: Vector2i, density_roll: float, definition: Dictionary) -> String:
	var biome: Variant = definition.get("biome_script")
	if not biome is Script:
		return ""
	var near_stream := bool(Callable(biome, "is_near_stream").call(hex, 7.0, river_centre_r(hex.x, definition)))
	return String(Callable(biome, "select_understorey_family").call(near_stream, density_roll))

static func stable_noise(q: int, r: int, definition: Dictionary) -> float:
	var biome: Variant = definition.get("biome_script")
	if not biome is Script:
		return 0.0
	return float(Callable(biome, "stable_noise").call(q, r))

static func _is_near_axial_segment(hex: Vector2i, start: Vector2i, finish: Vector2i, tolerance: int) -> bool:
	var steps := maxi(1, HexGrid.distance(start, finish) * 2)
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var sample := Vector2i(roundi(lerpf(float(start.x), float(finish.x), t)), roundi(lerpf(float(start.y), float(finish.y), t)))
		if HexGrid.distance(hex, sample) <= tolerance:
			return true
	return false

static func elevation_for_hex(hex: Vector2i, definition: Dictionary) -> float:
	var elevation: Variant = definition.get("elevation", 0.0)
	if elevation is float or elevation is int:
		return float(elevation)
	return 0.0
