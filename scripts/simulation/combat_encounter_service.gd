class_name CombatEncounterService
extends RefCounted
## Simulation-only participant and lifecycle policy for turn-based encounters.
## It owns side/dormancy setup and restoration, never Nodes, scenes, or UI.

static func begin(
	simulation: WorldSimulation,
	party_ids: Array[String],
	enemy_ids: Array[String]
) -> Dictionary:
	if simulation == null:
		return {"ok": false, "reason": "missing_simulation"}
	if simulation.is_in_combat:
		return {"ok": false, "reason": "combat_already_active"}
	if party_ids.is_empty() or enemy_ids.is_empty():
		return {"ok": false, "reason": "missing_participants"}

	var participant_ids: Dictionary = {}
	for character_id in party_ids:
		if character_id.is_empty() or participant_ids.has(character_id):
			return {"ok": false, "reason": "invalid_or_duplicate_participant", "character_id": character_id}
		participant_ids[character_id] = "player"
	for character_id in enemy_ids:
		if character_id.is_empty() or participant_ids.has(character_id):
			return {"ok": false, "reason": "invalid_or_duplicate_participant", "character_id": character_id}
		participant_ids[character_id] = "enemy"

	for character_id in party_ids:
		var member := simulation.get_character(character_id)
		if member == null or not member.can_act():
			return {"ok": false, "reason": "unavailable_party_member", "character_id": character_id}
	for character_id in enemy_ids:
		var enemy := simulation.get_character(character_id)
		if enemy == null or not enemy.can_act():
			return {"ok": false, "reason": "unavailable_enemy", "character_id": character_id}

	var previous_states: Dictionary = {}
	for state in simulation.character_states():
		previous_states[state.id] = {
			"side": state.side,
			"combat_dormant": state.combat_dormant
		}
		state.combat_dormant = true

	for character_id in party_ids:
		var member := simulation.get_character(character_id)
		member.side = "player"
		member.combat_dormant = false
		member.time_points = ActionEconomy.COMBAT_TURN_READY_TP
	for character_id in enemy_ids:
		var enemy := simulation.get_character(character_id)
		enemy.side = "enemy"
		enemy.combat_dormant = false
		enemy.time_points = ActionEconomy.COMBAT_TURN_READY_TP

	simulation.start_combat()
	return {
		"ok": true,
		"session": {
			"party_ids": party_ids.duplicate(),
			"enemy_ids": enemy_ids.duplicate(),
			"previous_states": previous_states
		}
	}


static func finish(simulation: WorldSimulation, session: Dictionary) -> Dictionary:
	if simulation == null:
		return {"ok": false, "reason": "missing_simulation"}
	var previous_states: Variant = session.get("previous_states")
	if not previous_states is Dictionary:
		return {"ok": false, "reason": "invalid_session"}
	if simulation.is_in_combat:
		simulation.end_combat()
	for character_id_value in previous_states:
		var character_id := String(character_id_value)
		var state := simulation.get_character(character_id)
		if state == null:
			continue
		var previous: Dictionary = previous_states[character_id_value]
		state.side = String(previous.get("side", state.side))
		state.combat_dormant = bool(previous.get("combat_dormant", state.combat_dormant))
	return {"ok": true}
