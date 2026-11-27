class_name CampaignSimulationSnapshotRestorer
extends RefCounted
## Restores serialised campaign-domain state into the authoritative WorldSimulation.
## Actor creation, appearance, camera, UI and scene choreography stay with the world adapter.

const PERSISTENT_RELATIONSHIP_STORE := preload("res://scripts/simulation/persistent_character_relationship_store.gd")
const COMPANION_RUNTIME_STORE := preload("res://scripts/simulation/companion_campaign_runtime_store.gd")


static func restore(simulation: WorldSimulation, data: Dictionary) -> Dictionary:
	if simulation == null:
		return {"ok": false, "reason": "missing_simulation"}

	simulation.reset_transient_combat_state()
	var restored_states: Array[CharacterState] = []
	var saved_diffs: Variant = data.get("character_diffs", {})
	if saved_diffs is Dictionary:
		for character_id_variant in saved_diffs.keys():
			var character_id := String(character_id_variant)
			var diff: Variant = saved_diffs[character_id_variant]
			if not diff is Dictionary:
				continue
			var restored: CharacterState
			if diff.has("__full_record"):
				restored = CharacterState.from_dict(diff["__full_record"])
			else:
				var existing := simulation.get_character(character_id)
				if existing == null:
					push_warning("Save references unknown base character '%s'; skipped." % character_id)
					continue
				var merged := existing.to_dict()
				merged.merge(diff, true)
				restored = CharacterState.from_dict(merged)
			restored.id = character_id
			restored_states.append(restored)
	if not simulation.restore_character_states(restored_states):
		return {"ok": false, "reason": "invalid_character_state"}

	var dynamic_records: Variant = data.get("dynamic_campaign_characters", {})
	if dynamic_records is Dictionary:
		for character_id_value in dynamic_records.keys():
			var character_id := String(character_id_value)
			if simulation.get_character(character_id) != null or not (dynamic_records[character_id_value] is Dictionary):
				continue
			var dynamic_state := CharacterState.from_dict(dynamic_records[character_id_value])
			if dynamic_state != null:
				simulation.register_character(dynamic_state)

	# Older saves stored both a location-side roster and a simulation roster.
	# Prefer the former for historical party ordering, then retain simulation-only
	# members. New snapshots write one canonical list.
	var restored_party_ids: Array[String] = []
	var legacy_location_party: Variant = data.get("party_member_ids", null)
	var legacy_simulation_party: Variant = data.get("simulation_party_member_ids", null)
	if legacy_location_party is Array:
		for member_id in legacy_location_party:
			var id := String(member_id)
			if not restored_party_ids.has(id):
				restored_party_ids.append(id)
	if legacy_simulation_party is Array:
		for member_id in legacy_simulation_party:
			var id := String(member_id)
			if not restored_party_ids.has(id):
				restored_party_ids.append(id)
	if restored_party_ids.is_empty():
		restored_party_ids = ["player", "companion_wren_talbot"]
	simulation.restore_party_members(restored_party_ids)

	var clock_data: Variant = data.get("clock", {})
	if clock_data is Dictionary:
		simulation.clock.load_dict(clock_data)
	var weather_data: Variant = data.get("world_weather", {})
	if weather_data is Dictionary and not weather_data.is_empty():
		if not simulation.weather_state.load_dict(weather_data):
			push_warning("Saved world weather seed was invalid; a new weather sequence was generated.")
	simulation.weather_state.update_to(simulation.clock.world_seconds)

	var saved_camp: Variant = data.get("camp_simulation", {})
	if saved_camp is Dictionary and not saved_camp.is_empty():
		if not simulation.camp_simulation.from_dict(saved_camp):
			push_warning("Saved camp state was invalid and has been reset.")
			simulation.camp_simulation = CampSimulation.new()
	var saved_dwellings: Variant = data.get("campaign_dwellings", {})
	if saved_dwellings is Dictionary and not saved_dwellings.is_empty():
		if not simulation.campaign_dwellings.from_dict(saved_dwellings):
			push_warning("Saved player dwelling ownership was invalid and has been reset.")
			simulation.campaign_dwellings = CampaignDwellingState.new()
	var saved_bonds: Variant = data.get("companion_bonds", {})
	if saved_bonds is Dictionary and not saved_bonds.is_empty():
		if not simulation.companion_bonds.from_dict(saved_bonds):
			push_warning("Saved companion-to-companion relationships were invalid and have been reset.")
			simulation.companion_bonds = CompanionBondState.new()

	var journal_data: Variant = data.get("campaign_journal", {})
	if journal_data is Dictionary:
		simulation.campaign_journal.load_dict(journal_data)
	var persistent_relationship_data: Variant = data.get("persistent_character_relationships", {})
	if persistent_relationship_data is Dictionary:
		if not PERSISTENT_RELATIONSHIP_STORE.restore(simulation, persistent_relationship_data):
			push_warning("Persistent NPC relationship state could not be fully synchronised with the campaign journal.")
	var companion_runtime_data: Variant = data.get("companion_campaign_runtime", {})
	if companion_runtime_data is Dictionary and not COMPANION_RUNTIME_STORE.restore(simulation, companion_runtime_data):
		push_warning("Companion relationship and personal quest state could not be fully restored.")

	var multistory_data: Variant = data.get("multistory_locations", {})
	if multistory_data is Dictionary and not simulation.restore_multistory_location_states(multistory_data):
		push_warning("Some multi-story location state could not be restored; affected locations will use their validated defaults.")
	var resource_data: Variant = data.get("wilderness_resources", {})
	if resource_data is Dictionary:
		simulation.wilderness_resources.load_dict(resource_data)
	var building_data: Variant = data.get("buildings", {})
	if building_data is Dictionary:
		simulation.building_registry.load_dict(building_data)

	return {"ok": true}
