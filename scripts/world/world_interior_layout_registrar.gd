class_name WorldInteriorLayoutRegistrar
extends RefCounted
## Applies authored interior collision/floor rules to the logical world map.
## Geometry and footprints come from the location's interior layout definition.

const BUILDING_LAYOUT_REGISTRAR = preload("res://scripts/world/building_layout_registrar.gd")

static func register_layout(
	simulation: WorldSimulation,
	definition: Dictionary,
	hex_radius: float
) -> bool:
	if simulation == null or definition.is_empty() or hex_radius <= 0.0:
		return false
	var ground: Dictionary = definition.get("ground_overlay", {})
	var query_script: Variant = ground.get("query_script")
	if not query_script is Script:
		return false
	var query_context: Dictionary = ground.get("query_context", {})
	var in_bounds: Callable = Callable(query_script, String(ground.get("in_bounds_method", "is_in_bounds"))).bind(query_context)
	var terrain_blocked: Callable = Callable(query_script, String(ground.get("blocked_method", "is_blocked"))).bind(query_context)
	if not in_bounds.is_valid() or not terrain_blocked.is_valid():
		return false
	var room_half_width := float(ground.get("room_half_width", 0.0))
	var room_half_depth := float(ground.get("room_half_depth", 0.0))
	if room_half_width <= 0.0 or room_half_depth <= 0.0:
		return false
	var wall_regions: Array = ground.get("wall_blockers", [])
	var furniture_regions: Array = ground.get("furniture_blockers", [])
	var radius := int(ground.get("map_radius", 0))
	if radius <= 0:
		return false

	for q in range(-radius, radius + 1):
		for r in range(-radius, radius + 1):
			var hex := Vector2i(q, r)
			if not bool(in_bounds.call(hex)):
				continue
			var world := HexGrid.axial_to_world(hex, hex_radius)
			var inside_room := absf(world.x) < room_half_width - 0.2 and absf(world.z) < room_half_depth - 0.2
			var blocked := (
				_matches_any_region(world, wall_regions)
				or (inside_room and _matches_any_region(world, furniture_regions))
				or bool(terrain_blocked.call(hex))
			)
			if inside_room:
				simulation.map_data.add_cell(hex, 0.0, not blocked, "timber_floor")
			else:
				simulation.map_data.set_walkable(hex, not blocked)

	var upper_floor_cells := _build_upper_floor_cells(definition.get("upper_floor", {}), hex_radius)
	if upper_floor_cells.is_empty():
		return false
	var building_definition: Dictionary = definition.get("building", {})
	var door_definition: Dictionary = definition.get("door", {})
	if not BUILDING_LAYOUT_REGISTRAR.register_layout(
		simulation, building_definition, door_definition, upper_floor_cells
	):
		return false
	return true

static func _matches_any_region(world: Vector3, regions: Array) -> bool:
	for region in regions:
		if not region is Dictionary:
			continue
		if (
			world.x > float(region.get("x_min", -INF))
			and world.x < float(region.get("x_max", INF))
			and world.z > float(region.get("z_min", -INF))
			and world.z < float(region.get("z_max", INF))
		):
			return true
	return false

static func _build_upper_floor_cells(definition: Dictionary, hex_radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var origin: Vector2i = definition.get("origin", Vector2i.ZERO)
	var q_min := int(definition.get("q_min", 0))
	var q_max := int(definition.get("q_max", -1))
	var row_min := int(definition.get("row_min", 0))
	var row_max := int(definition.get("row_max", -1))
	if q_max < q_min or row_max < row_min:
		return result
	var partition_rules: Array = definition.get("partition_rules", [])
	var blocked_hexes: Array = definition.get("blocked_hexes", [])
	var elevation := float(definition.get("elevation", 0.0))
	var terrain_id := String(definition.get("terrain_id", "timber_floor"))
	for q in range(q_min, q_max + 1):
		var row_shift := -floori(float(q) / 2.0)
		for row in range(row_min, row_max + 1):
			var local_hex := Vector2i(q, row + row_shift)
			var local_world := HexGrid.axial_to_world(local_hex, hex_radius)
			var partition_wall := _matches_partition_rule(q, local_world.z, partition_rules)
			var furniture_blocked := blocked_hexes.has(local_hex)
			result.append({
				"hex": origin + local_hex,
				"elevation": elevation,
				"walkable": not (partition_wall or furniture_blocked),
				"terrain_id": terrain_id
			})
	return result

static func _matches_partition_rule(q: int, local_z: float, rules: Array) -> bool:
	for rule in rules:
		if not rule is Dictionary:
			continue
		if q < int(rule.get("q_min", q)) or q > int(rule.get("q_max", q)):
			continue
		if (rule.get("exclude_q", []) as Array).has(q):
			continue
		if rule.has("z_abs_min") and absf(local_z) <= float(rule["z_abs_min"]):
			continue
		if rule.has("z_abs_max") and absf(local_z) >= float(rule["z_abs_max"]):
			continue
		return true
	return false
