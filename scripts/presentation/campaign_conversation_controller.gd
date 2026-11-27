class_name CampaignConversationController
extends Node
## Bridges the shared conversation session to the existing dialogue panel.
## It presents prompts and forwards selected choices; campaign consequences
## remain with the owning campaign/domain service.

signal choice_selected(choice: Dictionary, conversation_id: String)
signal conversation_finished(conversation_id: String, reason: String)

var session: CampaignConversationSession
var dialogue_panel: CampaignDialoguePanel
var portrait_resolver: Callable = Callable()


func _ready() -> void:
	session = CampaignConversationSession.new()
	session.prompt_changed.connect(_on_prompt_changed)
	session.choice_selected.connect(_on_session_choice_selected)
	session.finished.connect(_on_session_finished)


func configure(
	panel: CampaignDialoguePanel,
	resolver: Callable = Callable()
) -> Dictionary:
	if panel == null or not is_instance_valid(panel):
		return {"ok": false, "reason": "missing_dialogue_panel"}
	if not panel.is_inside_tree():
		return {"ok": false, "reason": "dialogue_panel_not_in_scene_tree"}
	if dialogue_panel != null and is_instance_valid(dialogue_panel):
		if dialogue_panel.choice_selected.is_connected(_on_panel_choice_selected):
			dialogue_panel.choice_selected.disconnect(_on_panel_choice_selected)
	dialogue_panel = panel
	portrait_resolver = resolver
	if not dialogue_panel.choice_selected.is_connected(_on_panel_choice_selected):
		dialogue_panel.choice_selected.connect(_on_panel_choice_selected)
	return {"ok": true}


func start_conversation(
	conversation_id: String,
	prompt: Dictionary,
	initiation_source: String
) -> Dictionary:
	if dialogue_panel == null or not is_instance_valid(dialogue_panel):
		return {"ok": false, "reason": "dialogue_panel_not_configured"}
	return session.start(conversation_id, prompt, initiation_source)


func update_prompt(prompt: Dictionary) -> Dictionary:
	return session.update_prompt(prompt)


func select_choice(choice_id: String) -> Dictionary:
	return session.choose(choice_id)


func cancel_conversation() -> Dictionary:
	return session.cancel()


func finish_conversation(reason: String = "completed") -> Dictionary:
	return session.finish(reason)


func _on_prompt_changed(prompt: Dictionary) -> void:
	if dialogue_panel == null or not is_instance_valid(dialogue_panel):
		return
	var speaker := String(prompt.get("speaker", "")).strip_edges()
	var context := String(prompt.get("context", "")).strip_edges()
	var dialogue := String(prompt.get("text", "")).strip_edges()
	var body_parts := PackedStringArray()
	if not context.is_empty():
		body_parts.append(context)
	if not dialogue.is_empty():
		body_parts.append(dialogue)
	var body := "\n\n".join(body_parts)

	var choices: Array[Dictionary] = []
	for choice_value in prompt.get("choices", []):
		if choice_value is Dictionary:
			var choice: Dictionary = choice_value
			choices.append(choice.duplicate(true))

	var portrait_texture: Texture2D
	var speaker_actor: AraCharacterActor
	if portrait_resolver.is_valid():
		var portrait_value: Variant = portrait_resolver.call(String(prompt.get("speaker_id", "")))
		if portrait_value is AraCharacterActor:
			speaker_actor = portrait_value as AraCharacterActor
		elif portrait_value is Texture2D:
			portrait_texture = portrait_value as Texture2D

	dialogue_panel.present(
		speaker,
		body,
		choices,
		portrait_texture,
		speaker_actor,
		String(prompt.get("expression", "neutral"))
	)


func _on_panel_choice_selected(choice: Dictionary) -> void:
	select_choice(String(choice.get("id", "")))


func _on_session_choice_selected(choice: Dictionary, conversation_id: String) -> void:
	choice_selected.emit(choice.duplicate(true), conversation_id)


func _on_session_finished(conversation_id: String, reason: String) -> void:
	if dialogue_panel != null and is_instance_valid(dialogue_panel):
		dialogue_panel.dismiss()
	conversation_finished.emit(conversation_id, reason)
