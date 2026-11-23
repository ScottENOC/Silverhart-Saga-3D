class_name CompanionCampaignRuntimeStore
extends RefCounted
## Owns the runtime instances for companion relationships and personal quest arcs.
## CampaignJournal remains authoritative for quest status and decisions.

const RELATIONSHIP_META_KEY := "companion_relationship_state"
const QUEST_CHAIN_META_KEY := "companion_quest_chain_state"\nconst WREN_ARC_META_KEY := "wren_character_arc_state"


static func relationship_state_for(simulation: WorldSimulation) -> CompanionRelationshipState:
	if simulation == null:
		return null
	var existing: Variant = simulation.get_meta(RELATIONSHIP_META_KEY, null)
	if existing is CompanionRelationshipState:
		return existing
	var state := CompanionRelationshipState.new()
	simulation.set_meta(RELATIONSHIP_META_KEY, state)
	return state


static func quest_chain_state_for(simulation: WorldSimulation) -> CompanionQuestChainState:
	if simulation == null:
		return null
	var existing: Variant = simulation.get_meta(QUEST_CHAIN_META_KEY, null)
	if existing is CompanionQuestChainState:
		return existing
	var state := CompanionQuestChainState.new()
	simulation.set_meta(QUEST_CHAIN_META_KEY, state)
	return state


static func register_quest_definitions(simulation: WorldSimulation) -> bool:
	if simulation == null or simulation.campaign_journal == null:
		return false
	var quest_state := quest_chain_state_for(simulation)
	if quest_state == null:
		return false
	quest_state.register_quest_definitions(simulation.campaign_journal)
	return true


static func to_dict(simulation: WorldSimulation) -> Dictionary:
	var relationships := relationship_state_for(simulation)
	var quest_chain := quest_chain_state_for(simulation)
	if relationships == null or quest_chain == null:
		return {}
	return {
		"version": 1,
		"relationships": relationships.to_dict(),
		"quest_chain": quest_chain.to_dict()
	}


static func restore(simulation: WorldSimulation, saved_state: Dictionary) -> bool:
	if simulation == null:
		return false
	var relationships := relationship_state_for(simulation)
	var quest_chain := quest_chain_state_for(simulation)
	if relationships == null or quest_chain == null:
		return false
	var relationship_data: Variant = saved_state.get("relationships", {})
	var quest_chain_data: Variant = saved_state.get("quest_chain", {})
	if relationship_data is Dictionary:
		relationships.load_dict(relationship_data)
	if quest_chain_data is Dictionary:
		quest_chain.from_dict(quest_chain_data)
	return true
