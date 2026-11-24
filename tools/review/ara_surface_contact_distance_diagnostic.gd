extends SceneTree
## Measures the current surface gaps for the five intended Aldric/Wren contacts.
## Fine anatomy masks are authoritative. Rig-derived broad regions are reported
## separately as approximations and are never presented as fine-region results.

const ACTOR_SCRIPT = preload("res://scripts/presentation/ara_character_actor.gd")
const OUTPUT_PATH := "res://build/aldric-wren-kiss-contact/surface-contact-distances.json"
const SAMPLE_LIMIT := 700
const MIN_WEIGHT := 0.20

const CONTACTS := [
    {
        "id": "kiss_lips",
        "a": "Wren", "a_regions": ["lips"], "a_fallback": ["head"],
        "b": "Aldric", "b_regions": ["lips"], "b_fallback": ["head"]
    },
    {
        "id": "aldric_left_hand_to_wren_right_breast",
        "a": "Aldric", "a_regions": ["palm_left", "hand_back_left", "thumb_left", "index_finger_left", "middle_finger_left", "ring_finger_left", "little_finger_left"],
        "a_fallback": ["hand_left"],
        "b": "Wren", "b_regions": ["breast_right"], "b_fallback": ["chest"]
    },
    {
        "id": "aldric_right_hand_to_wren_left_cheek",
        "a": "Aldric", "a_regions": ["palm_right", "hand_back_right", "thumb_right", "index_finger_right", "middle_finger_right", "ring_finger_right", "little_finger_right"],
        "a_fallback": ["hand_right"],
        "b": "Wren", "b_regions": ["cheek_left"], "b_fallback": ["head"]
    },
    {
        "id": "wren_right_hand_to_aldric_left_buttock",
        "a": "Wren", "a_regions": ["palm_right", "hand_back_right", "thumb_right", "index_finger_right", "middle_finger_right", "ring_finger_right", "little_finger_right"],
        "a_fallback": ["hand_right"],
        "b": "Aldric", "b_regions": ["buttock_left", "gluteal_left"], "b_fallback": ["pelvis"]
    },
    {
        "id": "wren_left_hand_to_aldric_right_shoulder",
        "a": "Wren", "a_regions": ["palm_left", "hand_back_left", "thumb_left", "index_finger_left", "middle_finger_left", "ring_finger_left", "little_finger_left"],
        "a_fallback": ["hand_left"],
        "b": "Aldric", "b_regions": ["shoulder_right"], "b_fallback": ["shoulder_right"]
    }
]

var actors: Dictionary = {}
var report: Dictionary = {"contacts": [], "sampling": {"method": "nearest evaluated surface-vertex samples", "sample_limit_per_region": SAMPLE_LIMIT, "minimum_region_weight": MIN_WEIGHT}}

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var wren := _create_actor("Wren", "res://build/wren-native/Wren.glb")
    var aldric := _create_actor("Aldric", "res://build/aldric-native/Aldric.glb")
    if wren == null or aldric == null:
        _write_report()
        quit(1)
        return
    actors = {"Wren": wren, "Aldric": aldric}
    await process_frame
    await process_frame
    await process_frame
    for actor_name in ["Wren", "Aldric"]:
        var actor: AraCharacterActor = actors[actor_name]
        var regions := actor.get_surface_regions()
        var mask_report := {"configured": regions != null, "authored_region_count": 0, "available_authored_ids": []}
        if regions != null:
            var ids: Array = []
            for region_id in CharacterSurfaceRegionMask.REGION_IDS:
                if regions.has_authored_region(region_id, MIN_WEIGHT):
                    ids.append(region_id)
            mask_report["authored_region_count"] = ids.size()
            mask_report["available_authored_ids"] = ids
        report[actor_name.to_lower() + "_mask_status"] = mask_report
    for contact in CONTACTS:
        report["contacts"].append(_measure_contact(contact))
    _write_report()
    print("SURFACE_CONTACT_DISTANCE_REPORT=" + JSON.stringify(report))
    quit(0)

func _create_actor(actor_name: String, asset_path: String) -> AraCharacterActor:
    var actor := ACTOR_SCRIPT.new() as AraCharacterActor
    actor.name = actor_name
    root.add_child(actor)
    if not actor.configure(asset_path):
        push_error("Could not configure " + actor_name + " from " + asset_path)
        return null
    return actor

func _collect_samples(actor_name: String, region_ids: Array, authored_only: bool) -> Array[Dictionary]:
    var actor: AraCharacterActor = actors[actor_name]
    var regions := actor.get_surface_regions()
    var result: Array[Dictionary] = []
    if regions == null:
        return result
    var seen := {}
    for region_id in region_ids:
        var samples: Array[Dictionary]
        if authored_only:
            samples = regions.get_authored_region_surface_samples(String(region_id), MIN_WEIGHT, SAMPLE_LIMIT)
        else:
            samples = regions.get_region_surface_samples(String(region_id), MIN_WEIGHT, SAMPLE_LIMIT)
        for sample in samples:
            var mesh_instance: MeshInstance3D = sample["mesh_instance"]
            var key := "%s:%d:%d" % [str(mesh_instance.get_instance_id()), int(sample["surface_index"]), int(sample["vertex_index"])]
            if seen.has(key):
                continue
            seen[key] = true
            var world_sample: Dictionary = sample.duplicate()
            world_sample["position"] = actor.global_transform * Vector3(sample["position"])
            world_sample["actor"] = actor_name
            result.append(world_sample)
    if result.size() > SAMPLE_LIMIT:
        var reduced: Array[Dictionary] = []
        var stride := int(ceil(float(result.size()) / float(SAMPLE_LIMIT)))
        for index in range(0, result.size(), stride):
            reduced.append(result[index])
        return reduced
    return result

func _measure_contact(contact: Dictionary) -> Dictionary:
    var a_actor: String = contact["a"]
    var b_actor: String = contact["b"]
    var a_regions: Array = contact["a_regions"]
    var b_regions: Array = contact["b_regions"]
    var a_samples := _collect_samples(a_actor, a_regions, true)
    var b_samples := _collect_samples(b_actor, b_regions, true)
    var a_mode := "authored_fine_regions"
    var b_mode := "authored_fine_regions"
    var a_used: Array = a_regions
    var b_used: Array = b_regions
    if a_samples.is_empty():
        a_used = contact["a_fallback"]
        a_samples = _collect_samples(a_actor, a_used, false)
        a_mode = "broad_rig_region_approximation" if not a_samples.is_empty() else "unavailable"
    if b_samples.is_empty():
        b_used = contact["b_fallback"]
        b_samples = _collect_samples(b_actor, b_used, false)
        b_mode = "broad_rig_region_approximation" if not b_samples.is_empty() else "unavailable"
    var result := {
        "id": contact["id"],
        "side_a": {"actor": a_actor, "requested_regions": a_regions, "measured_regions": a_used, "mode": a_mode, "sample_count": a_samples.size()},
        "side_b": {"actor": b_actor, "requested_regions": b_regions, "measured_regions": b_used, "mode": b_mode, "sample_count": b_samples.size()},
        "status": "unavailable"
    }
    if a_samples.is_empty() or b_samples.is_empty():
        result["reason"] = "One or both surface definitions have no qualifying evaluated samples."
        return result
    var best_distance := INF
    var best_a: Dictionary = {}
    var best_b: Dictionary = {}
    for sample_a in a_samples:
        var point_a: Vector3 = sample_a["position"]
        for sample_b in b_samples:
            var point_b: Vector3 = sample_b["position"]
            var distance := point_a.distance_to(point_b)
            if distance < best_distance:
                best_distance = distance
                best_a = sample_a
                best_b = sample_b
    result["minimum_sampled_vertex_distance_m"] = best_distance
    result["closest_points_world_m"] = {
        "a": [best_a["position"].x, best_a["position"].y, best_a["position"].z],
        "b": [best_b["position"].x, best_b["position"].y, best_b["position"].z]
    }
    result["closest_samples"] = {
        "a": {"mesh": str(best_a["mesh_instance"].name), "surface": best_a["surface_index"], "vertex": best_a["vertex_index"], "region": best_a["region_id"]},
        "b": {"mesh": str(best_b["mesh_instance"].name), "surface": best_b["surface_index"], "vertex": best_b["vertex_index"], "region": best_b["region_id"]}
    }
    result["status"] = "measured_fine_region_vertex_approximation" if a_mode == "authored_fine_regions" and b_mode == "authored_fine_regions" else "approximate_broad_region_vertex_distance"
    result["caveat"] = "Distance is nearest evaluated vertex-sample distance, not continuous triangle-to-triangle distance. It can slightly overestimate the true surface gap."
    return result

func _write_report() -> void:
    var absolute_path := ProjectSettings.globalize_path(OUTPUT_PATH)
    DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
    var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
    if file == null:
        push_error("Could not write surface contact report: " + OUTPUT_PATH)
        return
    file.store_string(JSON.stringify(report, "\t"))
    file.close()
