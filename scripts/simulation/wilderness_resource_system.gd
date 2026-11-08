class_name WildernessResourceSystem
extends RefCounted
## Deterministic, lazily materialised wilderness nodes. Only changed nodes are
## stored in saves; untouched terrain is regenerated from its axial coordinate.

const VILLAGE_EXCLUSION_RADIUS: int = 35
const SECONDS_PER_HOUR: float = 3600.0
const REGROW_HOURS := {
    "fruit_tree": 24.0,
    "herb_patch": 18.0,
    "fishing_spot": 4.0,
    "ore_node": 72.0,
    "timber_tree": 48.0,
    "stone_deposit": 48.0,
}
var nodes: Dictionary = {}

func ensure_node(hex: Vector2i, terrain_id: String) -> Dictionary:
    var key := _key(hex)
    if nodes.has(key):
        return (nodes[key] as Dictionary).duplicate(true)
    if HexGrid.distance(Vector2i.ZERO, hex) < VILLAGE_EXCLUSION_RADIUS:
        return {}
    var roll := _roll(hex.x * 2.13 + 31.0, hex.y * 3.17 + 53.0)
    var node: Dictionary = {}
    match terrain_id:
        "rocky_outcrop", "mountain":
            if roll < 0.05:
                var ore_roll := _roll(hex.x * 5.1 + 7.0, hex.y * 7.3 + 11.0)
                var ore_id := "ore_iron"
                if ore_roll > 0.9995:
                    ore_id = "starmetal_ore"
                elif ore_roll > 0.994:
                    ore_id = "gem_blue"
                elif ore_roll > 0.988:
                    ore_id = "gem_red"
                elif ore_roll > 0.980:
                    ore_id = "gem_green"
                elif ore_roll > 0.95:
                    ore_id = "ore_gold"
                elif ore_roll > 0.80:
                    ore_id = "ore_silver"
                node = {"type": "ore_node", "item_id": ore_id, "depleted": false, "regrow_at": 0.0}
            elif roll < 0.12:
                node = {"type": "stone_deposit", "depleted": false, "regrow_at": 0.0}
        "forest":
            if roll >= 0.5 and roll < 0.506:
                node = {"type": "fruit_tree", "available": true, "regrow_at": 0.0}
            elif roll >= 0.506 and roll < 0.52:
                node = {"type": "timber_tree", "available": true, "regrow_at": 0.0}
        "grass":
            if roll >= 0.96:
                node = {"type": "herb_patch", "available": true, "regrow_at": 0.0}
        "water":
            if roll < 0.008:
                node = {"type": "fishing_spot", "last_harvest_at": -14400.0}
    if not node.is_empty():
        nodes[key] = node
    return node.duplicate(true)

func harvest(hex: Vector2i, terrain_id: String, character: CharacterState, world_seconds: float) -> Dictionary:
    if character == null or not character.can_act():
        return _failure("character_unavailable")
    var key := _key(hex)
    var node: Dictionary
    if nodes.has(key):
        node = nodes[key]
    else:
        node = ensure_node(hex, terrain_id)
    if node.is_empty():
        return _failure("no_resource_here")
    var node_type := String(node.get("type", ""))
    var skill_bounty := int(character.skills.get("nature_bounty", 0)) > 0
    var forager := int(character.skills.get("keen_forager", 0)) > 0
    var amount := 1
    var item_ids: Array[String] = []
    match node_type:
        "ore_node":
            if bool(node.get("depleted", false)):
                return _failure("resource_depleted")
            if not _has_tool(character, "pickaxe"):
                return _failure("requires_pickaxe")
            amount = 3 if forager else 1 + _roll_int(hex, world_seconds, 3)
            _append_items(item_ids, String(node.get("item_id", "ore_iron")), amount)
            node["depleted"] = true
            node["regrow_at"] = world_seconds + REGROW_HOURS[node_type] * SECONDS_PER_HOUR
        "stone_deposit":
            if bool(node.get("depleted", false)):
                return _failure("resource_depleted")
            amount = 2 + _roll_int(hex, world_seconds, 3)
            _append_items(item_ids, "stone", amount)
            node["depleted"] = true
            node["regrow_at"] = world_seconds + REGROW_HOURS[node_type] * SECONDS_PER_HOUR
        "fruit_tree", "herb_patch":
            if not bool(node.get("available", false)):
                return _failure("resource_regrowing")
            amount = (2 if forager else 1 + _roll_int(hex, world_seconds, 2)) + (1 if skill_bounty else 0)
            _append_items(item_ids, "fruit" if node_type == "fruit_tree" else "herbs", amount)
            node["available"] = false
            node["regrow_at"] = world_seconds + REGROW_HOURS[node_type] * SECONDS_PER_HOUR
        "timber_tree":
            if not bool(node.get("available", false)):
                return _failure("resource_regrowing")
            if not _has_tool(character, "axe"):
                return _failure("requires_axe")
            amount = 2 + _roll_int(hex, world_seconds, 3)
            _append_items(item_ids, "wood", amount)
            node["available"] = false
            node["regrow_at"] = world_seconds + REGROW_HOURS[node_type] * SECONDS_PER_HOUR
        "fishing_spot":
            if world_seconds - float(node.get("last_harvest_at", -14400.0)) < REGROW_HOURS[node_type] * SECONDS_PER_HOUR:
                return _failure("resource_regrowing")
            amount = 1 + (1 if skill_bounty else 0)
            _append_items(item_ids, "fish", amount)
            node["last_harvest_at"] = world_seconds
        _:
            return _failure("unsupported_resource")
    for index in range(item_ids.size()):
        var item := ItemCatalog.create_instance(item_ids[index], "gather_%s_%s_%d" % [key.replace(",", "_"), str(int(world_seconds * 10.0)), index])
        if item.is_empty() or not character.add_inventory_item(item):
            return _failure("inventory_rejected_item")
    nodes[key] = node
    return {"ok": true, "item_ids": item_ids, "amount": item_ids.size(), "node": node.duplicate(true)}

func advance_time(world_seconds: float) -> void:
    for key in nodes:
        var node: Dictionary = nodes[key]
        var node_type := String(node.get("type", ""))
        var regrow_at := float(node.get("regrow_at", 0.0))
        if regrow_at <= 0.0 or world_seconds < regrow_at:
            continue
        if node_type == "ore_node" or node_type == "stone_deposit":
            node["depleted"] = false
        elif node_type != "fishing_spot":
            node["available"] = true
        node["regrow_at"] = 0.0

func to_dict() -> Dictionary:
    return {"nodes": nodes.duplicate(true)}

func load_dict(data: Dictionary) -> void:
    nodes = data.get("nodes", {}).duplicate(true)

static func _key(hex: Vector2i) -> String:
    return "%d,%d" % [hex.x, hex.y]

static func _roll(x: float, y: float) -> float:
    var value := sin(x * 12.9898 + y * 78.233) * 43758.5453
    return value - floor(value)

static func _roll_int(hex: Vector2i, world_seconds: float, upper_bound: int) -> int:
    var value := absf(sin(float(hex.x * 92821 + hex.y * 68917) + world_seconds * 0.013) * 43758.5453)
    return posmod(floori(value), maxi(1, upper_bound))

static func _append_items(items: Array[String], item_id: String, amount: int) -> void:
    for _i in range(amount):
        items.append(item_id)

static func _has_tool(character: CharacterState, item_id: String) -> bool:
    for item in character.inventory:
        if String(item.get("id", "")) == item_id:
            return true
    return String(character.equipment.get("weapon", "")) == item_id or String(character.equipment.get("offhand", "")) == item_id

static func _failure(reason: String) -> Dictionary:
    return {"ok": false, "reason": reason}
