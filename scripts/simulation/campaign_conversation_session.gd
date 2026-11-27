class_name CampaignConversationSession
extends RefCounted
## State machine for one blocking, player-facing campaign conversation.
## Player- and NPC-initiated conversations use the same session and choice path;
## authored content and campaign effects remain in their domain services.

signal prompt_changed(prompt: Dictionary)
signal choice_selected(choice: Dictionary, conversation_id: String)
signal finished(conversation_id: String, reason: String)

const INITIATION_SOURCES: Array[String] = ["player", "npc"]

var active: bool = false
var conversation_id: String = ""
var initiation_source: String = ""
var current_prompt: Dictionary = {}
var revision: int = 0


func start(
	requested_conversation_id: String,
	prompt: Dictionary,
	source: String
) -> Dictionary:
	if active:
		return {"ok": false, "reason": "conversation_already_active"}
	var clean_id := requested_conversation_id.strip_edges()
	if clean_id.is_empty():
		return {"ok": false, "reason": "missing_conversation_id"}
	var clean_source := source.strip_edges().to_lower()
	if not INITIATION_SOURCES.has(clean_source):
		return {"ok": false, "reason": "invalid_initiation_source"}
	var validation := _validate_prompt(prompt)
	if not bool(validation.get("ok", false)):
		return validation

	conversation_id = clean_id
	initiation_source = clean_source
	current_prompt = prompt.duplicate(true)
	active = true
	revision = 1
	prompt_changed.emit(current_prompt.duplicate(true))
	return {"ok": true, "snapshot": snapshot()}


func update_prompt(prompt: Dictionary) -> Dictionary:
	if not active:
		return {"ok": false, "reason": "conversation_not_active"}
	var validation := _validate_prompt(prompt)
	if not bool(validation.get("ok", false)):
		return validation
	current_prompt = prompt.duplicate(true)
	revision += 1
	prompt_changed.emit(current_prompt.duplicate(true))
	return {"ok": true, "snapshot": snapshot()}


func choose(choice_id: String) -> Dictionary:
	if not active:
		return {"ok": false, "reason": "conversation_not_active"}
	var requested_id := choice_id.strip_edges()
	if requested_id.is_empty():
		return {"ok": false, "reason": "missing_choice_id"}
	for choice_value in current_prompt.get("choices", []):
		var choice: Dictionary = choice_value
		if String(choice.get("id", "")) != requested_id:
			continue
		if not bool(choice.get("available", true)):
			return {
				"ok": false,
				"reason": "choice_unavailable",
				"unavailable_reason": String(choice.get("unavailable_reason", "Not available yet."))
			}
		var selected := choice.duplicate(true)
		choice_selected.emit(selected.duplicate(true), conversation_id)
		if bool(selected.get("ends_conversation", false)):
			finish("choice_selected")
		return {"ok": true, "choice": selected, "snapshot": snapshot()}
	return {"ok": false, "reason": "unknown_choice"}


func cancel() -> Dictionary:
	return finish("cancelled")


func finish(reason: String = "completed") -> Dictionary:
	if not active:
		return {"ok": false, "reason": "conversation_not_active"}
	var finished_id := conversation_id
	var finished_reason := reason.strip_edges()
	if finished_reason.is_empty():
		finished_reason = "completed"
	active = false
	conversation_id = ""
	initiation_source = ""
	current_prompt.clear()
	revision = 0
	finished.emit(finished_id, finished_reason)
	return {"ok": true, "conversation_id": finished_id, "reason": finished_reason}


func snapshot() -> Dictionary:
	return {
		"active": active,
		"conversation_id": conversation_id,
		"initiation_source": initiation_source,
		"revision": revision,
		"prompt": current_prompt.duplicate(true)
	}


func _validate_prompt(prompt: Dictionary) -> Dictionary:
	var speaker := String(prompt.get("speaker", "")).strip_edges()
	if speaker.is_empty():
		return {"ok": false, "reason": "missing_speaker"}
	var body := String(prompt.get("text", "")).strip_edges()
	var context := String(prompt.get("context", "")).strip_edges()
	if body.is_empty() and context.is_empty():
		return {"ok": false, "reason": "missing_dialogue_and_context"}
	var choices_value: Variant = prompt.get("choices", null)
	if not choices_value is Array or choices_value.is_empty():
		return {"ok": false, "reason": "missing_choices"}
	var seen_ids: Dictionary = {}
	var available_count := 0
	for choice_value in choices_value:
		if not choice_value is Dictionary:
			return {"ok": false, "reason": "invalid_choice"}
		var choice: Dictionary = choice_value
		var choice_id := String(choice.get("id", "")).strip_edges()
		var label := String(choice.get("label", "")).strip_edges()
		if choice_id.is_empty() or label.is_empty() or seen_ids.has(choice_id):
			return {"ok": false, "reason": "invalid_or_duplicate_choice"}
		seen_ids[choice_id] = true
		if bool(choice.get("available", true)):
			available_count += 1
	if available_count == 0:
		return {"ok": false, "reason": "no_available_choices"}
	return {"ok": true}
