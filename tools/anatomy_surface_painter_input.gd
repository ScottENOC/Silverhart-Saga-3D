extends Node3D

signal input_event_received(event: InputEvent)


func _unhandled_input(event: InputEvent) -> void:
    input_event_received.emit(event)
    get_viewport().set_input_as_handled()
