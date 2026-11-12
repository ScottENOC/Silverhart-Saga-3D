extends SceneTree

const MOUNT_PRESENTATION = preload("res://scripts/presentation/mount_presentation.gd")

var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene_root := Node3D.new()
    root.add_child(scene_root)
    var rider_actor := Node3D.new()
    rider_actor.name = "TestRiderActor"
    scene_root.add_child(rider_actor)
    var name_label := Label3D.new()
    name_label.name = "PlayerNameLabel"
    rider_actor.add_child(name_label)
    var mount_actor := Node3D.new()
    mount_actor.name = "TestMountActor"
    scene_root.add_child(mount_actor)

    _check(MOUNT_PRESENTATION.attach_rider(rider_actor, mount_actor), "Attach helper should accept valid actors")
    _check(rider_actor.get_parent() == mount_actor, "Rider actor should be parented to the mount")
    _check(rider_actor.position.distance_to(Vector3(0.0, 1.35, 0.0)) < 0.001, "Rider should use the provisional seat transform")
    _check(rider_actor.rotation == Vector3.ZERO, "Rider should use neutral local seat rotation")
    _check(not name_label.visible, "Rider name label should be hidden while mounted")

    MOUNT_PRESENTATION.set_mount_facing(mount_actor, 1)
    _check(is_equal_approx(mount_actor.rotation.y, deg_to_rad(60.0)), "Mount facing helper should apply the requested hex direction")
    var mounted_state := CharacterState.new("rider", "Rider", Vector2i.ZERO)
    mounted_state.mounted_animal_id = "horse"
    _check(not MOUNT_PRESENTATION.should_animate_character(mounted_state), "Mounted rider movement should not be animated independently")
    mounted_state.mounted_animal_id = ""
    _check(MOUNT_PRESENTATION.should_animate_character(mounted_state), "Unmounted character movement should use normal actor presentation")

    var destination := Vector3(4.0, 0.0, -2.0)
    _check(MOUNT_PRESENTATION.detach_rider(rider_actor, scene_root, destination, 2), "Detach helper should accept valid actors")
    _check(rider_actor.get_parent() == scene_root, "Dismounted rider should return to the scene root")
    _check(rider_actor.position.distance_to(destination) < 0.001, "Dismounted rider should move to the simulation destination")
    _check(is_equal_approx(rider_actor.rotation.y, 0.0), "Dismounted rider should restore the simulation facing")
    _check(name_label.visible, "Rider name label should return after dismount")
    _check(not MOUNT_PRESENTATION.attach_rider(null, mount_actor), "Attach helper should reject a missing rider")
    _check(not MOUNT_PRESENTATION.detach_rider(rider_actor, null, Vector3.ZERO, 0), "Detach helper should reject a missing destination parent")

    scene_root.queue_free()
    if failures > 0:
        push_error("%d mount presentation assertion(s) failed." % failures)
        quit(1)
        return
    print("Mount presentation tests passed.")
    quit(0)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)
