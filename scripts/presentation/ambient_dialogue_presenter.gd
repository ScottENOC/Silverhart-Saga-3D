class_name AmbientDialoguePresenter
extends Node
## Presents non-blocking, actor-attached dialogue that expires in real elapsed time.
## This component owns only ambient presentation; eligibility and dialogue content
## remain in simulation/content services.

const DEFAULT_HEIGHT := 3.0
const MIN_DURATION := 2.5
const MAX_DURATION := 6.5


func present(actor: Node3D, spoken_text: String, duration: float = -1.0) -> Label3D:
	if actor == null or not is_instance_valid(actor) or spoken_text.strip_edges().is_empty():
		return null
	var bubble := Label3D.new()
	bubble.name = "AmbientDialogueText"
	bubble.text = wrap_text(spoken_text)
	bubble.position = Vector3(0.0, DEFAULT_HEIGHT, 0.0)
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.font_size = 22
	bubble.pixel_size = 0.008
	bubble.outline_size = 6
	bubble.modulate = Color(1.0, 0.97, 0.86)
	actor.add_child(bubble)
	var lifetime := duration if duration > 0.0 else duration_for_text(spoken_text)
	var expiry := get_tree().create_timer(lifetime, true, false, true)
	expiry.timeout.connect(_expire_bubble.bind(bubble))
	return bubble


func _expire_bubble(bubble: Label3D) -> void:
	if is_instance_valid(bubble):
		bubble.queue_free()


static func wrap_text(value: String, max_characters: int = 34) -> String:
	var wrapped_lines := PackedStringArray()
	var current_line := ""
	for word_value in value.split(" ", false):
		var word := String(word_value)
		if current_line.is_empty():
			current_line = word
		elif current_line.length() + 1 + word.length() > max_characters:
			wrapped_lines.append(current_line)
			current_line = word
		else:
			current_line += " " + word
	if not current_line.is_empty():
		wrapped_lines.append(current_line)
	return "\n".join(wrapped_lines)


static func duration_for_text(value: String) -> float:
	var line_count := wrap_text(value).split("\n", false).size()
	return clampf(1.8 + float(line_count) * 0.85 + float(value.length()) * 0.008, MIN_DURATION, MAX_DURATION)
