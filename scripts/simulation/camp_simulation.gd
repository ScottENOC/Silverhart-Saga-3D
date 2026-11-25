class_name CampSimulation
extends RefCounted
## Simulation-level camp state. It deliberately knows nothing about 3D nodes:
## a world presentation controller can animate the activities this model assigns.

signal camp_started(site: Dictionary)
signal activity_assigned(character_id: String, activity: String)
signal night_resolved(summary: Dictionary)
signal animal_care_completed(animal_id: String, action: String, handler_id: String, care: Dictionary)

const EXPLORATION_SECONDS_PER_REAL_SECOND := 5.0
const DEFAULT_NIGHT_HOURS := 8.0
const TENT_COMFORTABLE_CAPACITY := 3
const TENT_MAX_CAPACITY := 5
const PLAYER_OVERRIDE_SECONDS := 10.0
const ROUTINE_STAGE_THRESHOLDS := [120.0, 360.0]
const WEATHER_CONTEXT_KEYS: Array[String] = [
	"weather_type", "weather_label", "season", "month_index", "temperature_c",
	"night_temperature_c", "wind_speed", "rain_intensity", "storm", "heavy_rain",
	"snow", "fog", "visibility_multiplier"
]
const ACTIVITY_IDS: Array[String] = [
	"gather_wood", "set_up_tents", "fetch_water", "cook", "repair_gear",
	"study_map", "train", "socialise", "watch", "sleep",
	"care_horse_water", "care_horse_feed", "care_horse_groom", "care_horse_tether"
]

var phase: String = "inactive"
var site: Dictionary = {}
var party_ids: Array[String] = []
## All entities present at camp. Party membership is a capability, not a
## prerequisite for being represented here.
var occupants: Dictionary = {}
## Per-animal camp care state, keyed by the animal occupant ID.
var animal_care: Dictionary = {}
## Time-based care chores, queued independently of party membership.
var animal_care_tasks: Array[Dictionary] = []
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
var night_index: int = 0
var night_watch_schedule: Array[Dictionary] = []
var night_encounter_result: Dictionary = {}


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
	occupants.clear()
	animal_care.clear()
	animal_care_tasks.clear()
	for character_id in party_ids:
		register_camp_occupant({
			"occupant_id": character_id, "kind": "party_member", "species": "humanoid",
			"participates_in_party": true, "can_sleep": true, "can_work": true,
			"needs": ["food", "water", "shelter", "sleep", "safety", "social"]
		})
	var supplied_occupants: Variant = environment.get("camp_occupants", [])
	if supplied_occupants is Array:
		for occupant_data in supplied_occupants:
			if occupant_data is Dictionary:
				register_camp_occupant(occupant_data)
	resources = {
		"wood": maxi(0, int(resource_data.get("wood", 0))),
		"rations": maxi(0, int(resource_data.get("rations", 0))),
		"water": maxi(0, int(resource_data.get("water", 0))),
		"tents": maxi(0, int(resource_data.get("tents", 0))),
		"sleeping_bags": maxi(0, int(resource_data.get("sleeping_bags", 0))),
		"repair_kits": maxi(0, int(resource_data.get("repair_kits", 0))),
		"fodder": maxi(0, int(resource_data.get("fodder", 0)))
	}
	assignments.clear()
	_default_assignments.clear()
	night_index = 0
	night_watch_schedule.clear()
	night_encounter_result.clear()
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
	_plan_horse_care_tasks()
	plan_sleeping_arrangements(resources.tents)
	camp_started.emit(site.duplicate(true))
	return {"ok": true, "party_size": party_ids.size(), "occupant_count": occupants.size(), "assignments": assignments.duplicate(true)}


const OCCUPANT_KINDS: Array[String] = [
	"party_member", "animal", "follower", "resident", "guest"
]


## Registers a non-party camp presence (or updates an existing occupant).
## Unknown fields are retained so later behaviour systems can add domain data.
func register_camp_occupant(data: Dictionary) -> Dictionary:
	var occupant_id := String(data.get("occupant_id", data.get("id", ""))).strip_edges()
	var kind := String(data.get("kind", "follower")).strip_edges().to_lower()
	if occupant_id.is_empty():
		return {"ok": false, "reason": "missing_occupant_id"}
	if not OCCUPANT_KINDS.has(kind):
		return {"ok": false, "reason": "invalid_occupant_kind"}
	var participates_in_party := bool(data.get("participates_in_party", kind == "party_member"))
	if participates_in_party and not party_ids.has(occupant_id):
		return {"ok": false, "reason": "party_member_not_in_party"}
	if participates_in_party != (kind == "party_member"):
		return {"ok": false, "reason": "party_member_kind_mismatch"}
	if not participates_in_party and party_ids.has(occupant_id):
		return {"ok": false, "reason": "party_member_kind_mismatch"}
	var clean := data.duplicate(true)
	clean.erase("id")
	clean["occupant_id"] = occupant_id
	clean["kind"] = kind
	clean["species"] = String(data.get("species", "humanoid" if kind != "animal" else "unknown"))
	clean["participates_in_party"] = participates_in_party
	clean["can_sleep"] = bool(data.get("can_sleep", kind != "guest" or bool(data.get("staying_overnight", false))))
	clean["can_work"] = bool(data.get("can_work", kind in ["party_member", "follower", "resident"]))
	var needs: Variant = data.get("needs", ["food", "water", "shelter", "sleep", "safety"])
	if not needs is Array:
		return {"ok": false, "reason": "invalid_occupant_needs"}
	clean["needs"] = needs.duplicate()
	occupants[occupant_id] = clean
	if kind == "animal" and String(clean.get("species", "")).to_lower() in ["horse", "equine"]:
		_ensure_horse_care_state(occupant_id)
	else:
		animal_care.erase(occupant_id)
	return {"ok": true, "occupant": clean.duplicate(true)}


## Initialise persistent care flags for a registered horse without assuming it
## has already been fed, watered or safely tethered.
func _ensure_horse_care_state(occupant_id: String) -> void:
	if not animal_care.has(occupant_id):
		animal_care[occupant_id] = {
			"watered": false, "fed": false, "groomed": false,
			"tethered": false, "resting": false,
			"last_care": "", "handler_id": ""
		}


## Resolve one deliberate camp-care action. Feed and water consume only the
## explicitly supplied fodder/water stores; grooming and resting do not invent
## consumable items. Tethering requires an authored safe anchor at the site.
func perform_animal_care(occupant_id: String, action: String, handler_id: String = "") -> Dictionary:
	if phase != "evening":
		return {"ok": false, "reason": "camp_not_in_evening"}
	var animal: Dictionary = occupant_for(occupant_id)
	if animal.is_empty() or String(animal.get("kind", "")) != "animal":
		return {"ok": false, "reason": "animal_not_in_camp"}
	if String(animal.get("species", "")).to_lower() not in ["horse", "equine"]:
		return {"ok": false, "reason": "unsupported_care_species"}
	if not handler_id.is_empty():
		var handler: Dictionary = occupant_for(handler_id)
		if handler.is_empty() or not bool(handler.get("can_work", false)):
			return {"ok": false, "reason": "handler_cannot_work"}
	_ensure_horse_care_state(occupant_id)
	var state: Dictionary = animal_care[occupant_id].duplicate(true)
	var completed_flag := String({
		"water": "watered", "feed": "fed", "groom": "groomed",
		"tether": "tethered", "rest": "resting"
	}.get(action, ""))
	if completed_flag.is_empty():
		return {"ok": false, "reason": "unknown_animal_care_action"}
	if bool(state.get(completed_flag, false)):
		return {"ok": true, "already_completed": true, "animal_id": occupant_id, "care": state.duplicate(true), "resources_remaining": resources.duplicate(true)}
	if action != "rest":
		state["resting"] = false
	match action:
		"water":
			if int(resources.get("water", 0)) <= 0:
				return {"ok": false, "reason": "no_water"}
			resources["water"] = int(resources.water) - 1
			state["watered"] = true
		"feed":
			if int(resources.get("fodder", 0)) <= 0:
				return {"ok": false, "reason": "no_fodder"}
			resources["fodder"] = int(resources.fodder) - 1
			state["fed"] = true
		"groom":
			state["groomed"] = true
		"tether":
			if not bool(site.get("safe_tethering", environment.get("safe_tethering", false))):
				return {"ok": false, "reason": "no_safe_tethering_anchor"}
			state["tethered"] = true
		"rest":
			state["resting"] = true
		_:
			return {"ok": false, "reason": "unknown_animal_care_action"}
	state["last_care"] = action
	state["handler_id"] = handler_id
	animal_care[occupant_id] = state
	animal_care_completed.emit(occupant_id, action, handler_id, state.duplicate(true))
	return {"ok": true, "animal_id": occupant_id, "care": state.duplicate(true), "resources_remaining": resources.duplicate(true)}


const HORSE_CARE_DURATIONS := {
	"water": 20.0, "feed": 20.0, "groom": 90.0, "tether": 15.0, "rest": 0.0
}


## Build a deterministic evening chore queue for horses actually registered at
## camp. A single suitable worker handles each horse's sequence; residents and
## followers remain independent of party capacity.
func _plan_horse_care_tasks() -> void:
	animal_care_tasks.clear()
	var assigned_handlers: Dictionary = {}
	for animal in occupants_of_kind("animal"):
		var species := String(animal.get("species", "")).to_lower()
		if species not in ["horse", "equine"]:
			continue
		var animal_id := String(animal.get("occupant_id", ""))
		_ensure_horse_care_state(animal_id)
		var handler_id := _select_horse_care_handler(assigned_handlers)
		if handler_id.is_empty():
			for action in ["water", "feed", "groom", "tether", "rest"]:
				animal_care_tasks.append(_new_horse_care_task(animal_id, action, "", "pending"))
			continue
		assigned_handlers[handler_id] = true
		for action in ["water", "feed", "groom", "tether", "rest"]:
			var initial_status := "pending"
			if action == "tether" and not bool(site.get("safe_tethering", environment.get("safe_tethering", false))):
				initial_status = "blocked"
			animal_care_tasks.append(_new_horse_care_task(animal_id, action, handler_id, initial_status))
		_activate_next_horse_care_task(animal_id)


func _new_horse_care_task(animal_id: String, action: String, handler_id: String, status: String) -> Dictionary:
	return {
		"task_id": "%s:%s" % [animal_id, action], "animal_id": animal_id,
		"action": action, "handler_id": handler_id, "status": status,
		"duration_world_seconds": float(HORSE_CARE_DURATIONS.get(action, 0.0)),
		"elapsed_world_seconds": 0.0, "blocked_reason": ""
	}


func _select_horse_care_handler(already_assigned: Dictionary) -> String:
	var candidates: Array[Dictionary] = []
	for occupant_id_value in occupants:
		var occupant_id := String(occupant_id_value)
		var occupant: Dictionary = occupants[occupant_id]
		if not bool(occupant.get("can_work", false)) or already_assigned.has(occupant_id):
			continue
		if String(occupant.get("kind", "")) == "animal" or String(occupant.get("kind", "")) == "guest":
			continue
		var current: Dictionary = assignments.get(occupant_id, {})
		if bool(current.get("player_override", false)):
			continue
		var score := 0.0
		if occupant_id == String(environment.get("player_character_id", "")):
			score -= 100.0
		var kind := String(occupant.get("kind", ""))
		if kind == "resident":
			score += 12.0
		elif kind == "follower":
			score += 6.0
		elif kind == "party_member":
			score += 1.0
		var occupation := String(occupant.get("occupation", occupant.get("role", ""))).to_lower()
		if occupation in ["stablehand", "groom", "horsekeeper", "ostler"]:
			score += 12.0
		var condition: Dictionary = conditions.get(occupant_id, {})
		score -= float(condition.get("fatigue", 0.0)) * 0.08
		if bool(condition.get("injured", false)):
			score -= 8.0
		candidates.append({"id": occupant_id, "score": score, "kind": kind})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.score), float(b.score)):
			return float(a.score) > float(b.score)
		return String(a.id) < String(b.id)
	)
	return String(candidates[0].id) if not candidates.is_empty() else ""


func _activate_next_horse_care_task(animal_id: String) -> void:
	var preferred_handler := ""
	for task in animal_care_tasks:
		if String(task.get("animal_id", "")) == animal_id and not String(task.get("handler_id", "")).is_empty():
			preferred_handler = String(task.get("handler_id", ""))
			break
	_activate_horse_care_task_for_handler(animal_id, preferred_handler)


func _activate_horse_care_task_for_handler(animal_id: String, preferred_handler: String) -> void:
	for index in range(animal_care_tasks.size()):
		var task: Dictionary = animal_care_tasks[index]
		if String(task.get("animal_id", "")) != animal_id:
			continue
		if String(task.get("status", "")) in ["completed", "blocked"]:
			continue
		var handler_id := String(task.get("handler_id", preferred_handler))
		var action := String(task.get("action", ""))
		if action == "rest":
			task["status"] = "in_progress"
			task["blocked_reason"] = ""
			animal_care_tasks[index] = task
			var rest_result := perform_animal_care(animal_id, "rest", "")
			task["status"] = "completed" if bool(rest_result.get("ok", false)) else "blocked"
			animal_care_tasks[index] = task
			continue
		if action == "water" and int(resources.get("water", 0)) <= 0:
			task["status"] = "pending"
			task["blocked_reason"] = "awaiting_water"
			animal_care_tasks[index] = task
			continue
		if action == "feed" and int(resources.get("fodder", 0)) <= 0:
			task["status"] = "pending"
			task["blocked_reason"] = "awaiting_fodder"
			animal_care_tasks[index] = task
			continue
		if handler_id.is_empty():
			task["status"] = "blocked"
			task["blocked_reason"] = "no_available_handler"
			animal_care_tasks[index] = task
			continue
		task["status"] = "in_progress"
		task["blocked_reason"] = ""
		animal_care_tasks[index] = task
		var activity := "care_horse_" + action
		var current: Dictionary = assignments.get(handler_id, {})
		if not _default_assignments.has(handler_id):
			_default_assignments[handler_id] = current.duplicate(true) if not current.is_empty() else {
				"activity": "socialise", "player_override": false, "override_remaining": 0.0
			}
		assignments[handler_id] = {
			"activity": activity, "player_override": false, "override_remaining": 0.0,
			"animal_care_task": true, "animal_id": animal_id, "care_action": action
		}
		activity_assigned.emit(handler_id, activity)
		return
	_restore_horse_care_handler(animal_id)


func _restore_horse_care_handler(animal_id: String) -> void:
	for task in animal_care_tasks:
		if String(task.get("animal_id", "")) != animal_id:
			continue
		var handler_id := String(task.get("handler_id", ""))
		if handler_id.is_empty():
			continue
		var current: Dictionary = assignments.get(handler_id, {})
		if bool(current.get("animal_care_task", false)) and String(current.get("animal_id", "")) == animal_id:
			var fallback: Dictionary = _default_assignments.get(handler_id, {"activity": "socialise", "player_override": false, "override_remaining": 0.0})
			assignments[handler_id] = fallback.duplicate(true)
			activity_assigned.emit(handler_id, String(fallback.get("activity", "socialise")))
		return


func _advance_animal_care_tasks(world_delta: float) -> void:
	if world_delta <= 0.0:
		return
	var animal_ids: Dictionary = {}
	for task in animal_care_tasks:
		animal_ids[String(task.get("animal_id", ""))] = true
	for animal_id_value in animal_ids:
		_advance_horse_care_sequence(String(animal_id_value), world_delta)


func _advance_horse_care_sequence(animal_id: String, world_delta: float) -> void:
	var remaining_world_seconds := world_delta
	var safety_counter := 0
	while remaining_world_seconds > 0.0 and safety_counter < animal_care_tasks.size() + 2:
		safety_counter += 1
		var active_index := -1
		for index in range(animal_care_tasks.size()):
			var candidate: Dictionary = animal_care_tasks[index]
			if String(candidate.get("animal_id", "")) == animal_id and String(candidate.get("status", "")) == "in_progress":
				active_index = index
				break
		if active_index < 0:
			_activate_next_horse_care_task(animal_id)
			for index in range(animal_care_tasks.size()):
				var candidate: Dictionary = animal_care_tasks[index]
				if String(candidate.get("animal_id", "")) == animal_id and String(candidate.get("status", "")) == "in_progress":
					active_index = index
					break
		if active_index < 0:
			return
		var task: Dictionary = animal_care_tasks[active_index]
		var handler_id := String(task.get("handler_id", ""))
		var handler_assignment: Dictionary = assignments.get(handler_id, {})
		if not bool(handler_assignment.get("animal_care_task", false)) or String(handler_assignment.get("animal_id", "")) != animal_id:
			if bool(handler_assignment.get("player_override", false)):
				return
			_activate_horse_care_task_for_handler(animal_id, handler_id)
			handler_assignment = assignments.get(handler_id, {})
			if not bool(handler_assignment.get("animal_care_task", false)):
				return
		var duration := float(task.get("duration_world_seconds", 0.0))
		var elapsed := float(task.get("elapsed_world_seconds", 0.0))
		var needed := maxf(0.0, duration - elapsed)
		var spent := minf(remaining_world_seconds, needed)
		task["elapsed_world_seconds"] = elapsed + spent
		remaining_world_seconds -= spent
		if float(task.get("elapsed_world_seconds", 0.0)) + 0.0001 < duration:
			animal_care_tasks[active_index] = task
			return
		var result := perform_animal_care(animal_id, String(task.get("action", "")), handler_id)
		if bool(result.get("ok", false)):
			task["status"] = "completed"
			task["blocked_reason"] = ""
		else:
			task["status"] = "blocked"
			task["blocked_reason"] = String(result.get("reason", "care_failed"))
		animal_care_tasks[active_index] = task
		_activate_next_horse_care_task(animal_id)


func horse_care_schedule_for(occupant_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for task in animal_care_tasks:
		if String(task.get("animal_id", "")) == occupant_id:
			result.append(task.duplicate(true))
	return result


func horse_care_for(occupant_id: String) -> Dictionary:
	return (animal_care.get(occupant_id, {}) as Dictionary).duplicate(true)


func remove_camp_occupant(occupant_id: String) -> Dictionary:
	if not occupants.has(occupant_id):
		return {"ok": false, "reason": "occupant_not_found"}
	if party_ids.has(occupant_id):
		return {"ok": false, "reason": "cannot_remove_party_member"}
	var removed: Dictionary = occupants[occupant_id]
	var removed_kind := String(removed.get("kind", ""))
	var affected_animals: Dictionary = {}
	if removed_kind == "animal":
		_restore_horse_care_handler(occupant_id)
		var remaining_tasks: Array[Dictionary] = []
		for task in animal_care_tasks:
			if String(task.get("animal_id", "")) != occupant_id:
				remaining_tasks.append(task)
		animal_care_tasks = remaining_tasks
		animal_care.erase(occupant_id)
	else:
		for task in animal_care_tasks:
			if String(task.get("handler_id", "")) != occupant_id:
				continue
			if String(task.get("status", "")) in ["pending", "in_progress"]:
				affected_animals[String(task.get("animal_id", ""))] = true
				if String(task.get("status", "")) == "in_progress":
					task["status"] = "pending"
					task["blocked_reason"] = "handler_departed"
			task["handler_id"] = ""
		assignments.erase(occupant_id)
		_default_assignments.erase(occupant_id)
	conditions.erase(occupant_id)
	companion_profiles.erase(occupant_id)
	occupants.erase(occupant_id)
	for animal_id_value in affected_animals:
		var animal_id := String(animal_id_value)
		var replacement_handler := _select_horse_care_handler({})
		for index in range(animal_care_tasks.size()):
			var task: Dictionary = animal_care_tasks[index]
			if String(task.get("animal_id", "")) != animal_id or String(task.get("status", "")) in ["completed", "blocked"]:
				continue
			task["handler_id"] = replacement_handler
			animal_care_tasks[index] = task
		if not replacement_handler.is_empty():
			_activate_next_horse_care_task(animal_id)
	return {"ok": true}


func occupant_for(occupant_id: String) -> Dictionary:
	return (occupants.get(occupant_id, {}) as Dictionary).duplicate(true)


func occupants_of_kind(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for occupant_id in occupants:
		var occupant: Dictionary = occupants[occupant_id]
		if String(occupant.get("kind", "")) == kind:
			result.append(occupant.duplicate(true))
	return result


func _plan_initial_activities() -> void:
	var available := party_ids.duplicate()
	if resources.wood <= 0 and bool(environment.get("trees_nearby", false)):
		_assign_from_pool(available, "gather_wood", 1)
	var outdoor_sleepers := maxi(0, party_ids.size() - _indoor_sleeping_capacity())
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
	var world_delta := real_delta * EXPLORATION_SECONDS_PER_REAL_SECOND
	_advance_companion_fatigue(world_delta)
	_advance_animal_care_tasks(world_delta)
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
			"care_horse_water", "care_horse_feed", "care_horse_tether":
				fatigue_rate = 0.008
			"care_horse_groom":
				fatigue_rate = 0.005
		condition["fatigue"] = clampf(float(condition.get("fatigue", 40.0)) + fatigue_rate * world_delta, 0.0, 100.0)
		conditions[character_id] = condition


func _advance_evening_routines(stage: int) -> void:
	if stage == 1 and not _preparations_completed:
		_complete_evening_preparations()
		_preparations_completed = true
	for character_id in party_ids:
		var current: Dictionary = assignments.get(character_id, {})
		if bool(current.get("animal_care_task", false)):
			continue
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
	var has_dwelling := not lodging_profile.is_empty() and bool(lodging_profile.get("is_sheltered", true))
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


func update_weather(weather_data: Dictionary) -> void:
	for key in WEATHER_CONTEXT_KEYS:
		environment.erase(key)
	environment.merge(weather_data, true)
	if phase != "evening" or routine_stage < 1:
		return
	for character_id in party_ids:
		var current: Dictionary = assignments.get(character_id, {})
		var next_activity := _routine_activity_for(character_id, routine_stage)
		if bool(current.get("animal_care_task", false)):
			continue
		if bool(current.get("player_override", false)):
			_default_assignments[character_id] = {
				"activity": next_activity, "player_override": false, "override_remaining": 0.0
			}
		elif not bool(current.get("animal_care_task", false)) and String(current.get("activity", "")) != next_activity:
			_set_assignment(character_id, next_activity)


func _weather_is_severe() -> bool:
	return (
		bool(environment.get("storm", false))
		or bool(environment.get("heavy_rain", false))
		or bool(environment.get("snow", false))
		or float(environment.get("wind_speed", 0.0)) >= 45.0
		or float(environment.get("rain_intensity", 0.0)) >= 0.7
		or float(environment.get("night_temperature_c", 10.0)) <= 2.0
	)


func _indoor_sleeping_capacity() -> int:
	if not bool(lodging_profile.get("is_sheltered", true)):
		return 0
	return maxi(0, int(lodging_profile.get("sleeping_capacity", 0))) + _indoor_floor_capacity()


func _indoor_floor_capacity() -> int:
	if not bool(lodging_profile.get("is_sheltered", true)):
		return 0
	if lodging_profile.has("indoor_floor_capacity"):
		return maxi(0, int(lodging_profile.get("indoor_floor_capacity", 0)))
	var floor_size_value: Variant = lodging_profile.get("floor_size", Vector2.ZERO)
	if not floor_size_value is Vector2:
		return 0
	var floor_size: Vector2 = floor_size_value
	var floor_count := maxi(1, int(lodging_profile.get("floor_count", 1)))
	var floor_area: float = floor_size.x * floor_size.y * float(floor_count)
	# Allow one person per 8 m² of gross floor area, leaving room for
	# circulation, stairs and existing non-sleeping furniture.
	return maxi(0, floori(floor_area / 8.0))


func plan_sleeping_arrangements(tent_count: int, bonds: CompanionBondState = null) -> Array[Dictionary]:
	sleeping_arrangements.clear()
	var remaining := party_ids.duplicate()
	var beds_available := mini(maxi(0, int(lodging_profile.get("sleeping_capacity", 0))), remaining.size())
	if not bool(lodging_profile.get("is_sheltered", true)):
		beds_available = 0
	var bags_remaining := int(resources.sleeping_bags)
	for _index in range(beds_available):
		var bed_user := String(remaining.pop_front())
		sleeping_arrangements.append({
			"tent_index": -2, "shelter_type": "dwelling", "sleeping_surface": "bed",
			"dwelling_id": String(lodging_profile.get("dwelling_id", "")),
			"character_ids": [bed_user], "sleeping_bag_character_ids": [],
			"comfort_penalty": 0
		})
	var floor_sleepers := mini(_indoor_floor_capacity(), remaining.size())
	for _index in range(floor_sleepers):
		var floor_user := String(remaining.pop_front())
		var has_floor_bag := bags_remaining > 0
		if has_floor_bag:
			bags_remaining -= 1
		sleeping_arrangements.append({
			"tent_index": -2, "shelter_type": "dwelling", "sleeping_surface": "floor",
			"dwelling_id": String(lodging_profile.get("dwelling_id", "")),
			"character_ids": [floor_user],
			"sleeping_bag_character_ids": [floor_user] if has_floor_bag else [],
			"comfort_penalty": 8 if not has_floor_bag else 3
		})
	var tent_limit := mini(maxi(0, tent_count), ceili(float(remaining.size()) / float(TENT_COMFORTABLE_CAPACITY)))
	var next_tent_index := 0
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
			"tent_index": next_tent_index, "shelter_type": "tent",
			"sleeping_surface": "ground",
			"character_ids": group,
			"sleeping_bag_character_ids": bag_users,
			"comfort_penalty": maxi(0, group.size() - TENT_COMFORTABLE_CAPACITY) * 10
		})
		next_tent_index += 1
		tent_limit -= 1
	for character_id in remaining:
		var has_bag := bags_remaining > 0
		if has_bag:
			bags_remaining -= 1
		sleeping_arrangements.append({
			"tent_index": -1, "shelter_type": "open_air", "sleeping_surface": "ground",
			"character_ids": [character_id],
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
	night_index += 1
	night_watch_schedule = _build_night_watch_schedule(DEFAULT_NIGHT_HOURS)
	night_encounter_result.clear()
	var first_shift_watchers: Array = night_watch_schedule[0].get("watcher_ids", []) if not night_watch_schedule.is_empty() else []
	for character_id in party_ids:
		_set_assignment(character_id, "watch" if first_shift_watchers.has(character_id) else "sleep")
	return {"ok": true, "watchers": _count_watchers(), "watch_schedule": night_watch_schedule.duplicate(true)}


## Split the night into three watches. The schedule rotates across the whole
## party where possible; the same companion is not kept awake for every shift.
func _build_night_watch_schedule(hours: float) -> Array[Dictionary]:
	var schedule: Array[Dictionary] = []
	var slots := watch_slots_for_party(party_ids.size())
	if slots <= 0:
		return schedule
	var candidates := party_ids.duplicate()
	candidates.sort_custom(func(a: String, b: String) -> bool:
		var score_a := _watcher_selection_score(a)
		var score_b := _watcher_selection_score(b)
		if not is_equal_approx(score_a, score_b):
			return score_a > score_b
		return a < b
	)
	var shift_count := 3
	var shift_hours := hours / float(shift_count)
	var rotation_offset := (night_index - 1) % maxi(1, candidates.size())
	for shift_index in range(shift_count):
		var selected: Array[String] = []
		var cursor := (rotation_offset + shift_index * slots) % maxi(1, candidates.size())
		var attempts := 0
		while selected.size() < slots and attempts < candidates.size() * 2:
			var candidate := String(candidates[cursor % candidates.size()])
			if not selected.has(candidate):
				selected.append(candidate)
			cursor += 1
			attempts += 1
		schedule.append({
			"shift_index": shift_index,
			"start_hour": float(shift_index) * shift_hours,
			"end_hour": float(shift_index + 1) * shift_hours,
			"watcher_ids": selected
		})
	return schedule


func _watcher_selection_score(character_id: String) -> float:
	var profile: Dictionary = companion_profiles.get(character_id, {})
	var skills: Dictionary = profile.get("skills", {}) if profile.get("skills", {}) is Dictionary else {}
	var perception := float(profile.get("perception", skills.get("perception", skills.get("awareness", 0.0))))
	var condition: Dictionary = conditions.get(character_id, {})
	var fatigue := float(condition.get("fatigue", 40.0))
	return perception * 2.0 - fatigue * 0.05


func _watch_hours_by_character(hours: float) -> Dictionary:
	var totals: Dictionary = {}
	for shift in night_watch_schedule:
		var duration := maxf(0.0, float(shift.get("end_hour", 0.0)) - float(shift.get("start_hour", 0.0)))
		for watcher_id in shift.get("watcher_ids", []):
			var key := String(watcher_id)
			totals[key] = float(totals.get(key, 0.0)) + duration
	return totals


func _resolve_night_threat(ambush_chance: float) -> Dictionary:
	var seed_value := int(environment.get("night_seed", 0))
	if seed_value == 0:
		var seed_text := String(site.get("site_id", site.get("location_id", "camp")))
		for character_id in party_ids:
			seed_text += ":" + character_id
		seed_value = int(seed_text.hash()) + night_index * 7919
	if seed_value == 0:
		seed_value = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var attack_roll := rng.randf()
	var attacked := attack_roll < ambush_chance
	if not attacked:
		return {"attacked": false, "detected": false, "attack_roll": attack_roll, "detection_chance": 0.0, "seed": seed_value}
	var best_detection := 0.0
	var detecting_watcher := ""
	var visibility := clampf(float(environment.get("visibility_multiplier", 1.0)), 0.1, 1.5)
	if bool(environment.get("fog", false)) or bool(environment.get("heavy_rain", false)):
		visibility *= 0.7
	for shift in night_watch_schedule:
		for watcher_value in shift.get("watcher_ids", []):
			var watcher_id := String(watcher_value)
			var profile: Dictionary = companion_profiles.get(watcher_id, {})
			var skills: Dictionary = profile.get("skills", {}) if profile.get("skills", {}) is Dictionary else {}
			var perception := float(profile.get("perception", skills.get("perception", skills.get("awareness", 0.0))))
			var fatigue := float(conditions.get(watcher_id, {}).get("fatigue", 40.0))
			var chance := clampf((0.35 + perception * 0.05 - fatigue * 0.002) * visibility, 0.05, 0.9)
			if chance > best_detection:
				best_detection = chance
				detecting_watcher = watcher_id
		var detection_roll := rng.randf()
		if detection_roll < best_detection:
			return {"attacked": true, "detected": true, "attack_roll": attack_roll, "detection_roll": detection_roll, "detection_chance": best_detection, "watcher_id": detecting_watcher, "seed": seed_value}
	return {"attacked": true, "detected": false, "attack_roll": attack_roll, "detection_roll": 1.0, "detection_chance": best_detection, "watcher_id": detecting_watcher, "seed": seed_value}


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
	var base_ambush_chance := clampf(danger * 0.45 - float(watchers) * 0.07, 0.0, 0.45)
	var exposure_total := 0.0
	for arrangement in sleeping_arrangements:
		var exposure := 1.0
		match String(arrangement.get("shelter_type", "open_air")):
			"dwelling":
				exposure = 0.0
			"tent":
				exposure = 0.65
		exposure_total += exposure * (arrangement.get("character_ids", []) as Array).size()
	var exposure_ratio := exposure_total / float(maxi(1, party_size))
	# A solid dwelling substantially reduces exposure; tents provide partial cover.
	var shelter_multiplier := 0.35 + 0.65 * exposure_ratio
	var ambush_chance := base_ambush_chance * shelter_multiplier
	var threat_result := _resolve_night_threat(ambush_chance)
	night_encounter_result = threat_result.duplicate(true)
	var watch_hours_by_character := _watch_hours_by_character(night_hours)
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
		var sleeping_surface := "ground"
		for arrangement in sleeping_arrangements:
			if (arrangement.get("character_ids", []) as Array).has(character_id):
				in_tent = int(arrangement.get("tent_index", -1)) >= 0
				in_dwelling = String(arrangement.get("shelter_type", "")) == "dwelling"
				sleeping_surface = String(arrangement.get("sleeping_surface", "ground"))
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
		var surface_comfort := 10.0 if sleeping_surface == "bed" else (3.0 if has_sleeping_bag else 0.0)
		var comfort := clampf((warmth * 0.23 + nutrition * 0.18 + hydration * 0.14 + security * 0.15 + sleep_quality * 0.20 + social * 0.10) + dwelling_comfort + surface_comfort, 0.0, 100.0)
		var watched_hours := float(watch_hours_by_character.get(character_id, 0.0))
		var watch_penalty := clampf(watched_hours / maxf(1.0, night_hours) * 10.0, 0.0, 10.0)
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
			"fatigue_recovered": fatigue_recovered,
			"sleeping_surface": sleeping_surface,
			"shelter_type": "dwelling" if in_dwelling else ("tent" if in_tent else "open_air")
		}
	phase = "resolved"
	var summary := {
		"hours": night_hours, "party_size": party_size, "watchers": watchers,
		"ambush_chance": ambush_chance, "base_ambush_chance": base_ambush_chance,
		"night_index": night_index, "watch_schedule": night_watch_schedule.duplicate(true),
		"night_encounter": threat_result.duplicate(true),
		"exposure_ratio": exposure_ratio, "shelter_multiplier": shelter_multiplier,
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
		"companion_profiles": companion_profiles.duplicate(true),
		"occupants": occupants.duplicate(true), "animal_care": animal_care.duplicate(true),
		"animal_care_tasks": animal_care_tasks.duplicate(true),
		"night_index": night_index, "night_watch_schedule": night_watch_schedule.duplicate(true),
		"night_encounter_result": night_encounter_result.duplicate(true)
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
	var saved_occupants: Variant = data.get("occupants", {})
	var saved_animal_care: Variant = data.get("animal_care", {})
	var saved_animal_care_tasks: Variant = data.get("animal_care_tasks", [])
	if not saved_animal_care_tasks is Array:
		return false
	if not saved_animal_care is Dictionary:
		return false
	if not saved_party is Array or not saved_conditions is Dictionary or not saved_assignments is Dictionary or not saved_resources is Dictionary or not saved_lodging is Dictionary or not saved_profiles is Dictionary or not saved_occupants is Dictionary:
		return false
	var ids: Array[String] = []
	for value in saved_party:
		var character_id := String(value)
		if character_id.is_empty() or ids.has(character_id):
			return false
		ids.append(character_id)
	for character_id in saved_assignments:
		if (not ids.has(String(character_id)) and not saved_occupants.has(character_id)) or not saved_assignments[character_id] is Dictionary:
			return false
	for character_id in saved_conditions:
		if String(character_id).is_empty() or not saved_conditions[character_id] is Dictionary:
			return false
	for task in saved_animal_care_tasks:
		if not task is Dictionary or String(task.get("animal_id", "")).is_empty() or not saved_occupants.has(String(task.get("animal_id", ""))):
			return false
		if not ["water", "feed", "groom", "tether", "rest"].has(String(task.get("action", ""))):
			return false
		if not ["pending", "in_progress", "completed", "blocked"].has(String(task.get("status", ""))):
			return false
		var task_animal: Dictionary = saved_occupants[String(task.get("animal_id", ""))]
		if String(task_animal.get("kind", "")) != "animal" or String(task_animal.get("species", "")).to_lower() not in ["horse", "equine"]:
			return false
		var task_handler := String(task.get("handler_id", ""))
		if not task_handler.is_empty() and (not saved_occupants.has(task_handler) or not bool(saved_occupants[task_handler].get("can_work", false))):
			return false
	for care_id in saved_animal_care:
		if not saved_occupants.has(care_id) or not saved_animal_care[care_id] is Dictionary:
			return false
		var care_occupant: Dictionary = saved_occupants[care_id]
		if String(care_occupant.get("kind", "")) != "animal" or String(care_occupant.get("species", "")).to_lower() not in ["horse", "equine"]:
			return false
	for occupant_id in saved_occupants:
		var occupant: Variant = saved_occupants[occupant_id]
		if not occupant is Dictionary or String(occupant.get("occupant_id", "")) != String(occupant_id):
			return false
		if not OCCUPANT_KINDS.has(String(occupant.get("kind", ""))):
			return false
		if bool(occupant.get("participates_in_party", false)) != ids.has(String(occupant_id)):
			return false
		if (String(occupant.get("kind", "")) == "party_member") != ids.has(String(occupant_id)):
			return false
	if not saved_occupants.is_empty():
		for character_id in ids:
			if not saved_occupants.has(character_id):
				return false
	phase = saved_phase
	night_index = maxi(0, int(data.get("night_index", 0)))
	night_watch_schedule.clear()
	var saved_watch_schedule: Variant = data.get("night_watch_schedule", [])
	if not saved_watch_schedule is Array:
		return false
	for shift in saved_watch_schedule:
		if not shift is Dictionary or not shift.get("watcher_ids", []) is Array:
			return false
		for watcher_id in shift.get("watcher_ids", []):
			if not ids.has(String(watcher_id)):
				return false
		night_watch_schedule.append(shift.duplicate(true))
	night_encounter_result = data.get("night_encounter_result", {}).duplicate(true)
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
	occupants = saved_occupants.duplicate(true)
	animal_care = saved_animal_care.duplicate(true)
	animal_care_tasks.clear()
	for task in saved_animal_care_tasks:
		animal_care_tasks.append(task.duplicate(true))
	for occupant_id in occupants:
		var occupant: Dictionary = occupants[occupant_id]
		if String(occupant.get("kind", "")) == "animal" and String(occupant.get("species", "")).to_lower() in ["horse", "equine"]:
			_ensure_horse_care_state(String(occupant_id))
	if occupants.is_empty() and not party_ids.is_empty():
		for character_id in party_ids:
			register_camp_occupant({
				"occupant_id": character_id, "kind": "party_member", "species": "humanoid",
				"participates_in_party": true, "can_sleep": true, "can_work": true
			})
	return true
