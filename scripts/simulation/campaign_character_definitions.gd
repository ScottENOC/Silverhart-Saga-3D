class_name CampaignCharacterDefinitions
extends RefCounted
## Loads authored character definitions independently of settlement/world layouts.

const CAMPAIGN2_CHARACTER_PATH := "res://data/characters/campaign2_characters.json"

static func load_campaign2() -> Dictionary:
	if not FileAccess.file_exists(CAMPAIGN2_CHARACTER_PATH):
		push_error("Campaign 2 character definitions are missing.")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CAMPAIGN2_CHARACTER_PATH))
	if not parsed is Dictionary:
		push_error("Campaign 2 character definitions are not valid JSON.")
		return {}
	var definitions: Dictionary = {}
	for entry in parsed.get("characters", []):
		if not entry is Dictionary:
			continue
		var character_id := String(entry.get("id", ""))
		if character_id.is_empty():
			push_error("Campaign 2 character definition is missing its id.")
			continue
		if definitions.has(character_id):
			push_error("Duplicate Campaign 2 character definition: %s" % character_id)
			continue
		var body_base := String(entry.get("body_base", ""))
		if body_base not in ["male", "female"]:
			push_error("Character %s must declare body_base as male or female." % character_id)
			continue
		definitions[character_id] = entry.duplicate(true)
	return definitions

static func get_campaign2_character(definitions: Dictionary, character_id: String) -> Dictionary:
	var value: Variant = definitions.get(character_id, {})
	return value.duplicate(true) if value is Dictionary else {}
