class_name IlsaWatchCaptainContent
extends RefCounted
## Source-backed persistent dialogue reflections for Captain Ilsa Rennick.
## The broader Missing Watch and Eyes on the Border quest encounters are not
## fabricated here; this ports the optional reflection layer from
## ilsaWatchCaptain.js and keeps its relationship effects idempotent.

const CHARACTER_ID := "ilsa_rennick"
const DIALOGUE_ID := "reddale_captain"
const PERSISTENT_DIALOGUE_CONTENT = preload("res://scripts/simulation/persistent_character_dialogue_content.gd")

static func greeting(journal: CampaignJournal, relationships: PersistentCharacterRelationshipState) -> Dictionary:
	if journal == null or relationships == null:
		return {"ok": false, "reason": "missing_journal_or_relationships"}
	PERSISTENT_DIALOGUE_CONTENT.new().note_audience(relationships, DIALOGUE_ID)
	_sync_story_events(journal, relationships)
	var options: Array[Dictionary] = []
	var reyna := _quest(journal, "reyna_empty_blind")
	var has_reyna_resolution := String(reyna.get("status", "")) == "completed"
	if has_reyna_resolution:
		options.append({"id": "ilsa_reflection_empty_blind", "label": "About Reyna’s missing trackers…"})
	if _has_necromancer_case(journal):
		options.append({"id": "ilsa_reflection_necromancer", "label": "What did the necromancer case teach the Watch?"})
	var relationship := relationships.snapshot(CHARACTER_ID)
	if int(relationship.get("familiarity", 0)) >= 8:
		options.append({"id": "ilsa_philosophy_law_and_truth", "label": "What do you think the Watch is actually for?"})
	if int(relationship.get("familiarity", 0)) >= 10:
		options.append({"id": "ilsa_philosophy_command_uncertainty", "label": "How do you make decisions when you do not know enough?"})
	if has_reyna_resolution:
		options.append({"id": "ilsa_reyna_institutional_trust", "label": "What do you make of Reyna?"})
	options.append({"id": "ilsa_leave", "label": "Understood."})
	return {
		"ok": true,
		"speaker": "Captain Ilsa Rennick",
		"text": "Keep your nose clean in Reddale and we won't have trouble.",
		"choices": options,
		"relationship": relationships.snapshot(CHARACTER_ID)
	}


static func resolve_choice(
	journal: CampaignJournal,
	relationships: PersistentCharacterRelationshipState,
	choice_id: String
) -> Dictionary:
	if journal == null or relationships == null:
		return {"ok": false, "reason": "missing_journal_or_relationships"}
	if choice_id == "ilsa_leave":
		return {"ok": true, "handled": true, "close": true}
	var key := ""
	var delta: Dictionary = {"familiarity": 2, "friendship": 3}
	var response := ""
	match choice_id:
		"ilsa_reflection_empty_blind":
			var reyna := _quest(journal, "reyna_empty_blind")
			if String(reyna.get("status", "")) != "completed":
				return {"ok": false, "reason": "reyna_arc_not_resolved"}
			var resolution := String(reyna.get("resolution", ""))
			key = "ilsa:reflection:empty_blind:" + resolution
			response = _empty_blind_text(resolution)
		"ilsa_reflection_necromancer":
			if not _has_necromancer_case(journal):
				return {"ok": false, "reason": "necromancer_case_not_started"}
			key = "ilsa:reflection:necromancer"
			response = _necromancer_text(journal)
		"ilsa_philosophy_law_and_truth":
			if int(relationships.snapshot(CHARACTER_ID).get("familiarity", 0)) < 8:
				return {"ok": false, "reason": "not_familiar_enough"}
			key = "ilsa:philosophy:law_and_truth"
			delta = {"familiarity": 3, "trust": 1, "friendship": 4}
			response = _philosophy_text(relationships)
		"ilsa_philosophy_command_uncertainty":
			if int(relationships.snapshot(CHARACTER_ID).get("familiarity", 0)) < 10:
				return {"ok": false, "reason": "not_familiar_enough"}
			key = "ilsa:philosophy:command_uncertainty"
			delta = {"familiarity": 2, "friendship": 2}
			response = _command_text(relationships)
		"ilsa_reyna_institutional_trust":
			var reyna := _quest(journal, "reyna_empty_blind")
			if String(reyna.get("status", "")) != "completed":
				return {"ok": false, "reason": "reyna_arc_not_resolved"}
			key = "ilsa:reyna:institutional_trust"
			delta = {"familiarity": 2, "friendship": 3}
			response = _reyna_text(String(reyna.get("resolution", "")))
		_:
			return {"ok": false, "handled": false, "reason": "unknown_choice"}
	var updated := relationships.note_conversation(CHARACTER_ID, key, delta)
	return {
		"ok": true,
		"handled": true,
		"speaker": "Captain Ilsa Rennick",
		"text": response,
		"choices": [{"id": "ilsa_leave", "label": "Understood."}],
		"relationship": updated
	}


static func _quest(journal: CampaignJournal, quest_id: String) -> Dictionary:
	return journal.quest_state(quest_id) if journal != null else {}


static func _has_necromancer_case(journal: CampaignJournal) -> bool:
	for quest_id in ["disciple_exposed", "necromancer_hunt", "necromancer_lichdom"]:
		if not String(_quest(journal, quest_id).get("status", "")).is_empty():
			return true
	return false


static func _sync_story_events(journal: CampaignJournal, relationships: PersistentCharacterRelationshipState) -> void:
	var missing := _quest(journal, "reddale_missing_watch")
	if String(missing.get("status", "")) == "completed":
		relationships.record_event(CHARACTER_ID, "ilsa:missing_watch:resolved", {"familiarity": 2, "trust": 4, "friendship": 2})
	var eyes := _quest(journal, "eyes_on_border")
	if String(eyes.get("status", "")) == "completed":
		relationships.record_event(CHARACTER_ID, "ilsa:eyes_on_border:resolved", {"familiarity": 2, "trust": 4, "friendship": 2})
	var reyna := _quest(journal, "reyna_empty_blind")
	if String(reyna.get("status", "")) == "completed":
		var resolution := String(reyna.get("resolution", ""))
		var delta: Dictionary = {}
		match resolution:
			"witness_deal": delta = {"familiarity": 4, "trust": 8, "friendship": 5}
			"turn_in": delta = {"familiarity": 3, "trust": 4, "friendship": 2}
			"double_agent": delta = {"familiarity": 3, "trust": -5, "friendship": -1}
			"let_disappear": delta = {"familiarity": 3, "trust": -8, "friendship": -3}
		if not delta.is_empty():
			relationships.record_event(CHARACTER_ID, "ilsa:empty_blind:" + resolution, delta)
	var disciple := _quest(journal, "disciple_exposed")
	if String(disciple.get("status", "")) == "completed":
		relationships.record_event(CHARACTER_ID, "ilsa:disciple:reported_with_evidence", {"familiarity": 2, "trust": 5, "friendship": 2})
	var hunt := _quest(journal, "necromancer_hunt")
	if String(hunt.get("status", "")) == "completed":
		relationships.record_event(CHARACTER_ID, "ilsa:necromancer_hunt:crypt_resolved", {"familiarity": 3, "trust": 6, "friendship": 2})
	var lich := _quest(journal, "necromancer_lichdom")
	if String(lich.get("resolution", "")) == "allied":
		relationships.record_event(CHARACTER_ID, "ilsa:lichdom:allied_with_ashgrave", {"familiarity": 4, "trust": -35, "friendship": -18})
	elif String(lich.get("status", "")) == "completed":
		relationships.record_event(CHARACTER_ID, "ilsa:lichdom:ashgrave_stopped", {"familiarity": 3, "trust": 10, "friendship": 4})


static func _empty_blind_text(resolution: String) -> String:
	match resolution:
		"witness_deal":
			return "“The witness deal was worth making,” Ilsa says. “Not because Tamsin and the others did nothing wrong. They leaked routes after the first coercion ended. But protection bought us testimony, current intelligence and a way to stop the leak without teaching every frightened informant that surrender is suicide.”"
		"turn_in":
			return "Ilsa nods. “A public trial was defensible. People died because of those routes, and coercion does not erase everything chosen afterward. My job then is to make sure the court hears the coercion as loudly as it hears the dead soldiers.”"
		"double_agent":
			return "Ilsa’s jaw tightens. “Clever operation. Also an unregistered intelligence network built from traumatised civilians who already proved they make bad decisions when isolated.” She exhales. “If it works, everyone calls it ingenuity. If it fails, the Watch finds out after the bodies arrive.”"
		"let_disappear":
			return "“I understand why Reyna wanted them gone,” Ilsa says. “I even understand why you helped.” She does not soften. “But disappearing witnesses also disappears what they know. Mercy for three people can still leave every patrol east of Reddale blind.”"
		_:
			return "Ilsa rubs at one eyebrow. “A Watch can punish betrayal. Harder question is whether people believe they can come back after the first bad choice. If the answer is always a rope, they stop coming back and start hiding the next mistake too.”"


static func _necromancer_text(journal: CampaignJournal) -> String:
	var lich := _quest(journal, "necromancer_lichdom")
	if String(lich.get("resolution", "")) == "allied":
		return "Ilsa looks at you as though recalculating every previous conversation. “You were the person I sent because you could get close enough to end Ashgrave. You used that access to join him.” Her voice stays level. “That is not a theological disagreement. It is an operational fact I now have to plan around.”"
	if String(lich.get("status", "")) == "completed":
		return "“Ashgrave is finished, then,” Ilsa says. “Good. I will still keep the reports. Threats like that become legends quickly, and legends are terrible intelligence. Next time I want names, dates, routes and exactly what failed to kill him the first time.”"
	if String(_quest(journal, "necromancer_hunt").get("status", "")) == "completed":
		return "“Clearing the crypt did not end the problem,” Ilsa says. “That is the lesson I care about. We saw one ritual site and wanted it to be the whole story. Commanders love complete stories because complete stories let us stop allocating patrols.”"
	if String(_quest(journal, "disciple_exposed").get("status", "")) == "completed":
		return "“Mirella was useful evidence because she was a thread, not because arresting one disciple made the cult disappear,” Ilsa says. “A Watch gets into trouble when every arrest is treated as proof the case is over.”"
	return "“If something supernatural is killing people, I still need ordinary facts,” Ilsa says. “Where. When. Who saw it. Which road. Which body. Fear is not improved by vague reports.”"


static func _philosophy_text(relationships: PersistentCharacterRelationshipState) -> String:
	var relationship := relationships.snapshot(CHARACTER_ID)
	if int(relationship.get("trust", 0)) < 15:
		return "Ilsa gives you a dry look. “My philosophy is that Reddale should still be standing tomorrow morning. The rest is easier to discuss after you have proved you are not creating extra work for the Watch.”"
	if int(relationship.get("friendship", 0)) < 15:
		return "“Law is useful when it makes people more willing to bring you the truth,” Ilsa says. “If every mistake means the maximum punishment, people do not become more honest. They become better at hiding mistakes until the consequences are too large to hide.”"
	return "Ilsa leans back. “Captains like to say civilians should have come to us sooner. Sometimes that is true.” She grimaces. “Sometimes we have spent years teaching them exactly what will happen if they do. You cannot build an institution around fear and then act surprised when frightened people avoid it.”"


static func _command_text(relationships: PersistentCharacterRelationshipState) -> String:
	var relationship := relationships.snapshot(CHARACTER_ID)
	if int(relationship.get("trust", 0)) < 25:
		return "“Command is deciding with incomplete information and then being responsible for the result,” Ilsa says. “Anyone who tells you certainty comes with the rank is selling uniforms.”"
	return "“The worst temptation in command is confusing decisiveness with being right,” Ilsa says. “You still have to choose before all the facts arrive. The discipline is keeping enough humility afterward to change the plan when the facts prove you wrong.”"


static func _reyna_text(resolution: String) -> String:
	match resolution:
		"witness_deal":
			return "Ilsa gives a short laugh. “Reyna asking an institution for help before the crisis is already half a miracle. Do not tell her I said that.” Then she sobers. “She is learning that relying on someone is not the same thing as surrendering judgement.”"
		"let_disappear":
			return "“Reyna is excellent at surviving systems she does not trust,” Ilsa says. “That is not the same skill as changing them. If she assumes every structure will fail her, she will keep proving she can operate alone—and keep carrying every failure alone too.”"
		_:
			return "“Reyna notices what formal patrols miss,” Ilsa says. “I value that. I would value it more if she stopped treating coordination as a character flaw.”"
