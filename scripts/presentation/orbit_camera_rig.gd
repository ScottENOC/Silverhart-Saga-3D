class_name OrbitCameraRig
extends Node3D

@export var follow_target: Node3D
@export var zoom_distance: float = 17.0
@export var min_zoom: float = 1.5
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

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
            dragging = mouse_event.pressed
        elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
            _set_zoom(zoom_distance - 0.8)
        elif mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _set_zoom(zoom_distance + 0.8)

    elif event is InputEventMouseMotion and dragging:
        var motion := event as InputEventMouseMotion
        rotation_degrees.y -= motion.relative.x * orbit_sensitivity
        pitch_pivot.rotation_degrees.x = clampf(
            pitch_pivot.rotation_degrees.x - motion.relative.y * pitch_sensitivity,
            -88.0,
            -25.0
        )

func _set_zoom(value: float) -> void:
    zoom_distance = clampf(value, min_zoom, max_zoom)
    camera.position.z = zoom_distance
