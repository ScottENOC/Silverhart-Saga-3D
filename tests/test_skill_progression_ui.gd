extends SceneTree

const CHARACTER_STATE_SCRIPT = preload("res://scripts/simulation/character_state.gd")
const SKILL_CATALOG_SCRIPT = preload("res://scripts/simulation/skill_catalog.gd")
const SKILL_PROGRESSION_SCRIPT = preload("res://scripts/simulation/skill_progression.gd")

var _failures := 0

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var character = CHARACTER_STATE_SCRIPT.new("skill_test", "Skill Test")
    character.attributes = {"strength": 2, "agility": 0, "elf": 1}
    SKILL_PROGRESSION_SCRIPT.initialise(character)

    var eligibility := SKILL_PROGRESSION_SCRIPT.can_purchase(character, "iron_grip")
    _check(bool(eligibility.get("ok", false)), "A root skill with an available matching pool should be purchasable")
    _check(String(eligibility.get("funding_pool", "")) == "strength", "A strength-tree skill should use the strength pool")

    var purchase := SKILL_PROGRESSION_SCRIPT.purchase(character, "iron_grip")
    _check(bool(purchase.get("ok", false)), "Purchasing a legal skill should succeed")
    _check(int(character.skills.get("iron_grip", 0)) == 1, "Purchasing should increase the skill rank")
    _check(int(character.attributes.get("strength", 0)) == 1, "Purchasing should deduct exactly one point from the selected pool")
    _check(int(character.skill_spent_by_pool.get("strength", 0)) == 1, "The spent-points ledger should record the purchase")
    _check(int(character.skill_spent_by_id.get("iron_grip", 0)) == 1, "The per-skill ledger should record the purchase")

    var capped := SKILL_PROGRESSION_SCRIPT.can_purchase(character, "iron_grip")
    _check(String(capped.get("reason", "")) == "maximum_rank_reached", "A one-rank skill should reject a second purchase")

    var locked := SKILL_PROGRESSION_SCRIPT.can_purchase(character, "ageless_patience")
    _check(String(locked.get("reason", "")) == "prerequisite_missing", "A skill with an unmet prerequisite should remain locked")

    var misc_character = CHARACTER_STATE_SCRIPT.new("misc_test", "Misc Test")
    misc_character.attributes = {"strength": 1, "agility": 1}
    SKILL_PROGRESSION_SCRIPT.initialise(misc_character)
    var misc_eligibility := SKILL_PROGRESSION_SCRIPT.can_purchase(misc_character, "appraisal")
    _check(String(misc_eligibility.get("reason", "")) == "funding_pool_choice_required", "Misc skills with multiple eligible pools should require an explicit pool choice")
    var misc_purchase := SKILL_PROGRESSION_SCRIPT.purchase(misc_character, "appraisal", "agility")
    _check(bool(misc_purchase.get("ok", false)), "A misc skill should purchase successfully with an explicitly selected pool")
    _check(int(misc_character.attributes.get("agility", 0)) == 0, "Misc purchase should deduct from the selected pool")
    _check(int(misc_character.attributes.get("strength", 0)) == 1, "Misc purchase should leave other pools unchanged")

    var report := SKILL_PROGRESSION_SCRIPT.accounting_report(character)
    for pool_name in report.get("pools", {}):
        var pool: Dictionary = report.pools[pool_name]
        _check(bool(pool.get("balanced", false)), "Point accounting should balance for pool %s" % String(pool_name))

    var restored = CHARACTER_STATE_SCRIPT.from_dict(character.to_dict())
    _check(int(restored.skills.get("iron_grip", 0)) == 1, "Purchased skill ranks should survive CharacterState save/load")
    _check(int(restored.attributes.get("strength", 0)) == 1, "Remaining points should survive CharacterState save/load")
    _check(int(restored.skill_spent_by_pool.get("strength", 0)) == 1, "Pool spending ledger should survive CharacterState save/load")
    _check(int(restored.skill_spent_by_id.get("iron_grip", 0)) == 1, "Per-skill spending ledger should survive CharacterState save/load")

    _check(SKILL_CATALOG_SCRIPT.get_skill("iron_grip").get("name", "") == "Iron Grip", "The UI catalogue should expose skill display metadata")

    if _failures > 0:
        push_error("%d skill progression test assertion(s) failed." % _failures)
        quit(1)
        return
    print("Skill progression tests passed.")
    quit(0)


func _check(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error("FAIL: " + message)
