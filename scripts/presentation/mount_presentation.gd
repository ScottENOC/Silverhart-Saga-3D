class_name MountPresentation
extends RefCounted
## Presentation-only helpers for attaching a rider actor to a mount actor.
## Simulation state remains authoritative; this class never changes game rules.

const RIDER_SEAT_POSITION := Vector3(0.0, 1.05, 0.0)
const RIDING_ANIMATION := &"Ride motorcycle"

static func attach_rider(rider_actor: Node3D, mount_actor: Node3D) -> bool:
    if rider_actor == null or mount_actor == null:
        return false
    rider_actor.reparent(mount_actor, true)
    rider_actor.position = RIDER_SEAT_POSITION
    rider_actor.rotation = Vector3.ZERO
    _play_riding_animation(rider_actor)
    _set_rider_name_visible(rider_actor, false)
    return true

static func detach_rider(rider_actor: Node3D, destination_parent: Node3D, destination: Vector3, facing_direction: int) -> bool:
    if rider_actor == null or destination_parent == null:
        return false
    if rider_actor.get_parent() != destination_parent:
        rider_actor.reparent(destination_parent, true)
    rider_actor.position = destination
    rider_actor.rotation.y = deg_to_rad(float(2 - facing_direction) * 60.0)
    _play_idle_animation(rider_actor)
    _set_rider_name_visible(rider_actor, true)
    return true

static func set_mount_facing(mount_actor: Node3D, facing_direction: int) -> void:
    if mount_actor == null:
        return
    mount_actor.rotation.y = deg_to_rad(float(2 - facing_direction) * 60.0)

static func should_animate_character(state: CharacterState) -> bool:
    return state == null or state.mounted_animal_id.is_empty()

static func _play_riding_animation(rider_actor: Node) -> void:
    var player := _find_animation_player(rider_actor)
    if player != null and player.has_animation(RIDING_ANIMATION):
        player.play(RIDING_ANIMATION)

static func _play_idle_animation(rider_actor: Node) -> void:
    var player := _find_animation_player(rider_actor)
    if player == null:
        return
    for animation_name in player.get_animation_list():
        var candidate := String(animation_name)
        if candidate.to_lower() == "idle":
            player.play(animation_name)
            return
    for animation_name in player.get_animation_list():
        if String(animation_name).to_lower().contains("idle"):
            player.play(animation_name)
            return

static func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

static func _set_rider_name_visible(rider_actor: Node3D, is_visible: bool) -> void:
    var name_label := rider_actor.get_node_or_null("PlayerNameLabel") as Label3D
    if name_label == null:
        name_label = rider_actor.get_node_or_null("CharacterNameLabel") as Label3D
    if name_label != null:
        name_label.visible = is_visible
