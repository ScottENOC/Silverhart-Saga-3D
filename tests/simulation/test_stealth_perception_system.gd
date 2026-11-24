extends SceneTree
## Headless regression checks for shared visual and acoustic perception.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var observer := {"hex": Vector2i(0, 0), "eye_height": 1.6}
	var forest := {
		Vector2i(1, 0): {"colours": [Color(0.18, 0.34, 0.16)]},
		Vector2i(2, 0): {"colours": [Color(0.18, 0.34, 0.16)]},
		Vector2i(3, 0): {"colours": [Color(0.18, 0.34, 0.16)]}
	}
	var matched := {
		"hex": Vector2i(3, 0),
		"appearance": {"colours": [Color(0.18, 0.34, 0.16)]}
	}
	var contrasting := {
		"hex": Vector2i(3, 0),
		"appearance": {"colours": [Color(0.88, 0.82, 0.68)]}
	}
	var matched_result := StealthPerceptionSystem.assess(observer, matched, forest)
	var contrasting_result := StealthPerceptionSystem.assess(observer, contrasting, forest)
	_check(float(matched_result.camouflage) > float(contrasting_result.camouflage), "matching palette should camouflage better")
	_check(float(matched_result.visual_confidence) > float(contrasting_result.visual_confidence), "matching palette should be harder to detect")

	var night := {"ambient_light": 0.0}
	var campfire := {"hex": Vector2i(80, 0), "light_emission": 0.95}
	var fire_result := StealthPerceptionSystem.assess(observer, campfire, {}, night)
	_check(int(fire_result.visual_level) >= StealthPerceptionSystem.VISUAL_VAGUE, "distant campfire should remain faintly visible at night")
	_check(int(fire_result.visual_level) < StealthPerceptionSystem.VISUAL_IDENTIFIED, "distant campfire should not reveal fine detail")

	var armoured_character := CharacterState.new("armoured_test", "Armoured test")
	armoured_character.equipped_item_data["armour"] = {"id": "steel_plate", "weight_class": "heavy"}
	var armour_profile := StealthPerceptionSystem.character_visual_profile(armoured_character)
	_check(float(armour_profile.reflectivity) >= 0.7, "steel armour should be reflective")
	_check(float(armour_profile.equipment_noise) >= 0.3, "steel plate should create equipment noise")

	var torch_character := CharacterState.new("torch_test", "Torch bearer")
	torch_character.equipped_item_data["offhand"] = {"id": "lit_torch", "type": "torch"}
	var torch_profile := StealthPerceptionSystem.character_visual_profile(torch_character)
	_check(float(torch_profile.light_emission) >= 0.8, "carried torch should emit light")

	var quiet_sound := {"hex": Vector2i(4, 0), "kind": "footsteps", "loudness": 0.18}
	var noisy_sound := {"hex": Vector2i(4, 0), "kind": "armoured_steps", "loudness": 0.18, "equipment_noise": 0.7}
	var quiet_result := StealthPerceptionSystem.assess_sound(Vector2i.ZERO, quiet_sound, {})
	var noisy_result := StealthPerceptionSystem.assess_sound(Vector2i.ZERO, noisy_sound, {})
	_check(float(noisy_result.confidence) > float(quiet_result.confidence), "noisy armour should carry further than quiet movement")
	_check(not noisy_result.has("source_hex"), "sound must not expose an exact source hex")
	_check(not bool(noisy_result.source_identified), "sound alone must not identify the source")
	_check(String(noisy_result.distance_band) != "", "heard sound should provide a broad distance band")

	var wall_cells := {Vector2i(1, 0): {"blocks_vision": true, "vision_block_height": 3.0, "blocks_sound": true, "sound_dampening": 0.5}}
	var near_target := {"hex": Vector2i(2, 0), "appearance": {"colours": [Color.WHITE]}}
	var open_result := StealthPerceptionSystem.assess(observer, near_target, {})
	var blocked_result := StealthPerceptionSystem.assess(observer, near_target, wall_cells)
	_check(float(blocked_result.visual_confidence) < float(open_result.visual_confidence), "intervening wall should reduce visual confidence")
	var open_sound := StealthPerceptionSystem.assess_sound(Vector2i.ZERO, {"hex": Vector2i(2, 0), "loudness": 0.8}, {})
	var blocked_sound := StealthPerceptionSystem.assess_sound(Vector2i.ZERO, {"hex": Vector2i(2, 0), "loudness": 0.8}, wall_cells)
	_check(float(blocked_sound.confidence) < float(open_sound.confidence), "sound barriers should attenuate sound")

	print("Stealth perception regression checks passed.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("Stealth perception check failed: " + message)
		quit(1)
