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
const NPC_SKILL_SPENDING = preload("res://scripts/simulation/npc_skill_spending.gd")

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
	_register_campaign_characters()

## The simulation outlives chunk nodes. Reattaching it here restores animal
## positions after a chunk is rebuilt instead of resetting them to authored starts.
func configure_simulation(source_simulation: WorldSimulation) -> void:
	simulation = source_simulation
	_register_campaign_characters()


## Named campaign characters belong to the shared simulation, not to the chunk
## that happens to display them. Register every canonical placement once so
## NPC state survives chunk unloads and movement away from its authored site.
func _register_campaign_characters() -> void:
	if simulation == null or character_registry == null:
		return
	for entry in settlements:
		if not entry is Dictionary:
			continue
		var definition: Dictionary = entry.get("definition", {})
		var origin: Vector2i = entry.get("origin", Vector2i.ZERO)
		var placements: Dictionary = definition.get("placements", {})
		for placement_value in placements.get("characters", []):
			if not placement_value is Dictionary:
				continue
			var placement: Dictionary = placement_value
			var character_id := String(placement.get("character_id", placement.get("id", ""))).strip_edges()
			if character_id.is_empty() or character_id == "player" or simulation.get_character(character_id) != null:
				continue
			var profile := character_registry.get_character(character_id)
			if profile.is_empty():
				continue
			var start_hex := _read_hex(placement.get("position", Vector2i.ZERO)) + origin
			var display_name := String(profile.get("name", profile.get("display_name", character_id)))
			var state := CharacterState.new(character_id, display_name, start_hex)
			var race := String(profile.get("race", "human"))
			state.race = race
			state.side = String(profile.get("side", "neutral"))
			state.combat_dormant = true
			state.time_points = 0.0
			state.health = maxi(1, int(profile.get("max_health", 100)))
			state.max_health = state.health
			state.tags.append("campaign2_npc")
			var faction_id := String(profile.get("faction_id", ""))
			if not faction_id.is_empty():
				state.tags.append("faction:" + faction_id)
			var dialogue_id := String(profile.get("dialogue_id", ""))
			if not dialogue_id.is_empty():
				state.tags.append("dialogue:" + dialogue_id)
			if bool(profile.get("tied_up", false)):
				state.tags.append("tied_up")
			var class_sequence: Array[String] = []
			for class_id_value in profile.get("class_levels", []):
				class_sequence.append(String(class_id_value))
			var preferred_skills: Dictionary = {}
			for skill_id_value in profile.get("skill_picks", []):
				var skill_id := String(skill_id_value)
				preferred_skills[skill_id] = int(preferred_skills.get(skill_id, 0)) + 1
			var custom_skills: Dictionary = profile.get("source_custom_skills", {})
			if not custom_skills.is_empty():
				state.character_class = class_sequence[0] if not class_sequence.is_empty() else "fighter"
				state.class_level_sequence = class_sequence.duplicate()
				for class_id in class_sequence:
					state.class_levels[class_id] = int(state.class_levels.get(class_id, 0)) + 1
				state.level = maxi(1, class_sequence.size())
				state.skills = custom_skills.duplicate(true)
				state.sync_skill_effects()
			elif not class_sequence.is_empty():
				var build_result: Dictionary = NPC_SKILL_SPENDING.build_authored(
					state, race, class_sequence, preferred_skills, "campaign2:" + character_id
				)
				if not bool(build_result.get("ok", false)):
					push_warning("Could not build authored campaign NPC %s: %s" % [character_id, build_result])
			else:
				NPC_SKILL_SPENDING.build_civilian(state, race)
			var registration := simulation.register_character(state)
			if simulation.get_character(character_id) == null:
				push_warning("Could not register persistent campaign NPC %s at %s: %s" % [character_id, start_hex, registration])

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
			var authored_hex := _read_hex(placement.get("position", Vector2i.ZERO)) + origin
			var character_state: CharacterState = simulation.get_character(character_id) if simulation != null else null
			var presentation_hex := character_state.axial if character_state != null else authored_hex
			if _contains_chunk(presentation_hex, chunk_min, chunk_size):
				_add_character(parent, character_id, presentation_hex)

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
	var actor := CHARACTER_ACTOR_FACTORY.create_settlement_actor(
		character,
		HexGrid.axial_to_world(world_hex, HEX_RADIUS)
	)
	if actor == null:
		return
	actor.set_meta("campaign2_npc_id", character_id)
	actor.add_to_group("campaign2_npc_actors")
	parent.add_child(actor)

func _contains_chunk(hex: Vector2i, chunk_min: Vector2i, chunk_size: int) -> bool:
	return hex.x >= chunk_min.x and hex.x < chunk_min.x + chunk_size and hex.y >= chunk_min.y and hex.y < chunk_min.y + chunk_size

func _read_hex(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Dictionary:
		return Vector2i(int(value.get("q", 0)), int(value.get("r", 0)))
	return Vector2i.ZERO
