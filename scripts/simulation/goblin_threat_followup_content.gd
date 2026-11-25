class_name GoblinThreatFollowupContent
extends RefCounted
## Source-authored follow-up dialogue for the Skarn-tooth camp.
## It returns campaign data and consequence descriptors; actors, inventory,
## world flags and party membership remain owned by the campaign runtime.

const ALDRIC_ID := "ser_aldric_thorne"
const NIX_ID := "nix_sharpear"
const GRONDLE_STOCK := ["axe", "spear", "club", "medium_armor", "wooden_shield", "torch", "potion_health"]

const NIX_ASSASSINATION_LINE := "You... you killed him. Skarnub was going to get us all killed clinging to this ground anyway. Truth told, I've wanted to move on for moons now. Let's not make enemies over this — we'll go, quietly, if you let us."
const NIX_ALLIANCE_LINE := "We're not going anywhere now — you saw to that. Skarnub speaks for us, but I never much liked sitting still watching a road. You're headed for more trouble than this camp's seen in years. Room for one more?"
const ALDRIC_CAPTIVE_LINE := "Please... cut me loose. I came out here to deal with this goblin problem myself, and, well — here we are. Whatever you decide to do about them, I intend to see them gone from this land. I'll owe you a debt either way."
const SCOUT_NOTE_TEXT := "A scrap of oilcloth, tucked inside the hut — not goblin make, and not goblin script. A crude map marks Hollowmere and the roads around it with small tally marks, dated across several months. At the bottom, in a different hand: \"Count their walls. Count their swords. Report back before the frost.\""


func nix_greeting(context: Dictionary) -> Dictionary:
	var resolution := String(context.get("quest_resolution", ""))
	if bool(context.get("chief_assassinated", false)) and resolution.is_empty():
		return _conversation("Nix Sharpear", NIX_ASSASSINATION_LINE, [
			{"id":"nix_resolve_succession","label":"Take your people and go.","kind":"goblin_stealth_succession"},
			{"id":"nix_leave","label":"...","kind":"leave"}
		])
	if resolution == "goblin_alliance":
		if bool(context.get("nix_recruited", false)):
			return _conversation("Nix Sharpear", "Still watching your back. What is it?", [
				{"id":"nix_leave","label":"Nothing, carry on.","kind":"leave"}
			])
		return _conversation("Nix Sharpear", NIX_ALLIANCE_LINE, [
			{"id":"nix_recruit","label":"Come with me.","kind":"recruit_goblin_companion"},
			{"id":"nix_leave","label":"Not yet.","kind":"leave"}
		])
	if not resolution.is_empty():
		return _conversation("Nix Sharpear", "We're already gone from here, or will be soon enough.", [
			{"id":"nix_leave","label":"Good.","kind":"leave"}
		])
	return _conversation("Nix Sharpear", "Something you need? Speak quick, this isn't a place for wandering humans.", [
		{"id":"nix_ask_why","label":"Why are you really this close to the village?","kind":"nix_patron_question"},
		{"id":"nix_leave","label":"Just passing through.","kind":"leave"}
	])


func nix_patron_response(question: String = "why") -> Dictionary:
	if question == "who":
		return _conversation("Nix Sharpear", "Someone with a lot more banners than we've got. That's all you're getting from me.", [
			{"id":"nix_leave","label":"...","kind":"leave"}
		])
	return _conversation("Nix Sharpear", "You think Skarnub chose this ground? We were told to sit here, watch the roads, count what comes and goes. Somebody's paying close attention to your precious Hollowmere, and it isn't us. I've said too much — forget I spoke.", [
		{"id":"nix_ask_who","label":"Who told you to watch us?","kind":"nix_patron_identity"},
		{"id":"nix_leave","label":"...","kind":"leave"}
	])


func resolve_stealth_succession(journal: CampaignJournal) -> Dictionary:
	if journal == null:
		return {"ok":false,"reason":"missing_campaign_journal"}
	var content := GoblinThreatCampaignContent.new()
	return content.resolve_threat(journal, "stealth_succession")


func nix_recruitment(context: Dictionary) -> Dictionary:
	if String(context.get("quest_resolution", "")) != "goblin_alliance":
		return {"ok":false,"reason":"goblin_alliance_required"}
	if bool(context.get("nix_recruited", false)):
		return {"ok":false,"reason":"already_recruited"}
	return {
		"ok":true,
		"character":{
			"id":NIX_ID,
			"display_name":"Nix Sharpear",
			"race":"human",
			"body_variant":"male",
			"height_scale":0.90,
			"build_scale":0.84,
			"progression":{"race":"human","class_levels":["rogue"],"skill_picks":["dagger_hit","dagger_dmg","stealth_rogue","stealth_agility"]},
			"extra_inventory":["dagger","light_armor"],
			"equip_items":["dagger","light_armor"],
			"faction_id":"goblin_tribe",
			"dialogue_id":"companion_nix_sharpear",
			"starts_in_party":true
		},
		"effects":{"initial_attitude":60,"message":"Nix Sharpear joins your party, glad to be off road-watch."}
	}


func grondle_greeting(context: Dictionary) -> Dictionary:
	if String(context.get("quest_resolution", "")) != "goblin_alliance":
		return _conversation("Grondle", "Nothing for you here, human.", [
			{"id":"grondle_leave","label":"...","kind":"leave"}
		])
	return {
		"ok":true,
		"speaker":"Grondle",
		"text":"Ha! Ally's coin spends same as anyone's. Look, take, pay.",
		"choices":[
			{"id":"grondle_trade","label":"Let me see your wares.","kind":"open_shop","item_ids":GRONDLE_STOCK.duplicate()},
			{"id":"grondle_leave","label":"Just looking.","kind":"leave"}
		]
	}


func aldric_captive_greeting(context: Dictionary) -> Dictionary:
	if bool(context.get("aldric_recruited", false)):
		return {"ok":true,"already_rescued":true,"speaker":"Ser Aldric Thorne","text":"","choices":[]}
	if bool(context.get("aldric_rescued", false)):
		return _conversation("Ser Aldric Thorne", "You cut me loose. I will not forget that. Whatever happens with the goblins, I owe you a debt — and I would rather repay it at your side. Will you have me?", [
			{"id":"recruit:ser_aldric_thorne","label":"Join us.","kind":"recruit_companion"},
			{"id":"aldric_leave","label":"Not yet.","kind":"leave"}
		])
	return _conversation("Ser Aldric Thorne", ALDRIC_CAPTIVE_LINE, [
		{"id":"aldric_free","label":"I'll free you now.","kind":"rescue_aldric"},
		{"id":"aldric_leave","label":"Not yet.","kind":"leave"}
	])

func aldric_recruitment_profile() -> Dictionary:
	return {
		"id":ALDRIC_ID,
		"display_name":"Ser Aldric Thorne",
		"race":"human",
		"body_variant":"male",
		"progression":{"race":"human","class_levels":["fighter","cleric"],"skill_picks":["health","sword_hit","sword_dmg","sword_parry","learn_heal"]},
		"extra_inventory":["wooden_shield"],
		"equip_items":["wooden_shield"],
		"dialogue_id":"companion_ser_aldric_thorne",
		"starts_in_party":true,
		"effects":{"initial_attitude":60,"message":"Ser Aldric Thorne joins your party, freed at last."}
	}


func read_scout_note(context: Dictionary) -> Dictionary:
	if bool(context.get("goblin_scout_note_read", false)):
		return {"ok":true,"already_read":true,"text":SCOUT_NOTE_TEXT,"effects":{}}
	return {
		"ok":true,
		"already_read":false,
		"text":SCOUT_NOTE_TEXT,
		"effects":{"set_world_flag":{"goblin_scout_note_read":true},"region_security":{"hollowmere":-3}}
	}


func _conversation(speaker: String, body: String, choices: Array[Dictionary]) -> Dictionary:
	return {"ok":true,"speaker":speaker,"text":body,"choices":choices.duplicate(true)}
