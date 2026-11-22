extends SceneTree

const REGISTRY = preload("res://scripts/world/campaign2_multistory_location_registry.gd")
var failures: int = 0

func _initialize() -> void:
	var registry = REGISTRY.new()
	_check(registry.validation_errors.is_empty(), "Source-authored multi-story locations must validate")
	_check(registry.location_ids() == ["kragmoor"], "Kragmoor must be registered as the first source-authored multi-story location")
	var definition: Dictionary = registry.get_definition("kragmoor")
	_check(int(definition.get("anchor", {}).get("q", 0)) == 908 and int(definition.get("anchor", {}).get("r", 0)) == -626, "Kragmoor anchor must match buildDwarvenKingdom")
	_check(int(definition.get("massif_radius", 0)) == 25, "Kragmoor must retain the source solid-massif radius")
	var expected_floors := [0, -1, -2, -3, -4, -5]
	var actual_floors: Array[int] = []
	for floor_variant in definition.get("floors", []):
		actual_floors.append(int(floor_variant.get("floor", 999999)))
	_check(actual_floors == expected_floors, "Kragmoor must preserve surface, four open underground levels and the sealed fifth level")
	var great_hall := registry.get_floor_definition("kragmoor", -1)
	_check(great_hall.get("actors", []).size() == 3, "Great Hall must contain King Balrik and both source guards")
	_check(_has_record(great_hall.get("tile_objects", []), "throne"), "Great Hall must retain its throne")
	var vault := registry.get_floor_definition("kragmoor", -2)
	_check(vault.get("actors", []).size() == 2, "Vault/Runeforge must contain the trader and master runesmith")
	_check(_has_record(vault.get("tile_objects", []), "rune_forge"), "Runeforge must retain its forge object")
	var mine := registry.get_floor_definition("kragmoor", -3)
	_check(_has_record(mine.get("tile_objects", []), "mine_ledger"), "Deep Mine must retain the foreman's ledger")
	_check(mine.get("actors", []).size() == 1, "Deep Mine must contain Foreman Dornik")
	var tunnels := registry.get_floor_definition("kragmoor", -4)
	_check(tunnels.get("creatures", []).size() == 3, "Lower Tunnels must preserve two spiders and the Broodmother")
	var deep := registry.get_floor_definition("kragmoor", -5)
	_check(deep.get("creatures", []).size() == 1, "Sunken Deep must contain the Ember-Wreathed Horror")
	_check(int(deep.get("creatures", [])[0].get("health", 0)) == 160, "The Horror must retain its source health")
	_check(deep.get("creatures", [])[0].get("inventory", []).count("starmetal_ore") == 2, "The Horror must retain both source Starmetal drops")
	var gate: Dictionary = definition.get("quest_gates", [])[0] if not definition.get("quest_gates", []).is_empty() else {}
	_check(String(gate.get("quest_id", "")) == "deepholds_infestation", "Sunken Deep must be gated by the source infestation quest ID")
	_check(String(gate.get("quest_title", "")) == "What Nests Below", "Sunken Deep must retain the source quest title")
	_check(not bool(gate.get("initially_available", true)) and bool(gate.get("reveal_is_idempotent", false)), "Sunken Deep passage must begin sealed and reveal idempotently")
	var gated_transition := false
	for transition in definition.get("transitions", []):
		if int(transition.get("from_floor", 999)) == -4 and int(transition.get("to_floor", 999)) == -5:
			gated_transition = not bool(transition.get("initially_available", true)) and String(transition.get("unlocked_by_quest", "")) == "deepholds_infestation"
	_check(gated_transition, "The -4 to -5 stair must be locked behind What Nests Below")
	var king := great_hall.get("actors", []).filter(func(actor): return String(actor.get("id", "")) == "dwarf_king")[0]
	_check(String(king.get("race", "")) == "dwarf" and String(king.get("gender", "")) == "male", "King Balrik must retain his source dwarf/male profile")
	_check(king.get("class_levels", []) == ["fighter", "fighter"], "King Balrik must retain his two fighter levels")
	_check(king.get("skill_picks", []) == ["health", "axe_hit", "axe_dmg", "heavy_armor_training"], "King Balrik must retain his source skill picks")
	_check(king.get("equipment", []) == ["axe", "heavy_armor", "wooden_shield"] and bool(king.get("gold_gear", false)), "King Balrik must retain his source equipment and gold gear")
	var guard_actors: Array = great_hall.get("actors", []).filter(func(actor): return String(actor.get("role", "")) == "guard")
	_check(guard_actors.size() == 2 and guard_actors[0].get("gender") != guard_actors[1].get("gender"), "Kragmoor must retain its distinct male and female Hall Guard profiles")
	var trader := vault.get("actors", []).filter(func(actor): return String(actor.get("id", "")) == "deepholds_trader")[0]
	_check(trader.get("shop_inventory", []) == ["sword", "axe", "medium_armor", "heavy_armor", "wooden_shield", "nasal_helm"], "Ingra must retain the source Vault shop inventory")
	var interactions: Array = definition.get("interaction_rules", [])
	var trader_rule := interactions.filter(func(rule): return String(rule.get("id", "")) == "deepholds_trader")[0]
	_check(int(trader_rule.get("minimum_faction_standing", 0)) == 10, "Ingra's shop must retain its +10 faction-standing gate")
	var smith_rule := interactions.filter(func(rule): return String(rule.get("id", "")) == "deepholds_runesmith")[0]
	_check(int(smith_rule.get("trust_quest", {}).get("minimum_faction_standing", 0)) == 10, "Thrain's trust quest must require +10 standing")
	_check(int(smith_rule.get("teaching_quest", {}).get("dwarf", {}).get("required_starmetal_ore", 0)) == 1 and int(smith_rule.get("teaching_quest", {}).get("other_races", {}).get("required_starmetal_ore", 0)) == 2, "Thrain must preserve the source dwarf/non-dwarf ore requirements")
	_check(int(smith_rule.get("teaching_quest", {}).get("other_races", {}).get("minimum_faction_standing", 0)) == 30, "Non-dwarves must retain the +30 teaching threshold")
	var infestation: Dictionary = definition.get("quests", [])[0]
	_check(String(infestation.get("title", "")) == "What Nests Below" and String(infestation.get("giver", "")) == "King Balrik Deepholm", "The infestation quest must retain its source title and giver")
	_check(String(infestation.get("objective", {}).get("creature_tag", "")) == "deepholds_vermin", "The quest must target the source-tagged Lower Tunnels vermin")
	_check(int(infestation.get("completion", {}).get("reputation", {}).get("standing_delta", 0)) == 20 and int(infestation.get("completion", {}).get("reputation", {}).get("knowledge_delta", 0)) == 20, "The quest must retain both source faction reputation deltas")
	_check(int(infestation.get("completion", {}).get("experience", 0)) == 200 and infestation.get("completion", {}).get("items", []) == ["deep_crystal"], "The quest must retain its 200 XP and Deep Crystal reward")
	var broodmother: Dictionary = tunnels.get("creatures", []).filter(func(creature): return String(creature.get("id", "")) == "deepholds_broodmother")[0]
	_check(String(broodmother.get("monster_type", "")) == "spider" and broodmother.get("quest_tags", []) == ["deepholds_vermin"], "The Broodmother must retain its source spider type and quest tag")
	_check(int(broodmother.get("custom_skills", {}).get("health", 0)) == 6 and int(broodmother.get("custom_skills", {}).get("melee_damage", 0)) == 4, "The Broodmother must retain its source custom skills")
	_check(String(deep.get("creatures", [])[0].get("monster_type", "")) == "dragon_young", "The Horror must reuse the source young-dragon monster template")

	if failures > 0:
		push_error("%d multi-story location test(s) failed." % failures)
		quit(1)
		return
	print("Kragmoor source-authored multi-story floor data validated.")
	quit(0)

func _has_record(records: Array, record_id: String) -> bool:
	for record in records:
		if record is Dictionary and String(record.get("id", "")) == record_id:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
