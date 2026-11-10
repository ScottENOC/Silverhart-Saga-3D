class_name CharacterState
extends RefCounted

signal lifecycle_changed(character_id: String, transition: String)

var id: String
var display_name: String
var axial: Vector2i
var race: String = "human"
var character_class: String = "fighter"
var level: int = 1
var experience: int = 0
var attributes: Dictionary = {}
var class_levels: Dictionary = {}
var free_skill_ranks: Dictionary = {}
var current_mana: int = 0
var max_mana: int = 0
var mana_caps: Dictionary = {"arcane": 10, "divine": 10, "nature": 10}
var max_spell_slots: int = 8
var unlocked_base_spells: Array[String] = []
var gold: int = 0
var game_mode: String = "campaign"
var campaign_id: String = "2"
var difficulty_mode: String = "normal"
var ironman_mode: bool = false
var gender_presentation: String = "Masculine"
var pronouns: String = "they/them"
var facing_direction: int = 2 # HexGrid direction index; 2 initially faces the W key direction.
var health: int = 100
var max_health: int = 100
## Runtime-only portrait supplied by the 3D presentation layer when available.
var portrait_texture: Texture2D
var side: String = "neutral"
var base_damage: int = 1
var to_hit_melee: float = 0.0
var to_hit_ranged: float = 0.0
var passive_dodge: float = 0.0
var base_reduction: int = 0
var armour_reduction: int = 0
var shield_reduction: int = 0
var helmet_reduction: int = 0
var temp_reduction: int = 0
var caught_off_guard: bool = false
var climbing: bool = false
var reaction_blocked: bool = false
var parries_remaining: int = 3
var sidesteps_remaining: int = 3
var tags: Array[String] = []
var alive: bool = true
var unconscious: bool = false
var is_rider: bool = false
var combat_dormant: bool = false
## If true, the player cannot squeeze past this NPC during exploration.
var impassable_to_player: bool = false

# The original game accumulates Time Points continuously. 100 TP makes an
# entity eligible to act in combat; a player turn normally ends at 80 TP.
var time_points: float = ActionEconomy.COMBAT_TURN_READY_TP
var time_points_per_tick: float = 1.0
var max_time_points: float = ActionEconomy.DEFAULT_MAX_TP
var total_time_points_spent: float = 0.0
var quick_recovery_rank: int = 0
var skills: Dictionary = {}
# equipment remains a compact slot -> gameplay item ID map for existing rules.
# equipped_item_data stores the corresponding item instance metadata, while
# inventory stores carried item instances with stable instance IDs.
var equipment: Dictionary = {}
var inventory: Array[Dictionary] = []
var equipped_item_data: Dictionary = {}

func _init(character_id: String = "", character_name: String = "", start_hex: Vector2i = Vector2i.ZERO) -> void:
    id = character_id
    display_name = character_name
    axial = start_hex

func add_inventory_item(item: Dictionary) -> bool:
    var instance_id := String(item.get("instance_id", ""))
    var item_id := String(item.get("id", ""))
    var quantity := int(item.get("quantity", 1))
    if instance_id.is_empty() or item_id.is_empty() or quantity < 1:
        return false
    for existing in inventory:
        if String(existing.get("instance_id", "")) == instance_id:
            return false
    inventory.append(item.duplicate(true))
    return true


func remove_inventory_item(instance_id: String, quantity: int = 1) -> bool:
    if instance_id.is_empty() or quantity < 1:
        return false
    for index in range(inventory.size()):
        if String(inventory[index].get("instance_id", "")) != instance_id:
            continue
        var current_quantity := int(inventory[index].get("quantity", 1))
        if current_quantity < quantity:
            return false
        if current_quantity == quantity:
            inventory.remove_at(index)
        else:
            inventory[index]["quantity"] = current_quantity - quantity
        return true
    return false


func equip_inventory_item(instance_id: String) -> bool:
    for index in range(inventory.size()):
        var item: Dictionary = inventory[index]
        if String(item.get("instance_id", "")) != instance_id:
            continue
        var slot := String(item.get("equipment_slot", ""))
        var item_id := String(item.get("id", ""))
        if slot.is_empty() or item_id.is_empty() or int(item.get("quantity", 1)) != 1:
            return false
        if equipped_item_data.has(slot):
            var previously_equipped: Dictionary = equipped_item_data[slot]
            inventory.append(previously_equipped.duplicate(true))
        equipment[slot] = item_id
        equipped_item_data[slot] = item.duplicate(true)
        inventory.remove_at(index)
        return true
    return false


func unequip_equipment_slot(slot: String) -> bool:
    if slot.is_empty() or not equipped_item_data.has(slot):
        return false
    var item: Dictionary = equipped_item_data[slot]
    inventory.append(item.duplicate(true))
    equipped_item_data.erase(slot)
    equipment.erase(slot)
    return true


func can_be_targeted() -> bool:
    return alive

func can_act() -> bool:
    return alive and not unconscious

## Source behaviour: 0..-50% max HP is unconscious; <= -50% is true death.
func apply_damage(amount: int) -> String:
    if not alive or amount <= 0:
        return "unchanged"
    health -= amount
    if float(health) <= -float(max_health) * 0.5:
        alive = false
        unconscious = false
        lifecycle_changed.emit(id, "died")
        return "died"
    if health <= 0:
        unconscious = true
        lifecycle_changed.emit(id, "downed")
        return "downed"
    return "damaged"

## Healing above zero wakes an unconscious living character. True death is terminal.
func apply_healing(amount: int) -> String:
    if not alive or amount <= 0:
        return "unchanged"
    health = mini(max_health, health + amount)
    if unconscious and health > 0:
        unconscious = false
        lifecycle_changed.emit(id, "revived")
        return "revived_from_unconscious"
    return "healed"

func can_start_combat_turn() -> bool:
    return ActionEconomy.can_start_combat_turn(
        time_points, alive, unconscious, is_rider, combat_dormant
    )

func should_end_turn(forced: bool = false) -> bool:
    return ActionEconomy.should_end_turn(time_points, quick_recovery_rank, forced)

func can_spend_time_points(cost: float) -> bool:
    return ActionEconomy.can_afford(time_points, cost)

func spend_time_points(cost: float) -> bool:
    if not can_spend_time_points(cost):
        return false
    time_points = ActionEconomy.spend(time_points, cost)
    total_time_points_spent += cost
    return true

func regenerate_time_points(tick_multiplier: float = 1.0) -> void:
    time_points = ActionEconomy.regenerate(
        time_points, time_points_per_tick, tick_multiplier, 150.0
    )

func to_dict() -> Dictionary:
    return {
        "id": id,
        "display_name": display_name,
        "race": race,
        "character_class": character_class,
        "level": level,
        "experience": experience,
        "attributes": attributes.duplicate(true),
        "class_levels": class_levels.duplicate(true),
        "free_skill_ranks": free_skill_ranks.duplicate(true),
        "current_mana": current_mana,
        "max_mana": max_mana,
        "mana_caps": mana_caps.duplicate(true),
        "max_spell_slots": max_spell_slots,
        "unlocked_base_spells": unlocked_base_spells.duplicate(),
        "gold": gold,
        "game_mode": game_mode,
        "campaign_id": campaign_id,
        "difficulty_mode": difficulty_mode,
        "ironman_mode": ironman_mode,
        "gender_presentation": gender_presentation,
        "pronouns": pronouns,
        "axial_q": axial.x,
        "axial_r": axial.y,
        "facing_direction": facing_direction,
        "health": health,
        "max_health": max_health,
        "side": side,
        "base_damage": base_damage,
        "to_hit_melee": to_hit_melee,
        "to_hit_ranged": to_hit_ranged,
        "passive_dodge": passive_dodge,
        "base_reduction": base_reduction,
        "armour_reduction": armour_reduction,
        "shield_reduction": shield_reduction,
        "helmet_reduction": helmet_reduction,
        "temp_reduction": temp_reduction,
        "caught_off_guard": caught_off_guard,
        "climbing": climbing,
        "reaction_blocked": reaction_blocked,
        "parries_remaining": parries_remaining,
        "sidesteps_remaining": sidesteps_remaining,
        "tags": tags.duplicate(),
        "alive": alive,
        "unconscious": unconscious,
        "is_rider": is_rider,
        "combat_dormant": combat_dormant,
        "impassable_to_player": impassable_to_player,
        "time_points": time_points,
        "time_points_per_tick": time_points_per_tick,
        "max_time_points": max_time_points,
        "total_time_points_spent": total_time_points_spent,
        "quick_recovery_rank": quick_recovery_rank,
        "skills": skills.duplicate(true),
        "equipment": equipment.duplicate(true),
        "inventory": inventory.duplicate(true),
        "equipped_item_data": equipped_item_data.duplicate(true),
    }

static func from_dict(data: Dictionary) -> CharacterState:
    var state := CharacterState.new(
        String(data.get("id", "")),
        String(data.get("display_name", "")),
        Vector2i(int(data.get("axial_q", 0)), int(data.get("axial_r", 0)))
    )
    state.facing_direction = posmod(int(data.get("facing_direction", 2)), 6)
    state.race = String(data.get("race", "human"))
    state.character_class = String(data.get("character_class", "fighter"))
    state.level = maxi(1, int(data.get("level", 1)))
    state.experience = maxi(0, int(data.get("experience", 0)))
    state.attributes = data.get("attributes", {}).duplicate(true)
    state.class_levels = data.get("class_levels", {}).duplicate(true)
    state.free_skill_ranks = data.get("free_skill_ranks", {}).duplicate(true)
    state.current_mana = int(data.get("current_mana", 0))
    state.max_mana = int(data.get("max_mana", 0))
    state.mana_caps = data.get("mana_caps", {"arcane": 10, "divine": 10, "nature": 10}).duplicate(true)
    state.max_spell_slots = int(data.get("max_spell_slots", 8))
    for spell_id in data.get("unlocked_base_spells", []):
        state.unlocked_base_spells.append(String(spell_id))
    state.gold = int(data.get("gold", 0))
    state.game_mode = String(data.get("game_mode", "campaign"))
    state.campaign_id = String(data.get("campaign_id", "2"))
    state.difficulty_mode = String(data.get("difficulty_mode", "normal"))
    state.ironman_mode = bool(data.get("ironman_mode", false))
    state.gender_presentation = String(data.get("gender_presentation", "Masculine"))
    state.pronouns = String(data.get("pronouns", "they/them"))
    state.health = int(data.get("health", 100))
    state.max_health = int(data.get("max_health", 100))
    state.side = String(data.get("side", "neutral"))
    state.base_damage = int(data.get("base_damage", 1))
    state.to_hit_melee = float(data.get("to_hit_melee", 0.0))
    state.to_hit_ranged = float(data.get("to_hit_ranged", 0.0))
    state.passive_dodge = float(data.get("passive_dodge", 0.0))
    state.base_reduction = int(data.get("base_reduction", 0))
    state.armour_reduction = int(data.get("armour_reduction", 0))
    state.shield_reduction = int(data.get("shield_reduction", 0))
    state.helmet_reduction = int(data.get("helmet_reduction", 0))
    state.temp_reduction = int(data.get("temp_reduction", 0))
    state.caught_off_guard = bool(data.get("caught_off_guard", false))
    state.climbing = bool(data.get("climbing", false))
    state.reaction_blocked = bool(data.get("reaction_blocked", false))
    state.parries_remaining = clampi(int(data.get("parries_remaining", 3)), 0, 3)
    state.sidesteps_remaining = clampi(int(data.get("sidesteps_remaining", 3)), 0, 3)
    var saved_tags: Array = data.get("tags", [])
    for tag in saved_tags:
        state.tags.append(String(tag))
    state.alive = bool(data.get("alive", true))
    state.unconscious = bool(data.get("unconscious", false))
    state.is_rider = bool(data.get("is_rider", false))
    state.combat_dormant = bool(data.get("combat_dormant", false))
    state.impassable_to_player = bool(data.get("impassable_to_player", false))
    state.time_points = float(data.get("time_points", 0.0))
    state.time_points_per_tick = float(data.get("time_points_per_tick", 1.0))
    state.max_time_points = float(data.get("max_time_points", ActionEconomy.DEFAULT_MAX_TP))
    state.total_time_points_spent = float(data.get("total_time_points_spent", 0.0))
    state.quick_recovery_rank = clampi(int(data.get("quick_recovery_rank", 0)), 0, ActionEconomy.MAX_QUICK_RECOVERY_RANK)
    state.skills = data.get("skills", {}).duplicate(true)
    state.equipment = data.get("equipment", {}).duplicate(true)
    var saved_inventory: Array = data.get("inventory", [])
    for item in saved_inventory:
        if item is Dictionary:
            state.inventory.append(item.duplicate(true))
    state.equipped_item_data = data.get("equipped_item_data", {}).duplicate(true)
    return state
