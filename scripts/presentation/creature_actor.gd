class_name CreatureActor
extends Node3D

const HORSE_TACK = preload("res://scripts/presentation/horse_tack_presentation.gd")
## Runtime wrapper for Quaternius animal scenes. Keeps each animal's imported
## skeleton and animation library intact; animation names are discovered at
## runtime because the packs do not share one naming convention.

@export_file("*.gltf", "*.glb") var model_path: String = ""
@export_enum("cow", "bull", "horse", "donkey", "alpaca", "wolf", "fox", "deer", "stag", "husky", "shiba_inu") var creature_kind: String = "cow"
@export_enum("farm", "passive_wildlife", "predator", "mount") var behaviour: String = "farm"
@export_range(0.1, 4.0, 0.05) var model_scale: float = 1.0
@export var idle_animation_hints: PackedStringArray = PackedStringArray(["idle", "graze", "eat", "stand"])
@export var move_animation_hints: PackedStringArray = PackedStringArray(["walk", "move", "trot"])
@export var alert_animation_hints: PackedStringArray = PackedStringArray(["alert", "look", "sniff"])
@export var run_animation_hints: PackedStringArray = PackedStringArray(["run", "gallop", "sprint"])

var model_root: Node3D
var animation_player: AnimationPlayer
var animation_names: PackedStringArray = PackedStringArray()
var active_animation: StringName = &""
## Hex-grid position and simulation state are assigned by the world owner.
var axial_hex: Vector2i = Vector2i.ZERO
var simulation_state: CharacterState

func _ready() -> void:
    _load_model()

func _load_model() -> void:
    if model_path.is_empty():
        push_warning("CreatureActor %s has no model_path." % name)
        return
    var resource := load(model_path)
    if not resource is PackedScene:
        push_error("Creature model did not import as a PackedScene: %s" % model_path)
        return
    model_root = (resource as PackedScene).instantiate() as Node3D
    if model_root == null:
        push_error("Creature model root is not Node3D: %s" % model_path)
        return
    model_root.name = "ImportedAnimalModel"
    model_root.scale = Vector3.ONE * model_scale
    add_child(model_root)
    if creature_kind == "horse":
        HORSE_TACK.attach_to_horse(model_root)
    animation_player = _find_animation_player(model_root)
    if animation_player == null:
        push_warning("No AnimationPlayer found in creature model: %s" % model_path)
        return
    animation_names = animation_player.get_animation_list()
    # Prefer the most characteristic resting loop when a pack supplies one;
    # the remaining hints are fallbacks for animals with smaller clip sets.
    match creature_kind:
        "cow", "bull":
            idle_animation_hints = PackedStringArray(["graze", "eat", "idle", "stand"])
        "deer", "stag":
            idle_animation_hints = PackedStringArray(["graze", "idle", "stand", "look"])
        "fox":
            idle_animation_hints = PackedStringArray(["idle", "stand", "look", "alert"])
        "wolf", "husky", "shiba_inu":
            idle_animation_hints = PackedStringArray(["idle", "stand", "look", "alert"])
        "horse", "donkey", "alpaca":
            idle_animation_hints = PackedStringArray(["idle", "stand", "graze", "eat"])
    play_idle()

func _find_animation_player(root: Node) -> AnimationPlayer:
    if root is AnimationPlayer:
        return root as AnimationPlayer
    for child in root.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

func play_idle() -> void:
    _play_matching(idle_animation_hints)

func play_move() -> void:
    _play_matching(move_animation_hints)

func play_alert() -> void:
    _play_matching(alert_animation_hints)

func play_run() -> void:
    _play_matching(run_animation_hints)

func play_animation_by_hint(hints: PackedStringArray) -> bool:
    return _play_matching(hints)

func _play_matching(hints: PackedStringArray) -> bool:
    if animation_player == null:
        return false
    var candidates: Array[String] = []
    for animation_name in animation_names:
        candidates.append(String(animation_name))
    candidates.sort()
    for hint in hints:
        var normalized_hint := hint.to_lower()
        for candidate in candidates:
            if candidate.to_lower().contains(normalized_hint):
                if active_animation == StringName(candidate):
                    return true
                animation_player.play(candidate)
                active_animation = StringName(candidate)
                return true
    return false

## Creates the matching gameplay state for this rendered animal.
func create_simulation_state(
    creature_id: String,
    display_name: String = "",
    start_hex: Vector2i = Vector2i.ZERO,
    individual_seed: int = 0
) -> CharacterState:
    simulation_state = AnimalCatalog.create_state(creature_kind, creature_id, display_name, start_hex, individual_seed)
    axial_hex = start_hex
    return simulation_state

func available_animations() -> PackedStringArray:
    return animation_names.duplicate()
