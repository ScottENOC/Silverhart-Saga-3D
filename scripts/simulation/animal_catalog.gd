class_name AnimalCatalog
extends RefCounted
## Gameplay profiles for every animal model currently shipped in art/creatures.
## Values for horse, wolf and deer preserve the original Hex-crpg template
## health/skills where those templates exist. Other profiles are explicit
## first-pass 3D baselines, not claimed conversions from the 2D game.

const PROFILES: Dictionary = {
    "cow": {
        "display_name": "Cow", "health": 35, "strength": 3, "endurance": 5, "agility": 2,
        "damage": 1, "to_hit": 0.0, "dodge": 0.0, "tp_rate": 1.0, "fast_movement": 0,
        "vision": 0, "scent": 1, "size": 3, "mount_size": 0, "mountable": false,
        "carry_capacity": 0, "movement_mode": "ground", "temperament": "domestic",
        "skills": {}
    },
    "bull": {
        "display_name": "Bull", "health": 50, "strength": 7, "endurance": 6, "agility": 2,
        "damage": 8, "to_hit": 5.0, "dodge": 0.0, "tp_rate": 1.0, "fast_movement": 0,
        "vision": 0, "scent": 1, "size": 3, "mount_size": 0, "mountable": false,
        "carry_capacity": 0, "movement_mode": "ground", "temperament": "aggressive",
        "skills": {"meleeDamage": 2}
    },
    "horse": {
        "display_name": "Horse", "health": 50, "strength": 5, "endurance": 6, "agility": 6,
        "damage": 1, "to_hit": 0.0, "dodge": 0.0, "tp_rate": 1.0, "fast_movement": 2,
        "vision": 0, "scent": 1, "size": 3, "mount_size": 3, "mountable": true,
        "carry_capacity": 4, "movement_mode": "ground", "temperament": "domestic",
        "skills": {"health": 4, "fastMovement": 2}
    },
    "donkey": {
        "display_name": "Donkey", "health": 35, "strength": 4, "endurance": 7, "agility": 3,
        "damage": 2, "to_hit": 0.0, "dodge": 0.0, "tp_rate": 1.0, "fast_movement": 0,
        "vision": 0, "scent": 1, "size": 2, "mount_size": 0, "mountable": false,
        "carry_capacity": 5, "movement_mode": "ground", "temperament": "domestic",
        "skills": {}
    },
    "alpaca": {
        "display_name": "Alpaca", "health": 25, "strength": 2, "endurance": 4, "agility": 4,
        "damage": 1, "to_hit": 0.0, "dodge": 0.0, "tp_rate": 1.0, "fast_movement": 0,
        "vision": 0, "scent": 1, "size": 2, "mount_size": 0, "mountable": false,
        "carry_capacity": 2, "movement_mode": "ground", "temperament": "domestic",
        "skills": {}
    },
    "wolf": {
        "display_name": "Wolf", "health": 20, "strength": 4, "endurance": 3, "agility": 7,
        "damage": 3, "to_hit": 5.0, "dodge": 5.0, "tp_rate": 1.3, "fast_movement": 1,
        "vision": 10, "scent": 3, "size": 2, "mount_size": 2, "mountable": true,
        "carry_capacity": 1, "movement_mode": "ground", "temperament": "predator",
        "skills": {"health": 1, "unarmed_hit": 1, "unarmed_dmg": 1, "fastMovement": 1, "timePointRate": 6, "keen_scent": 1}
    },
    "fox": {
        "display_name": "Fox", "health": 15, "strength": 2, "endurance": 2, "agility": 8,
        "damage": 2, "to_hit": 5.0, "dodge": 10.0, "tp_rate": 1.1, "fast_movement": 1,
        "vision": 5, "scent": 3, "size": 1, "mount_size": 0, "mountable": false,
        "carry_capacity": 0, "movement_mode": "ground", "temperament": "wild",
        "skills": {"fastMovement": 1, "keen_scent": 1}
    },
    "deer": {
        "display_name": "Deer", "health": 4, "strength": 2, "endurance": 2, "agility": 8,
        "damage": 1, "to_hit": 0.0, "dodge": 10.0, "tp_rate": 1.0, "fast_movement": 1,
        "vision": 5, "scent": 2, "size": 2, "mount_size": 0, "mountable": false,
        "carry_capacity": 0, "movement_mode": "ground", "temperament": "prey",
        "skills": {"fastMovement": 1}
    },
    "stag": {
        "display_name": "Stag", "health": 30, "strength": 5, "endurance": 4, "agility": 5,
        "damage": 5, "to_hit": 5.0, "dodge": 5.0, "tp_rate": 1.0, "fast_movement": 1,
        "vision": 5, "scent": 2, "size": 3, "mount_size": 0, "mountable": false,
        "carry_capacity": 0, "movement_mode": "ground", "temperament": "defensive",
        "skills": {"fastMovement": 1}
    },
    "husky": {
        "display_name": "Husky", "health": 25, "strength": 4, "endurance": 6, "agility": 7,
        "damage": 3, "to_hit": 5.0, "dodge": 5.0, "tp_rate": 1.1, "fast_movement": 1,
        "vision": 0, "scent": 3, "size": 2, "mount_size": 0, "mountable": false,
        "carry_capacity": 1, "movement_mode": "ground", "temperament": "domestic",
        "skills": {"fastMovement": 1, "keen_scent": 1}
    },
    "shiba_inu": {
        "display_name": "Shiba Inu", "health": 20, "strength": 3, "endurance": 4, "agility": 7,
        "damage": 2, "to_hit": 0.0, "dodge": 5.0, "tp_rate": 1.0, "fast_movement": 1,
        "vision": 0, "scent": 2, "size": 1, "mount_size": 0, "mountable": false,
        "carry_capacity": 0, "movement_mode": "ground", "temperament": "domestic",
        "skills": {"fastMovement": 1, "keen_scent": 1}
    }
}

static func supported_kinds() -> PackedStringArray:
    var kinds := PackedStringArray()
    for kind in PROFILES.keys():
        kinds.append(String(kind))
    kinds.sort()
    return kinds

static func has_profile(creature_kind: String) -> bool:
    return PROFILES.has(creature_kind.to_lower())

static func profile_for(creature_kind: String) -> Dictionary:
    return PROFILES.get(creature_kind.to_lower(), {}).duplicate(true)

## Creates a normal CharacterState so existing combat, scheduler, world-save,
## and movement systems can process animals without a parallel combat stack.
## A non-zero seed gives stable per-individual variation across save/load/rebuild.
static func create_state(
    creature_kind: String,
    creature_id: String,
    display_name: String = "",
    start_hex: Vector2i = Vector2i.ZERO,
    individual_seed: int = 0
) -> CharacterState:
    var kind := creature_kind.to_lower()
    if not PROFILES.has(kind):
        push_error("No animal gameplay profile for art kind: %s" % creature_kind)
        return null

    var profile: Dictionary = PROFILES[kind]
    var state := CharacterState.new(
        creature_id,
        display_name if not display_name.is_empty() else String(profile["display_name"]),
        start_hex
    )
    state.race = "animal"
    state.character_class = "creature"
    state.creature_kind = kind
    state.tags = ["animal", kind]
    state.animal_attributes = {
        "strength": int(profile["strength"]),
        "endurance": int(profile["endurance"]),
        "agility": int(profile["agility"])
    }
    state.creature_size = int(profile["size"])
    state.mount_size = int(profile["mount_size"])
    state.mountable = bool(profile["mountable"])
    state.carry_capacity = int(profile["carry_capacity"])
    state.movement_mode = String(profile["movement_mode"])
    state.temperament = String(profile["temperament"])
    state.vision_bonus = int(profile["vision"])
    state.scent_bonus = int(profile["scent"])
    state.individual_seed = individual_seed if individual_seed != 0 else abs(hash(creature_id + ":" + kind))

    var rng := RandomNumberGenerator.new()
    rng.seed = state.individual_seed
    # Use separate base-three digits from the stable individual seed for the
    # physical offsets. This makes variation repeatable and ensures distinct
    # seeds can yield visibly different individuals without random rerolls.
    var seed_value := absi(state.individual_seed)
    var strength_offset := posmod(seed_value, 3) - 1
    var endurance_offset := posmod(floori(float(seed_value) / 3.0), 3) - 1
    var agility_offset := posmod(floori(float(seed_value) / 9.0), 3) - 1
    if strength_offset == 0 and endurance_offset == 0 and agility_offset == 0:
        agility_offset = 1
    state.animal_attributes["strength"] = maxi(1, int(state.animal_attributes["strength"]) + strength_offset)
    state.animal_attributes["endurance"] = maxi(1, int(state.animal_attributes["endurance"]) + endurance_offset)
    state.animal_attributes["agility"] = maxi(1, int(state.animal_attributes["agility"]) + agility_offset)

    var base_health := int(profile["health"])
    var health_variance := roundi(base_health * 0.05)
    var health_delta := rng.randi_range(-health_variance, health_variance)
    state.max_health = maxi(1, base_health + health_delta)
    state.health = state.max_health
    state.base_damage = int(profile["damage"])
    state.to_hit_melee = float(profile["to_hit"])
    state.passive_dodge = float(profile["dodge"])
    state.time_points_per_tick = float(profile["tp_rate"])
    state.max_time_points = ActionEconomy.DEFAULT_MAX_TP
    state.time_points = ActionEconomy.COMBAT_TURN_READY_TP
    state.skills = profile["skills"].duplicate(true)
    state.quick_recovery_rank = int(state.skills.get("quickRecovery", 0))
    state.side = "neutral"
    state.combat_dormant = false
    state.is_rider = false
    state.impassable_to_player = false
    return state

static func validate_profiles() -> Dictionary:
    var errors: Array[String] = []
    for kind in supported_kinds():
        var profile: Dictionary = PROFILES[kind]
        for required in ["health", "strength", "endurance", "agility", "damage", "tp_rate", "size", "mount_size", "mountable", "skills"]:
            if not profile.has(required):
                errors.append("%s missing %s" % [kind, required])
        if int(profile.get("health", 0)) < 1:
            errors.append("%s has invalid health" % kind)
        if float(profile.get("tp_rate", 0.0)) <= 0.0:
            errors.append("%s has invalid TP regeneration" % kind)
    return {"ok": errors.is_empty(), "errors": errors}
