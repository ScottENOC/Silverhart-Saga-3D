class_name MovementRules
extends RefCounted

const BASE_STEP_COST: float = 5.0

static func base_cost_for(state: CharacterState) -> float:
    var cost := BASE_STEP_COST
    var skills: Dictionary = state.skills
    var equipment: Dictionary = state.equipment
    var armour_id := String(equipment.get("armour", ""))
    var armour_item: Dictionary = state.equipped_item_data.get("armour", {})
    var light_or_unarmoured := armour_id.is_empty() or armour_id == "light_armor" or String(armour_item.get("weight_class", "")) == "light"
    if light_or_unarmoured:
        cost -= float(skills.get("fastMovement", skills.get("fast_movement", 0)))
    var offhand_id := String(equipment.get("offhand", ""))
    var offhand_item: Dictionary = state.equipped_item_data.get("offhand", {})
    var has_shield := bool(equipment.get("offhand_is_shield", false)) or offhand_id == "shield" or String(offhand_item.get("type", "")) == "shield"
    if armour_id.is_empty() and armour_item.is_empty() and not has_shield and int(skills.get("swift_step", 0)) > 0:
        cost -= 1.0
    return maxf(1.0, cost)

static func terrain_multiplier(map_data: HexMapData, destination: Vector2i, state: CharacterState) -> float:
    var multiplier := map_data.movement_multiplier_at(destination)
    var terrain_id := map_data.terrain_id_at(destination)
    if terrain_id == "foliage" and (int(state.skills.get("elf_foliage_expertise", 0)) > 0 or int(state.skills.get("druid_foliage_expertise", 0)) > 0):
        multiplier = 1.0
    return maxf(0.1, multiplier)

static func step_cost(map_data: HexMapData, from_hex: Vector2i, to_hex: Vector2i, state: CharacterState) -> float:
    if state == null or HexGrid.distance(from_hex, to_hex) != 1:
        return INF
    var elevation_multiplier := TerrainElevationRules.movement_multiplier(map_data, from_hex, to_hex, state)
    if is_inf(elevation_multiplier):
        return INF
    return base_cost_for(state) * terrain_multiplier(map_data, to_hex, state) * elevation_multiplier
