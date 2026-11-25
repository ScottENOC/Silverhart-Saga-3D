class_name CombatEncounterController
extends RefCounted
## Shared combat-loop and HUD orchestration.
## Encounter content and location scripts provide rosters and resolve outcomes;
## WorldSimulation remains authoritative for all combat rules and state.

const COMBAT_AI_SCRIPT = preload("res://scripts/simulation/combat_ai.gd")

signal resolution_check_requested

var simulation: WorldSimulation
var hud: CampaignCombatHud
var enemy_ids: Array[String] = []
var party_ids: Array[String] = []
var player_controlled_ids: Array[String] = []
var active: bool = false
var enemy_turn_processed: bool = false
var enemy_turn_waiting_for_reaction: bool = false


func configure(world_simulation: WorldSimulation, combat_hud: CampaignCombatHud) -> void:
	simulation = world_simulation
	hud = combat_hud


func begin_encounter(
	encounter_enemy_ids: Array[String],
	encounter_party_ids: Array[String],
	controlled_character_ids: Array[String]
) -> void:
	enemy_ids = encounter_enemy_ids.duplicate()
	party_ids = encounter_party_ids.duplicate()
	player_controlled_ids = controlled_character_ids.duplicate()
	active = true
	enemy_turn_processed = false
	enemy_turn_waiting_for_reaction = false


func end_encounter() -> void:
	active = false
	enemy_ids.clear()
	party_ids.clear()
	player_controlled_ids.clear()
	enemy_turn_processed = false
	enemy_turn_waiting_for_reaction = false
	update_hud(false, "")


func on_combat_turn_started() -> void:
	enemy_turn_processed = false


func update_combat(encounter_active: bool, selected_character_id: String) -> void:
	if not active or not encounter_active or simulation == null or not simulation.is_in_combat:
		return
	resolution_check_requested.emit()
	if not active or not encounter_active or not simulation.is_in_combat:
		return
	if enemy_turn_waiting_for_reaction and not simulation.has_pending_reaction():
		enemy_turn_waiting_for_reaction = false
		simulation.try_end_current_turn(true)
		return
	if simulation.has_pending_reaction():
		return
	var current := simulation.get_current_turn_character()
	if current == null or enemy_turn_processed:
		return
	var is_ai_turn := current.side == "enemy" or (
		current.side == "player" and not player_controlled_ids.has(current.id)
	)
	if not is_ai_turn:
		return
	enemy_turn_processed = true
	enemy_turn_waiting_for_reaction = COMBAT_AI_SCRIPT.take_turn(
		simulation,
		current,
		enemy_ids,
		party_ids
	)


func request_player_attack(encounter_active: bool, selected_character_id: String) -> void:
	if not active or not encounter_active or simulation == null or not simulation.is_in_combat or simulation.has_pending_reaction():
		return
	var current := simulation.get_current_turn_character()
	if current == null or current.id != selected_character_id or current.side != "player":
		hud.set_status_text("It is not this character turn. Switch party members with Tab.")
		return
	var target := _nearest_enemy_in_attack_range(current)
	if target == null:
		hud.set_status_text("No enemy in reach. Move closer to an enemy first.")
		return
	var weapon_id := String(current.equipment.get("weapon", ""))
	var result := simulation.try_attack_character(current.id, target.id, {
		"time_point_cost": 10.0,
		"weapon_id": weapon_id
	}, int(current.id.hash() + target.id.hash()))
	if bool(result.get("pending", false)) or simulation.has_pending_reaction():
		hud.set_status_text("Resolving a defensive reaction...")
	elif bool(result.get("ok", false)):
		hud.set_status_text("Attack resolved against %s." % target.display_name)
	else:
		hud.set_status_text("Attack unavailable: %s" % String(result.get("reason", "unknown")))
	resolution_check_requested.emit()


func request_end_player_turn(encounter_active: bool, selected_character_id: String) -> void:
	if not active or not encounter_active or simulation == null or not simulation.is_in_combat or simulation.has_pending_reaction():
		return
	var current := simulation.get_current_turn_character()
	if current == null or current.id != selected_character_id or current.side != "player":
		return
	simulation.try_end_current_turn(true)


func update_hud(encounter_active: bool, selected_character_id: String) -> void:
	if hud == null:
		return
	var combat_visible := active and encounter_active and simulation != null and simulation.is_in_combat
	if not combat_visible:
		hud.present(false, false, false, "")
		return
	var current := simulation.get_current_turn_character()
	var player_turn := current != null and current.side == "player" and current.id == selected_character_id and current.can_act() and not simulation.has_pending_reaction()
	var can_attack := player_turn and _nearest_enemy_in_attack_range(current) != null
	var status_text := ""
	if simulation.has_pending_reaction():
		status_text = "Reaction pending..."
	elif current == null:
		status_text = "Waiting for the next combat turn..."
	elif current.side == "enemy":
		status_text = "%s is acting..." % current.display_name
	elif current.id != selected_character_id and player_controlled_ids.has(current.id):
		status_text = "Switch to %s with Tab." % current.display_name
	elif current.id != selected_character_id:
		status_text = "%s is acting..." % current.display_name
	else:
		status_text = "%s  ·  HP %d/%d  ·  TP %d" % [current.display_name, current.health, current.max_health, roundi(current.time_points)]
	hud.present(true, player_turn, can_attack, status_text)


func _nearest_enemy_in_attack_range(attacker: CharacterState) -> CharacterState:
	var best: CharacterState
	var best_distance := 999
	if simulation == null:
		return best
	for enemy_id in enemy_ids:
		var enemy := simulation.get_character(enemy_id)
		if enemy == null or not enemy.can_act():
			continue
		var distance := HexGrid.distance(attacker.axial, enemy.axial)
		if distance <= COMBAT_AI_SCRIPT.attack_range_for(attacker) and distance < best_distance:
			best_distance = distance
			best = enemy
	return best
