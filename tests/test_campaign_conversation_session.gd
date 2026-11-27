extends SceneTree

const SESSION = preload("res://scripts/simulation/campaign_conversation_session.gd")

var _failures: int = 0
var _prompt_changes: int = 0
var _choices_selected: int = 0
var _finished_reason: String = ""


func _initialize() -> void:
	_test_player_initiated_session()
	_test_npc_initiated_session_uses_same_flow()
	_test_invalid_prompts_and_choices()
	if _failures > 0:
		push_error("%d campaign conversation session assertion(s) failed." % _failures)
		quit(1)
		return
	print("Campaign conversation session tests passed.")
	quit(0)


func _check(condition: bool, message: String = "Assertion failed") -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _prompt(speaker: String = "Elder Marta Wynfield") -> Dictionary:
	return {
		"speaker_id": "elder_marta",
		"speaker": speaker,
		"context": "The old woman studies you over the rim of her spectacles.",
		"text": "Welcome, traveller. What brings you to Hollowmere?",
		"portrait_id": "elder_marta",
		"choices": [
			{"id": "ask_help", "label": "Need any help around the village?"},
			{"id": "leave", "label": "Goodbye.", "ends_conversation": true}
		]
	}


func _test_player_initiated_session() -> void:
	var session := SESSION.new()
	session.prompt_changed.connect(_on_prompt_changed)
	session.choice_selected.connect(_on_choice_selected)
	session.finished.connect(_on_finished)
	var started := session.start("elder_marta_greeting", _prompt(), "player")
	_check(bool(started.get("ok", false)))
	_check(session.active)
	_check(session.initiation_source == "player")
	_check(_prompt_changes == 1)
	_check(int(session.snapshot().get("revision", 0)) == 1)
	_check(String(session.snapshot().get("prompt", {}).get("speaker_id", "")) == "elder_marta")

	var unavailable_prompt := _prompt()
	unavailable_prompt["choices"][0]["available"] = false
	unavailable_prompt["choices"][0]["unavailable_reason"] = "She is busy."
	_check(bool(session.update_prompt(unavailable_prompt).get("ok", false)))
	var blocked := session.choose("ask_help")
	_check(not bool(blocked.get("ok", true)))
	_check(String(blocked.get("reason", "")) == "choice_unavailable")
	_check(_choices_selected == 0)

	var next_prompt := _prompt("Elder Marta Wynfield")
	next_prompt["text"] = "A small kindness would mean a great deal."
	_check(bool(session.update_prompt(next_prompt).get("ok", false)))
	_check(int(session.snapshot().get("revision", 0)) == 3)
	var selected := session.choose("ask_help")
	_check(bool(selected.get("ok", false)))
	_check(_choices_selected == 1)
	_check(session.active, "A normal choice leaves the session active for its domain resolver")
	_check(String(selected.get("choice", {}).get("id", "")) == "ask_help")

	var ended := session.choose("leave")
	_check(bool(ended.get("ok", false)))
	_check(not session.active, "An explicit end-conversation choice closes the session")
	_check(_finished_reason == "choice_selected")
	_check(_prompt_changes == 3)


func _test_npc_initiated_session_uses_same_flow() -> void:
	var session := SESSION.new()
	var started := session.start("garrick_checks_on_player", _prompt("Garrick Holt"), "npc")
	_check(bool(started.get("ok", false)))
	_check(session.initiation_source == "npc")
	_check(String(session.snapshot().get("prompt", {}).get("speaker", "")) == "Garrick Holt")
	_check(bool(session.choose("ask_help").get("ok", false)))
	_check(session.active)
	_check(bool(session.cancel().get("ok", false)))
	_check(not session.active)


func _test_invalid_prompts_and_choices() -> void:
	var session := SESSION.new()
	var valid := _prompt()
	_check(String(session.start("", valid, "player").get("reason", "")) == "missing_conversation_id")
	_check(String(session.start("bad_source", valid, "system").get("reason", "")) == "invalid_initiation_source")
	var missing_speaker := valid.duplicate(true)
	missing_speaker["speaker"] = ""
	_check(String(session.start("missing_speaker", missing_speaker, "player").get("reason", "")) == "missing_speaker")
	var missing_body := valid.duplicate(true)
	missing_body["text"] = ""
	missing_body["context"] = ""
	_check(String(session.start("missing_body", missing_body, "player").get("reason", "")) == "missing_dialogue_and_context")
	var no_choices := valid.duplicate(true)
	no_choices["choices"] = []
	_check(String(session.start("no_choices", no_choices, "player").get("reason", "")) == "missing_choices")
	var duplicate_choices := valid.duplicate(true)
	duplicate_choices["choices"].append({"id": "leave", "label": "A duplicate."})
	_check(String(session.start("duplicate", duplicate_choices, "player").get("reason", "")) == "invalid_or_duplicate_choice")
	var all_disabled := valid.duplicate(true)
	for choice in all_disabled["choices"]:
		choice["available"] = false
	_check(String(session.start("disabled", all_disabled, "player").get("reason", "")) == "no_available_choices")
	_check(String(session.choose("missing").get("reason", "")) == "conversation_not_active")


func _on_prompt_changed(_prompt: Dictionary) -> void:
	_prompt_changes += 1


func _on_choice_selected(_choice: Dictionary, _conversation_id: String) -> void:
	_choices_selected += 1


func _on_finished(_conversation_id: String, reason: String) -> void:
	_finished_reason = reason
