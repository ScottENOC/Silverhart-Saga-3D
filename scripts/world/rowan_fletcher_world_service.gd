class_name RowanFletcherWorldService
extends Node

const INVALID_HEX := Vector2i(2147483647, 2147483647)
const RELATIONSHIP_STORE = preload("res://scripts/simulation/persistent_character_relationship_store.gd")
const ENCOUNTER_CONTENT = preload("res://scripts/simulation/rowan_fletcher_encounter_content.gd")

var simulation: WorldSimulation
var camp_activity_director: CampPartyActivityDirector
var show_dialogue: Callable
var roaming_hex: Vector2i = INVALID_HEX
var return_accumulator: float = 0.0
var return_busy: bool = false

func configure(world_simulation: WorldSimulation, activity_director: CampPartyActivityDirector, dialogue_callback: Callable) -> void:
	simulation = world_simulation
	camp_activity_director = activity_director
	show_dialogue = dialogue_callback

func visit_key() -> String:
	var site_hex: Variant = simulation.camp_simulation.site.get("hex", Vector2i.ZERO)
	var camp_hex: Vector2i = site_hex if site_hex is Vector2i else Vector2i.ZERO
	var world_day := int(floor(simulation.clock.world_seconds / 86400.0))
	return "%d:%d:%d" % [world_day, camp_hex.x, camp_hex.y]

func show_camp_encounter() -> void:
	if simulation.camp_simulation.phase != "evening":
		show_dialogue.call("Rowan Fletcher", "Rowan gives you a friendly nod. “We seem to keep crossing paths. Perhaps we’ll share a fire one evening, when you’ve made camp.”", [{"id": "continue", "label": "Until next time.", "text": ""}])
		return
	var relationships := RELATIONSHIP_STORE.state_for(simulation)
	var encounter := ENCOUNTER_CONTENT.build_encounter(relationships, {
		"camp_active": true, "rowan_nearby": true, "visit_key": visit_key()
	})
	if not bool(encounter.get("ok", false)) or not bool(encounter.get("available", false)):
		show_dialogue.call("Rowan Fletcher", "Rowan smiles and says he’ll leave you to your evening.", [{"id": "continue", "label": "Good night.", "text": ""}])
		return
	var choices: Array[Dictionary] = []
	for value in encounter.get("choices", []):
		if not value is Dictionary:
			continue
		var choice: Dictionary = value.duplicate(true)
		choice["rowan_choice_id"] = String(choice.get("id", ""))
		choice["rowan_visit_key"] = String(encounter.get("visit_key", ""))
		choice["id"] = "rowan_camp:" + String(choice.get("id", ""))
		choices.append(choice)
	show_dialogue.call(String(encounter.get("speaker", "Rowan Fletcher")), String(encounter.get("text", "")), choices)

func resolve_camp_choice(choice: Dictionary) -> void:
	if simulation == null or simulation.camp_simulation.phase != "evening":
		show_dialogue.call("Rowan Fletcher", "The evening has moved on. Perhaps another time.", [{"id": "continue", "label": "Understood.", "text": ""}])
		return
	var relationships := RELATIONSHIP_STORE.state_for(simulation)
	var choice_id := String(choice.get("rowan_choice_id", ""))
	var outcome := ENCOUNTER_CONTENT.resolve_choice(relationships, String(choice.get("rowan_visit_key", "")), choice_id)
	if not bool(outcome.get("ok", false)):
		show_dialogue.call("Rowan Fletcher", "That conversation cannot be resolved just now.", [{"id": "continue", "label": "Continue", "text": ""}])
		return
	if not bool(outcome.get("accepted_overnight_stay", false)):
		show_dialogue.call("Rowan Fletcher", "“No hard feelings. Safe roads to you.”", [{"id": "continue", "label": "Safe travels.", "text": ""}])
		return
	var guest: Dictionary = outcome.get("camp_occupant", {}).duplicate(true)
	var registered := simulation.camp_simulation.register_camp_occupant(guest)
	if not bool(registered.get("ok", false)):
		show_dialogue.call("Rowan Fletcher", "I’m sorry — there isn’t a safe place for me to settle tonight. We’ll try another time.", [{"id": "continue", "label": "Of course.", "text": ""}])
		return
	var rowan_state := simulation.get_character("rowan_fletcher")
	if rowan_state != null and roaming_hex == INVALID_HEX:
		roaming_hex = rowan_state.axial
	simulation.camp_simulation.assignments["rowan_fletcher"] = {"activity": "socialise", "source": "overnight_guest"}
	camp_activity_director.begin_camp(simulation.camp_simulation.site)
	var response_line := "“Thank you. I’ll keep out of the way and be gone before first light.”"
	match choice_id:
		"ask_about_travels":
			response_line = "Rowan tells you about the villages and hunting trails he has crossed since you last met. The stories stretch on until the fire burns low; he asks if he may stay the night."
		"share_stories":
			response_line = "You trade stories beside the fire. Rowan seems reluctant to let the conversation end, but eventually asks where he might bed down for the night."
		"warm_greeting":
			response_line = "His smile lingers. “I was hoping you might say that. It’s good to see you again.” He settles beside the fire."
		"guarded_welcome":
			response_line = "Rowan accepts your terms without argument and chooses a place where he won’t get in the way."
	show_dialogue.call("Rowan Fletcher", response_line, [{"id": "continue", "label": "Make yourself at home.", "text": ""}])

func process(delta: float) -> void:
	if roaming_hex == INVALID_HEX or return_busy or simulation == null:
		return
	if simulation.camp_simulation.occupants.has("rowan_fletcher") or simulation.camp_simulation.phase not in ["morning", "resolved", "inactive"]:
		return
	return_accumulator += delta
	if return_accumulator < 1.0:
		return
	return_accumulator = 0.0
	return_after_night()

func return_after_night() -> void:
	if roaming_hex == INVALID_HEX or simulation == null or return_busy:
		return
	if simulation.camp_simulation.occupants.has("rowan_fletcher"):
		return
	var rowan_state := simulation.get_character("rowan_fletcher")
	if rowan_state == null:
		roaming_hex = INVALID_HEX
		return
	return_busy = true
	camp_activity_director.stop()
	var destination := roaming_hex
	var path := simulation.find_path("rowan_fletcher", destination)
	if path.size() > 1:
		for step_index in range(1, path.size()):
			if not simulation.try_move_character_step("rowan_fletcher", path[step_index]):
				return_busy = false
				return
			await get_tree().create_timer(0.16).timeout
			if not is_instance_valid(self):
				return
	if rowan_state.axial == destination:
		roaming_hex = INVALID_HEX
		if simulation.camp_simulation.phase in ["morning", "resolved"]:
			camp_activity_director.begin_camp(simulation.camp_simulation.site)
	return_busy = false
