class_name CampSimulation
extends RefCounted
## Simulation-level camp state. It deliberately knows nothing about 3D nodes:
## a world presentation controller can animate the activities this model assigns.

signal camp_started(site: Dictionary)
signal activity_assigned(character_id: String, activity: String)
signal night_resolved(summary: Dictionary)

const EXPLORATION_SECONDS_PER_REAL_SECOND := 5.0
const DEFAULT_NIGHT_HOURS := 8.0
const TENT_COMFORTABLE_CAPACITY := 3
const TENT_MAX_CAPACITY := 5
const PLAYER_OVERRIDE_SECONDS := 10.0
const ROUTINE_STAGE_THRESHOLDS := [120.0, 360.0]
const ACTIVITY_IDS: Array[String] = [
	"gather_wood", "set_up_tents", "fetch_water", "cook", "repair_gear",
	"study_map", "train", "socialise", "watch", "sleep"
]

var phase: String = "inactive"
var site: Dictionary = {}
var party_ids: Array[String] = []
var environment: Dictionary = {}
var resources: Dictionary = {}
var assignments: Dictionary = {}
var sleeping_arrangements: Array[Dictionary] = []
var conditions: Dictionary = {}
var evening_activity_history: Dictionary = {}
var elapsed_world_seconds: float = 0.0
var routine_stage: int = 0
var _preparations_completed: bool = false
var companion_profiles: Dictionary = {}
var _default_assignments: Dictionary = {}
var lodging_profile: Dictionary = {}


func begin_camp(site_data: Dictionary, member_ids: Array, environment_data: Dictionary = {}, resource_data: Dictionary = {}) -> Dictionary:
	if phase != "inactive" and phase != "resolved":
		return {"ok": false, "reason": "camp_already_active"}
	if not bool(site_data.get("walkable", false)):
		return {"ok": false, "reason": "unsuitable_ground"}
	if bool(site_data.get("occupied", false)):
		return {"ok": false, "reason": "site_occupied"}
	if bool(site_data.get("in_combat", false)):
		return {"ok": false, "reason": "cannot_camp_during_combat"}
	var validated_ids: Array[String] = []
	for value in member_ids:
		var character_id := String(value).strip_edges()
		if character_id.is_empty() or validated_ids.has(character_id):
			continue
		validated_ids.append(character_id)
	if validated_ids.is_empty():
		return {"ok": false, "reason": "empty_party"}
	site = site_data.duplicate(true)
	lodging_profile = site.get("dwelling_profile", {}).duplicate(true)
	party_ids = validated_ids
	environment = environment_data.duplicate(true)
	resources = {
		"wood": maxi(0, int(resource_data.get("wood", 0))),
		"rations": maxi(0, int(resource_data.get("rations", 0))),
		"water": maxi(0, int(resource_data.get("water", 0))),
		"tents": maxi(0, int(resource_data.get("tents", 0))),
		"sleeping_bags": maxi(0, int(resource_data.get("sleeping_bags", 0))),
		"repair_kits": maxi(0, int(resource_data.get("repair_kits", 0)))
	}
	assignments.clear()
	_default_assignments.clear()
	companion_profiles = environment.get("companion_profiles", {}).duplicate(true)
	routine_stage = 0
	_preparations_completed = false
	sleeping_arrangements.clear()
	evening_activity_history.clear()
	elapsed_world_seconds = 0.0
	phase = "evening"
	for character_id in party_ids:
		if not conditions.has(character_id):
			conditions[character_id] = {
				"fatigue": 40.0, "hunger": 30.0, "thirst": 25.0,
				"warmth": 50.0, "comfort": 50.0, "social_satisfaction": 0.0
			}
	_plan_initial_activities()
	plan_sleeping_arrangements(resources.tents)
	camp_started.emit(site.duplicate(true))
	return {"ok": true, "party_size": party_ids.size(), "assignments": assignments.duplicate(true)}


func _plan_initial_activities() -> void:
	var available := party_ids.duplicate()
	if resources.wood <= 0 and bool(environment.get("trees_nearby", false)):
		_assign_from_pool(available, "gather_wood", 1)
	var outdoor_sleepers := maxi(0, party_ids.size() - int(lodging_profile.get("sleeping_capacity", 0)))
	if resources.tents > 0 and outdoor_sleepers > 0:
		_assign_from_pool(available, "set_up_tents", mini(resources.tents, 1))
	if bool(environment.get("water_nearby", false)) and resources.water < party_ids.size():
		_assign_from_pool(available, "fetch_water", 1)
	if resources.rations > 0 and (resources.wood > 0 or bool(environment.get("trees_nearby", false))):
		_assign_from_pool(available, "cook", 1)
	if resources.repair_kits > 0:
		_assign_from_pool(available, "repair_gear", 1)
	if available.size() > 1:
		_assign_from_pool(available, "study_map", 1)
	for character_id in available:
		_set_assignment(character_id, "socialise")


func _assign_from_pool(available: Array, activity: String, count: int) -> void:
	for _index in range(mini(count, available.size())):
		var best_index := 0
		var best_score := -INF
		for candidate_index in range(available.size()):
			var candidate_id := String(available[candidate_index])
			var score := _activity_suitability(candidate_id, activity)
			if score > best_score:
				best_score = score
				best_index = candidate_index
		var character_id := String(available.pop_at(best_index))
		_set_assignment(character_id, activity)


func _activity_suitability(character_id: String, activity: String) -> float:
	var profile: Dictionary = companion_profiles.get(character_id, {})
	var condition := condition_for(character_id)
	var fatigue := maxf(float(profile.get("fatigue", 0.0)), float(condition.get("fatigue", 0.0)))
	var injured := bool(profile.get("injured", false))
	var role := String(profile.get("role", "")).to_lower()
	var personality := String(profile.get("personality", "")).to_lower()
	var score := 0.0
	match activity:
		"gather_wood", "set_up_tents":
			if role in ["ranger", "fighter", "barbarian", "druid"] or personality in ["practical", "dutiful", "outdoors"]:
				score += 3.0
		"fetch_water":
			if role in ["ranger", "druid", "cleric"] or personality == "practical":
				score += 2.0
		"cook":
			if personality in ["nurturing", "gregarious", "practical"]:
				score += 3.0
		"repair_gear":
			if role in ["fighter", "ranger", "rogue"] or personality in ["craftsman", "meticulous"]:
				score += 3.0
		"study_map":
			if role in ["mage", "cleric", "wizard"] or personality in ["scholarly", "curious", "methodical"]:
				score += 3.0
		"socialise":
			if personality in ["gregarious", "warm", "outgoing"]:
				score += 3.0
	if activity in ["gather_wood", "set_up_tents", "fetch_water", "train"] and fatigue >= 65.0:
		score -= 4.0
	if injured and activity in ["gather_wood", "set_up_tents", "train"]:
		score -= 5.0
	return score


func _assign_watchers(available: Array) -> void:
	var watcher_count := watch_slots_for_party(party_ids.size())
	for _index in range(mini(watcher_count, available.size())):
		var character_id := String(available.pop_back())
		_set_assignment(character_id, "watch")


func watch_slots_for_party(party_size: int) -> int:
	if party_size <= 1:
		return 0
	return mini(party_size - 1, maxi(1, ceili(float(party_size) / 6.0)))


func _set_assignment(character_id: String, activity: String) -> void:
	if not ACTIVITY_IDS.has(activity):
		return
	var entry := {"activity": activity, "player_override": false, "override_remaining": 0.0}
	assignments[character_id] = entry
	_default_assignments[character_id] = entry.duplicate(true)
	activity_assigned.emit(character_id, activity)


## Social contact can happen during any camp job or outside camp entirely.
## The small satisfaction reserve carries into the next night's comfort.
func record_social_interaction(character_id: String, satisfaction_delta: float = 3.0) -> void:
	if character_id.strip_edges().is_empty():
		return
	if not conditions.has(character_id):
		conditions[character_id] = {
			"fatigue": 40.0, "hunger": 30.0, "thirst": 25.0,
			"warmth": 50.0, "comfort": 50.0, "social_satisfaction": 0.0
		}
	var condition: Dictionary = conditions[character_id]
	condition["social_satisfaction"] = clampf(float(condition.get("social_satisfaction", 0.0)) + satisfaction_delta, 0.0, 50.0)
	conditions[character_id] = condition


func condition_for(character_id: String) -> Dictionary:
	return (conditions.get(character_id, {}) as Dictionary).duplicate(true)


func time_point_regeneration_multiplier(character_id: String) -> float:
	var condition := condition_for(character_id)
	if condition.is_empty():
		return 1.0
	var multiplier := 1.0
	var fatigue := float(condition.get("fatigue", 0.0))
	var hunger := float(condition.get("hunger", 0.0))
	var thirst := float(condition.get("thirst", 0.0))
	if fatigue >= 75.0:
		multiplier *= 0.85
	elif fatigue >= 50.0:
		multiplier *= 0.95
	elif fatigue <= 15.0:
		multiplier *= 1.05
	if hunger >= 80.0:
		multiplier *= 0.85
	elif hunger >= 50.0:
		multiplier *= 0.95
	if thirst >= 75.0:
		multiplier *= 0.80
	elif thirst >= 45.0:
		multiplier *= 0.95
	return clampf(multiplier, 0.55, 1.10)


func next_day_effects(character_id: String) -> Dictionary:
	var condition := condition_for(character_id)
	if condition.is_empty():
		return {}
	var fatigue := float(condition.get("fatigue", 0.0))
	var hunger := float(condition.get("hunger", 0.0))
	var thirst := float(condition.get("thirst", 0.0))
	var comfort := float(condition.get("comfort", 50.0))
	return {
		"fatigue_band": "exhausted" if fatigue >= 75.0 else ("tired" if fatigue >= 50.0 else ("rested" if fatigue <= 15.0 else "normal")),
		"nutrition_band": "starving" if hunger >= 80.0 else ("hungry" if hunger >= 50.0 else "sated"),
		"hydration_band": "dehydrated" if thirst >= 75.0 else ("thirsty" if thirst >= 45.0 else "hydrated"),
		"comfort_band": "poor" if comfort < 30.0 else ("good" if comfort >= 70.0 else "ordinary")
	}


func assign_activity(character_id: String, activity: String, player_instruction: bool = true) -> Dictionary:
	if phase == "inactive" or phase == "resolved":
		return {"ok": false, "reason": "camp_not_active"}
	if not party_ids.has(character_id):
		return {"ok": false, "reason": "not_in_camp_party"}
	if not ACTIVITY_IDS.has(activity):
		return {"ok": false, "reason": "unknown_activity"}
	assignments[character_id] = {
		"activity": activity,
		"player_override": player_instruction,
		"override_remaining": PLAYER_OVERRIDE_SECONDS if player_instruction else 0.0
	}
	activity_assigned.emit(character_id, activity)
	return {"ok": true, "assignment": assignments[character_id].duplicate(true)}


## Camp activity uses the ordinary exploration clock. This method only expires
## temporary player-directed activity overrides; it never advances world time.
func advance_real_time(real_delta: float) -> float:
	if phase == "inactive" or phase == "resolved" or real_delta <= 0.0:
		return 0.0
	_advance_companion_fatigue(real_delta * EXPLORATION_SECONDS_PER_REAL_SECOND)
	for character_id in assignments.keys():
		var assignment: Dictionary = assignments[character_id]
		if not bool(assignment.get("player_override", false)):
			continue
		assignment["override_remaining"] = maxf(0.0, float(assignment.get("override_remaining", 0.0)) - real_delta)
		if float(assignment["override_remaining"]) <= 0.0:
			var fallback: Dictionary = _default_assignments.get(character_id, {"activity": "socialise"})
			assignments[character_id] = fallback.duplicate(true)
			activity_assigned.emit(String(character_id), String(fallback.get("activity", "socialise")))
		else:
			assignments[character_id] = assignment
	elapsed_world_seconds += real_delta * EXPLORATION_SECONDS_PER_REAL_SECOND
	var next_stage := 0
	for threshold in ROUTINE_STAGE_THRESHOLDS:
		if elapsed_world_seconds >= float(threshold):
			next_stage += 1
	while routine_stage < next_stage:
		routine_stage += 1
		_advance_evening_routines(routine_stage)
	return 0.0


func _advance_companion_fatigue(world_delta: float) -> void:
	for character_id_value in party_ids:
		var character_id := String(character_id_value)
		var condition := condition_for(character_id)
		if condition.is_empty():
			continue
		var activity := String(assignments.get(character_id, {}).get("activity", "socialise"))
		var fatigue_rate := 0.0
		match activity:
			"gather_wood":
				fatigue_rate = 0.035
			"set_up_tents":
				fatigue_rate = 0.025
			"fetch_water":
				fatigue_rate = 0.020
			"train":
				fatigue_rate = 0.040
			"repair_gear":
				fatigue_rate = 0.008
			"cook":
				fatigue_rate = 0.006
			"study_map":
				fatigue_rate = 0.002
			"socialise":
				fatigue_rate = 0.001
		condition["fatigue"] = clampf(float(condition.get("fatigue", 40.0)) + fatigue_rate * world_delta, 0.0, 100.0)
		conditions[character_id] = condition


func _advance_evening_routines(stage: int) -> void:
	if stage == 1 and not _preparations_completed:
		_complete_evening_preparations()
		_preparations_completed = true
	for character_id in party_ids:
		var current: Dictionary = assignments.get(character_id, {})
		var next_activity := _routine_activity_for(character_id, stage)
		if bool(current.get("player_override", false)):
			_default_assignments[character_id] = {
				"activity": next_activity, "player_override": false, "override_remaining": 0.0
			}
			continue
		if String(current.get("activity", "")) != next_activity:
			_set_assignment(character_id, next_activity)


func _routine_activity_for(character_id: String, stage: int) -> String:
	var profile: Dictionary = companion_profiles.get(character_id, {})
	var condition := condition_for(character_id)
	var fatigue := maxf(float(profile.get("fatigue", 0.0)), float(condition.get("fatigue", 0.0)))
	var injured := bool(profile.get("injured", false))
	var personality := String(profile.get("personality", "")).to_lower()
	var has_dwelling := int(lodging_profile.get("sleeping_capacity", 0)) > 0
	var severe_weather := _weather_is_severe()
	if int(resources.water) < party_ids.size() and bool(environment.get("water_nearby", false)):
		return "fetch_water"
	if int(resources.wood) <= 0 and bool(environment.get("trees_nearby", false)) and not bool(environment.get("fire_lit", false)):
		return "gather_wood"
	if severe_weather and not has_dwelling:
		return "socialise"
	if stage == 1:
		if int(resources.repair_kits) > 0 and injured:
			return "repair_gear"
		if fatigue >= 70.0 or injured:
			return "socialise"
		if personality in ["scholarly", "curious", "methodical"]:
			return "study_map"
		if personality in ["craftsman", "meticulous"] and int(resources.repair_kits) > 0:
			return "repair_gear"
		if personality in ["dutiful", "guardian"] and fatigue < 55.0 and not severe_weather:
			return "train"
		return "cook" if int(resources.rations) > 0 and int(resources.wood) > 0 else "socialise"
	if fatigue >= 55.0 or injured:
		return "socialise"
	if personality in ["scholarly", "curious", "methodical"]:
		return "study_map"
	if has_dwelling and personality in ["craftsman", "meticulous"] and int(resources.repair_kits) > 0:
		return "repair_gear"
	return "socialise"


func _weather_is_severe() -> bool:
	return (
		bool(environment.get("storm", false))
		or bool(environment.get("heavy_rain", false))
		or float(environment.get("wind_speed", 0.0)) >= 45.0
		or float(environment.get("rain_intensity", 0.0)) >= 0.7
		or float(environment.get("night_temperature_c", 10.0)) <= 2.0
	)


func plan_sleeping_arrangements(tent_count: int, bonds: CompanionBondState = null) -> Array[Dictionary]:
	sleeping_arrangements.clear()
	var remaining := party_ids.duplicate()
	var indoor_capacity := mini(maxi(0, int(lodging_profile.get("sleeping_capacity", 0))), remaining.size())
	for _index in range(indoor_capacity):
		var indoor_id := String(remaining.pop_front())
		sleeping_arrangements.append({
			"tent_index": -2, "shelter_type": "dwelling", "dwelling_id": String(lodging_profile.get("dwelling_id", "")),
			"character_ids": [indoor_id], "sleeping_bag_character_ids": [], "comfort_penalty": 0
		})
	var tent_limit := mini(maxi(0, tent_count), ceili(float(remaining.size()) / float(TENT_COMFORTABLE_CAPACITY)))
	var bags_remaining := int(resources.sleeping_bags)
	while tent_limit > 0 and not remaining.is_empty():
		var group: Array[String] = [String(remaining.pop_front())]
		var target_size := mini(TENT_MAX_CAPACITY, maxi(TENT_COMFORTABLE_CAPACITY, remaining.size() + 1 - (tent_limit - 1) * TENT_COMFORTABLE_CAPACITY))
		while group.size() < target_size and not remaining.is_empty():
			var best_index := _best_sleeping_candidate(remaining, group, bonds)
			group.append(String(remaining.pop_at(best_index)))
		var bag_users: Array[String] = []
		for member_id in group:
			if bags_remaining <= 0:
				break
			bag_users.append(member_id)
			bags_remaining -= 1
		sleeping_arrangements.append({
			"tent_index": sleeping_arrangements.size(), "shelter_type": "tent",
			"character_ids": group,
			"sleeping_bag_character_ids": bag_users,
			"comfort_penalty": maxi(0, group.size() - TENT_COMFORTABLE_CAPACITY) * 10
		})
		tent_limit -= 1
	for character_id in remaining:
		var has_bag := bags_remaining > 0
		if has_bag:
			bags_remaining -= 1
		sleeping_arrangements.append({
			"tent_index": -1, "shelter_type": "open_air", "character_ids": [character_id],
			"sleeping_bag_character_ids": [character_id] if has_bag else [],
			"comfort_penalty": 0
		})
	return sleeping_arrangements.duplicate(true)


func _best_sleeping_candidate(candidates: Array, group: Array[String], bonds: CompanionBondState) -> int:
	if candidates.size() <= 1 or bonds == null:
		return 0
	var best_index := 0
	var best_score := -INF
	for index in range(candidates.size()):
		var candidate := String(candidates[index])
		var score := 0.0
		for member_id in group:
			score += bonds.compatibility_score(member_id, candidate)
		score /= float(group.size())
		if score > best_score:
			best_score = score
			best_index = index
	return best_index


func begin_night() -> Dictionary:
	if phase != "evening":
		return {"ok": false, "reason": "not_in_evening_phase"}
	_complete_evening_preparations()
	evening_activity_history.clear()
	for character_id in party_ids:
		evening_activity_history[character_id] = String(assignments.get(character_id, {}).get("activity", ""))
	phase = "night"
	var available_watchers := party_ids.duplicate()
	for character_id in party_ids:
		var current: Dictionary = assignments.get(character_id, {})
		if String(current.get("activity", "")) == "watch":
			available_watchers.erase(character_id)
	var required_watchers := watch_slots_for_party(party_ids.size())
	while _count_watchers() < required_watchers and not available_watchers.is_empty():
		var watcher_id := String(available_watchers.pop_back())
		_set_assignment(watcher_id, "watch")
	for character_id in party_ids:
		if String(assignments.get(character_id, {}).get("activity", "")) != "watch":
			_set_assignment(character_id, "sleep")
	return {"ok": true, "watchers": _count_watchers()}


func _has_activity(activity: String) -> bool:
	for assignment in assignments.values():
		if String(assignment.get("activity", "")) == activity:
			return true
	return false


func _count_watchers() -> int:
	var count := 0
	for assignment in assignments.values():
		if String(assignment.get("activity", "")) == "watch":
			count += 1
	return count


func _complete_evening_preparations() -> void:
	if _preparations_completed:
		return
	if int(resources.wood) <= 0 and bool(environment.get("trees_nearby", false)) and _has_activity("gather_wood"):
		resources["wood"] = 1
	if bool(environment.get("water_nearby", false)) and _has_activity("fetch_water"):
		resources["water"] = maxi(int(resources.water), party_ids.size())
	if int(resources.wood) > 0 and not bool(environment.get("fire_lit", false)):
		resources["wood"] = maxi(0, int(resources.wood) - 1)
		environment["fire_lit"] = true
	if bool(environment.get("fire_lit", false)) and int(resources.rations) >= party_ids.size() and _has_activity("cook"):
		resources["rations"] = int(resources.rations) - party_ids.size()
		environment["meal_prepared"] = true
	_preparations_completed = true


func skip_to_morning(hours: float = DEFAULT_NIGHT_HOURS) -> Dictionary:
	if phase == "evening":
		begin_night()
	return resolve_night(hours)


func resolve_night(hours: float = DEFAULT_NIGHT_HOURS) -> Dictionary:
	if phase != "night":
		return {"ok": false, "reason": "night_not_started"}
	var night_hours := clampf(hours, 1.0, 16.0)
	var party_size := party_ids.size()
	var has_fire := bool(environment.get("fire_lit", false))
	var has_meal := bool(environment.get("meal_prepared", false))
	var has_water := int(resources.water) >= party_size
	var watchers := _count_watchers()
	var danger := clampf(float(environment.get("danger", 0.25)), 0.0, 1.0)
	var ambush_chance := clampf(danger * 0.45 - float(watchers) * 0.07, 0.0, 0.45)
	var starting_temperature := float(environment.get("night_temperature_c", 10.0))
	var temperature_change := float(environment.get("temperature_change_per_hour", -0.4))
	var temperature := starting_temperature + temperature_change * night_hours
	var cold_penalty := maxf(0.0, 10.0 - temperature) * 2.0
	var bagged_characters: Dictionary = {}
	for arrangement in sleeping_arrangements:
		for bagged_id in arrangement.get("sleeping_bag_character_ids", []):
			bagged_characters[String(bagged_id)] = true
	if has_water:
		resources["water"] = maxi(0, int(resources.water) - party_size)
	var results: Dictionary = {}
	var total_comfort := 0.0
	for character_id in party_ids:
		var condition: Dictionary = conditions[character_id]
		var in_tent := false
		var in_dwelling := false
		var tent_penalty := 0.0
		for arrangement in sleeping_arrangements:
			if (arrangement.get("character_ids", []) as Array).has(character_id):
				in_tent = int(arrangement.get("tent_index", -1)) >= 0
				in_dwelling = String(arrangement.get("shelter_type", "")) == "dwelling"
				tent_penalty = float(arrangement.get("comfort_penalty", 0))
				break
		var has_sleeping_bag := bool(bagged_characters.get(character_id, false))
		var dwelling_warmth := float(lodging_profile.get("warmth_bonus", 0.0)) if in_dwelling else 0.0
		var warmth := clampf(45.0 + (15.0 if in_tent else 0.0) + (20.0 if has_sleeping_bag else 0.0) + (10.0 if has_fire else 0.0) + dwelling_warmth - cold_penalty, 0.0, 100.0)
		var nutrition := 90.0 if has_meal else (55.0 if int(resources.rations) > 0 else 35.0)
		var hydration := 90.0 if has_water else 35.0
		var dwelling_security := float(lodging_profile.get("security_bonus", 0.0)) if in_dwelling else 0.0
		var security := clampf(55.0 + float(watchers) * 15.0 - danger * 30.0 + dwelling_security, 0.0, 100.0)
		# Social interactions can happen during any activity. The old dedicated
		# "socialise" assignment is merely idle behaviour, not a social-time gate.
		var social := clampf(50.0 + float(condition.get("social_satisfaction", 0.0)), 0.0, 100.0)
		condition["social_satisfaction"] = maxf(0.0, float(condition.get("social_satisfaction", 0.0)) - 5.0)
		var sleep_quality := clampf((warmth + nutrition + hydration + security) * 0.25 - tent_penalty, 0.0, 100.0)
		var dwelling_comfort := float(lodging_profile.get("comfort_bonus", 0.0)) if in_dwelling else 0.0
		var comfort := clampf((warmth * 0.23 + nutrition * 0.18 + hydration * 0.14 + security * 0.15 + sleep_quality * 0.20 + social * 0.10) + dwelling_comfort, 0.0, 100.0)
		var watch_penalty := 10.0 if String(assignments.get(character_id, {}).get("activity", "")) == "watch" else 0.0
		var fatigue_recovered := minf(float(condition.fatigue), maxf(0.0, 20.0 + comfort * 0.35 - watch_penalty))
		condition["fatigue"] = maxf(0.0, float(condition.fatigue) - fatigue_recovered)
		condition["hunger"] = clampf(float(condition.hunger) + night_hours * 2.0 - (25.0 if has_meal else 0.0), 0.0, 100.0)
		condition["thirst"] = clampf(float(condition.thirst) + night_hours * 2.5 - (30.0 if has_water else 0.0), 0.0, 100.0)
		condition["warmth"] = warmth
		condition["comfort"] = comfort
		conditions[character_id] = condition
		total_comfort += comfort
		results[character_id] = {
			"comfort": comfort, "warmth": warmth, "nutrition": nutrition,
			"hydration": hydration, "security": security, "social": social,
			"fatigue_recovered": fatigue_recovered
		}
	phase = "resolved"
	var summary := {
		"hours": night_hours, "party_size": party_size, "watchers": watchers,
		"ambush_chance": ambush_chance,
		"average_comfort": total_comfort / float(maxi(1, party_size)),
		"characters": results,
		"resources_remaining": resources.duplicate(true)
	}
	night_resolved.emit(summary.duplicate(true))
	return {"ok": true, "summary": summary}


func to_dict() -> Dictionary:
	return {
		"phase": phase, "site": site.duplicate(true), "party_ids": party_ids.duplicate(),
		"environment": environment.duplicate(true), "resources": resources.duplicate(true),
		"assignments": assignments.duplicate(true), "default_assignments": _default_assignments.duplicate(true),
		"sleeping_arrangements": sleeping_arrangements.duplicate(true),
		"conditions": conditions.duplicate(true), "evening_activity_history": evening_activity_history.duplicate(true),
		"elapsed_world_seconds": elapsed_world_seconds, "lodging_profile": lodging_profile.duplicate(true),
		"routine_stage": routine_stage, "preparations_completed": _preparations_completed,
		"companion_profiles": companion_profiles.duplicate(true)
	}


func from_dict(data: Dictionary) -> bool:
	var saved_phase := String(data.get("phase", "inactive"))
	if not ["inactive", "evening", "night", "resolved"].has(saved_phase):
		return false
	var saved_party: Variant = data.get("party_ids", [])
	var saved_conditions: Variant = data.get("conditions", {})
	var saved_assignments: Variant = data.get("assignments", {})
	var saved_resources: Variant = data.get("resources", {})
	var saved_lodging: Variant = data.get("lodging_profile", data.get("site", {}).get("dwelling_profile", {}))
	var saved_profiles: Variant = data.get("companion_profiles", data.get("environment", {}).get("companion_profiles", {}))
	if not saved_party is Array or not saved_conditions is Dictionary or not saved_assignments is Dictionary or not saved_resources is Dictionary or not saved_lodging is Dictionary or not saved_profiles is Dictionary:
		return false
	var ids: Array[String] = []
	for value in saved_party:
		var character_id := String(value)
		if character_id.is_empty() or ids.has(character_id):
			return false
		ids.append(character_id)
	for character_id in saved_assignments:
		if not ids.has(String(character_id)) or not saved_assignments[character_id] is Dictionary:
			return false
	for character_id in saved_conditions:
		if String(character_id).is_empty() or not saved_conditions[character_id] is Dictionary:
			return false
	phase = saved_phase
	site = data.get("site", {}).duplicate(true)
	lodging_profile = saved_lodging.duplicate(true)
	party_ids = ids
	environment = data.get("environment", {}).duplicate(true)
	resources = saved_resources.duplicate(true)
	assignments = saved_assignments.duplicate(true)
	_default_assignments = data.get("default_assignments", {}).duplicate(true)
	sleeping_arrangements = data.get("sleeping_arrangements", []).duplicate(true)
	conditions = saved_conditions.duplicate(true)
	evening_activity_history = data.get("evening_activity_history", {}).duplicate(true)
	elapsed_world_seconds = maxf(0.0, float(data.get("elapsed_world_seconds", 0.0)))
	routine_stage = clampi(int(data.get("routine_stage", 0)), 0, ROUTINE_STAGE_THRESHOLDS.size())
	_preparations_completed = bool(data.get("preparations_completed", false))
	companion_profiles = saved_profiles.duplicate(true)
	return true
