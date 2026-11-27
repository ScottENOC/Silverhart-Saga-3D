class_name CampaignAmbientDialoguePresenter
extends Node
## Shared presenter for non-blocking character speech.
## Every bubble is parented to its speaking actor and expires on an unscaled
## timer, so pausing or slowing the simulation cannot leave dialogue floating.

const DEFAULT_HEIGHT_OFFSET := 2.1
const MIN_DURATION_SECONDS := 2.0
const MAX_DURATION_SECONDS := 7.0
const SECONDS_PER_CHARACTER := 0.055
const DURATION_PADDING_SECONDS := 1.2


static func duration_for_text(text: String) -> float:
	var character_count := text.strip_edges().length()
	return clampf(
		DURATION_PADDING_SECONDS + float(character_count) * SECONDS_PER_CHARACTER,
		MIN_DURATION_SECONDS,
		MAX_DURATION_SECONDS
	)


func present_exchange(
	lines: Array[Dictionary],
	actors_by_id: Dictionary,
	duration_seconds: float = -1.0
) -> Dictionary:
	if not is_inside_tree():
		return {"ok": false, "reason": "presenter_not_in_scene_tree"}
	if lines.is_empty():
		return {"ok": false, "reason": "empty_exchange"}
	var tree := get_tree()
	var presented_lines: Array[Dictionary] = []
	for index in range(lines.size()):
		var line: Dictionary = lines[index]
		var speaker_id := String(line.get("speaker_id", "")).strip_edges()
		var actor_value: Variant = actors_by_id.get(speaker_id, null)
		if not actor_value is Node3D:
			return {"ok": false, "reason": "missing_exchange_speaker", "speaker_id": speaker_id, "line_index": index}
		var result := present_line(actor_value as Node3D, String(line.get("text", "")), duration_seconds)
		if not bool(result.get("ok", false)):
			return {"ok": false, "reason": "exchange_line_failed", "line_index": index, "details": result}
		var line_duration := float(result.get("duration_seconds", 0.0))
		presented_lines.append({"speaker_id": speaker_id, "duration_seconds": line_duration})
		await tree.create_timer(line_duration, true, false, true).timeout
	return {"ok": true, "lines_presented": presented_lines}


func present_line(
	speaker_actor: Node3D,
	text: String,
	duration_seconds: float = -1.0,
	height_offset: float = DEFAULT_HEIGHT_OFFSET
) -> Dictionary:
	if speaker_actor == null or not is_instance_valid(speaker_actor):
		return {"ok": false, "reason": "missing_speaker_actor"}
	if not speaker_actor.is_inside_tree():
		return {"ok": false, "reason": "speaker_actor_not_in_scene_tree"}
	var line := text.strip_edges()
	if line.is_empty():
		return {"ok": false, "reason": "empty_ambient_line"}
	var resolved_duration := duration_seconds
	if resolved_duration < 0.0:
		resolved_duration = duration_for_text(line)
	if not is_finite(resolved_duration) or resolved_duration <= 0.0:
		return {"ok": false, "reason": "invalid_duration"}
	if not is_finite(height_offset):
		return {"ok": false, "reason": "invalid_height_offset"}

	var bubble := Label3D.new()
	bubble.name = "AmbientDialogueBubble"
	bubble.text = line
	bubble.position = Vector3(0.0, height_offset, 0.0)
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.no_depth_test = true
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.width = 520.0
	bubble.font_size = 42
	bubble.pixel_size = 0.006
	bubble.outline_size = 8
	bubble.modulate = Color(1.0, 0.97, 0.86, 1.0)
	bubble.add_to_group("campaign_ambient_dialogue_bubble")
	bubble.set_meta("ambient_dialogue_duration_seconds", resolved_duration)
	speaker_actor.add_child(bubble)

	var expiry := Timer.new()
	expiry.name = "RealTimeExpiry"
	expiry.one_shot = true
	expiry.ignore_time_scale = true
	expiry.wait_time = resolved_duration
	bubble.add_child(expiry)
	expiry.timeout.connect(bubble.queue_free)
	expiry.start()

	return {
		"ok": true,
		"bubble": bubble,
		"duration_seconds": resolved_duration
	}
