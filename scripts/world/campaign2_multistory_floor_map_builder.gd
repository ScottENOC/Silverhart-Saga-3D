class_name Campaign2MultiStoryFloorMapBuilder
extends RefCounted
## Converts source-authored multi-story floor geometry into logical HexMapData.
## The returned tile objects and actor placements are consumed by the location
## presentation/runtime; this builder does not create 3D nodes.

static func build_floor_map(
	location_definition: Dictionary,
	floor_number: int,
	location_state: Variant = null
) -> Dictionary:
	var floor_definition := _find_floor(location_definition, floor_number)
	if floor_definition.is_empty():
		return {"ok": false, "reason": "unknown_floor"}
	var floor_cells: Dictionary = {}
	var wall_cells: Dictionary = {}
	for room_variant in floor_definition.get("rooms", []):
		if not room_variant is Dictionary:
			return {"ok": false, "reason": "invalid_room_definition"}
		var room: Dictionary = room_variant
		var secret_id := String(room.get("hidden_by_secret", "")).strip_edges()
		if not secret_id.is_empty() and not _is_secret_discovered(location_state, secret_id):
			continue
		_add_room(room, floor_cells, wall_cells)
	for corridor_variant in floor_definition.get("corridors", []):
		if not corridor_variant is Dictionary:
			return {"ok": false, "reason": "invalid_corridor_definition"}
		_add_corridor(corridor_variant, floor_cells, wall_cells)

	var tile_objects: Array[Dictionary] = []
	for object_variant in floor_definition.get("tile_objects", []):
		if not object_variant is Dictionary:
			return {"ok": false, "reason": "invalid_tile_object"}
		var tile_object: Dictionary = object_variant.duplicate(true)
		var position := _position_from(tile_object.get("position", {}))
		if not _is_valid_position(position):
			return {"ok": false, "reason": "tile_object_missing_position"}
		var hidden_by_secret := String(tile_object.get("hidden_by_secret", "")).strip_edges()
		if String(tile_object.get("type", "")) == "secret_door" and bool(tile_object.get("hidden", true)):
			hidden_by_secret = String(tile_object.get("id", ""))
		if not hidden_by_secret.is_empty() and not _is_secret_discovered(location_state, hidden_by_secret):
			if String(tile_object.get("type", "")) == "secret_door":
				wall_cells[position] = true
			continue
		floor_cells[position] = true
		wall_cells.erase(position)
		tile_objects.append(tile_object)

	# Stairs are source tile objects on ordinary levels. A quest-gated stair is
	# absent from the source floor until its transition state is revealed.
	for transition_variant in location_definition.get("transitions", []):
		if not transition_variant is Dictionary:
			continue
		var transition: Dictionary = transition_variant
		if int(transition.get("from_floor", 999999)) != floor_number:
			continue
		var available := bool(transition.get("initially_available", true))
		if transition.has("unlocked_by_quest"):
			available = false
			if location_state is Object and location_state.has_method("is_transition_available"):
				var transition_position := _position_from(transition.get("position", {}))
				available = bool(location_state.call(
					"is_transition_available",
					floor_number,
					int(transition.get("to_floor", 999999)),
					transition_position
				))
		if not available:
			continue
		var stair_position := _position_from(transition.get("position", {}))
		if _has_stair_at(tile_objects, stair_position):
			continue
		var destination_floor := int(transition.get("to_floor", 999999))
		tile_objects.append({
			"id": "transition_%d_%d" % [floor_number, destination_floor],
			"type": "stair_down" if destination_floor < floor_number else "stair_up",
			"position": {"q": stair_position.x, "r": stair_position.y},
			"to_floor": destination_floor
		})
		floor_cells[stair_position] = true
		wall_cells.erase(stair_position)

	if floor_cells.is_empty():
		return {"ok": false, "reason": "floor_has_no_walkable_cells"}
	var map_data := HexMapData.new()
	for wall_hex in wall_cells:
		if not floor_cells.has(wall_hex):
			map_data.add_cell(wall_hex, 0.0, false, "climbable_wall")
	for floor_hex in floor_cells:
		map_data.add_cell(floor_hex, 0.0, true, String(floor_definition.get("terrain", "cave_floor")))

	for actor_variant in floor_definition.get("actors", []):
		if not actor_variant is Dictionary or not _is_valid_position(_position_from(actor_variant.get("position", {}))):
			return {"ok": false, "reason": "actor_missing_position"}
		if not map_data.is_walkable(_position_from(actor_variant.get("position", {}))):
			return {"ok": false, "reason": "actor_outside_walkable_floor", "actor_id": String(actor_variant.get("id", ""))}
	for creature_variant in floor_definition.get("creatures", []):
		if not creature_variant is Dictionary or not _is_valid_position(_position_from(creature_variant.get("position", {}))):
			return {"ok": false, "reason": "creature_missing_position"}
		if not map_data.is_walkable(_position_from(creature_variant.get("position", {}))):
			return {"ok": false, "reason": "creature_outside_walkable_floor", "creature_id": String(creature_variant.get("id", ""))}

	var bounds := _bounds_for_cells(floor_cells, wall_cells)
	return {
		"ok": true,
		"location_id": String(location_definition.get("id", "")),
		"floor": floor_number,
		"map_data": map_data,
		"tile_objects": tile_objects,
		"actors": floor_definition.get("actors", []).duplicate(true),
		"creatures": floor_definition.get("creatures", []).duplicate(true),
		"walkable_hexes": _keys_as_array(floor_cells),
		"wall_hexes": _keys_as_array(wall_cells),
		"bounds": bounds
	}

static func _is_secret_discovered(location_state: Variant, secret_id: String) -> bool:
	if secret_id.is_empty():
		return false
	if not (location_state is Object):
		return false
	if not location_state.has_method("is_secret_discovered"):
		return false
	return bool(location_state.call("is_secret_discovered", secret_id))

static func _find_floor(location_definition: Dictionary, floor_number: int) -> Dictionary:
	for floor_variant in location_definition.get("floors", []):
		if floor_variant is Dictionary and int(floor_variant.get("floor", 999999)) == floor_number:
			return (floor_variant as Dictionary).duplicate(true)
	return {}

static func _add_room(room: Dictionary, floor_cells: Dictionary, wall_cells: Dictionary) -> void:
	var centre := _position_from(room.get("center", {}))
	var half_width := int(room.get("half_width", 0))
	var half_height := int(room.get("half_height", 0))
	var room_cells: Dictionary = {}
	var row_shift_mode := String(room.get("row_shift_mode", "flat"))
	for dq in range(-half_width + 1, half_width):
		var row_shift := floori(float(dq) / 2.0) if row_shift_mode == "source_building" else -floori(float(dq) / 2.0)
		for dr in range(-half_height + 1, half_height):
			var hex := Vector2i(centre.x + dq, centre.y + dr + row_shift)
			floor_cells[hex] = true
			room_cells[hex] = true
			wall_cells.erase(hex)
	if String(room.get("wall_mode", "enclosed")) == "open":
		return
	for floor_hex in room_cells:
		for neighbour in HexGrid.neighbors(floor_hex):
			if not floor_cells.has(neighbour):
				wall_cells[neighbour] = true

static func _add_corridor(corridor: Dictionary, floor_cells: Dictionary, wall_cells: Dictionary) -> void:
	var from_hex := _position_from(corridor.get("from", {}))
	var to_hex := _position_from(corridor.get("to", {}))
	var current_r := from_hex.y
	var q_step := 1 if to_hex.x > from_hex.x else -1
	var q := from_hex.x
	while q != to_hex.x:
		var hex := Vector2i(q, current_r)
		floor_cells[hex] = true
		wall_cells.erase(hex)
		q += q_step
	var r_step := 1 if to_hex.y > from_hex.y else -1
	var r := from_hex.y
	while r != to_hex.y:
		var hex := Vector2i(to_hex.x, r)
		floor_cells[hex] = true
		wall_cells.erase(hex)
		r += r_step
	floor_cells[to_hex] = true
	wall_cells.erase(to_hex)

static func _has_stair_at(tile_objects: Array[Dictionary], position: Vector2i) -> bool:
	for tile_object in tile_objects:
		if String(tile_object.get("type", "")) not in ["stair_up", "stair_down"]:
			continue
		if _position_from(tile_object.get("position", {})) == position:
			return true
	return false

static func _position_from(value: Variant) -> Vector2i:
	if not value is Dictionary:
		return Vector2i(2147483647, 2147483647)
	return Vector2i(int(value.get("q", 2147483647)), int(value.get("r", 2147483647)))

static func _is_valid_position(position: Vector2i) -> bool:
	return position.x != 2147483647 and position.y != 2147483647

static func _bounds_for_cells(floor_cells: Dictionary, wall_cells: Dictionary) -> Dictionary:
	var min_q := 2147483647
	var min_r := 2147483647
	var max_q := -2147483648
	var max_r := -2147483648
	for hex in floor_cells.keys() + wall_cells.keys():
		min_q = mini(min_q, hex.x)
		min_r = mini(min_r, hex.y)
		max_q = maxi(max_q, hex.x)
		max_r = maxi(max_r, hex.y)
	return {"min_q": min_q, "min_r": min_r, "max_q": max_q, "max_r": max_r}

static func _keys_as_array(cells: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for hex in cells:
		result.append(hex)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x < b.x if a.x != b.x else a.y < b.y
	)
	return result
