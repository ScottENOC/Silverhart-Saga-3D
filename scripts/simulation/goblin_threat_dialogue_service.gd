class_name GoblinThreatDialogueService
extends RefCounted
## Dialogue and choice adapter for the Skarn-tooth camp. Quest effects are
## delegated to GoblinThreatCampaignRuntimeService, never location scripts.

const CONTENT_SCRIPT = preload("res://scripts/simulation/goblin_threat_campaign_content.gd")
const FOLLOWUP_SCRIPT = preload("res://scripts/simulation/goblin_threat_followup_content.gd")
const RUNTIME_SERVICE = preload("res://scripts/simulation/goblin_threat_campaign_runtime_service.gd")


static func handles_npc(npc_id: String) -> bool:
	return npc_id in [
		"chief_skarnub",
		"nix_sharpear",
		"ser_aldric_thorne",
		"goblin_trader",
		"grondle"
	]


static func handles_choice(choice_id: String) -> bool:
	return choice_id.begins_with("skarnub_") or choice_id.begins_with("nix_") or choice_id.begins_with("aldric_") or choice_id.begins_with("grondle_")


static func dialogue_for_npc(
	simulation: WorldSimulation,
	npc_id: String,
	relationships: PersistentCharacterRelationshipState
) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"ok": false, "reason": "missing_simulation"}
	var journal := simulation.campaign_journal
	match npc_id:
		"chief_skarnub":
			var quest := journal.quest_state(CONTENT_SCRIPT.QUEST_ID)
			var context := {
				"goblin_standing": journal.faction_standing("goblin_tribe"),
				"player_gold": simulation.get_character(simulation.player_character_id).gold if simulation.get_character(simulation.player_character_id) != null else 0,
				"quest_resolution": String(quest.get("decisions", {}).get("resolution", "")),
				"goblin_scout_note_read": bool(journal.world_campaign_flag("goblin_scout_note_read", false)),
				"mine_raid_started": bool(journal.world_campaign_flag("goblin_mine_raid_started", false)),
				"mine_raid_completed": bool(journal.world_campaign_flag("goblin_mine_raid_completed", false)),
				"greenskin_spy_started": bool(journal.world_campaign_flag("greenskin_spy_started", false)),
				"greenskin_spy_completed": bool(journal.world_campaign_flag("greenskin_spy_completed", false))
			}
			return CONTENT_SCRIPT.new().chief_greeting(relationships, context)
		"nix_sharpear":
			return RUNTIME_SERVICE.nix_greeting(simulation)
		"ser_aldric_thorne":
			return RUNTIME_SERVICE.aldric_captive_greeting(simulation)
		"goblin_trader", "grondle":
			return RUNTIME_SERVICE.grondle_greeting(simulation)
	return {"ok": false, "reason": "unsupported_goblin_npc"}


static func select_choice(
	simulation: WorldSimulation,
	npc_id: String,
	choice_id: String,
	relationships: PersistentCharacterRelationshipState,
	scene_tree: SceneTree = null,
	local_actor_by_id: Dictionary = {}
) -> Dictionary:
	if simulation == null or simulation.campaign_journal == null:
		return {"ok": false, "handled": true, "reason": "missing_simulation"}
	if npc_id.is_empty():
		if choice_id.begins_with("skarnub_"):
			npc_id = "chief_skarnub"
		elif choice_id.begins_with("nix_"):
			npc_id = "nix_sharpear"
		elif choice_id.begins_with("aldric_"):
			npc_id = "ser_aldric_thorne"
		elif choice_id.begins_with("grondle_"):
			npc_id = "grondle"
	if not handles_npc(npc_id):
		return {"ok": false, "handled": false}
	if choice_id in ["skarnub_leave", "nix_leave", "aldric_leave", "grondle_leave"]:
		return {"ok": true, "handled": true, "closed": true}

	var result: Dictionary = {}
	if npc_id == "chief_skarnub":
		if choice_id == "skarnub_give_gift":
			result = RUNTIME_SERVICE.give_chief_gift(simulation, relationships)
			if bool(result.get("ok", false)):
				result = {
					"ok": true,
					"speaker": "Chief Skarnub",
					"text": String(result.get("text", "The chief accepts your gift.")),
					"choices": [{"id": "continue", "label": "You're welcome."}]
				}
		elif choice_id == "skarnub_offer_favour":
			result = RUNTIME_SERVICE.begin_favour_negotiation(simulation)
		elif choice_id == "skarnub_offer_favours":
			result = {
				"ok": true,
				"speaker": "Chief Skarnub",
				"text": "Three jobs, then. Pick the one you mean to do.",
				"choices": CONTENT_SCRIPT.new().favour_options(simulation.campaign_journal.faction_standing("goblin_tribe"))
			}
		elif choice_id == "skarnub_start_mine_raid":
			result = RUNTIME_SERVICE.start_mine_raid(simulation)
			if bool(result.get("ok", false)):
				result = {"ok":true,"speaker":"Chief Skarnub","text":"Quest started: A Favor for the Tribe. The mine lies down the west road. Come back when you're ready to lead the raid.","choices":[{"id":"continue","label":"I'll return."}]}
		elif choice_id == "skarnub_resolve_mine_raid":
			result = RUNTIME_SERVICE.resolve_mine_raid(simulation)
		elif choice_id == "skarnub_start_spy":
			result = RUNTIME_SERVICE.start_greenskin_spy(simulation)
			if bool(result.get("ok", false)):
				result = {"ok":true,"speaker":"Chief Skarnub","text":"Quest started: A Hand on the Inside. The warband is gathering near Northwatch. Find a way to help them bring down the fort.","choices":[{"id":"continue","label":"I'll head east."}]}
		elif choice_id == "skarnub_spy_status":
			result = {"ok":true,"speaker":"Chief Skarnub","text":"Northwatch still stands. Get in there and help our warband bring it down.","choices":[{"id":"continue","label":"On it."}]}
		elif choice_id == "skarnub_offer_diplomacy":
			result = RUNTIME_SERVICE.resolve_threat(simulation, "goblin_diplomacy", relationships, scene_tree, local_actor_by_id)
		elif choice_id == "skarnub_offer_alliance":
			result = RUNTIME_SERVICE.resolve_threat(simulation, "goblin_alliance", relationships, scene_tree, local_actor_by_id)
		elif choice_id.begins_with("skarnub_favour_"):
			var favour := choice_id.trim_prefix("skarnub_favour_")
			result = RUNTIME_SERVICE.resolve_favour(simulation, favour, scene_tree, local_actor_by_id)
		elif choice_id == "skarnub_read_chief":
			result = CONTENT_SCRIPT.new().read_chief(relationships)
		elif choice_id == "skarnub_threaten":
			result = {
				"ok": true,
				"speaker": "Chief Skarnub",
				"text": "Skarnub bares his teeth. The camp is on edge; a fight here would turn the whole tribe against you.",
				"choices": [{"id": "skarnub_leave", "label": "Stand down."}]
			}
		else:
			return {"ok": false, "handled": true, "reason": "unknown_chief_choice"}
	elif npc_id == "nix_sharpear":
		if choice_id == "nix_ask_why":
			result = RUNTIME_SERVICE.nix_patron_response("why")
		elif choice_id == "nix_ask_who":
			result = RUNTIME_SERVICE.nix_patron_response("who")
		elif choice_id == "nix_resolve_succession":
			result = RUNTIME_SERVICE.resolve_threat(simulation, "stealth_succession", relationships, scene_tree, local_actor_by_id)
		elif choice_id == "nix_recruit":
			result = RUNTIME_SERVICE.recruit_nix(simulation)
			if bool(result.get("ok", false)):
				result = {
					"ok": true,
					"speaker": "Nix Sharpear",
					"text": "Nix shoulders his pack and falls in beside you. He looks relieved to be leaving the watch behind.",
					"choices": [{"id": "continue", "label": "Let's go."}]
				}
		else:
			return {"ok": false, "handled": true, "reason": "unknown_nix_choice"}
	elif npc_id == "ser_aldric_thorne":
		if choice_id == "aldric_free":
			result = RUNTIME_SERVICE.rescue_aldric(simulation, scene_tree, local_actor_by_id)
			if bool(result.get("ok", false)):
				result = {
					"ok": true,
					"speaker": "Ser Aldric Thorne",
					"text": "The ropes fall away. Aldric works feeling back into his wrists, then steadies himself. \"I owe you my life. Let us deal with the goblins, and then we can speak of the road ahead.\"",
					"choices": [{"id": "continue", "label": "We'll talk soon."}]
				}
		else:
			return {"ok": false, "handled": true, "reason": "unknown_aldric_choice"}
	elif npc_id in ["goblin_trader", "grondle"]:
		if choice_id == "grondle_trade":
			return {
				"ok": true,
				"handled": true,
				"open_shop": true,
				"speaker": "Grondle",
				"item_ids": FOLLOWUP_SCRIPT.GRONDLE_STOCK.duplicate()
			}
		return {"ok": false, "handled": true, "reason": "unknown_trader_choice"}

	if not bool(result.get("ok", false)):
		var reason := String(result.get("reason", "campaign_action_failed")).replace("_", " ")
		return {
			"ok": true,
			"handled": true,
			"speaker": _speaker_for(npc_id),
			"text": "That cannot be done just now: %s." % reason.capitalize(),
			"choices": [{"id": "continue", "label": "Understood."}]
		}

	if result.has("choices"):
		result["handled"] = true
		return result

	var effects: Dictionary = result.get("effects", {})
	var body := String(effects.get("message", result.get("text", "The decision is recorded.")))
	if result.has("world_effects"):
		var reward_xp := int(result.get("world_effects", {}).get("experience_awarded", 0))
		var reward_gold := int(result.get("world_effects", {}).get("gold_delta", 0))
		if reward_xp != 0:
			body += "\n\n%d experience gained." % reward_xp
		if reward_gold != 0:
			body += "\n%d gold." % reward_gold
	return {
		"ok": true,
		"handled": true,
		"speaker": _speaker_for(npc_id),
		"text": body,
		"choices": [{"id": "continue", "label": "Continue."}]
	}


static func _speaker_for(npc_id: String) -> String:
	match npc_id:
		"chief_skarnub":
			return "Chief Skarnub"
		"nix_sharpear":
			return "Nix Sharpear"
		"ser_aldric_thorne":
			return "Ser Aldric Thorne"
		_:
			return "Grondle"
