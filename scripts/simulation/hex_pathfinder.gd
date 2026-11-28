class_name HexPathfinder
extends RefCounted

## Weighted A* over the logical hex map. Closed, unlocked doors are valid
## route steps with an opening action cost; locked doors remain impassable.
static func find_path(map_data: HexMapData, occupied_hexes: Dictionary, start: Vector2i, target: Vector2i, state: CharacterState, characters: Dictionary = {}, combat_active: bool = false, doors: Dictionary = {}) -> Array[Vector2i]:
    var empty: Array[Vector2i] = []
    if state == null or not _is_traversable(map_data, start, doors) or not _is_traversable(map_data, target, doors):
        return empty
    if start == target:
        return [start]
    if occupied_hexes.has(target):
        return empty

    var open: Array[Vector2i] = [start]
    var came_from: Dictionary = {}
    var g_score: Dictionary = {start: 0.0}
    var minimum_step_cost := MovementRules.base_cost_for(state) * 0.075 # 0.1 minimum terrain multiplier x 0.75 minimum downhill multiplier.
    var f_score: Dictionary = {start: float(HexGrid.distance(start, target)) * minimum_step_cost}
    var iterations := 0
    while not open.is_empty() and iterations < 10000:
        iterations += 1
        var best_index := 0
        for i in range(1, open.size()):
            if float(f_score.get(open[i], INF)) < float(f_score.get(open[best_index], INF)):
                best_index = i
        var current: Vector2i = open.pop_at(best_index)
        if current == target:
            var path: Array[Vector2i] = [current]
            while came_from.has(current):
                current = came_from[current]
                path.push_front(current)
            return path
        for neighbour in HexGrid.neighbors(current):
            if not _is_traversable(map_data, neighbour, doors):
                continue
            if occupied_hexes.has(neighbour) and neighbour != start:
                var occupant := characters.get(String(occupied_hexes[neighbour])) as CharacterState
                if not _can_pass_through(state, occupant, combat_active):
                    continue
            var step_cost := MovementRules.step_cost(map_data, current, neighbour, state)
            var door := _door_at(doors, neighbour)
            if door != null and not door.is_passable():
                step_cost += WorldSimulation.DOOR_OPEN_TIME_POINT_COST
            var tentative := float(g_score[current]) + step_cost
            if tentative >= float(g_score.get(neighbour, INF)):
                continue
            came_from[neighbour] = current
            g_score[neighbour] = tentative
            f_score[neighbour] = tentative + float(HexGrid.distance(neighbour, target)) * minimum_step_cost
            if not open.has(neighbour):
                open.append(neighbour)
    return empty

static func _can_pass_through(mover: CharacterState, occupant: CharacterState, _combat_active: bool) -> bool:
    if mover == null or occupant == null:
        return false
    if occupant.impassable_to_player and mover.side != "enemy":
        return false
    if (mover.side == "enemy") != (occupant.side == "enemy") and (mover.side == "enemy" or occupant.side == "enemy"):
        return false
    return true

static func _is_traversable(map_data: HexMapData, hex: Vector2i, doors: Dictionary) -> bool:
    if map_data.is_walkable(hex):
        return true
    var door := _door_at(doors, hex)
    if door == null or door.is_passable() or door.locked:
        return false
    if not map_data.has_cell(hex):
        return false
    return bool(map_data.cells[hex].get("door_base_walkable", false))

static func _door_at(doors: Dictionary, hex: Vector2i) -> BuildingDoorState:
    for value in doors.values():
        var door := value as BuildingDoorState
        if door != null and door.hex == hex:
            return door
    return null
