extends SceneTree
## Headless contract tests for exclusive primary surface partitions.

const PARTITION_SCRIPT := preload("res://scripts/characters/character_surface_region_partition.gd")
var failed := false

func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var quad_indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
    var regions := PackedStringArray(["chest_left", "chest_right"])
    var valid := PackedInt32Array([0, 0, 1, 1])
    _expect_empty(
        "complete connected partition",
        PARTITION_SCRIPT.validate_arrays(4, quad_indices, regions, valid)
    )
    _expect_contains(
        "unassigned vertex rejected",
        PARTITION_SCRIPT.validate_arrays(4, quad_indices, regions, PackedInt32Array([0, 0, 1, -1])),
        "no valid primary region"
    )
    _expect_contains(
        "disconnected region rejected",
        PARTITION_SCRIPT.validate_arrays(
            6,
            PackedInt32Array([0, 1, 2, 3, 4, 5]),
            PackedStringArray(["torso"]),
            PackedInt32Array([0, 0, 0, 0, 0, 0])
        ),
        "disconnected surface islands"
    )
    _expect_contains(
        "duplicate region identifiers rejected",
        PARTITION_SCRIPT.validate_arrays(
            4,
            quad_indices,
            PackedStringArray(["chest", "chest"]),
            valid
        ),
        "Duplicate primary region ID"
    )
    _expect_contains(
        "assignment cardinality enforced",
        PARTITION_SCRIPT.validate_arrays(4, quad_indices, regions, PackedInt32Array([0, 0, 1])),
        "exactly one primary region"
    )
    _expect_contains(
        "empty primary region rejected",
        PARTITION_SCRIPT.validate_arrays(
            4,
            quad_indices,
            PackedStringArray(["chest", "unused"]),
            valid
        ),
        "has no assigned vertices"
    )
    if failed:
        quit(1)
        return
    print("SURFACE_REGION_PARTITION_TESTS_OK cases=6")
    quit(0)


func _expect_empty(label: String, actual: String) -> void:
    if not actual.is_empty():
        push_error("%s failed: %s" % [label, actual])
        failed = true


func _expect_contains(label: String, actual: String, expected: String) -> void:
    if not actual.contains(expected):
        push_error("%s failed: expected '%s', got '%s'" % [label, expected, actual])
        failed = true
