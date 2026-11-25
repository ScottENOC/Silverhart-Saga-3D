class_name CampaignDwellingWorldService
extends RefCounted
## Source-anchored world access points for the campaign dwelling system.
## This registry owns location identity and interaction copy, not ownership,
## inventory, campaign progression or save state.

const SITES: Array[Dictionary] = [
	{
		"id": CampaignFurnitureCatalog.SHOP_ID,
		"name": CampaignFurnitureCatalog.SHOP_NAME,
		"hex": Vector2i(8, -496),
		"kind": "furniture_shop",
		"description": "A capital-city furniture merchant sells ready-made beds, storage, tables and workshop equipment."
	},
	{
		"id": "crossroads_plot",
		"name": "Surveyed cottage plot",
		"hex": Vector2i(13, 27),
		"dwelling_id": "crossroads_cottage",
		"description": "The surveyed plot lies just beyond Hollowmere's crossroads. A builder has marked out the ground for a small home.",
		"actions": ["build_crossroads_cottage", "upgrade_country_house"]
	},
	{
		"id": "abandoned_house",
		"name": "Abandoned roadside house",
		"hex": Vector2i(14, -176),
		"dwelling_id": "abandoned_house",
		"description": "A lonely house stands beside the north road. The old occupants are gone; three undead guardians still defend the rooms.",
		"actions": ["restore_abandoned_house"]
	},
	{
		"id": "silverhart_manor",
		"name": "Corstane townhouse",
		"hex": Vector2i(39, -502),
		"dwelling_id": "silverhart_manor",
		"description": "The Corstane family's townhouse stands empty in the Noble Quarter. The royal grant conveys ownership, not a habitable home; the roof and walls still need fortifying.",
		"actions": ["fortify_silverhart_manor"]
	}
]


static func site_definition(site_id: String) -> Dictionary:
	for site in SITES:
		if String(site.get("id", "")) == site_id:
			return site.duplicate(true)
	return {}


static func nearby_sites(hex: Vector2i, radius: int = 2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site in SITES:
		var site_hex: Vector2i = site.get("hex", Vector2i.ZERO)
		var distance := HexGrid.distance(hex, site_hex)
		if distance <= radius:
			var entry := site.duplicate(true)
			entry["distance"] = distance
			result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := int(a.get("distance", 999))
		var db := int(b.get("distance", 999))
		if da != db:
			return da < db
		return String(a.get("id", "")) < String(b.get("id", ""))
	)
	return result


static func inspection_for_site(
	dwelling_state: CampaignDwellingState,
	journal: CampaignJournal,
	player: CharacterState,
	site_id: String,
	remaining_guardians: int = 0
) -> Dictionary:
	var site := site_definition(site_id)
	if site.is_empty() or dwelling_state == null or journal == null:
		return {"ok": false, "reason": "unknown_site_or_missing_campaign_state"}
	if site_id == CampaignFurnitureCatalog.SHOP_ID:
		return furniture_shop_inspection(player)
	var dwelling_id := String(site.get("dwelling_id", ""))
	var profile := dwelling_state.camp_profile_for(dwelling_id)
	var lines: PackedStringArray = [String(site.get("description", ""))]
	if site_id == "silverhart_manor" and not bool(dwelling_state.owned.get("silverhart_manor", false)):
		lines.append("Royal grant: request the Corstane townhouse from Queen Seraphine at Silverhart Palace.")
		lines.append("Silverhart Kingdom reputation: %d / 60." % roundi(journal.faction_standing("silverhart_kingdom")))
	if bool(dwelling_state.owned.get(dwelling_id, false)):
		lines.append("Ownership: yours.")
		if bool(profile.get("is_sheltered", false)):
			lines.append("Building: structurally habitable.")
			lines.append("Indoor beds: %d. Layout: %s." % [
				int(profile.get("sleeping_capacity", 0)),
				String(profile.get("layout_id", "unassigned"))
			])
			if int(profile.get("sleeping_capacity", 0)) == 0:
				lines.append("The house is unfurnished. Buy or craft beds and other furniture to make use of the rooms.")
		else:
			lines.append("Status: owned, but structural repairs are still required.")
	else:
		lines.append("Ownership: not yet acquired.")

	var choices: Array[Dictionary] = []
	if site_id == "abandoned_house":
		var quest := journal.quest_state("abandoned_house_cleared")
		var quest_status := String(quest.get("status", ""))
		if quest_status.is_empty():
			choices.append({
				"id": "abandoned_house_investigate",
				"label": "Investigate the house",
				"text": ""
			})
		elif quest_status == "active" and remaining_guardians > 0:
			choices.append({
				"id": "abandoned_house_enter",
				"label": "Enter the house · %d guardians remain" % remaining_guardians,
				"text": ""
			})
		elif quest_status == "active" and remaining_guardians == 0:
			choices.append({
				"id": "abandoned_house_finalize",
				"label": "Confirm the house is clear",
				"text": ""
			})

	for action_id_value in site.get("actions", []):
		var action_id := String(action_id_value)
		var definition := dwelling_state.action_definition(action_id)
		if definition.is_empty():
			continue
		lines.append("")
		lines.append(String(definition.get("label", action_id)) + ":")
		var payment_methods: Array[String] = ["materials"]
		if int(definition.get("gold_alternative", -1)) >= 0:
			payment_methods.append("gold")
		var action_available := false
		for payment in payment_methods:
			var status := dwelling_state.evaluate_action(action_id, journal, player, payment, site_id)
			var payment_label := _payment_label(definition, payment)
			if bool(status.get("ok", false)):
				action_available = true
				choices.append({
					"id": "dwelling_action:%s:%s:%s" % [action_id, payment, site_id],
					"label": "%s · %s" % [String(definition.get("label", action_id)), payment_label],
					"text": ""
				})
			else:
				for requirement_value in status.get("requirements", []):
					var requirement: Dictionary = requirement_value
					if not bool(requirement.get("met", false)):
						lines.append("  • %s (%s)" % [payment_label, _requirement_text(requirement)])
		if action_available:
			lines.append("  Ready to proceed.")
	if choices.is_empty():
		choices.append({"id": "continue", "label": "Understood.", "text": ""})
	return {
		"ok": true,
		"speaker": String(site.get("name", "Property")),
		"text": "\n".join(lines),
		"choices": choices,
		"site_id": site_id
	}



static func furniture_shop_inspection(player: CharacterState) -> Dictionary:
	var choices: Array[Dictionary] = []
	for item in CampaignFurnitureCatalog.shop_catalogue():
		var item_id := String(item.get("id", ""))
		var item_name := String(item.get("name", item_id))
		var price := int(item.get("price", 0))
		choices.append({
			"id": "furniture_buy:" + item_id,
			"label": "Buy %s · %d gold" % [item_name, price],
			"text": ""
		})
	choices.append({"id": "continue", "label": "Leave the shop.", "text": ""})
	return {
		"ok": true,
		"speaker": CampaignFurnitureCatalog.SHOP_NAME,
		"text": "Beds, storage, dining furniture and workshop equipment. Ready-made pieces can be bought here; the same designs can also be crafted from materials at an owned dwelling. Your available gold: %d." % (player.gold if player != null else 0),
		"choices": choices,
		"site_id": CampaignFurnitureCatalog.SHOP_ID
	}


static func _payment_label(definition: Dictionary, payment: String) -> String:
	if payment == "gold":
		return "%d gold" % int(definition.get("gold_alternative", 0))
	var materials: Dictionary = definition.get("materials", {})
	if materials.is_empty():
		return "no payment"
	var parts: PackedStringArray = []
	for material_id in materials.keys():
		parts.append("%d %s" % [int(materials[material_id]), String(material_id)])
	return " + ".join(parts)


static func _requirement_text(requirement: Dictionary) -> String:
	match String(requirement.get("reason", "")):
		"wrong_dwelling_site":
			return "interact at %s" % String(requirement.get("required_site", "")).replace("_", " ")
		"already_owned":
			return "already owned"
		"already_upgraded":
			return "already improved"
		"prerequisite_dwelling_not_owned":
			return "first own %s" % String(requirement.get("required_dwelling", "")).replace("_", " ")
		"required_quest_incomplete":
			var quest_status := String(requirement.get("current", ""))
			if quest_status.is_empty():
				quest_status = "not started"
			return "complete the abandoned-house clearing encounter (status: %s)" % quest_status
		"insufficient_reputation":
			return "Silverhart Kingdom reputation %d / %d" % [roundi(float(requirement.get("current", 0.0))), roundi(float(requirement.get("required", 0.0)))]
		"insufficient_materials":
			var missing: Dictionary = requirement.get("missing", {})
			var parts: PackedStringArray = []
			for material_id in missing.keys():
				parts.append("%d %s" % [int(missing[material_id]), String(material_id)])
			return "missing " + (", ".join(parts) if not parts.is_empty() else "required materials")
		"insufficient_gold":
			return "gold %d / %d" % [int(requirement.get("current", 0)), int(requirement.get("required", 0))]
		"gold_not_accepted":
			return "gold is not accepted for this work"
		"unknown_payment_method":
			return "unsupported payment method"
	return String(requirement.get("reason", "requirements not met")).replace("_", " ")


