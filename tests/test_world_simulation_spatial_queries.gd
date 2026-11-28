extends SceneTree

func _initialize() -> void:
	var simulation := WorldSimulation.new()
	var player := CharacterState.new("player", "Player", Vector2i.ZERO)
	player.side = "player"
	simulation.register_character(player)
	var companion := CharacterState.new("companion", "Companion", Vector2i(1, -1))
	companion.side = "player"
	simulation.register_character(companion)
	var distant := CharacterState.new("distant", "Distant", Vector2i(4, 0))
	simulation.register_character(distant)

	assert(simulation.hex_distance(Vector2i.ZERO, Vector2i(1, -1)) == 2)
	assert(simulation.is_hex_within_range(Vector2i.ZERO, Vector2i(1, -1), 2))
	assert(not simulation.is_hex_within_range(Vector2i.ZERO, Vector2i(1, -1), 1))
	assert(simulation.is_character_within_hex_range("player", Vector2i(0, 2), 2))
	assert(not simulation.is_character_within_hex_range("unknown", Vector2i.ZERO, 2))
	assert(simulation.are_characters_within_hex_range("player", "companion", 2))
	assert(not simulation.are_characters_within_hex_range("player", "distant", 2))
	assert(not simulation.are_characters_within_hex_range("player", "unknown", 2))

	print("World simulation spatial query tests passed.")
	simulation.free()
	quit(0)
