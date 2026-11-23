extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_firebolt()
	_test_counterspell()
	_test_counterspell_reaction()
	_test_feather_fall()
	_test_disguise_self()
	_test_heal()
	_test_divine_protection()
	_test_divine_strength()
	_test_curse()
	_test_summon_animal_and_companion()
	_test_summon_uses_animal_catalog_and_mount_profile()
	_test_multi_target_heal()
	_test_entangle()
	_test_calm_animal()
	_test_wild_fury()
	if failures > 0:
		push_error("%d official spell effect test(s) failed." % failures)
		quit(1)
		return
	print("All 12 official spell effect tests passed.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: " + message)


func _new_sim() -> Dictionary:
	var sim := WorldSimulation.new()
	var caster := CharacterState.new("caster", "Caster", Vector2i.ZERO)
	caster.side = "player"
	caster.current_mana = 100
	caster.max_mana = 100
	caster.time_points = 500.0
	caster.unlocked_base_spells = [
		"firebolt", "counterspell", "feather_fall", "disguise_self",
		"heal", "divine_protection", "divine_strength", "curse",
		"summon_animal", "entangle", "calm_animal", "wild_fury"
	]
	for q in range(-5, 6):
		for r in range(-5, 6):
			var hex := Vector2i(q, r)
			if HexGrid.distance(Vector2i.ZERO, hex) <= 5:
				sim.map_data.add_cell(hex)
	sim.register_character(caster)
	return {"sim": sim, "caster": caster}


func _cast(sim: WorldSimulation, caster: CharacterState, target: CharacterState, spell_id: String, modifiers: Dictionary = {}) -> Dictionary:
	var prepared := PreparedSpell.create(spell_id, modifiers)
	caster.prepared_spells.append(prepared.to_dict())
	return sim.submit_action(SimulationActionRequest.cast_spell(caster.id, target.id if target != null else "", prepared), 42)


func _cast_at(sim: WorldSimulation, caster: CharacterState, hex: Vector2i, spell_id: String, modifiers: Dictionary = {}) -> Dictionary:
	var prepared := PreparedSpell.create(spell_id, modifiers)
	caster.prepared_spells.append(prepared.to_dict())
	return sim.submit_action(SimulationActionRequest.cast_spell_at_hex(caster.id, hex, prepared), 42)


func _test_firebolt() -> void:
	var setup := _new_sim()
	var sim: WorldSimulation = setup.sim
	var caster: CharacterState = setup.caster
	var enemy := CharacterState.new("fire_target", "Fire Target", Vector2i(2, 0))
	enemy.side = "enemy"
	enemy.health = 30
	caster.to_hit_spell = 100.0
	sim.register_character(enemy)
	var result := _cast(sim, caster, enemy, "firebolt")
	_check(bool(result.get("ok", false)) and enemy.health == 25, "Firebolt should deal its base damage")
	sim.free()


func _test_counterspell() -> void:
	var setup := _new_sim()
	var sim: WorldSimulation = setup.sim
	var caster: CharacterState = setup.caster
	var enemy := CharacterState.new("counter_target", "Enemy Mage", Vector2i(2, 0))
	enemy.side = "enemy"
	enemy.add_spell_effect({"effect_id": "divine_protection", "source_id": enemy.id})
	sim.register_character(enemy)
	var result := _cast(sim, caster, enemy, "counterspell")
	_check(not bool(result.get("ok", true)), "Counterspell must not be cast as an ordinary targeted spell")
	_check(enemy.has_spell_effect("divine_protection"), "A rejected direct Counterspell must not remove the target effect")
	sim.free()


func _test_feather_fall() -> void:
	var setup := _new_sim()
	var sim: WorldSimulation = setup.sim
	var caster: CharacterState = setup.caster
	var result := _cast(sim, caster, caster, "feather_fall")
	var fall := sim.resolve_fall_damage(caster.id, 12)
	_check(bool(result.get("ok", false)) and bool(fall.get("prevented", false)), "Feather Fall should prevent the next fall")
	_check(not caster.has_spell_effect("feather_fall"), "Feather Fall should be consumed once")
	sim.free()


func _test_disguise_self() -> void:
	var setup := _new_sim()
	var sim: WorldSimulation = setup.sim
	var caster: CharacterState = setup.caster
	var prepared := PreparedSpell.new("disguise_self", {}, {"profile_id": "merchant", "copy_character_id": "old_mac"})
	caster.prepared_spells.append(prepared.to_dict())
	var result := sim.submit_action(SimulationActionRequest.cast_spell(caster.id, caster.id, prepared))
	_check(bool(result.get("ok", false)) and caster.has_spell_effect("disguise_self"), "Disguise Self should apply to its caster")
	var disguise := caster.get_spell_effect("disguise_self")
	_check(String(disguise.get("copy_character_id", "")) == "old_mac", "Disguise Self should retain the selected encountered character")
	disguise["profile"] = {"hair_colour": "Silver", "hair_style": "Braid"}
	caster.add_spell_effect(disguise)
	var restored := CharacterState.from_dict(caster.to_dict())
	_check(restored != null and String(restored.get_spell_effect("disguise_self").get("profile", {}).get("hair_colour", "")) == "Silver", "The chosen disguise appearance should persist through character save/load")
	sim.free()


func _test_heal() -> void:
	var setup := _new_sim()
	var sim: WorldSimulation = setup.sim
	var caster: CharacterState = setup.caster
	var ally := CharacterState.new("heal_target", "Wounded Ally", Vector2i(1, 0))
	ally.side = "player"
	ally.health = 10
	sim.register_character(ally)
	var result := _cast(sim, caster, ally, "heal")
	_check(bool(result.get("ok", false)) and ally.health == 15, "Heal should restore its base magnitude")
	sim.free()


func _test_divine_protection() -> void:
	var setup := _new_sim()
	var sim: WorldSimulation = setup.sim
	var caster: CharacterState = setup.caster
	var ally := CharacterState.new("protected_ally", "Protected Ally", Vector2i(1, 0))
	ally.side = "player"
	sim.register_character(ally)
	var result := _cast(sim, caster, ally, "divine_protection")
	_check(bool(result.get("ok", false)) and ally.has_spell_effect("divine_protection"), "Divine Protection should apply its defensive effect")
	sim.free()


func _test_divine_strength() -> void:
	var setup := _new_sim()
	var sim: WorldSimulation = setup.sim
	var caster: CharacterState = setup.caster
	var ally := CharacterState.new("strong_ally", "Strong Ally", Vector2i(1, 0))
	var enemy := CharacterState.new("strength_enemy", "Enemy", Vector2i(2, 0))
	ally.side = "player"
	enemy.side = "enemy"
	ally.base_damage = 3
	ally.to_hit_melee = 100.0
	sim.register_character(ally)
	sim.register_character(enemy)
	var result := _cast(sim, caster, ally, "divine_strength")
	var enemy_health_before := enemy.health
	var attack := sim.submit_action(SimulationActionRequest.new(SimulationActionRequest.ActionType.ATTACK, ally.id, enemy.id, Vector2i.ZERO, 0.0, {}), 77)
	_check(bool(result.get("ok", false)) and ally.has_spell_effect("divine_strength"), "Divine Strength should apply its timed ally buff")
	_check(bool(attack.get("ok", false)) and enemy_health_before - enemy.health >= 6, "Divine Strength should add three damage to an ally's attack")
	sim.free()


func _test_curse() -> void:
	var setup := _new_sim()
	var sim: WorldSimulation = setup.sim
	var caster: CharacterState = setup.caster
	var enemy := CharacterState.new("cursed_enemy", "Cursed Enemy", Vector2i(1, 0))
	enemy.side = "enemy"
	enemy.to_hit_melee = 100.0
	enemy.base_damage = 8
	enemy.health = 50
	enemy.current_mana = 10
	enemy.max_mana = 10
	enemy.time_points = 100.0
	caster.skills["cleric_trigger_damage"] = 1
	caster.skills["cleric_trigger_dmg_red"] = 2
	caster.skills["cleric_trigger_heal_red"] = 1
	caster.skills["cleric_trigger_mana"] = 2
	caster.skills["cleric_trigger_vision"] = 1
	caster.skills["extended_sentence"] = 1
	caster.skills["armistice"] = 1
	sim.register_character(enemy)
	var vision_before := VisionRules.vision_range(enemy)
	var health_before_curse := enemy.health
	var result := _cast(sim, caster, enemy, "curse")
	_check(bool(result.get("ok", false)) and enemy.has_spell_effect("curse"), "Curse should mark an enemy")
	_check(enemy.health == health_before_curse - 1, "Divine Retribution should damage the target when Curse is applied")
	_check(int(enemy.current_mana) == 8, "Divine Drain should remove mana when Curse is applied")
	_check(int(enemy.get_spell_effect("curse").get("ticks_remaining", 0)) == 22, "Extended Sentence should extend Curse duration")
	_check(int(enemy.get_spell_effect("curse").get("vision_penalty", 0)) == 1, "Clouded Mind should record its vision penalty on the curse")
	_check(VisionRules.vision_range(enemy) == vision_before - 1, "Clouded Mind should reduce the cursed target's actual vision range")

	var healer := CharacterState.new("enemy_healer", "Enemy Healer", Vector2i(2, 0))
	healer.side = "enemy"
	healer.current_mana = 20
	healer.max_mana = 20
	healer.time_points = 100.0
	healer.unlocked_base_spells = ["heal"]
	sim.register_character(healer)
	var health_before_heal := enemy.health
	var heal_result := _cast(sim, healer, enemy, "heal")
	_check(bool(heal_result.get("ok", false)) and enemy.health - health_before_heal == 2, "Severed Grace should halve healing received by the cursed target")

	var before_attack := enemy.health
	var attack := sim.submit_action(SimulationActionRequest.new(SimulationActionRequest.ActionType.ATTACK, enemy.id, caster.id, Vector2i.ZERO, 0.0, {}), 88)
	_check(bool(attack.get("ok", false)) and int(attack.get("raw_damage", -1)) == 6, "Feeble Strike should reduce the cursed target's outgoing damage")
	_check(is_equal_approx(enemy.time_points, 95.0), "Armistice should add five TP to the cursed target's next attack")
	_check(before_attack - enemy.health == 2, "Curse should punish the enemy's next hostile action")
	_check(not enemy.has_spell_effect("curse"), "Curse should be consumed by the hostile action")
	sim.free()

func _test_summon_animal_and_companion() -> void:
	var setup := _new_sim()
	var sim: WorldSimulation = setup.sim
	var caster: CharacterState = setup.caster
	var temporary := _cast_at(sim, caster, Vector2i(1, 0), "summon_animal", {"summon_id": "wolf"})
	var temporary_animal := sim.get_character(String(temporary.get("summoned_id", "")))
	_check(bool(temporary.get("ok", false)) and temporary_animal != null and temporary_animal.is_summoned, "Summon Animal should create a temporary summon")
	sim.start_combat()
	sim.end_combat()
	_check(sim.get_character(String(temporary.get("summoned_id", ""))) == null, "Temporary summons should expire when combat ends")
	sim.free()

	var companion_setup := _new_sim()
	var companion_sim: WorldSimulation = companion_setup.sim
	var druid: CharacterState = companion_setup.caster
	druid.skills["animal_companion"] = 1
	var permanent := _cast_at(companion_sim, druid, Vector2i(1, 0), "summon_animal", {"summon_id": "wolf"})
	var companion := companion_sim.get_character(String(permanent.get("summoned_id", "")))
	_check(bool(permanent.get("ok", false)) and companion != null and companion.is_animal_companion, "Animal Companion should make the first summon permanent")
	_check(companion != null and companion_sim.get_party_member_ids().has(companion.id), "A permanent animal companion should join the party roster")
	companion_sim.start_combat()
	companion_sim.end_combat()
	_check(companion_sim.get_character(companion.id) != null, "Permanent animal companions should survive combat ending")
	if companion != null:
		var restored_companion := CharacterState.from_dict(companion.to_dict())
		_check(restored_companion != null and restored_companion.is_animal_companion and restored_companion.summoned_by_id == druid.id, "Animal companion ownership should survive character save/load serialization")
		var initiative := CombatInitiativeModel.build_entries([companion])
		_check(initiative.size() == 1 and String(initiative[0].get("id", "")) == companion.id, "A permanent animal companion should appear in initiative")
		var dismissal := companion_sim.dismiss_companion(companion.id, true)
		_check(bool(dismissal.get("ok", false)) and not companion_sim.is_party_member(companion.id), "A permanent animal companion should be dismissible from the active party")
		_check(companion_sim.get_character(companion.id) == companion, "Dismissing a permanent animal companion should not delete its persistent character state")
		var doomed_companion := CharacterState.new("doomed_wolf_companion", "Doomed Wolf", Vector2i(3, 0))
		doomed_companion.side = "player"
		doomed_companion.tags.append("animal")
		doomed_companion.is_animal_companion = true
		doomed_companion.summoned_by_id = druid.id
		doomed_companion.creature_kind = "wolf"
		companion_sim.register_character(doomed_companion)
		_check(companion_sim.is_party_member(doomed_companion.id), "A living permanent animal companion should join the active party")
		doomed_companion.apply_damage(doomed_companion.health + doomed_companion.max_health)
		var dead_companion := CharacterState.from_dict(doomed_companion.to_dict())
		_check(dead_companion != null and not dead_companion.alive and dead_companion.is_animal_companion, "Animal companion death should persist through character save/load")
		_check(not companion_sim.is_party_member(doomed_companion.id), "A dead permanent animal companion should be removed from the active party")
	companion_sim.free()


func _test_summon_uses_animal_catalog_and_mount_profile() -> void:
	var setup := _new_sim()
	var sim: WorldSimulation = setup.sim
	var caster: CharacterState = setup.caster
	var result := _cast_at(sim, caster, Vector2i(1, 0), "summon_animal", {"summon_id": "horse"})
	var horse := sim.get_character(String(result.get("summoned_id", "")))
	_check(bool(result.get("ok", false)) and horse != null, "Summon Animal should create a horse from AnimalCatalog")
	_check(horse != null and horse.race == "animal" and horse.creature_kind == "horse", "Summoned horse should use the shared animal identity")
	_check(horse != null and horse.mountable and horse.mount_size >= 2, "Summoned horse should retain its mount profile")
	if horse != null:
		caster.skills["riding"] = 1
		_check(bool(sim.can_ride(caster.id, horse.id).get("ok", false)), "A summoned horse should use shared riding eligibility")
		_check(bool(sim.mount_animal(caster.id, horse.id).get("ok", false)), "A summoned horse should be mountable through WorldSimulation")
	sim.free()


func _test_multi_target_heal() -> void:
	var setup := _new_sim()
	var sim: WorldSimulation = setup.sim
	var caster: CharacterState = setup.caster
	caster.skills["divine_targets"] = 1
	var first := CharacterState.new("heal_first", "First Ally", Vector2i(1, 0))
	var second := CharacterState.new("heal_second", "Second Ally", Vector2i(0, 1))
	first.side = "player"
	second.side = "player"
	first.health = 10
	second.health = 10
	sim.register_character(first)
	sim.register_character(second)
	var prepared := PreparedSpell.create("heal", {"target_bonus": 1})
	caster.prepared_spells.append(prepared.to_dict())
	var request := SimulationActionRequest.cast_spell(caster.id, first.id, prepared)
	request.options["target_ids"] = [first.id, second.id]
	var result := sim.submit_action(request, 55)
	_check(bool(result.get("ok", false)), "Heal should accept a selected multi-target list")
	_check(first.health == 15 and second.health == 15, "Multi-target Heal should resolve on every selected ally")
	sim.free()


func _test_entangle() -> void:
	var setup := _new_sim()
	var sim: WorldSimulation = setup.sim
	var caster: CharacterState = setup.caster
	var enemy := CharacterState.new("rooted_enemy", "Rooted Enemy", Vector2i(2, 0))
	enemy.side = "enemy"
	sim.register_character(enemy)
	var result := _cast_at(sim, caster, enemy.axial, "entangle")
	var effect := enemy.get_spell_effect("entangled")
	var zone_id := String(effect.get("zone_id", ""))
	_check(bool(result.get("ok", false)) and enemy.has_spell_effect("entangled"), "Entangle should apply its movement restriction in the area")
	_check(int(effect.get("ticks_remaining", 0)) == 20 and not zone_id.is_empty(), "Entangle should have a finite duration and a stable zone identifier")
	var affected_cell: Dictionary = sim.map_data.cells.get(enemy.axial, {})
	_check(int(affected_cell.get("spell_entangle_ticks", 0)) == 20, "Entangle should mark affected terrain cells")
	var terrain_snapshot := sim.spell_terrain_effects_to_dict()
	var restored_enemy := CharacterState.from_dict(enemy.to_dict())
	_check(restored_enemy != null and String(restored_enemy.get_spell_effect("entangled").get("zone_id", "")) == zone_id, "Entangle status should persist through character save/load")
	sim.restore_spell_terrain_effects([])
	sim.restore_spell_terrain_effects(terrain_snapshot)
	_check(int(sim.map_data.cells[enemy.axial].get("spell_entangle_ticks", 0)) == 20, "Entangle terrain zones should survive save/restore")
	var normal_cost := MovementRules.step_cost(sim.map_data, Vector2i.ZERO, Vector2i(1, 0), caster)
	var entangled_cost := MovementRules.step_cost(sim.map_data, Vector2i(1, 0), enemy.axial, caster)
	_check(entangled_cost > normal_cost, "Entangled terrain should increase movement cost for other characters")
	_check(sim.dispel_entangle_zone(zone_id), "An Entangle zone should be explicitly dispellable")
	_check(not enemy.has_spell_effect("entangled") and int(sim.map_data.cells[enemy.axial].get("spell_entangle_ticks", 0)) == 0, "Dispelling should remove both character and terrain effects")

	var second_cast := _cast_at(sim, caster, enemy.axial, "entangle")
	_check(bool(second_cast.get("ok", false)), "Entangle should be recast after its previous zone is dispelled")
	for _tick in range(20):
		sim._advance_spell_terrain_effects()
		sim._advance_character_spell_effects(enemy, 1.0)
	_check(not enemy.has_spell_effect("entangled") and int(sim.map_data.cells[enemy.axial].get("spell_entangle_ticks", 0)) == 0, "Entangle should clean up its status and terrain when its duration expires")
	sim.free()

func _test_calm_animal() -> void:
	var setup := _new_sim()
	var sim: WorldSimulation = setup.sim
	var caster: CharacterState = setup.caster
	var animal := CharacterState.new("calmable_animal", "Wolf", Vector2i(2, 0))
	animal.side = "enemy"
	animal.tags.append("animal")
	animal.time_points = 100.0
	sim.register_character(animal)
	var result := _cast(sim, caster, animal, "calm_animal", {"calm_mode": "come"})
	_check(bool(result.get("ok", false)) and String(animal.get_spell_effect("calmed").get("mode", "")) == "come", "Calm Animal should apply its selected mode to a mundane animal")
	var restored := CharacterState.from_dict(animal.to_dict())
	_check(restored != null and String(restored.get_spell_effect("calmed").get("mode", "")) == "come", "Calm Animal behaviour should persist through character save/load")
	var distance_before := HexGrid.distance(animal.axial, caster.axial)
	CombatAI.take_turn(sim, animal, ["caster"], ["calmable_animal"])
	_check(HexGrid.distance(animal.axial, caster.axial) < distance_before, "A calmed animal in come mode should move towards its caster instead of attacking")
	sim.free()

func _test_wild_fury() -> void:
	var setup := _new_sim()
	var sim: WorldSimulation = setup.sim
	var caster: CharacterState = setup.caster
	var result := _cast(sim, caster, caster, "wild_fury")
	_check(bool(result.get("ok", false)) and caster.has_spell_effect("wild_fury"), "Wild Fury should apply to its caster")
	_check(int(caster.get_spell_effect("wild_fury").get("magnitude", 0)) == 3, "Wild Fury should preserve its unarmed damage bonus")
	sim.free()

func _test_counterspell_reaction() -> void:
	var sim := WorldSimulation.new()
	var caster := CharacterState.new("enemy_caster", "Enemy Caster", Vector2i(0, 0))
	var player := CharacterState.new("player_reactor", "Player Reactor", Vector2i(3, 0))
	caster.side = "enemy"
	caster.current_mana = 20
	caster.max_mana = 20
	caster.time_points = 50.0
	caster.unlocked_base_spells = ["firebolt"]
	var firebolt := PreparedSpell.create("firebolt")
	caster.prepared_spells.append(firebolt.to_dict())
	player.side = "player"
	player.current_mana = 20
	player.max_mana = 20
	player.time_points = 50.0
	player.unlocked_base_spells = ["counterspell"]
	var counterspell := PreparedSpell.create("counterspell")
	player.prepared_spells.append(counterspell.to_dict())
	for q in range(-5, 6):
		for r in range(-5, 6):
			var hex := Vector2i(q, r)
			if HexGrid.distance(Vector2i.ZERO, hex) <= 5:
				sim.map_data.add_cell(hex)
	sim.register_character(caster)
	sim.register_character(player)
	sim.start_combat()
	sim.turn_scheduler.current_character_id = caster.id
	var result := sim.submit_action(SimulationActionRequest.cast_spell(caster.id, player.id, firebolt), 91)
	_check(bool(result.get("pending", false)), "Enemy casting should pause for the player's Counterspell reaction")
	_check(not sim.pending_reaction.is_empty(), "Counterspell should use the shared reaction request system")
	var reaction_result := sim.resolve_reaction("counterspell_player_reactor")
	_check(bool(reaction_result.get("ok", false)), "The player should be able to select Counterspell")
	_check(player.current_mana == 10 and is_equal_approx(player.time_points, 45.0), "Counterspell should spend its own mana and five TP")
	_check(caster.current_mana == 15 and is_equal_approx(caster.time_points, 50.0), "A countered spell should cost caster mana but not cast TP")
	_check(player.health == player.max_health, "Counterspell should prevent the incoming spell effect")
	sim.free()

