class_name OrbitCameraRig
extends Node3D

@export var follow_target: Node3D
@export var zoom_distance: float = 17.0
@export var min_zoom: float = 1.4
@export var max_zoom: float = 32.0
@export var orbit_sensitivity: float = 0.25
@export var pitch_sensitivity: float = 0.20

@onready var pitch_pivot: Node3D = $PitchPivot
@onready var camera: Camera3D = $PitchPivot/Camera3D

var dragging: bool = false

func _ready() -> void:
    pitch_pivot.rotation_degrees.x = -52.0
    camera.position = Vector3(0.0, 0.0, zoom_distance)

func _process(_delta: float) -> void:
    if is_instance_valid(follow_target):
        global_position = follow_target.global_position + Vector3(0.0, 0.65, 0.0)
    _update_camera_clearance()

func _update_camera_clearance() -> void:
    # Preserve requested zoom while shortening the camera arm if geometry
    # blocks the view, preventing floor and furniture clipping.
    var start := pitch_pivot.global_position
    var desired := pitch_pivot.to_global(Vector3(0.0, 0.0, zoom_distance))
    var query := PhysicsRayQueryParameters3D.create(start, desired)
    query.collide_with_areas = false
    if is_instance_valid(follow_target) and follow_target is CollisionObject3D:
        query.exclude = [follow_target.get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    var allowed_distance := zoom_distance
    if not hit.is_empty():
        allowed_distance = maxf(0.35, start.distance_to(hit.position) - 0.12)
    camera.position.z = allowed_distance

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
            dragging = mouse_event.pressed
        elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _set_zoom(zoom_distance - 0.5)
        elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _set_zoom(zoom_distance + 0.5)

    elif event is InputEventMouseMotion and dragging:
        var motion := event as InputEventMouseMotion
        rotation_degrees.y -= motion.relative.x * orbit_sensitivity
        pitch_pivot.rotation_degrees.x = clampf(
            pitch_pivot.rotation_degrees.x - motion.relative.y * pitch_sensitivity,
            -89.0,
            89.0
        )

func _set_zoom(value: float) -> void:
    zoom_distance = clampf(value, min_zoom, max_zoom)
    camera.position.z = zoom_distance
