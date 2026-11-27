class_name CampLifecycleController
extends Node

var simulation: WorldSimulation
var camp_presentation: CampWorldPresentation
var camp_activity_director: CampPartyActivityDirector
var sleep_button: Button
var status_label: Label
var return_rowan: Callable
var encounter_active: Callable

func configure(
	world_simulation: WorldSimulation,
	presentation: CampWorldPresentation,
	activity_director: CampPartyActivityDirector,
	button: Button,
	label: Label,
	rowan_return_callback: Callable,
	encounter_active_callback: Callable
) -> void:
	simulation = world_simulation
	camp_presentation = presentation
	camp_activity_director = activity_director
	sleep_button = button
	status_label = label
	return_rowan = rowan_return_callback
	encounter_active = encounter_active_callback

func restore_saved_camp() -> void:
	if simulation == null or simulation.camp_simulation.phase not in ["evening", "night", "interrupted", "morning", "resolved"]:
		return
	camp_presentation.present_camp(simulation.camp_simulation.site, simulation.camp_simulation.sleeping_arrangements, simulation.camp_simulation.environment)
	if simulation.camp_simulation.phase == "evening":
		camp_activity_director.begin_camp(simulation.camp_simulation.site)
	sync_sleep_button_state()

func sync_sleep_button_state() -> void:
	if sleep_button == null or simulation == null:
		return
	var phase := simulation.camp_simulation.phase
	sleep_button.visible = phase in ["evening", "night", "interrupted", "morning", "resolved"]
	sleep_button.disabled = phase == "morning"
	match phase:
		"evening":
			sleep_button.text = "Sleep until morning"
		"night":
			sleep_button.text = "Pack camp"
		"interrupted":
			sleep_button.text = "Continue sleeping"
		"morning":
			sleep_button.text = "Morning routine…"
		"resolved":
			sleep_button.text = "Pack camp"
		"inactive":
			sleep_button.text = ""

func camp_established() -> void:
	sync_sleep_button_state()

func sleep_or_pack() -> void:
	if simulation == null or simulation.is_in_combat:
		return
	if simulation.camp_simulation.phase == "evening":
		camp_activity_director.stop()
		var result := simulation.skip_camp_to_morning()
		if not bool(result.get("ok", false)):
			status_label.text = "Could not begin the night: %s" % String(result.get("reason", "unknown"))
			sync_sleep_button_state()
			return
		var summary: Dictionary = result.get("summary", {})
		if not bool(summary.get("sleep_interrupted", false)):
			await return_rowan.call()
		camp_presentation.present_camp(simulation.camp_simulation.site, simulation.camp_simulation.sleeping_arrangements, simulation.camp_simulation.environment)
		if encounter_active.is_valid() and bool(encounter_active.call()):
			status_label.text = "Night ambush! The party has been roused to defend the camp."
			sync_sleep_button_state()
			return
		status_label.text = "Morning. Camp comfort: %d/100 · estimated overnight ambush risk: %d%%." % [
			roundi(float(summary.get("average_comfort", 0.0))),
			roundi(float(summary.get("ambush_chance", 0.0)) * 100.0)
		]
	elif simulation.camp_simulation.phase == "interrupted":
		camp_activity_director.stop()
		var resumed := simulation.continue_camp_sleep()
		if not bool(resumed.get("ok", false)):
			status_label.text = "Could not resume sleep: %s" % String(resumed.get("reason", "unknown"))
			sync_sleep_button_state()
			return
		var resumed_summary: Dictionary = resumed.get("summary", {})
		await return_rowan.call()
		camp_presentation.present_camp(simulation.camp_simulation.site, simulation.camp_simulation.sleeping_arrangements, simulation.camp_simulation.environment)
		status_label.text = "Morning. The party completed the remaining %.1f hours of sleep." % float(resumed_summary.get("hours", 0.0))
	elif simulation.camp_simulation.phase == "resolved":
		camp_activity_director.stop()
		camp_presentation.clear_camp()
		status_label.text = "Camp packed. Ready to continue travelling."
		simulation.camp_simulation.phase = "inactive"
	sync_sleep_button_state()

func continue_sleep_after_ambush() -> void:
	if simulation == null or simulation.is_in_combat:
		return
	var resumed := simulation.continue_camp_sleep()
	if not bool(resumed.get("ok", false)):
		status_label.text = "Could not resume sleep: %s" % String(resumed.get("reason", "unknown"))
		return
	var summary: Dictionary = resumed.get("summary", {})
	await return_rowan.call()
	camp_presentation.present_camp(simulation.camp_simulation.site, simulation.camp_simulation.sleeping_arrangements, simulation.camp_simulation.environment)
	status_label.text = "Morning. The party completed the remaining %.1f hours of sleep." % float(summary.get("hours", 0.0))
	sync_sleep_button_state()

func pack_after_ambush() -> void:
	if simulation == null:
		return
	simulation.finish_interrupted_camp_night()
	await return_rowan.call()
	status_label.text = "The party stays awake through the remaining night hours. Dawn has arrived; pack camp when ready."
	sync_sleep_button_state()
