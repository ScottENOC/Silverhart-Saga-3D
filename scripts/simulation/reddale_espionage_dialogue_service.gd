class_name ReddaleEspionageDialogueService
extends RefCounted
## Dialogue adapter for the Baron's and Guildmaster's mirrored Reddale missions.

const CONTENT = preload("res://scripts/simulation/reddale_espionage_content.gd")
const BARON_ID := "baron_corwin_aldervale"
const GUILDMASTER_ID := "petra_voss"

static func dialogue_for_npc(journal: CampaignJournal, npc_id: String) -> Dictionary:
	if journal == null:
		return {"ok":false, "reason":"missing_journal"}
	var quest_id := CONTENT.quest_for_employer(npc_id)
	if quest_id.is_empty():
		return {"ok":false, "reason":"unsupported_dialogue_actor"}
	var quest: Dictionary = journal.quests.get(quest_id, {})
	var is_guild := quest_id == CONTENT.GUILD_QUEST
	var employer := "Baron Corwin Aldervale" if is_guild else "Guildmaster Petra Voss"
	var target := "Ironbond's guildhouse" if is_guild else "the Baron's manor"
	if quest.is_empty():
		if CONTENT.can_offer(journal, quest_id):
			return {"ok":true, "speaker":employer, "body":"I need you to enter %s, recover the private records, and leave without being seen. If their guard catches you, the mission is blown." % target, "choices":[{"id":"start_espionage", "label":"I'll do it."},{"id":"leave", "label":"Not my business."}]}
		return {"ok":true, "speaker":employer, "body":"There is nothing I need you to do just now.", "choices":[{"id":"leave","label":"Understood."}]}
	var status := String(quest.get("status", ""))
	if status == "failed":
		return {"ok":true, "speaker":employer, "body":"I heard the guard caught you. That operation is over; I won't send you back.", "choices":[{"id":"leave","label":"..."}]}
	if status == "completed":
		return {"ok":true, "speaker":employer, "body":"The records have been dealt with. Reddale will feel the consequences soon enough.", "choices":[{"id":"leave","label":"I'll leave you to it."}]}
	var choices: Array[Dictionary] = []
	if not bool(quest.get("double_cross_offered", false)):
		choices.append({"id":"double_cross_accept", "label":"Agree to work as a double agent."})
		choices.append({"id":"double_cross_decline", "label":"Refuse the offer."})
	choices.append({"id":"return_evidence", "label":"I've recovered the records."})
	choices.append({"id":"leave", "label":"Not yet."})
	return {"ok":true, "speaker":employer, "body":"The operation is still active. Have you recovered the records, or has the other side approached you?", "choices":choices}

static func select_choice(journal: CampaignJournal, player: CharacterState, npc_id: String, choice_id: String) -> Dictionary:
	if journal == null or player == null:
		return {"ok":false, "reason":"missing_journal_or_player"}
	var quest_id := CONTENT.quest_for_employer(npc_id)
	if quest_id.is_empty():
		return {"ok":false, "reason":"unsupported_dialogue_actor"}
	if choice_id == "leave":
		return {"ok":true, "closed":true}
	if choice_id == "start_espionage":
		var started := CONTENT.start(journal, quest_id)
		if not bool(started.get("ok", false)):
			return started
		var mission := {"quest_id":quest_id, "guard_id":"guild_watchman_corley" if quest_id == CONTENT.GUILD_QUEST else "steward_halvard_greer", "evidence_id":"guild_ledgers" if quest_id == CONTENT.GUILD_QUEST else "baron_tariffs", "target_faction_id":"ironbond_company" if quest_id == CONTENT.GUILD_QUEST else "silverhart_kingdom", "fail_standing_delta":-20.0}
		return {"ok":true, "mission":mission, "body":"Keep out of sight. The records are inside; return to me once you have them."}
	if choice_id == "double_cross_accept" or choice_id == "double_cross_decline":
		var side := "silverhart_kingdom" if quest_id == CONTENT.BARON_QUEST else "ironbond_company"
		var flipped := CONTENT.record_double_agent(journal, quest_id, side, choice_id == "double_cross_accept")
		if not bool(flipped.get("ok", false)):
			return flipped
		return {"ok":true, "accepted":choice_id == "double_cross_accept"}
	if choice_id == "return_evidence":
		var evidence_id := "guild_ledger_evidence" if quest_id == CONTENT.GUILD_QUEST else "baron_tariff_evidence"
		var evidence_index := -1
		for index in range(player.inventory.size()):
			if String(player.inventory[index].get("id", "")) == evidence_id:
				evidence_index = index
				break
		if evidence_index < 0:
			return {"ok":false, "reason":"evidence_not_carried"}
		var completed := CONTENT.complete(journal, quest_id, player)
		if not bool(completed.get("ok", false)):
			return completed
		player.inventory.remove_at(evidence_index)
		return completed
	return {"ok":false, "reason":"unknown_choice"}
