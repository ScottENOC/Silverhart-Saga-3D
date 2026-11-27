extends SceneTree

const CONTENT := preload("res://scripts/simulation/campaign2_tunnel_interaction_content.gd")

var _failures := 0

func _initialize() -> void:
	var entry := CONTENT.entry_prompt("palace")
	_check(String(entry.get("title", "")) == "Hidden Passage", "Entry prompt should use the shared hidden-passage title.")
	_check(_choice_exists(entry, "tunnel_enter:palace"), "Entry prompt should offer the matching tunnel node.")
	_check(_choice_exists(entry, "continue"), "Entry prompt should allow leaving the passage.")

	var secret := CONTENT.secret_search_prompt("palace_secret_passage")
	_check(_choice_exists(secret, "tunnel_search:palace_secret_passage"), "Secret prompt should target its authored secret id.")

	var destinations: Array[Dictionary] = [
		{"id": "city", "label": "the city passage"},
		{"id": "wilderness", "label": "the sea-cave den"}
	]
	var junction := CONTENT.junction_prompt(destinations, true, "palace")
	_check(_choice_exists(junction, "tunnel_travel:city"), "Junction should offer the city destination.")
	_check(_choice_exists(junction, "tunnel_travel:wilderness"), "Junction should offer the wilderness destination.")
	_check(_choice_exists(junction, "tunnel_return:palace"), "Junction should offer return when the surface passage is discovered.")
	_check(_choice_exists(junction, "continue"), "Junction should allow the player to stay.")
	var undiscovered_return := CONTENT.junction_prompt(destinations, false, "palace")
	_check(not _choice_exists(undiscovered_return, "tunnel_return:palace"), "Undiscovered surface passage must not be offered.")

	var failed_search := CONTENT.search_result({"ok": false, "reason": "not_near_secret"})
	_check(String(failed_search.get("body", "")).contains("cannot search"), "Failed searches should explain why the wall cannot be searched.")
	var missed_search := CONTENT.search_result({"ok": true, "found": false})
	_check(String(missed_search.get("body", "")).contains("old stone"), "Unsuccessful searches should retain the retry hint.")
	var found_palace := CONTENT.search_result({"ok": true, "found": true, "node_id": "palace"})
	_check(bool(found_palace.get("set_chancellor_tunnel_discovered", false)), "Discovering the palace passage should raise its campaign flag.")
	var found_city := CONTENT.search_result({"ok": true, "found": true, "node_id": "city"})
	_check(not bool(found_city.get("set_chancellor_tunnel_discovered", false)), "Other passages must not raise the Chancellor flag.")

	var returned := CONTENT.arrival_prompt("tunnel_return", "the palace")
	_check(String(returned.get("body", "")).contains("emerge"), "Surface return should have its distinct arrival text.")
	var travelled := CONTENT.arrival_prompt("tunnel_travel", "the sea-cave den")
	_check(String(travelled.get("body", "")).contains("sea-cave den"), "Tunnel travel should name the destination.")
	_check(String(CONTENT.travel_failed_prompt("destination_unwalkable").get("body", "")).contains("destination unwalkable"), "Travel errors should be readable.")

	if _failures > 0:
		push_error("Campaign 2 tunnel interaction content tests failed: %d" % _failures)
		quit(1)
		return
	print("Campaign 2 tunnel interaction content tests passed.")
	quit(0)


func _choice_exists(prompt: Dictionary, choice_id: String) -> bool:
	for choice in prompt.get("choices", []):
		if String(choice.get("id", "")) == choice_id:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
