class_name CampaignWorldConsequenceService
extends RefCounted
## Applies durable settlement and named-NPC state changes caused by a recorded
## campaign decision. Authored definitions remain untouched; runtime systems
## read the resulting deltas and flags from CampaignJournal.

static func apply_decision_consequences(
	journal: CampaignJournal,
	quest_id: String,
	decision_id: String,
	settlement_updates: Array,
	npc_updates: Array
) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	if settlement_updates.is_empty() and npc_updates.is_empty():
		return {"ok": false, "reason": "empty_world_updates"}

	for update in settlement_updates:
		if String(update.get("settlement_id", "")).strip_edges().is_empty():
			return {"ok": false, "reason": "missing_settlement_id"}
		if not _valid_update_payload(update):
			return {"ok": false, "reason": "invalid_settlement_update"}

	for update in npc_updates:
		if String(update.get("npc_id", "")).strip_edges().is_empty():
			return {"ok": false, "reason": "missing_npc_id"}
		if not _valid_update_payload(update):
			return {"ok": false, "reason": "invalid_npc_update"}

	var consequence_id := "%s::%s::world_state" % [quest_id, decision_id]
	var payload := {
		"settlements": settlement_updates.duplicate(true),
		"npcs": npc_updates.duplicate(true)
	}
	var recorded := journal.record_world_consequence(consequence_id, quest_id, decision_id, payload)
	if not bool(recorded.get("ok", false)):
		return recorded
	if bool(recorded.get("already_recorded", false)):
		return {"ok": true, "already_recorded": true, "consequence_id": consequence_id}

	var settlement_results: Array[Dictionary] = []
	for update in settlement_updates:
		settlement_results.append(journal.apply_settlement_campaign_state(
			String(update["settlement_id"]),
			update.get("deltas", {}),
			update.get("flags", {})
		))

	var npc_results: Array[Dictionary] = []
	for update in npc_updates:
		npc_results.append(journal.apply_npc_campaign_state(
			String(update["npc_id"]),
			update.get("deltas", {}),
			update.get("flags", {})
		))

	return {
		"ok": true,
		"already_recorded": false,
		"consequence_id": consequence_id,
		"settlements": settlement_results,
		"npcs": npc_results
	}


static func _valid_update_payload(update: Dictionary) -> bool:
	var deltas: Variant = update.get("deltas", {})
	var flags: Variant = update.get("flags", {})
	if not deltas is Dictionary or not flags is Dictionary:
		return false
	if deltas.is_empty() and flags.is_empty():
		return false
	for key in deltas:
		if String(key).strip_edges().is_empty():
			return false
		var value: Variant = deltas[key]
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
	for key in flags:
		if String(key).strip_edges().is_empty():
			return false
		var flag_value: Variant = flags[key]
		if not (flag_value is bool or flag_value is String):
			return false
	return true
