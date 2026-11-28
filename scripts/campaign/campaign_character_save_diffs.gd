class_name CampaignCharacterSaveDiffs
extends RefCounted
## Builds compact character and appearance deltas for campaign save snapshots.
## This owns serialization comparison only; actor creation and save-slot I/O
## remain with their respective world and save systems.


static func capture_character_baselines(simulation: WorldSimulation) -> Dictionary:
	var baselines: Dictionary = {}
	if simulation == null:
		return baselines
	for state in simulation.character_states():
		baselines[state.id] = state.to_dict()
	return baselines


static func build_character_diffs(simulation: WorldSimulation, baselines: Dictionary) -> Dictionary:
	var diffs: Dictionary = {}
	if simulation == null:
		return diffs
	for state in simulation.character_states():
		var character_id := state.id
		var current := state.to_dict()
		if not baselines.has(character_id):
			diffs[character_id] = {"__full_record": current}
			continue
		var baseline: Dictionary = baselines[character_id]
		var changed: Dictionary = {}
		for field in current.keys():
			if not baseline.has(field) or current[field] != baseline[field]:
				changed[field] = current[field]
		if not changed.is_empty():
			diffs[character_id] = changed
	return diffs


static func build_appearance_diffs(actors_by_id: Dictionary) -> Dictionary:
	var diffs: Dictionary = {}
	for actor_id_variant in actors_by_id.keys():
		var actor_id := String(actor_id_variant)
		var actor := actors_by_id[actor_id] as Node3D
		if actor == null or actor_id == "player":
			continue
		var base: Dictionary = actor.get_meta("base_appearance_profile", {})
		var current: Dictionary = actor.get_meta("appearance_profile", base)
		var changed: Dictionary = {}
		for field in current.keys():
			if not base.has(field) or current[field] != base[field]:
				changed[field] = current[field]
		if not changed.is_empty():
			diffs[actor_id] = changed
	return diffs
