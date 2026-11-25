extends SceneTree

const SOURCE_DIALOGUE = preload("res://scripts/simulation/source_campaign_npc_dialogue.gd")

func _initialize() -> void:
	var yvette := SOURCE_DIALOGUE.greeting("yvette_marlow", "Yvette Marlow")
	_check(String(yvette.get("text", "")).contains("Tomas"), "Yvette should retain her source-authored story about her son in the border levy.")
	_check(_has_choice(yvette, "source_yvette_letter"), "Yvette should let the player ask about the letter.")

	var hendra := SOURCE_DIALOGUE.greeting("hendra_wells", "Hendra Wells")
	_check(String(hendra.get("text", "")).contains("Tam"), "Hendra should introduce the missing-boy story.")
	_check(not _choice_available(hendra, "source_hendra_look"), "Do not offer an action for the unported Missing Boy quest.")

	var rowan := SOURCE_DIALOGUE.greeting("rowan_fletcher", "Rowan Fletcher", "hunter", {"hollowmere_security":20.0})
	_check(String(rowan.get("text", "")).contains("rough stretch"), "The hunter should react to low Hollowmere security.")
	_check(_has_choice(rowan, "source_hunter_news"), "The hunter should retain the source road-rumour topic.")
	_check(not _choice_available(rowan, "source_hunter_sell"), "Do not offer the unported hunter trade action.")

	var marta := SOURCE_DIALOGUE.greeting("marta_wynfield", "Elder Marta Wynfield", "elder", {"player_race":"orc"})
	_check(String(marta.get("text", "")).contains("greenskin"), "Marta should recognise the source's greenskin-specific reaction.")
	_check(not _choice_available(marta, "source_marta_prove"), "Do not start the unported diplomacy quest.")

	var original := {"speaker":"Yvette Marlow","text":"A Silverhart-added line.","choices":[{"id":"local","label":"Local topic","text":"Local response."}]}
	var merged := SOURCE_DIALOGUE.merge_with_existing(original, yvette)
	_check(String(merged.get("text", "")).contains("Tomas"), "Source-preferred dialogue should remain the opening line.")
	_check(_has_choice(merged, "silverhart_existing_greeting"), "The merge should preserve the target's existing greeting as a choice.")

	var merchant_a := SOURCE_DIALOGUE.generic_greeting("merchant_01", "Merchant One", "merchant")
	var merchant_b := SOURCE_DIALOGUE.generic_greeting("merchant_01", "Merchant One", "merchant")
	var guard := SOURCE_DIALOGUE.generic_greeting("guard_01", "Guard One", "guard")
	_check(merchant_a == merchant_b, "Procedural NPC dialogue should be stable for the same character.")
	_check(String(guard.get("text", "")).contains("road") or String(guard.get("text", "")).contains("watch") or String(guard.get("text", "")).contains("gate") or String(guard.get("text", "")).contains("boots"), "Guard roles should receive occupation-appropriate dialogue.")
	_check(String(merchant_a.get("text", "")).contains("Caravan") or String(merchant_a.get("text", "")).contains("pack") or String(merchant_a.get("text", "")).contains("stock") or String(merchant_a.get("text", "")).contains("toll"), "Merchant roles should receive trade-related dialogue.")

	print("Source campaign NPC dialogue tests passed.")
	quit(0)


func _has_choice(conversation: Dictionary, choice_id: String) -> bool:
	for choice_value in conversation.get("choices", []):
		var choice: Dictionary = choice_value
		if String(choice.get("id", "")) == choice_id:
			return true
	return false


func _choice_available(conversation: Dictionary, choice_id: String) -> bool:
	for choice_value in conversation.get("choices", []):
		var choice: Dictionary = choice_value
		if String(choice.get("id", "")) == choice_id:
			return bool(choice.get("available", true))
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
