class_name PersistentCharacterRelationshipStore
extends RefCounted
## Attaches persistent non-companion relationships to the authoritative campaign
## simulation node without expanding the legacy WorldSimulation source file.

const META_KEY := "persistent_character_relationships"


static func state_for(simulation: WorldSimulation) -> PersistentCharacterRelationshipState:
	if simulation == null:
		return null
	if simulation.has_meta(META_KEY):
		var existing: Variant = simulation.get_meta(META_KEY)
		if existing is PersistentCharacterRelationshipState:
			return existing
	var state := PersistentCharacterRelationshipState.new()
	simulation.set_meta(META_KEY, state)
	return state


static func to_dict(simulation: WorldSimulation) -> Dictionary:
	var state := state_for(simulation)
	if state == null:
		return {}
	var sync_result := state.sync_all_with_journal(simulation.campaign_journal)
	if not bool(sync_result.get("ok", false)):
		push_warning("Could not synchronise all persistent NPC relationships before saving: %s" % sync_result)
	return state.to_dict()


static func restore(simulation: WorldSimulation, saved_state: Dictionary) -> bool:
	var state := state_for(simulation)
	if state == null:
		return false
	state.from_dict(saved_state)
	var sync_result := state.sync_all_with_journal(simulation.campaign_journal)
	return bool(sync_result.get("ok", false))
