class_name CampaignDwellingDialogueService
extends RefCounted
## Resolves dwelling and furniture-shop dialogue choices without depending on
## scene nodes. The world adapter performs the requested presentation refresh.

const DWELLING_WORLD_SERVICE = preload("res://scripts/world/campaign_dwelling_world_service.gd")


static func resolve_dialogue_choice(
	simulation: WorldSimulation,
	choice: Dictionary,
	active_character_id: String = ""
) -> Dictionary:
	if simulation == null:
		return {"handled": false, "ok": false, "reason": "missing_simulation"}
	var choice_id := String(choice.get("id", ""))
	if choice_id.begins_with("furniture_buy:"):
		var item_id := choice_id.trim_prefix("furniture_buy:")
		var purchase := simulation.buy_dwelling_furniture(item_id, 1, active_character_id)
		var inspection := DWELLING_WORLD_SERVICE.furniture_shop_inspection(
			simulation.get_character(simulation.player_character_id)
		)
		var item_name := String(CampaignFurnitureCatalog.definition(item_id).get("name", item_id))
		var prefix := "%s purchased. The piece is now in your furniture inventory." % item_name if bool(purchase.get("ok", false)) else "The purchase could not be completed: %s." % String(purchase.get("reason", "purchase_failed")).replace("_", " ")
		return {
			"handled": true,
			"ok": bool(purchase.get("ok", false)),
			"dialogue": {
				"speaker": String(inspection.get("speaker", "Furniture Shop")),
				"text": "%s\n\n%s" % [prefix, String(inspection.get("text", ""))],
				"choices": inspection.get("choices", [])
			}
		}
	if choice_id.begins_with("dwelling_action:"):
		var parts := choice_id.split(":")
		if parts.size() != 4:
			return _dialogue_result(
				false,
				"Property",
				"That property action is invalid."
			)
		var result := simulation.claim_dwelling(
			String(parts[1]),
			String(parts[2]),
			String(parts[3]),
			active_character_id
		)
		if bool(result.get("ok", false)):
			var dwelling_name := String(result.get("dwelling_id", "Property")).replace("_", " ")
			var layout_id := String(result.get("layout_id", ""))
			return {
				"handled": true,
				"ok": true,
				"refresh_dwelling_world": true,
				"dialogue": {
					"speaker": "Property",
					"text": "The work is complete. %s is now yours.\nLayout identity: %s." % [dwelling_name.capitalize(), layout_id],
					"choices": [{"id": "continue", "label": "Continue", "text": ""}]
				}
			}
		return _dialogue_result(
			false,
			"Property",
			"That work cannot be completed: %s." % String(result.get("reason", "requirements_not_met")).replace("_", " ")
		)
	return {"handled": false}


static func _dialogue_result(ok: bool, speaker: String, body: String) -> Dictionary:
	return {
		"handled": true,
		"ok": ok,
		"dialogue": {
			"speaker": speaker,
			"text": body,
			"choices": [{"id": "continue", "label": "Understood.", "text": ""}]
		}
	}
