class_name CampNightAmbushEncounter
extends RefCounted
## Domain-owned wolf ambush content for camp night-watch results.
## Spawn-cell selection and creature presentation remain with the world presenter.

const COMBAT_ENCOUNTER_SERVICE = preload("res://scripts/simulation/combat_encounter_service.gd")
const ANIMAL_CATALOG = preload("res://scripts/simulation/animal_catalog.gd")

const WOLVES_PER_AMBUSH := 2
const SURPRISE_TIME_POINT_PENALTY := 20.0


static func start(
	simulation: WorldSimulation,
	party_ids: Array[String],
	spawn_hexes: Array[Vector2i],
	detected: bool
) -> Dictionary:
	if simulation == null:
		return {"ok": false, "reason": "missing_simulation"}
	if simulation.is_in_combat:
		return {"ok": false, "reason": "combat_already_active"}
	if party_ids.is_empty():
		return {"ok": false, "reason": "missing_party"}
	if spawn_hexes.size() < WOLVES_PER_AMBUSH:
		return {"ok": false, "reason": "insufficient_spawn_cells"}

	var night_index := maxi(1, simulation.camp_simulation.night_index)
	var enemy_ids: Array[String] = []
	for index in range(WOLVES_PER_AMBUSH):
		var enemy_id := "camp_night_wolf_%02d_%02d" % [night_index, index + 1]
		if simulation.get_character(enemy_id) != null:
			_cleanup_spawned_wolves(simulation, enemy_ids)
			return {"ok": false, "reason": "encounter_id_already_exists", "character_id": enemy_id}
		var wolf := ANIMAL_CATALOG.create_state(
			"wolf",
			enemy_id,
			"Night Wolf",
			spawn_hexes[index],
			night_index * 100 + index + 1
		)
		if wolf == null:
			_cleanup_spawned_wolves(simulation, enemy_ids)
			return {"ok": false, "reason": "wolf_profile_unavailable"}
		wolf.side = "enemy"
		wolf.combat_dormant = true
		wolf.time_points = wolf.max_time_points
		var registered := simulation.register_animal(wolf)
		if not bool(registered.get("ok", false)):
			_cleanup_spawned_wolves(simulation, enemy_ids)
			return {"ok": false, "reason": String(registered.get("reason", "wolf_registration_failed"))}
		enemy_ids.append(enemy_id)

	var modifiers := {
		"party_time_point_penalty": 0.0 if detected else SURPRISE_TIME_POINT_PENALTY
	}
	var lifecycle := COMBAT_ENCOUNTER_SERVICE.begin(simulation, party_ids, enemy_ids, modifiers)
	if not bool(lifecycle.get("ok", false)):
		_cleanup_spawned_wolves(simulation, enemy_ids)
		return lifecycle

	return {
		"ok": true,
		"enemy_ids": enemy_ids,
		"party_ids": party_ids.duplicate(),
		"detected": detected,
		"surprise_time_point_penalty": float(modifiers.party_time_point_penalty),
		"lifecycle_session": lifecycle.get("session", {}),
		"night_index": night_index
	}


static func resolve_combat(
	simulation: WorldSimulation,
	_journal: CampaignJournal,
	party_ids: Array[String],
	session: Dictionary
) -> Dictionary:
	if simulation == null:
		return {"resolved": false, "reason": "missing_simulation"}
	var enemy_ids: Array[String] = []
	for value in session.get("enemy_ids", []):
		enemy_ids.append(String(value))
	if enemy_ids.is_empty():
		return {"resolved": false, "reason": "missing_enemy_roster"}

	var living_enemies := 0
	for enemy_id in enemy_ids:
		var enemy := simulation.get_character(enemy_id)
		if enemy != null and enemy.can_act():
			living_enemies += 1
	var living_party := 0
	for party_id in party_ids:
		var member := simulation.get_character(party_id)
		if member != null and member.can_act():
			living_party += 1
	if living_enemies > 0 and living_party > 0:
		return {"resolved": false}

	var outcome := "victory" if living_enemies == 0 else "defeat"
	var lifecycle: Dictionary = session.get("lifecycle_session", {})
	var finished := COMBAT_ENCOUNTER_SERVICE.finish(simulation, lifecycle)
	if not bool(finished.get("ok", false)):
		return {"resolved": false, "reason": String(finished.get("reason", "encounter_cleanup_failed"))}

	var removed_actor_ids: Array[String] = []
	for enemy_id in enemy_ids:
		if simulation.unregister_character(enemy_id):
			removed_actor_ids.append(enemy_id)

	return {
		"resolved": true,
		"outcome": outcome,
		"status_text": "The night wolves have been driven off." if outcome == "victory" else "The camp is overrun. The wolves prowl among the fallen.",
		"message": "The last wolf falls, and the camp slowly settles." if outcome == "victory" else "The wolves break off their attack, leaving the party unable to defend the camp.",
		"speech_bubble_character_id": String(party_ids[0]) if not party_ids.is_empty() else "",
		"remove_actor_ids": removed_actor_ids,
		"enemy_ids": enemy_ids
	}


static func _cleanup_spawned_wolves(simulation: WorldSimulation, enemy_ids: Array[String]) -> void:
	for enemy_id in enemy_ids:
		simulation.unregister_character(enemy_id)
