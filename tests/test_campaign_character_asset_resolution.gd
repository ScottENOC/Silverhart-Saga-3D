extends SceneTree

const FACTORY = preload("res://scripts/presentation/campaign_character_actor_factory.gd")

func _initialize() -> void:
	var expected_companions := {
		"companion_wren_talbot": "res://art/characters/companions/wren.glb",
		"companion_ser_aldric_thorne": "res://art/characters/companions/aldric.glb",
		"companion_dagna_stoneward": "res://art/characters/companions/dagna.glb"
	}
	for character_id in expected_companions:
		var expected_path := String(expected_companions[character_id])
		var resolved := FACTORY._resolve_character_model_path(
			character_id,
			{},
			"male" if character_id.contains("aldric") else "female"
		)
		if resolved != expected_path or not ResourceLoader.exists(resolved):
			_fail("Approved companion asset was not selected for %s (got %s)" % [character_id, resolved])
			return

	var authored_npcs := {
		"garrick_holt": "res://art/characters/hollowmere/garrick_holt.glb",
		"mira_ashbrook": "res://art/characters/hollowmere/mira_ashbrook.glb"
	}
	if FACTORY._hollowmere_body_variant_for("garrick_holt", "female") != "male":
		_fail("Garrick's authored model was not identified as male")
		return
	if FACTORY._hollowmere_body_variant_for("mira_ashbrook", "male") != "female":
		_fail("Mira's authored model was not identified as female")
		return
	for character_id in authored_npcs:
		var expected_path := String(authored_npcs[character_id])
		var resolved := FACTORY._resolve_character_model_path(
			character_id,
			{},
			"male" if character_id == "garrick_holt" else "female"
		)
		if resolved != expected_path or not ResourceLoader.exists(resolved):
			_fail("Authored Hollowmere model was not selected for %s (got %s)" % [character_id, resolved])
			return

	var female_fallback := FACTORY._resolve_character_model_path("unknown_female", {}, "female")
	var male_fallback := FACTORY._resolve_character_model_path("unknown_male", {}, "male")
	if female_fallback != "res://art/characters/ara_runtime/ara_player_female_body.glb":
		_fail("Unknown female NPC did not use the current female runtime base")
		return
	if male_fallback != "res://art/characters/ara_runtime/ara_player_male_body.glb":
		_fail("Unknown male NPC did not use the current male runtime base")
		return

	print("CAMPAIGN_CHARACTER_ASSET_TEST: PASS (approved companions, authored NPCs and gendered fallbacks)")
	quit(0)


func _fail(message: String) -> void:
	push_error("CAMPAIGN_CHARACTER_ASSET_TEST: " + message)
	quit(1)
