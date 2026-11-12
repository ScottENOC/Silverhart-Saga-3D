extends SceneTree

const HOST_SCRIPT = preload("res://tests/mount_presentation_test_host.gd")
const MOUNT_ACTOR_SCRIPT = preload("res://tests/mount_presentation_test_creature.gd")

var failures: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var host := HOST_SCRIPT.new()
    host.name = "MountPresentationTestHost"
    root.add_child(host)

    var simulation := WorldSimulation.new()
    host.add_child(simulation)
    host.simulation = simulation
    host.active_character_id = "mount_test_rider"
    host.resource_status_label = Label.new()
    host.camera_rig = OrbitCameraRig.new()

    var rider := CharacterState.new("mount_test_rider", "Test Rider", Vector2i(0, 0))
    rider.side = "player"
    rider.skills["riding"] = 1
    rider.time_points = 100.0
    simulation.register_character(rider)

    for hex in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, -1), Vector2i(2, 1)]:
        simulation.map_data.add_cell(hex, 0.0, true, "grass")

    var horse := AnimalCatalog.create_state("horse", "mount_test_horse", "Test Horse", Vector2i(1, 0), 1234)
    horse.side = "neutral"
    horse.combat_dormant = true
    _check(bool(simulation.register_animal(horse).get("ok", false)), "Test horse should register")

    var rider_actor := Node3D.new()
    rider_actor.name = "TestRiderActor"
    host.add_child(rider_actor)
    var name_label := Label3D.new()
    name_label.name = "PlayerNameLabel"
    rider_actor.add_child(name_label)
    host.actor_by_id[rider.id] = rider_actor

    var mount_actor := MOUNT_ACTOR_SCRIPT.new()
    mount_actor.name = "TestHorseActor"
    mount_actor.creature_kind = "horse"
    mount_actor.simulation_state = horse
    mount_actor.add_to_group("creature_actors")
    root.add_child(mount_actor)
    simulation.action_committed.connect(host._on_simulation_action_committed)

    host.call("_toggle_mount")
    _check(rider.mounted_animal_id == horse.id, "R command should mount the adjacent horse")
    _check(horse.mounted_by_id == rider.id, "Mount should retain reciprocal rider link")
    _check(rider_actor.get_parent() == mount_actor, "Rider actor should be parented to the mount")
    _check(rider_actor.position.distance_to(Vector3(0.0, 1.35, 0.0)) < 0.001, "Rider should use the provisional seat transform")
    _check(not name_label.visible, "Rider name label should be hidden while mounted")
    _check(host.camera_rig.follow_target == mount_actor, "Camera should follow the mount")

    var seat_position := rider_actor.position
    host.call("_on_character_moved", rider.id, Vector2i(0, 0), horse.axial)
    _check(rider_actor.get_parent() == mount_actor and rider_actor.position == seat_position, "Rider movement events must not tween the mounted rider off the seat")
    host.call("_rotate_active_character", 1)
    _check(mount_actor.rotation.y != 0.0, "Turning a mounted rider should turn the mount actor")
    _check(rider_actor.rotation == Vector3.ZERO, "Mounted rider should retain local seat orientation")

    host.call("_toggle_mount")
    _check(rider.mounted_animal_id.is_empty() and horse.mounted_by_id.is_empty(), "R command should dismount normally")
    _check(rider_actor.get_parent() == host, "Dismounted rider should return to the tavern scene")
    _check(name_label.visible, "Rider name label should return after dismount")

    host.call("_toggle_mount")
    _check(rider.mounted_animal_id == horse.id, "Rider should be able to mount again before forced dismount test")
    simulation.call("_force_dismount_pair", rider, horse, "test_incapacitation")
    _check(rider.mounted_animal_id.is_empty(), "Simulation forced dismount should clear the riding link")
    _check(rider_actor.get_parent() == host, "Forced dismount event should detach the rider presentation")

    _check(bool(simulation.mount_animal(rider.id, horse.id).get("ok", false)), "Test fixture should remount before restore test")
    rider_actor.reparent(host, true)
    host.call("restore_mounted_actor_attachments")
    _check(rider_actor.get_parent() == mount_actor, "Load restoration should reattach a saved mounted rider")
    _check(host.camera_rig.follow_target == mount_actor, "Restored mounted player should return camera focus to the mount")

    mount_actor.queue_free()
    host.queue_free()
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
