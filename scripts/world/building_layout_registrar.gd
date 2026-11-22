class_name BuildingLayoutRegistrar
extends RefCounted
## Reusable registration for authored building definitions, doors and floor cells.
## Location scripts retain their geometry; this class owns the common setup path.

static func register_layout(
    simulation: WorldSimulation,
    building_definition: Dictionary,
    door_definition: Dictionary,
    floor_cells: Array[Dictionary]
) -> bool:
    if simulation == null:
        return false

    var building_id := String(building_definition.get("id", "")).strip_edges()
    var entrance: Variant = building_definition.get("entrance_hex")
    var door_id := String(door_definition.get("id", "")).strip_edges()
    var door_building_id := String(door_definition.get("building_id", "")).strip_edges()
    var door_hex: Variant = door_definition.get("hex")
    if building_id.is_empty() or not (entrance is Vector2i):
        return false
    if door_id.is_empty() or door_building_id != building_id or not (door_hex is Vector2i):
        return false
    if not simulation.map_data.has_cell(door_hex):
        return false
    if simulation.building_registry.definitions.has(building_id) or simulation.building_registry.doors.has(door_id):
        return false

    var seen_floor_hexes: Dictionary = {}
    for cell in floor_cells:
        var hex: Variant = cell.get("hex")
        if not (hex is Vector2i) or seen_floor_hexes.has(hex):
            return false
        # Regional terrain chunks may already have materialised cells beneath
        # an authored upper floor. Interior registration explicitly overlays
        # those generated terrain records with the authored floor records.
        # This runs during world setup, before gameplay mutations are possible.
        seen_floor_hexes[hex] = true

    if not simulation.building_registry.register_building(building_definition):
        return false
    if not simulation.building_registry.register_door(
        door_id,
        building_id,
        door_hex,
        bool(door_definition.get("starts_open", true)),
        bool(door_definition.get("starts_locked", false)),
        int(door_definition.get("durability", 20))
    ):
        simulation.building_registry.definitions.erase(building_id)
        return false

    var door_cell: Dictionary = simulation.map_data.cells[door_hex]
    door_cell["door_base_walkable"] = bool(door_cell.get("walkable", false))
    simulation.map_data.cells[door_hex] = door_cell
    simulation.sync_door_map_state(door_id)

    for cell in floor_cells:
        simulation.map_data.add_cell(
            cell["hex"],
            float(cell.get("elevation", 0.0)),
            bool(cell.get("walkable", true)),
            String(cell.get("terrain_id", "grass")),
            float(cell.get("movement_multiplier", -1.0))
        )
    return true
