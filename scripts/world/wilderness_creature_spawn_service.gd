class_name WildernessCreatureSpawnService
extends RefCounted
## Owns travel-triggered ambient wildlife presentation. Gameplay animal state,
## encounters and regional exclusion rules remain with their existing owners.

const CREATURE_ACTOR_SCRIPT = preload("res://scripts/presentation/creature_actor.gd")

const SPAWN_STEP_INTERVAL := 12
const MAX_VISIBLE_CREATURES := 5
const MAX_VISIBLE_DISTANCE := 60.0
const SPAWN_MIN_DISTANCE := 6
const SPAWN_MAX_DISTANCE := 13
const SPAWN_ROLL_CHANCE := 0.42
const SPECIES: Array[String] = ["wolf", "fox", "deer", "stag"]
const SPECIES_WEIGHTS := [0.25, 0.25, 0.30, 0.20]

var simulation: WorldSimulation
var world_parent: Node3D
var position_for_hex: Callable
var is_spawn_excluded: Callable
var random_source: RandomNumberGenerator
var steps_since_spawn := 0
var creature_nodes: Array[Node3D] = []

func configure(
	world_simulation: WorldSimulation,
	parent: Node3D,
	world_position_for_hex: Callable,
	exclusion_predicate: Callable,
	rng: RandomNumberGenerator
) -> void:
	simulation = world_simulation
	world_parent = parent
	position_for_hex = world_position_for_hex
	is_spawn_excluded = exclusion_predicate
	random_source = rng

## Called only after the player moves. The cadence and cap therefore remain
## independent of frame rate and the service never rolls while in excluded land.
func player_moved(player_hex: Vector2i) -> void:
	if simulation == null or world_parent == null or position_for_hex.is_null() or is_spawn_excluded.is_null() or random_source == null:
		return
	if _is_excluded(player_hex):
		return
	steps_since_spawn += 1
	if steps_since_spawn < SPAWN_STEP_INTERVAL:
		return
	steps_since_spawn = 0

	var player_world: Vector3 = position_for_hex.call(player_hex)
	_prune_distant_creatures(player_world)
	if creature_nodes.size() >= MAX_VISIBLE_CREATURES or random_source.randf() > SPAWN_ROLL_CHANCE:
		return

	var kind := species_for_roll(random_source.randf())
	for _attempt in range(18):
		var candidate := player_hex + Vector2i(
			random_source.randi_range(-12, 12),
			random_source.randi_range(-12, 12)
		)
		if not candidate_is_valid(simulation, player_hex, candidate, is_spawn_excluded):
			continue
		_spawn_creature(kind, candidate)
		return

static func species_for_roll(roll: float) -> String:
	var cumulative := 0.0
	for index in range(SPECIES.size()):
		cumulative += SPECIES_WEIGHTS[index]
		if roll <= cumulative:
			return SPECIES[index]
	return SPECIES.back()

static func candidate_is_valid(
	world_simulation: WorldSimulation,
	player_hex: Vector2i,
	candidate: Vector2i,
	exclusion_predicate: Callable
) -> bool:
	if world_simulation == null:
		return false
	if not world_simulation.is_hex_within_range(player_hex, candidate, SPAWN_MAX_DISTANCE):
		return false
	if world_simulation.is_hex_within_range(player_hex, candidate, SPAWN_MIN_DISTANCE):
		return false
	if not exclusion_predicate.is_null() and bool(exclusion_predicate.call(candidate)):
		return false
	if not world_simulation.map_data.is_walkable(candidate) or world_simulation.is_hex_occupied(candidate):
		return false
	return true

func clear() -> void:
	for creature in creature_nodes:
		if is_instance_valid(creature):
			creature.queue_free()
	creature_nodes.clear()
	steps_since_spawn = 0

func _is_excluded(hex: Vector2i) -> bool:
	return bool(is_spawn_excluded.call(hex))

func _prune_distant_creatures(player_world: Vector3) -> void:
	for index in range(creature_nodes.size() - 1, -1, -1):
		var existing := creature_nodes[index]
		if not is_instance_valid(existing) or existing.global_position.distance_to(player_world) > MAX_VISIBLE_DISTANCE:
			if is_instance_valid(existing):
				existing.queue_free()
			creature_nodes.remove_at(index)

func _spawn_creature(kind: String, hex: Vector2i) -> void:
	var creature := CREATURE_ACTOR_SCRIPT.new() as CreatureActor
	creature.name = "Wilderness_%s_%d" % [kind, creature_nodes.size() + 1]
	creature.creature_kind = kind
	creature.behaviour = "predator" if kind == "wolf" else "passive_wildlife"
	creature.model_scale = 0.72 if kind == "fox" else 0.78
	creature.model_path = "res://art/creatures/quaternius/%s.gltf" % kind.capitalize()
	creature.position = position_for_hex.call(hex)
	world_parent.add_child(creature)
	creature_nodes.append(creature)
