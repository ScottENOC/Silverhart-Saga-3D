class_name ReddaleCampaignDialogueService
extends RefCounted
## Dialogue-facing adapter for the Reeve's Reddale's Cut quest.
## The journal owns quest state; this service only builds choices and routes
## selected choices into the source-authored campaign content.

const CONTENT := preload("res://scripts/simulation/reddale_campaign_content.gd")


static func dialogue_for_reeve(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	var quest: Dictionary = journal.quests.get(CONTENT.QUEST_ID, {})
	if quest.is_empty():
		if CONTENT.can_offer_cut(journal):
			return {
				"ok": true,
				"speaker": "Reeve Aldous Finch",
				"body": "Ironbond's influence has grown too strong in Reddale. I need someone who can help me decide whether we stand against them or make terms.",
				"choices": [
					{"id": "reddale_cut_start", "label": "Tell me what Ironbond wants."},
					{"id": "leave", "label": "Not now."}
				]
			}
		return {
			"ok": true,
			"speaker": "Reeve Aldous Finch",
			"body": "Reddale has its troubles, but there is nothing I need to ask of you just now.",
			"choices": [{"id": "leave", "label": "I'll leave you to it."}]
			}
	if String(quest.get("status", "")) == "active":
		return {
			"ok": true,
			"speaker": "Reeve Aldous Finch",
			"body": "We cannot leave this unresolved. Will you help me resist the Company, or broker the arrangement they want?",
			"choices": CONTENT.choices()
			}
	var state := journal.npc_campaign_state("reeve_aldous_finch")
	var flags: Dictionary = state.get("flags", {})
	var body := "The matter is settled. Reddale will live with the consequences."
	if bool(flags.get("will_openly_oppose_ironbond", false)):
		body = "Reddale stood its ground. The Company has not forgotten, but neither have we."
	elif bool(flags.get("ironbond_deal_brokered", false)):
		body = "The arrangement with Ironbond is in place. Trade has improved, though the Company now has a firmer foothold here."
	return {
		"ok": true,
		"speaker": "Reeve Aldous Finch",
		"body": body,
		"choices": [{"id": "leave", "label": "I'll leave you to it."}]
		}


static func select_choice(
	journal: CampaignJournal,
	player: CharacterState,
	choice_id: String
) -> Dictionary:
	if journal == null:
		return {"ok": false, "reason": "missing_journal"}
	if choice_id == "leave":
		return {"ok": true, "closed": true}
	if choice_id == "reddale_cut_start":
		var started := CONTENT.start_cut(journal)
		if not bool(started.get("ok", false)):
			return started
		return {
			"ok": true,
			"speaker": "Reeve Aldous Finch",
			"body": "Thank you. Then let us decide what sort of future Reddale is to have.",
			"choices": CONTENT.choices()
			}
	if choice_id == "resist_ironbond" or choice_id == "broker_ironbond_deal":
		if player == null:
			return {"ok": false, "reason": "missing_player"}
		return CONTENT.resolve_cut(journal, choice_id, player)
	return {"ok": false, "reason": "unknown_choice"}
