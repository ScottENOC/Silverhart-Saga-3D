class_name Campaign2CharacterDefinitionRegistry
extends RefCounted
## Character-owned identity and appearance lookup for streamed settlement actors.
## The legacy fallback is temporary: it reads NPC profiles only when the new
## character catalogue has not yet been installed by the character-data migration.

const CHARACTER_CATALOGUE_PATH := "res://data/characters/campaign2_characters.json"
const LEGACY_LAYOUT_PATH := "res://data/world/campaign2_settlement_layouts.json"

var _characters: Dictionary = {}
var validation_errors: Array[String] = []

func _init() -> void:
	if FileAccess.file_exists(CHARACTER_CATALOGUE_PATH):
		_load_character_catalogue()
	else:
		_load_legacy_character_profiles()

func get_character(character_id: String) -> Dictionary:
	return (_characters.get(character_id, {}) as Dictionary).duplicate(true)

func character_ids() -> Array[String]:
	var result: Array[String] = []
	for character_id in _characters:
		result.append(String(character_id))
	result.sort()
	return result

func _load_character_catalogue() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHARACTER_CATALOGUE_PATH))
	if not parsed is Dictionary or not parsed.get("characters", []) is Array:
		validation_errors.append("Campaign 2 character catalogue is invalid.")
		return
	for character in parsed.get("characters", []):
		_register_character(character)

func _load_legacy_character_profiles() -> void:
	if not FileAccess.file_exists(LEGACY_LAYOUT_PATH):
		validation_errors.append("No Campaign 2 character catalogue or legacy character source is available.")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_LAYOUT_PATH))
	if not parsed is Dictionary:
		validation_errors.append("Legacy Campaign 2 character source is invalid.")
		return
	for settlement in parsed.get("settlements", []):
		if not settlement is Dictionary:
			continue
		for character in settlement.get("npcs", []):
			_register_character(character)

func _register_character(value: Variant) -> void:
	if not value is Dictionary:
		validation_errors.append("Character catalogue entries must be objects.")
		return
	var character_id := String(value.get("id", value.get("character_id", ""))).strip_edges()
	if character_id.is_empty():
		validation_errors.append("Character catalogue entry is missing its stable ID.")
		return
	if _characters.has(character_id):
		validation_errors.append("Duplicate character definition: %s" % character_id)
		return
	_characters[character_id] = value.duplicate(true)
