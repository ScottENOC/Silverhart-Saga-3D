extends SceneTree

const VALIDATOR = preload("res://scripts/world/settlement_definition_validator.gd")

func _initialize() -> void:
	_test_valid_definition()
	_test_required_envelope_fields()
	_test_invalid_bounds_and_coordinate_frame()
	_test_duplicate_feature_ids()
	_test_feature_positions_within_bounds()
	_test_non_dictionary_records()
	if failures > 0:
		push_error("%d canonical settlement validator test(s) failed." % failures)
		quit(1)
		return
	print("Canonical settlement definition validator tests passed.")
	quit(0)

var failures := 0

func _valid_definition() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "test_settlement",
		"name": "Test Settlement",
		"source": "tests",
		"coordinate_system": "campaign2_local_axial_qr",
		"origin": {"q": 100, "r": -200},
		"bounds": {"min_q": -10, "max_q": 10, "min_r": -20, "max_r": 20},
		"terrain": {},
		"layout": {"buildings": [{"id": "house_01", "center": {"q": 0, "r": 0}, "door": {"q": 2, "r": 0}}], "paths": [], "bridges": [], "fields": [], "props": []},
		"placements": {"characters": [{"id": "character_01", "position": {"q": 1, "r": 1}}], "creatures": []},
		"presentation": {"hex_radius": 2.0, "ground": {}, "palette": {}, "vegetation": {}},
		"interiors": []
	}

func _test_valid_definition() -> void:
	var result: Dictionary = VALIDATOR.validate(_valid_definition())
	_check(bool(result.ok), "A structurally valid canonical settlement should pass: %s" % str(result.errors))

func _test_required_envelope_fields() -> void:
	var definition := _valid_definition()
	definition.erase("placements")
	var result: Dictionary = VALIDATOR.validate(definition)
	_check(not bool(result.ok), "Missing required envelope sections must fail validation")
	_check(_has_error(result, "placements is required"), "Missing required section should identify its field")

func _test_invalid_bounds_and_coordinate_frame() -> void:
	var definition := _valid_definition()
	definition["coordinate_system"] = "unknown_coordinates"
	definition["bounds"] = {"min_q": 5, "max_q": -5, "min_r": 0, "max_r": 1}
	var result: Dictionary = VALIDATOR.validate(definition)
	_check(not bool(result.ok), "Unsupported coordinate frames and inverted bounds must fail")

func _test_duplicate_feature_ids() -> void:
	var definition := _valid_definition()
	definition["layout"]["buildings"].append({"id": "house_01", "center": {"q": 1, "r": 1}})
	var result: Dictionary = VALIDATOR.validate(definition)
	_check(not bool(result.ok), "Duplicate IDs within a feature collection must fail")
	_check(_has_error(result, "duplicate id house_01"), "Duplicate ID failure should identify the duplicate")

func _test_feature_positions_within_bounds() -> void:
	var definition := _valid_definition()
	definition["placements"]["characters"][0]["position"] = {"q": 11, "r": 0}
	var result: Dictionary = VALIDATOR.validate(definition)
	_check(not bool(result.ok), "Feature anchors outside local bounds must fail")

func _test_non_dictionary_records() -> void:
	var definition := _valid_definition()
	definition["layout"]["props"] = ["not_a_record"]
	var result: Dictionary = VALIDATOR.validate(definition)
	_check(not bool(result.ok), "Non-object feature records must fail")

func _has_error(result: Dictionary, fragment: String) -> bool:
	for message in result.get("errors", []):
		if String(message).contains(fragment):
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
