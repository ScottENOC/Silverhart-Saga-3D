class_name CampaignWorldStateService
extends RefCounted
## Read-only projection of durable campaign state for NPC interaction and
## presentation. Authored definitions remain immutable; the journal is authority.

static func settlement_context(journal: CampaignJournal, settlement_id: String) -> Dictionary:
	if journal == null or settlement_id.strip_edges().is_empty():
		return {}
	var state := journal.settlement_campaign_state(settlement_id)
	if state.is_empty():
		return {}
	var flags: Dictionary = state.get("flags", {})
	return {
		"settlement_id": settlement_id,
		"values": state.duplicate(true),
		"flags": flags.duplicate(true)
	}


static func npc_context(journal: CampaignJournal, npc_id: String, settlement_id: String = "", faction_id: String = "") -> Dictionary:
	if journal == null or npc_id.strip_edges().is_empty():
		return {}
	var npc_state := journal.npc_campaign_state(npc_id)
	var settlement_state := journal.settlement_campaign_state(settlement_id) if not settlement_id.is_empty() else {}
	var npc_flags: Dictionary = npc_state.get("flags", {})
	var settlement_flags: Dictionary = settlement_state.get("flags", {})
	var public_status := String(npc_flags.get("public_status", "")).strip_edges()
	if public_status.is_empty() and bool(npc_flags.get("public_status_visible", false)):
		public_status = "Changed by recent events"
	if public_status.is_empty() and faction_id == "ironbond_company":
		var presence := float(settlement_state.get("ironbond_presence", 0.0))
		if presence <= -1.0:
			public_status = "Ironbond influence weakened"
		elif presence >= 1.0:
			public_status = "Ironbond influence entrenched"
	return {
		"npc_id": npc_id,
		"settlement_id": settlement_id,
		"npc": npc_state,
		"settlement": settlement_state,
		"npc_flags": npc_flags.duplicate(true),
		"settlement_flags": settlement_flags.duplicate(true),
		"trust": float(npc_state.get("trust", 0.0)),
		"fear": float(npc_state.get("fear", 0.0)),
		"public_status": public_status
	}


## Attach a fresh projection to an actor whenever a streamed chunk is built.
## The actor is disposable presentation; the journal remains persistent state.
static func apply_npc_actor_state(actor: Node3D, journal: CampaignJournal, npc_id: String, settlement_id: String, faction_id: String = "") -> Dictionary:
	if actor == null or journal == null:
		return {"ok": false, "reason": "missing_actor_or_journal"}
	var context := npc_context(journal, npc_id, settlement_id, faction_id)
	if context.is_empty():
		return {"ok": false, "reason": "missing_campaign_context"}
	actor.set_meta("campaign2_settlement_id", settlement_id)
	actor.set_meta("campaign_npc_state", context.get("npc", {}).duplicate(true))
	actor.set_meta("campaign_settlement_state", context.get("settlement", {}).duplicate(true))
	actor.set_meta("campaign_npc_flags", context.get("npc_flags", {}).duplicate(true))
	actor.set_meta("campaign_settlement_flags", context.get("settlement_flags", {}).duplicate(true))
	actor.set_meta("campaign_public_status", String(context.get("public_status", "")))
	_update_public_status_label(actor, String(context.get("public_status", "")))
	return {"ok": true, "context": context}


static func _update_public_status_label(actor: Node3D, status: String) -> void:
	var label := actor.get_node_or_null("CampaignStatusLabel") as Label3D
	if status.is_empty():
		if label != null:
			label.queue_free()
		return
	if label == null:
		label = Label3D.new()
		label.name = "CampaignStatusLabel"
		label.position.y = 2.38
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 18
		label.outline_size = 4
		label.modulate = Color(0.92, 0.82, 0.62)
		actor.add_child(label)
	label.text = status
