class_name Campaign2SettlementBuilder
extends RefCounted
## Presents canonical settlement layout and placement data in streamed chunks.
## Character identity/profile resolution is delegated to the character catalogue.

const HEX_RADIUS := HexGrid.DEFAULT_RADIUS_M
const CHARACTER_ACTOR_FACTORY = preload("res://scripts/presentation/campaign_character_actor_factory.gd")
const FEATURE_COMPOSER = preload("res://scripts/world/world_settlement_feature_composer.gd")
const VEGETATION_GENERATOR = preload("res://scripts/world/world_vegetation_generator.gd")
const CREATURE_ACTOR_SCRIPT = preload("res://scripts/presentation/creature_actor.gd")
const CHARACTER_REGISTRY_SCRIPT = preload("res://scripts/world/campaign2_character_definition_registry.gd")

var settlements: Array = []
var character_registry: Campaign2CharacterDefinitionRegistry
var simulation: WorldSimulation

func _init(
	canonical_entries: Array = [],
	source_character_registry: Campaign2CharacterDefinitionRegistry = null,
	source_simulation: WorldSimulation = null
) -> void:
	settlements = canonical_entries.duplicate(true)
	character_registry = source_character_registry
	simulation = source_simulation
	if character_registry == null:
		character_registry = CHARACTER_REGISTRY_SCRIPT.new()

## The simulation outlives chunk nodes. Reattaching it here restores animal
## positions after a chunk is rebuilt instead of resetting them to authored starts.
func configure_simulation(source_simulation: WorldSimulation) -> void:
	simulation = source_simulation

## Authored features, vegetation and actor placements are attached only to the
## chunk owning their canonical anchor/candidate. Chunk unloads retire presentation,
## not authored data or persistent simulation state.
func add_settlements_in_chunk(parent: Node3D, chunk_min: Vector2i, chunk_size: int, presentation_mode_override: String = "") -> void:
	for entry in settlements:
		if not entry is Dictionary:
			continue
		var settlement_id := String(entry.get("id", ""))
		var origin: Vector2i = entry.get("origin", Vector2i.ZERO)
		var definition: Dictionary = entry.get("definition", {})
		var presentation: Dictionary = definition.get("presentation", {})
		var presentation_mode := String(presentation.get("mode", "chunked"))
		if presentation_mode != "chunked" and presentation_mode_override != "chunked":
			continue
		# The explicit override is the regional streamer's ownership decision.
		# Pass that decision through to the composer as well; otherwise its
		# canonical-mode guard silently skips location-presenter settlements.
		var composition_entry: Dictionary = entry
		if presentation_mode_override == "chunked" and presentation_mode != "chunked":
			composition_entry = entry.duplicate(true)
			var composition_definition: Dictionary = composition_entry.get("definition", {}).duplicate(true)
			var composition_presentation: Dictionary = composition_definition.get("presentation", {}).duplicate(true)
			composition_presentation["mode"] = "chunked"
			composition_definition["presentation"] = composition_presentation
			composition_entry["definition"] = composition_definition
		var composition := FEATURE_COMPOSER.compose_chunk(
			parent,
			composition_entry,
			chunk_min,
			chunk_size,
			HEX_RADIUS
		)
		if not bool(composition.get("ok", false)):
			push_warning("Settlement feature composition failed for %s: %s" % [settlement_id, composition])

		var vegetation: Dictionary = presentation.get("vegetation", {})
		var vegetation_result: Dictionary = VEGETATION_GENERATOR.generate_settlement_chunk(
			parent, chunk_min, chunk_size, HEX_RADIUS, vegetation, origin
		)
		if not bool(vegetation_result.get("ok", false)):
			push_warning("Settlement vegetation generation failed for %s: %s" % [settlement_id, vegetation_result])
		_add_creatures_in_chunk(parent, definition, origin, chunk_min, chunk_size)

		var placements: Dictionary = definition.get("placements", {})
		for placement in placements.get("characters", []):
			if not placement is Dictionary:
				continue
			var character_id := String(placement.get("character_id", placement.get("id", "")))
			if character_id.is_empty() or character_id == "player":
				continue
			var world_hex := _read_hex(placement.get("position", Vector2i.ZERO)) + origin
			var existing_state: CharacterState = simulation.get_character(character_id) if simulation != null else null
			var presentation_hex := existing_state.axial if existing_state != null else world_hex
			if _contains_chunk(presentation_hex, chunk_min, chunk_size):
				_add_character(parent, character_id, world_hex)

func _add_creatures_in_chunk(
	parent: Node3D,
	definition: Dictionary,
	origin: Vector2i,
	chunk_min: Vector2i,
	chunk_size: int
) -> void:
	var placements: Dictionary = definition.get("placements", {})
	for placement in placements.get("creatures", []):
		if not placement is Dictionary:
			continue
		var creature_id := String(placement.get("id", "")).strip_edges()
		var creature_kind := String(placement.get("kind", "")).strip_edges()
		if creature_id.is_empty() or creature_kind.is_empty():
			continue
		var authored_hex := _read_hex(placement.get("position", placement.get("hex", Vector2i.ZERO))) + origin
		var animal_id := "animal_" + creature_id.to_lower()
		var state: CharacterState = simulation.get_character(animal_id) if simulation != null else null
		var actor_hex := authored_hex
		if state != null:
			if state.race != "animal" or state.creature_kind != creature_kind:
				push_warning("Settlement creature %s conflicts with its saved simulation profile." % creature_id)
				continue
			actor_hex = state.axial
		if not _contains_chunk(actor_hex, chunk_min, chunk_size):
			continue
		var actor := CREATURE_ACTOR_SCRIPT.new() as CreatureActor
		actor.name = creature_id
		actor.creature_kind = creature_kind
		actor.behaviour = String(placement.get("behaviour", "passive_wildlife"))
		actor.axial_hex = actor_hex
		actor.model_scale = float(placement.get("scale", 1.0))
		var authored_asset_path := String(placement.get("asset_path", "")).strip_edges()
		if not authored_asset_path.is_empty():
			actor.model_path = authored_asset_path
		else:
			var filename := String(placement.get("asset", ""))
			if filename.is_empty():
				filename = "%s.gltf" % creature_kind.capitalize()
			actor.model_path = "res://art/creatures/quaternius/%s" % filename
		actor.dialogue_id = String(placement.get("dialogue_id", ""))
		actor.position = HexGrid.axial_to_world(actor_hex, HEX_RADIUS)
		if state != null:
			actor.simulation_state = state
			actor.rotation.y = deg_to_rad(float(2 - state.facing_direction) * 60.0)
		else:
			actor.rotation.y = deg_to_rad(float(posmod(actor_hex.x * 37 + actor_hex.y * 19, 360)))
			if simulation != null:
				state = actor.create_simulation_state(animal_id, creature_id, actor_hex)
				if state == null:
					actor.free()
					continue
				state.side = "neutral"
				state.combat_dormant = true
				if not state.tags.has("ambient_animal"):
					state.tags.append("ambient_animal")
				var registration := simulation.register_animal(state)
				if not bool(registration.get("ok", false)):
					push_warning("Could not register settlement animal %s: %s" % [creature_id, registration])
					actor.free()
					continue
		actor.add_to_group("creature_actors")
		parent.add_child(actor)

func _add_character(parent: Node3D, character_id: String, world_hex: Vector2i) -> void:
	var character := character_registry.get_character(character_id)
	if character.is_empty():
		push_warning("Settlement placement references missing character definition: %s" % character_id)
		return
	character["id"] = character_id

	# Streamed NPCs are not disposable scenery. Their simulation state outlives
	# the chunk presentation, so movement, faction state, relationships and
	# save/load all use the same CharacterState registry as the player.
	var state: CharacterState = simulation.get_character(character_id) if simulation != null else null
	if simulation != null and state == null:
		state = _create_streamed_npc_state(character, character_id, world_hex)
		if state == null:
			return
		if simulation.characters.has(character_id):
			state = simulation.get_character(character_id)
		else:
			simulation.register_character(state)
			state = simulation.get_character(character_id)
	if simulation != null and state == null:
		push_warning("Could not register streamed campaign NPC: %s" % character_id)
		return

	var actor_hex := state.axial if state != null else world_hex
	var actor := CHARACTER_ACTOR_FACTORY.create_settlement_actor(
		character,
		HexGrid.axial_to_world(actor_hex, HEX_RADIUS)
	)
	if actor == null:
		return
	actor.set_meta("campaign2_npc_id", character_id)
	actor.set_meta("dialogue_id", String(character.get("dialogue_id", "")))
	actor.set_meta("faction_id", String(character.get("faction_id", "")))
	actor.set_meta("side", String(character.get("side", "neutral")))
	actor.set_meta("title", String(character.get("title", "")))
	actor.set_meta("class_levels", character.get("class_levels", []))
	actor.set_meta("skill_picks", character.get("skill_picks", []))
	actor.set_meta("quest_hooks", character.get("quest_hooks", []))
	actor.add_to_group("campaign2_npc")
	parent.add_child(actor)


func _create_streamed_npc_state(character: Dictionary, character_id: String, world_hex: Vector2i) -> CharacterState:
	var progression := {
		"race": String(character.get("race", "human")),
		"class_levels": character.get("class_levels", []),
		"skill_picks": character.get("skill_picks", [])
	}
	var equipment: Array = character.get("equipment", [])
	var profile := {
		"progression": progression,
		"extra_inventory": equipment,
		"party": {"starts_in_party": false}
	}
	var spawn_hex := _resolve_npc_spawn_hex(world_hex, character_id)
	if spawn_hex == Vector2i(2147483647, 2147483647):
		push_warning("No free simulation hex is available for streamed NPC %s." % character_id)
		return null
	var state := CampaignCharacterFactory.create_npc_state(
		character_id,
		String(character.get("name", character_id)),
		spawn_hex,
		profile,
		{}
	)
	if state == null:
		return null
	state.side = String(character.get("side", "neutral"))
	state.race = String(character.get("race", "human"))
	state.combat_dormant = state.side == "neutral"
	state.progression_mode = "npc"
	state.gender_presentation = String(character.get("appearance", {}).get("gender_presentation", "Masculine" if String(character.get("gender", "male")) == "male" else "Feminine"))
	state.pronouns = String(character.get("appearance", {}).get("pronouns", "they/them"))
	state.tags.append("campaign2_streamed_npc")
	state.tags.append("faction:" + String(character.get("faction_id", "")))
	return state


func _resolve_npc_spawn_hex(origin: Vector2i, character_id: String) -> Vector2i:
	if simulation == null:
		return origin
	if not simulation.occupied_hexes.has(origin) or String(simulation.occupied_hexes.get(origin, "")) == character_id:
		return origin
	for radius in range(1, 4):
		var candidates: Array[Vector2i] = [origin]
		var frontier: Array[Vector2i] = [origin]
		for _step in range(radius):
			var next_frontier: Array[Vector2i] = []
			for hex in frontier:
				for neighbour in HexGrid.neighbors(hex):
					if not candidates.has(neighbour):
						candidates.append(neighbour)
						next_frontier.append(neighbour)
			frontier = next_frontier
		for candidate in candidates:
			if not simulation.occupied_hexes.has(candidate):
				return candidate
	return Vector2i(2147483647, 2147483647)

func _contains_chunk(hex: Vector2i, chunk_min: Vector2i, chunk_size: int) -> bool:
	return hex.x >= chunk_min.x and hex.x < chunk_min.x + chunk_size and hex.y >= chunk_min.y and hex.y < chunk_min.y + chunk_size

func _read_hex(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		return Vector2i(int(value.get("q", 0)), int(value.get("r", 0)))
	return Vector2i.ZERO
