class_name StealthPerceptionService
extends RefCounted
## Campaign-facing adapter around the shared perception rules. Kept separate
## from WorldSimulation so stealth does not add more responsibilities to the
## long-lived world simulation class.

var world_simulation: WorldSimulation


func _init(simulation: WorldSimulation = null) -> void:
	world_simulation = simulation


func assess_character(observer_id: String, target_id: String, environment: Dictionary = {}, target_appearance: Dictionary = {}) -> Dictionary:
	if world_simulation == null:
		return {"visual_level": StealthPerceptionSystem.VISUAL_NONE, "visual_label": "unseen", "reason": "missing_world_simulation"}
	var observer := world_simulation.get_character(observer_id)
	var target := world_simulation.get_character(target_id)
	if observer == null or target == null or not observer.alive or not target.alive:
		return {"visual_level": StealthPerceptionSystem.VISUAL_NONE, "visual_label": "unseen", "reason": "character_unavailable"}
	var target_profile := StealthPerceptionSystem.character_visual_profile(target, target_appearance)
	var observer_profile := {
		"hex": observer.axial,
		"eye_height": 1.1 if observer.tags.has("small_creature") else 1.6
	}
	var target_profile_data := {
		"hex": target.axial,
		"visual_height": 1.0 if target.tags.has("small_creature") else 1.6,
		"appearance": target_profile,
		"movement_exposure": 0.25 if target.tags.has("running") else 0.0
	}
	return StealthPerceptionSystem.assess(observer_profile, target_profile_data, world_simulation.map_data.cells, _resolve_environment(environment))


func make_character_sound_event(character_id: String, kind: String, loudness: float, movement_noise: float = 0.0) -> Dictionary:
	if world_simulation == null:
		return {}
	var character := world_simulation.get_character(character_id)
	if character == null:
		return {}
	return StealthPerceptionSystem.make_character_sound_event(character, kind, loudness, movement_noise)


func assess_sound_event(observer_id: String, sound_event: Dictionary, environment: Dictionary = {}) -> Dictionary:
	if world_simulation == null:
		return {"sound_level": StealthPerceptionSystem.SOUND_UNHEARD, "heard": false, "reason": "missing_world_simulation"}
	var observer := world_simulation.get_character(observer_id)
	if observer == null or not observer.alive:
		return {"sound_level": StealthPerceptionSystem.SOUND_UNHEARD, "heard": false, "reason": "observer_unavailable"}
	return StealthPerceptionSystem.assess_sound(observer.axial, sound_event, world_simulation.map_data.cells, _resolve_environment(environment))


## Weather, local light sources and other explicit overrides are supplied by the
## caller. If ambient light is omitted, derive it from the shared campaign clock
## so the same observer sees very different things at noon and midnight.
func _resolve_environment(overrides: Dictionary) -> Dictionary:
	var resolved := overrides.duplicate(true)
	if not resolved.has("ambient_light"):
		var time := world_simulation.clock.time_of_day()
		var hour := float(time.get("hour", 12)) + float(time.get("minute", 0)) / 60.0
		var daylight := clampf(sin((hour - 6.0) * PI / 12.0), 0.0, 1.0)
		resolved["ambient_light"] = 0.025 + daylight * 0.975
	return resolved
