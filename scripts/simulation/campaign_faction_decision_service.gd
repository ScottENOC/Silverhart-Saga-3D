class_name CampaignFactionDecisionService
extends RefCounted
## Applies source-authored faction reputation and political/economic influence
## consequences for a single recorded campaign decision.
## CampaignJournal remains the authority for persistence and idempotency.

static func apply_outcome(
	journal: CampaignJournal,
	quest_id: String,
	decision_id: String,
	choice_id: String,
	faction_changes: Array[Dictionary],
	influence_changes: Array[Dictionary],
	reason: String
) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	if quest_id.strip_edges().is_empty() or decision_id.strip_edges().is_empty() or choice_id.strip_edges().is_empty():
		return {"ok": false, "reason": "missing_decision_identity"}
	if reason.strip_edges().is_empty():
		return {"ok": false, "reason": "missing_reason"}

	for change in faction_changes:
		if String(change.get("faction_id", "")).strip_edges().is_empty():
			return {"ok": false, "reason": "missing_faction_id"}
		if not _is_finite_number(change.get("standing_delta", 0.0)) or not _is_finite_number(change.get("knowledge_delta", 0.0)):
			return {"ok": false, "reason": "invalid_faction_delta"}

	for change in influence_changes:
		if String(change.get("faction_id", "")).strip_edges().is_empty() or String(change.get("kingdom_id", "")).strip_edges().is_empty():
			return {"ok": false, "reason": "missing_influence_target"}
		if not _is_finite_number(change.get("amount", 0.0)):
			return {"ok": false, "reason": "invalid_influence_delta"}

	var recorded := journal.record_decision(quest_id, decision_id, choice_id)
	if not bool(recorded.get("ok", false)):
		return recorded

	var reputation_results: Array[Dictionary] = []
	for change in faction_changes:
		reputation_results.append(journal.adjust_faction_reputation(
			String(change["faction_id"]),
			float(change.get("standing_delta", 0.0)),
			float(change.get("knowledge_delta", 0.0)),
			reason
		))

	var influence_results: Array[Dictionary] = []
	for change in influence_changes:
		influence_results.append(journal.adjust_merchant_influence(
			String(change["faction_id"]),
			String(change["kingdom_id"]),
			float(change.get("amount", 0.0)),
			reason
		))

	return {
		"ok": true,
		"choice_id": choice_id,
		"reputation": reputation_results,
		"influence": influence_results
	}


static func _is_finite_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value))
