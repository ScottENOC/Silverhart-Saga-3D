class_name HollowmereShakedownDialogueService
extends RefCounted
## Resolves the Ironbond choice using the authored Hollowmere content; world combat and soldier movement remain external.

const CONTENT = preload("res://scripts/simulation/hollowmere_campaign_content.gd")


static func resolve_choice(simulation: WorldSimulation, choice: Dictionary) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"handled": true, "ok": false, "reason": "missing_campaign_journal"}
	var choice_id := String(choice.get("id", ""))
	var selected: Dictionary = {}
	for choice_value in CONTENT.shakedown_choices():
		var authored: Dictionary = choice_value
		if String(authored.get("id", "")) == choice_id and bool(authored.get("available", true)):
			selected = authored
			break
	if selected.is_empty():
		return {"handled": false, "ok": false, "reason": "choice_unavailable"}
	var result: Dictionary
	var action := "move_soldiers_outside"
	if choice_id == "fight":
		result = CONTENT.apply_shakedown_choice(simulation.campaign_journal, choice_id)
		action = "begin_combat"
	else:
		result = CONTENT.resolve_shakedown(simulation.campaign_journal, choice_id)
	if not bool(result.get("ok", false)):
		return {"handled": true, "ok": false, "reason": String(result.get("reason", "choice_could_not_be_recorded"))}
	return {
		"handled": true,
		"ok": true,
		"action": action,
		"choice": selected.duplicate(true),
		"response": String(selected.get("response", "")),
		"event_key": "hollowmere_shakedown:" + choice_id
	}
