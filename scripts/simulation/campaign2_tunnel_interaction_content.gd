class_name Campaign2TunnelInteractionContent
extends RefCounted
## Presentation-neutral dialogue descriptors for the Campaign 2 tunnel network.
## The world adapter displays these through the shared CampaignDialoguePanel;
## traversal and discovery state remain owned by the multi-story runtime.

static func entry_prompt(node_id: String) -> Dictionary:
	if node_id.strip_edges().is_empty():
		return {}
	return {
		"title": "Hidden Passage",
		"body": "A concealed stair descends into the Guild's old tunnel network.",
		"choices": [
			{"id": "tunnel_enter:" + node_id, "label": "Descend into the tunnels.", "text": ""},
			{"id": "continue", "label": "Leave it for now.", "text": ""}
		]
	}


static func secret_search_prompt(secret_id: String) -> Dictionary:
	if secret_id.strip_edges().is_empty():
		return {}
	return {
		"title": "Hidden Passage",
		"body": "A section of wall looks slightly out of place. You could examine it more closely.",
		"choices": [
			{"id": "tunnel_search:" + secret_id, "label": "Search the wall.", "text": ""},
			{"id": "continue", "label": "Leave it for now.", "text": ""}
		]
	}


static func junction_prompt(destinations: Array[Dictionary], can_return: bool, node_id: String) -> Dictionary:
	var choices: Array[Dictionary] = []
	for destination in destinations:
		var destination_id := String(destination.get("id", ""))
		if destination_id.is_empty():
			continue
		choices.append({
			"id": "tunnel_travel:" + destination_id,
			"label": "Go to %s." % String(destination.get("label", "the other passage")),
			"text": ""
		})
	if can_return and not node_id.is_empty():
		choices.append({
			"id": "tunnel_return:" + node_id,
			"label": "Return to the surface passage.",
			"text": ""
		})
	choices.append({"id": "continue", "label": "Stay at the junction.", "text": ""})
	return {
		"title": "Tunnel Junction",
		"body": "Old brick, worn smooth by years of foot traffic. Passages lead off in more than one direction.",
		"choices": choices
	}


static func search_result(result: Dictionary) -> Dictionary:
	if not bool(result.get("ok", false)):
		return _continue_prompt("Hidden Passage", "You cannot search that section of wall right now.")
	if not bool(result.get("found", false)):
		return _continue_prompt("Hidden Passage", "Just old stone and plaster here, as far as you can tell. It might be worth another look.")
	return {
		"title": "Hidden Passage",
		"body": "A section of wall gives way at your touch — a hidden passage, dug some time ago and never sealed.",
		"choices": [{"id": "continue", "label": "Continue", "text": ""}],
		"set_chancellor_tunnel_discovered": String(result.get("node_id", "")) == "palace"
	}


static func missing_passage_prompt() -> Dictionary:
	return _continue_prompt("Tunnel Junction", "That passage cannot be found.")


static func destination_load_failed_prompt() -> Dictionary:
	return _continue_prompt("Tunnel Junction", "The destination could not be loaded.")


static func travel_failed_prompt(reason: String) -> Dictionary:
	var readable_reason := reason.replace("_", " ")
	if readable_reason.is_empty():
		readable_reason = "travel failed"
	return _continue_prompt("Tunnel Junction", "The passage cannot be used: %s." % readable_reason)


static func arrival_prompt(action: String, destination_label: String) -> Dictionary:
	var body := "You arrive at %s." % destination_label
	if action == "tunnel_return":
		body = "You emerge through the concealed surface passage."
	return _continue_prompt("Tunnel Junction", body)


static func _continue_prompt(title: String, body: String) -> Dictionary:
	return {
		"title": title,
		"body": body,
		"choices": [{"id": "continue", "label": "Continue", "text": ""}]
	}
