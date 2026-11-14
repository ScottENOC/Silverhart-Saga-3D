extends SceneTree

const HORSE_TACK = preload("res://scripts/presentation/horse_tack_presentation.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var horse_model := Node3D.new()
    root.add_child(horse_model)
    var tack := HORSE_TACK.attach_to_horse(horse_model)
    _check(tack != null, "Horse tack should attach to a valid horse model")
    _check(tack.get_parent() == horse_model, "Tack should remain a removable child of the horse model")
    var saddle := tack.get_node_or_null("SaddleAsset")
    var bridle := tack.get_node_or_null("BridleAsset")
    _check(saddle != null, "Separate saddle asset should be attached")
    _check(bridle != null, "Separate bridle asset should be attached")
    _check(_contains_mesh(saddle), "Saddle asset should contain imported mesh geometry")
    _check(_contains_mesh(bridle), "Bridle asset should contain imported mesh geometry")
    var child_count := tack.get_child_count()
    _check(child_count == 2, "Saddle and bridle should remain independently replaceable modules")
    _check(HORSE_TACK.attach_to_horse(horse_model) == tack, "Repeated attachment should reuse the existing tack node")
    _check(tack.get_child_count() == child_count, "Repeated attachment should not duplicate tack geometry")
    var null_result = HORSE_TACK.attach_to_horse(null)
    _check(null_result == null, "Null horse model should be rejected")
    horse_model.queue_free()
    if failures > 0:
        push_error("%d horse tack assertion(s) failed." % failures)
        quit(1)
        return
    print("Horse tack presentation tests passed.")
    quit(0)

var failures := 0

func _contains_mesh(node: Node) -> bool:
    if node == null:
        return false
    if node is MeshInstance3D and node.mesh != null:
        return true
    for child in node.get_children():
        if _contains_mesh(child):
            return true
    return false

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)
