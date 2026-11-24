class_name CampaignDwellingWorldService
extends RefCounted
## Source-anchored world access points for the campaign dwelling system.
## This registry owns location identity and interaction copy, not ownership,
## inventory, campaign progression or save state.

const SITES: Array[Dictionary] = [
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
		"id": "silverhart_palace",
		"name": "Silverhart Palace",
		"hex": Vector2i(8, -496),
		"dwelling_id": "silverhart_manor",
		"description": "The royal palace stands at the heart of Silverhart. The Queen can grant the abandoned Corstane townhouse to someone who has earned the crown's trust.",
		"actions": ["claim_silverhart_manor"]
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
	var dwelling_id := String(site.get("dwelling_id", ""))
	var profile := dwelling_state.camp_profile_for(dwelling_id)
	var lines: PackedStringArray = [String(site.get("description", ""))]
	if bool(dwelling_state.owned.get(dwelling_id, false)):
		lines.append("Ownership: yours.")
		if int(profile.get("sleeping_capacity", 0)) > 0:
			lines.append("Indoor sleeping places: %d. Layout: %s." % [
				int(profile.get("sleeping_capacity", 0)),
				String(profile.get("layout_id", "unassigned"))
			])
		else:
			lines.append("Status: owned, but still uninhabitable.")
	else:
		lines.append("Ownership: not yet acquired.")

	var choices: Array[Dictionary] = []
	if site_id == "abandoned_house" and remaining_guardians > 0:
		var quest := journal.quest_state("abandoned_house_cleared")
		if String(quest.get("status", "")) == "active":
			choices.append({
				"id": "abandoned_house_enter",
				"label": "Enter the house · %d guardians remain" % remaining_guardians,
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
			if payment_methods.size() == 1 and not bool(status.get("ok", false)):
				# The action is not currently available; the unmet requirements
				# above explain exactly what must change before it can be taken.
				pass
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
			return "complete the abandoned-house clearing encounter (status: %s)" % String(requirement.get("current", "not started"))
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


