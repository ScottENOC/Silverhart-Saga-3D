class_name CharacterState
extends RefCounted

var id: String
var display_name: String
var axial: Vector2i
var facing_direction: int = 2 # HexGrid direction index; 2 initially faces the W key direction.
var health: int = 100
var max_health: int = 100
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
var tags: Array[String] = []
var alive: bool = true
var unconscious: bool = false
var is_rider: bool = false
var combat_dormant: bool = false

# The original game accumulates Time Points continuously. 100 TP makes an
# entity eligible to act in combat; a player turn normally ends at 80 TP.
var time_points: float = 0.0
var time_points_per_tick: float = 1.0
var max_time_points: float = ActionEconomy.DEFAULT_MAX_TP
var total_time_points_spent: float = 0.0
var quick_recovery_rank: int = 0
var skills: Dictionary = {}
var equipment: Dictionary = {}

func _init(character_id: String = "", character_name: String = "", start_hex: Vector2i = Vector2i.ZERO) -> void:
    id = character_id
    display_name = character_name
    axial = start_hex

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
        time_points, time_points_per_tick, tick_multiplier, max_time_points
    )

func to_dict() -> Dictionary:
    return {
        "id": id,
        "display_name": display_name,
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
        "tags": tags.duplicate(),
        "alive": alive,
        "unconscious": unconscious,
        "is_rider": is_rider,
        "combat_dormant": combat_dormant,
        "time_points": time_points,
        "time_points_per_tick": time_points_per_tick,
        "max_time_points": max_time_points,
        "total_time_points_spent": total_time_points_spent,
        "quick_recovery_rank": quick_recovery_rank,
        "skills": skills.duplicate(true),
        "equipment": equipment.duplicate(true),
    }

static func from_dict(data: Dictionary) -> CharacterState:
    var state := CharacterState.new(
        String(data.get("id", "")),
        String(data.get("display_name", "")),
        Vector2i(int(data.get("axial_q", 0)), int(data.get("axial_r", 0)))
    )
    state.facing_direction = posmod(int(data.get("facing_direction", 2)), 6)
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
    var saved_tags: Array = data.get("tags", [])
    for tag in saved_tags:
        state.tags.append(String(tag))
    state.alive = bool(data.get("alive", true))
    state.unconscious = bool(data.get("unconscious", false))
    state.is_rider = bool(data.get("is_rider", false))
    state.combat_dormant = bool(data.get("combat_dormant", false))
    state.time_points = float(data.get("time_points", 0.0))
    state.time_points_per_tick = float(data.get("time_points_per_tick", 1.0))
    state.max_time_points = float(data.get("max_time_points", ActionEconomy.DEFAULT_MAX_TP))
    state.total_time_points_spent = float(data.get("total_time_points_spent", 0.0))
    state.quick_recovery_rank = clampi(int(data.get("quick_recovery_rank", 0)), 0, ActionEconomy.MAX_QUICK_RECOVERY_RANK)
    state.skills = data.get("skills", {}).duplicate(true)
    state.equipment = data.get("equipment", {}).duplicate(true)
    return state
