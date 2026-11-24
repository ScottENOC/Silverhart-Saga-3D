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
	var campfire := {"hex": Vector2i(20, 0), "light_emission": 0.95}
	var fire_result := StealthPerceptionSystem.assess(observer, campfire, {}, night)
	_check(int(fire_result.visual_level) >= StealthPerceptionSystem.VISUAL_VAGUE, "distant campfire should remain faintly visible at night")
	_check(int(fire_result.visual_level) < StealthPerceptionSystem.VISUAL_IDENTIFIED, "distant campfire should not reveal fine detail")

	_check(not bool(fire_result.hex_known), "distant fire should not reveal an exact target hex")
	_check(bool(fire_result.long_range_light_allowed), "night should allow long-range light detection")
	var daytime_fire_result := StealthPerceptionSystem.assess(observer, campfire, {}, {"ambient_light": 1.0})
	_check(int(daytime_fire_result.visual_level) == StealthPerceptionSystem.VISUAL_NONE, "distant fire should not be visible in daylight")
	_check(not bool(daytime_fire_result.light_detected), "daylight should disable long-range light detection")
	var distant_unlit_target := {"hex": Vector2i(20, 0), "appearance": {"colours": [Color.WHITE]}}
	var distant_unlit_result := StealthPerceptionSystem.assess(observer, distant_unlit_target, {}, night)
	_check(int(distant_unlit_result.visual_level) == StealthPerceptionSystem.VISUAL_NONE, "unlit target beyond vision radius should remain unseen")
	var badly_camouflaged_outside := {"hex": Vector2i(9, 0), "appearance": {"colours": [Color.WHITE]}}
	var outside_result := StealthPerceptionSystem.assess(observer, badly_camouflaged_outside, forest)
	_check(int(outside_result.visual_level) == StealthPerceptionSystem.VISUAL_NONE, "poor camouflage must not extend the hard vision radius")
	_check(not bool(outside_result.within_vision_radius), "target beyond default vision radius should be outside local sight")

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

	var world := WorldSimulation.new()
	var observer_state := CharacterState.new("observer_test", "Observer", Vector2i.ZERO)
	var target_state := CharacterState.new("target_test", "Target", Vector2i(4, 0))
	world.register_character(observer_state)
	world.register_character(target_state)
	var service := StealthPerceptionService.new(world)
	world.clock.set_world_seconds(12.0 * 3600.0)
	var daylight_result := service.assess_character(observer_state.id, target_state.id)
	target_state.skills["stealth"] = 5
	var skilled_result := service.assess_character(observer_state.id, target_state.id)
	_check(float(skilled_result.visual_confidence) < float(daylight_result.visual_confidence), "stealth skill should reduce visual detection")
	world.clock.set_world_seconds(0.0)
	var midnight_result := service.assess_character(observer_state.id, target_state.id)
	_check(float(daylight_result.visual_confidence) > float(midnight_result.visual_confidence), "campaign time should change ambient visibility")
	world.free()

	print("Stealth perception regression checks passed.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		push_error("Stealth perception check failed: " + message)
		quit(1)
