class_name AbandonedHouseDialogueService
extends RefCounted
## Resolves abandoned-house quest choices without presentation or scene access.

const QUEST_SCRIPT = preload("res://scripts/simulation/abandoned_house_clearing_quest.gd")


static func resolve_choice(simulation: WorldSimulation, choice: Dictionary) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"handled": false, "ok": false, "reason": "missing_simulation_or_journal"}
	var choice_id := String(choice.get("id", ""))
	match choice_id:
		"abandoned_house_investigate":
			var started := QUEST_SCRIPT.ensure_started(simulation.campaign_journal)
			var spawned := QUEST_SCRIPT.ensure_guardians(simulation)
			if bool(started.get("ok", false)) and bool(spawned.get("ok", false)):
				return {
					"handled": true,
					"ok": true,
					"action": "restore_guardian_actors",
					"dialogue": _dialogue(
						"Abandoned House",
						"The journal lies in the centre of the room. Three skeletons turn towards you, their weapons scraping against the old floorboards.",
						[
							{"id": "abandoned_house_read_journal", "label": "Read the journal.", "text": ""},
							{"id": "abandoned_house_enter", "label": "Face the guardians.", "text": ""},
							{"id": "continue", "label": "Withdraw for now.", "text": ""}
						]
					)
				}
			return {
				"handled": true,
				"ok": false,
				"dialogue": _dialogue("Abandoned House", "The house cannot be investigated right now.")
			}
		"abandoned_house_read_journal":
			return {
				"handled": true,
				"ok": true,
				"journal_read": true,
				"dialogue": _dialogue(
					"Abandoned House",
					"You take a moment to read the journal before confronting the guardians.",
					[
						{"id": "abandoned_house_enter", "label": "Face the guardians.", "text": ""},
						{"id": "continue", "label": "Withdraw for now.", "text": ""}
					]
				)
			}
		"abandoned_house_finalize":
			QUEST_SCRIPT.apply_defeat_consequences(simulation.campaign_journal, simulation)
			var clearing := QUEST_SCRIPT.resolve_clearing(simulation.campaign_journal, simulation)
			if bool(clearing.get("ok", false)) and bool(clearing.get("completed", false)):
				return {
					"handled": true,
					"ok": true,
					"dialogue": _dialogue(
						"Abandoned House",
						"The last of the necromancer's undead minions is gone. The house can now be restored."
					)
				}
			return {
				"handled": true,
				"ok": false,
				"dialogue": _dialogue(
					"Abandoned House",
					"The clearing is not yet resolved: %s." % String(clearing.get("reason", "remaining necromancer minions")).replace("_", " "),
					[{"id": "continue", "label": "Understood.", "text": ""}]
				)
			}
		"abandoned_house_enter":
			return {"handled": true, "ok": true, "action": "begin_encounter"}
	return {"handled": false}


static func _dialogue(speaker: String, body: String, choices: Array = [{"id": "continue", "label": "Continue", "text": ""}]) -> Dictionary:
	return {"speaker": speaker, "text": body, "choices": choices}
