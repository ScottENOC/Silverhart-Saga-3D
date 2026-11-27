class_name HollowmereOpeningSequenceController
extends Node
## Coordinates the Hollowmere opening beat without owning scene nodes or UI.
## World-specific movement and presentation are supplied by thin adapter callables.

signal shakedown_started

const CONTENT := preload("res://scripts/simulation/hollowmere_campaign_content.gd")

var _running := false


func begin(
	player_race: String,
	start_quest: Callable,
	present_ambient: Callable,
	move_soldiers_inside: Callable,
	present_interactive: Callable,
	is_shakedown_resolved: Callable
) -> void:
	if _running or player_race in ["goblin", "orc"]:
		return
	_running = true
	if start_quest.is_valid():
		start_quest.call()
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	if present_ambient.is_valid():
		present_ambient.call("companion_wren_talbot", "Well, here we are then. Try not to get us both killed, yeah?")
	await get_tree().create_timer(6.0).timeout
	if not is_inside_tree() or _resolved(is_shakedown_resolved):
		return
	shakedown_started.emit()
	for line_value in CONTENT.opening_lines():
		if not is_inside_tree():
			return
		var line: Dictionary = line_value
		var speaker_id := String(line.get("speaker_id", "dray_coltayne"))
		if speaker_id == "narrator":
			if move_soldiers_inside.is_valid():
				await move_soldiers_inside.call()
		else:
			if present_ambient.is_valid():
				present_ambient.call(speaker_id, String(line.get("text", "")))
		await get_tree().create_timer(2.25).timeout
	if not is_inside_tree() or _resolved(is_shakedown_resolved):
		return
	if present_interactive.is_valid():
		present_interactive.call()


func _resolved(check: Callable) -> bool:
	return check.is_valid() and bool(check.call())
