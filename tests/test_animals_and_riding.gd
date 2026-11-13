extends SceneTree

var _failures: int = 0

func _initialize() -> void:
    _test_animal_catalog_and_state()
    _test_animal_world_registration()
    _test_animal_riding()
    _test_mounted_lifecycle_cleanup()
    if _failures > 0:
        push_error("%d test assertion(s) failed." % _failures)
        quit(1)
        return
    print("Animals and riding tests passed.")
    quit(0)

func _check(condition: bool, message: String = "Assertion failed") -> void:
    if not condition:
        _failures += 1
        push_error(message)
func _test_animal_catalog_and_state() -> void:
    var expected_kinds := PackedStringArray([
        "cow", "bull", "horse", "donkey", "alpaca", "wolf",
        "fox", "deer", "stag", "husky", "shiba_inu"
    ])
    var supported := AnimalCatalog.supported_kinds()
    _check(supported.size() == expected_kinds.size(), "Every currently modelled animal must have a gameplay profile")
    for kind in expected_kinds:
        _check(AnimalCatalog.has_profile(kind), "Missing animal profile for art kind: %s" % kind)
        var animal := AnimalCatalog.create_state(kind, "animal_" + kind)
        _check(animal != null, "Animal profile should create a CharacterState: %s" % kind)
        if animal == null:
            continue
        _check(animal.creature_kind == kind and animal.race == "animal", "Animal identity should be explicit")
        _check(animal.tags.has("animal"), "Animal combat tag should be present")
        _check(animal.max_health > 0 and animal.health == animal.max_health, "Animal should start at full positive health")
        _check(animal.animal_attributes.has("strength") and animal.animal_attributes.has("endurance") and animal.animal_attributes.has("agility"), "Animal physical attributes should be complete")
        _check(animal.time_points >= ActionEconomy.COMBAT_TURN_READY_TP, "Unridden animals should own an independent ready TP pool")
        var restored := CharacterState.from_dict(animal.to_dict())
        _check(restored.creature_kind == animal.creature_kind, "Animal species survives save/load")
        _check(restored.animal_attributes == animal.animal_attributes, "Individual animal attributes survive save/load")
        _check(restored.mountable == animal.mountable and restored.mount_size == animal.mount_size, "Mount metadata survives save/load")
        _check(restored.individual_seed == animal.individual_seed, "Individual seed survives save/load")
        _check(restored.skills == animal.skills, "Species skills survive save/load")

    var horse := AnimalCatalog.create_state("horse", "horse_source_check", "", Vector2i.ZERO, 101)
    _check(horse.max_health >= 49 and horse.max_health <= 51, "Horse should receive exactly four Health ranks on top of its 10 HP base")
    _check(int(horse.skills.get("health", 0)) == 4 and int(horse.skills.get("fastMovement", 0)) == 2, "Horse should retain original 2D skills")
    _check(horse.mountable and horse.mount_size == 3, "Horse should retain original mount size")

    var wolf := AnimalCatalog.create_state("wolf", "wolf_source_check", "", Vector2i.ZERO, 202)
    _check(wolf.max_health >= 19 and wolf.max_health <= 21, "Wolf should receive exactly one Health rank on top of its 10 HP base")
    _check(int(wolf.skills.get("timePointRate", 0)) == 6, "Wolf should retain its original time-point-rate skill")
    _check(is_equal_approx(wolf.time_points_per_tick, 1.3), "Wolf TP regeneration should reflect six 0.05 ranks")
    _check(wolf.mountable and wolf.mount_size == 2, "Wolf should retain original mount size")

    var deer := AnimalCatalog.create_state("deer", "deer_source_check", "", Vector2i.ZERO, 303)
    _check(deer.max_health >= 3 and deer.max_health <= 5, "Deer should retain its original 4 HP baseline")
    _check(int(deer.skills.get("fastMovement", 0)) == 1, "Deer should retain its original fast movement")

    var individual_a := AnimalCatalog.create_state("horse", "horse_a", "", Vector2i.ZERO, 111)
    var individual_b := AnimalCatalog.create_state("horse", "horse_b", "", Vector2i.ZERO, 222)
    _check(individual_a.individual_seed != individual_b.individual_seed, "Separate animals should carry separate individual seeds")
    _check(individual_a.animal_attributes != individual_b.animal_attributes or individual_a.max_health != individual_b.max_health, "Individuals of one species should be capable of differing physical stats")

    var profile_validation := AnimalCatalog.validate_profiles()
    _check(bool(profile_validation.get("ok", false)), "All animal profiles should pass completeness validation")

    var movement_horse := MovementRules.base_cost_for(horse)
    _check(is_equal_approx(movement_horse, 3.0), "Horse movement should use its source fastMovement ranks")
    var movement_wolf := MovementRules.base_cost_for(wolf)
    _check(is_equal_approx(movement_wolf, 4.0), "Wolf movement should use its source fastMovement rank")

func _test_animal_world_registration() -> void:
    var simulation := WorldSimulation.new()
    var horse := AnimalCatalog.create_state("horse", "registered_horse", "Farm Horse", Vector2i(5, 66), 4242)
    horse.combat_dormant = true
    horse.side = "neutral"
    var result := simulation.register_animal(horse)
    _check(bool(result.get("ok", false)), "An art-backed animal should register in the campaign simulation")
    _check(horse.max_health >= 49 and horse.max_health <= 51, "Registration must not apply the horse Health ranks a second time")
    _check(simulation.get_character("registered_horse") == horse, "Registered animal should use the shared CharacterState registry")
    _check(simulation.occupied_hexes.get(Vector2i(5, 66), "") == "registered_horse", "Registered animal should reserve its world hex")
    _check(horse.combat_dormant and horse.side == "neutral", "Ambient animal should remain dormant and neutral")
    _check(not simulation.is_party_member(horse.id), "Animals must not be added to the player party")
    _check(horse.time_points >= ActionEconomy.COMBAT_TURN_READY_TP, "Unridden animal should retain its own TP pool")
    var duplicate := simulation.register_animal(AnimalCatalog.create_state("horse", "registered_horse", "Duplicate", Vector2i(6, 66)))
    _check(String(duplicate.get("reason", "")) == "duplicate_character_id", "Duplicate animal IDs should be rejected")
    var occupied := simulation.register_animal(AnimalCatalog.create_state("wolf", "occupied_wolf", "Wolf", Vector2i(5, 66)))
    _check(String(occupied.get("reason", "")) == "occupied_hex", "Animals cannot register on an occupied hex")
    var invalid := CharacterState.new("not_an_animal", "Not an animal", Vector2i(8, 66))
    _check(String(simulation.register_animal(invalid).get("reason", "")) == "invalid_animal_profile", "The animal registration path must reject human character states")
    var restored := WorldSimulation.new()
    restored.load_dict(simulation.to_dict())
    var saved_horse := restored.get_character("registered_horse")
    _check(saved_horse != null and saved_horse.creature_kind == "horse", "Registered animal should survive world save/load")
    _check(saved_horse.animal_attributes == horse.animal_attributes, "Registered animal individual attributes should survive world save/load")
    simulation.free()
    restored.free()

func _test_animal_riding() -> void:
    var simulation := WorldSimulation.new()
    var rider := CharacterState.new("rider", "Rider", Vector2i(0, 0))
    rider.side = "player"
    rider.skills["riding_druid"] = 1
    rider.time_points = 100.0
    simulation.register_character(rider)
    var horse := AnimalCatalog.create_state("horse", "riding_horse", "Farm Horse", Vector2i(1, 0), 5150)
    horse.side = "neutral"
    horse.combat_dormant = true
    simulation.register_animal(horse)
    for hex in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(1, 1), Vector2i(0, 1)]:
        simulation.map_data.add_cell(hex, 0.0, true, "grass")

    var untrained := CharacterState.new("untrained", "Untrained", Vector2i(0, 1))
    _check(String(simulation.can_ride(untrained.id, horse.id).get("reason", "")) == "unknown_character", "Riding eligibility should require registered participants")
    simulation.register_character(untrained)
    _check(String(simulation.can_ride(untrained.id, horse.id).get("reason", "")) == "riding_skill_required", "Riding must require one of the three alternative riding skills")
    rider.skills.erase("riding_druid")
    rider.skills["riding"] = 1
    _check(bool(simulation.can_ride(rider.id, horse.id).get("ok", false)), "Agility Riding should independently grant mount permission")
    rider.skills.erase("riding")
    rider.skills["riding_paladin"] = 1
    _check(bool(simulation.can_ride(rider.id, horse.id).get("ok", false)), "Divine Riding should independently grant mount permission")
    rider.skills.erase("riding_paladin")
    rider.skills["riding_druid"] = 1
    horse.side = "enemy"
    _check(String(simulation.can_ride(rider.id, horse.id).get("reason", "")) == "hostile_mount", "Hostile quest animals cannot be mounted")
    horse.side = "neutral"

    var mounted := simulation.mount_animal(rider.id, horse.id)
    _check(bool(mounted.get("ok", false)), "Nature Riding should allow mounting an appropriately sized horse")
    _check(rider.mounted_animal_id == horse.id and horse.mounted_by_id == rider.id, "Rider and mount should retain reciprocal stable links")
    _check(horse.is_rider and horse.side == "player" and not horse.combat_dormant, "A mounted animal joins its rider's side and leaves the dormant roster")
    var mounted_rider_tp := rider.time_points
    rider.time_points = ActionEconomy.COMBAT_TURN_READY_TP
    _check(not horse.can_start_combat_turn() and rider.can_start_combat_turn(), "The mount is removed from initiative while its rider remains the combatant")
    rider.time_points = mounted_rider_tp
    _check(rider.axial == horse.axial, "Mounted rider should share the mount's axial position")
    _check(not simulation.occupied_hexes.has(rider.axial) or String(simulation.occupied_hexes[rider.axial]) == horse.id, "Mounted rider must not reserve a second occupancy slot")
    _check(is_equal_approx(rider.time_points, 95.0), "Mounting should cost the rider 5 TP")
    _check(simulation.movement_cost(rider.id, Vector2i(2, 0)) < MovementRules.BASE_STEP_COST, "Mounted movement cost should use the horse's movement profile")

    horse.time_points = 110.0
    rider.time_points = 60.0
    simulation.is_in_combat = true
    simulation.turn_scheduler.current_character_id = rider.id
    _check(simulation.try_end_current_turn(), "Mounted rider should be able to end their own combat turn")
    _check(is_equal_approx(horse.time_points, float(ActionEconomy.TURN_END_TP)), "Mount TP should be capped at 80 when its rider ends their turn")
    simulation.is_in_combat = false

    var restored := WorldSimulation.new()
    restored.load_dict(simulation.to_dict())
    var restored_rider := restored.get_character(rider.id)
    var restored_horse := restored.get_character(horse.id)
    _check(restored_rider.mounted_animal_id == horse.id and restored_horse.mounted_by_id == rider.id, "Mounted relationship should survive save/load")
    _check(String(restored.occupied_hexes.get(horse.axial, "")) == horse.id, "Save/load should reserve only the mount's shared hex")

    # Restore a ready rider and verify mounted movement spends the mount's TP,
    # moves both axial states, and leaves the rider's TP untouched.
    rider.time_points = 100.0
    horse.time_points = 100.0
    var horse_tp_before := horse.time_points
    var rider_tp_before := rider.time_points
    _check(simulation.try_move_character_step(rider.id, Vector2i(2, 0)), "Rider movement input should move the horse")
    _check(horse.axial == Vector2i(2, 0) and rider.axial == horse.axial, "Mounted movement should move rider and horse together")
    _check(is_equal_approx(horse.time_points, horse_tp_before - MovementRules.step_cost(simulation.map_data, Vector2i(1, 0), Vector2i(2, 0), horse)), "Mounted movement should spend the mount's terrain-adjusted TP")
    _check(is_equal_approx(rider.time_points, rider_tp_before), "Mounted travel should not spend the rider's TP")

    var dismounted := simulation.dismount_animal(rider.id)
    _check(bool(dismounted.get("ok", false)), "Rider should be able to dismount into an adjacent free hex")
    _check(rider.mounted_animal_id.is_empty() and horse.mounted_by_id.is_empty() and not horse.is_rider, "Dismounting should clear both riding links")
    _check(rider.axial != horse.axial and String(simulation.occupied_hexes.get(rider.axial, "")) == rider.id, "Dismounted rider should reserve their own adjacent hex")
    _check(horse.side == "neutral" and horse.combat_dormant, "Dismounted ambient mount should restore its original world status")
    simulation.free()
    restored.free()

func _test_mounted_lifecycle_cleanup() -> void:
    var mount_simulation := WorldSimulation.new()
    var rider := CharacterState.new("lifecycle_rider", "Lifecycle Rider", Vector2i(0, 0))
    rider.side = "player"
    rider.skills["riding"] = 1
    mount_simulation.register_character(rider)
    var horse := AnimalCatalog.create_state("horse", "lifecycle_horse", "Horse", Vector2i(1, 0), 8080)
    horse.combat_dormant = true
    for hex in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(1, 1), Vector2i(0, 1)]:
        mount_simulation.map_data.add_cell(hex, 0.0, true, "grass")
    mount_simulation.register_animal(horse)
    _check(bool(mount_simulation.mount_animal(rider.id, horse.id).get("ok", false)), "Lifecycle test rider should mount")
    horse.apply_damage(horse.max_health + 1)
    _check(horse.unconscious and not horse.can_act(), "Damage should incapacitate the horse")
    _check(rider.mounted_animal_id.is_empty() and horse.mounted_by_id.is_empty(), "An incapacitated mount must not retain a rider link")
    _check(not horse.is_rider and horse.side == "neutral" and horse.combat_dormant, "An incapacitated mount must restore its original world flags")
    _check(rider.axial != horse.axial and String(mount_simulation.occupied_hexes.get(rider.axial, "")) == rider.id, "Rider must be moved to a free adjacent hex when the mount is incapacitated")
    mount_simulation.free()

    var rider_simulation := WorldSimulation.new()
    var doomed_rider := CharacterState.new("doomed_rider", "Doomed Rider", Vector2i(0, 0))
    doomed_rider.side = "player"
    doomed_rider.skills["riding_druid"] = 1
    rider_simulation.register_character(doomed_rider)
    var second_horse := AnimalCatalog.create_state("horse", "rider_death_horse", "Horse", Vector2i(1, 0), 9090)
    second_horse.combat_dormant = true
    for hex in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(1, 1), Vector2i(0, 1)]:
        rider_simulation.map_data.add_cell(hex, 0.0, true, "grass")
    rider_simulation.register_animal(second_horse)
    _check(bool(rider_simulation.mount_animal(doomed_rider.id, second_horse.id).get("ok", false)), "Second lifecycle test rider should mount")
    doomed_rider.apply_damage(doomed_rider.max_health + int(ceil(float(doomed_rider.max_health) * 0.5)) + 1)
    _check(not doomed_rider.alive, "Lethal damage should kill the mounted rider")
    _check(doomed_rider.mounted_animal_id.is_empty() and second_horse.mounted_by_id.is_empty(), "A dead rider must be detached from the mount")
    _check(not second_horse.is_rider and second_horse.side == "neutral" and second_horse.combat_dormant, "Mount must return to its original world state when its rider dies")
    rider_simulation.free()
