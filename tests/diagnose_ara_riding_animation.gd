extends SceneTree
## Inspect imported Ara horse-riding animation tracks and evaluated skeleton pose.
const ARA_ACTOR = preload("res://scripts/presentation/ara_character_actor.gd")
const BODY_PATHS := {
    "female": "res://art/characters/ara_runtime/ara_person_body.glb",
    "male": "res://art/characters/ara_runtime/ara_person_male_body.glb"
}
const CLIP := "Ride horse (trot)"
const FOCUS_BONES := ["Hips", "Spine", "Spine1", "Spine2", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot", "LeftArm", "LeftForeArm", "RightArm", "RightForeArm"]

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for variant in BODY_PATHS:
        var actor := ARA_ACTOR.new() as AraCharacterActor
        actor.name = "RidingDiagnostic_" + variant
        root.add_child(actor)
        if not actor.configure(BODY_PATHS[variant]) or actor.animation_player == null:
            push_error("Could not configure Ara " + variant)
            quit(1)
            return
        for _frame in range(4):
            await process_frame
        var player := actor.animation_player
        if not player.has_animation(CLIP):
            push_error("Missing riding clip for " + variant)
            quit(1)
            return
        var animation := player.get_animation(CLIP)
        print("[Ara ride animation] VARIANT=%s LENGTH=%.3f TRACKS=%d" % [variant, animation.length, animation.get_track_count()])
        for track in range(animation.get_track_count()):
            var path := str(animation.track_get_path(track))
            var path_lower := path.to_lower()
            if not ("hips" in path_lower or "upleg" in path_lower or path_lower.ends_with("leg") or "foot" in path_lower or "spine" in path_lower or "armature" in path_lower or "root" in path_lower):
                continue
            var count := animation.track_get_key_count(track)
            var first_value: Variant = animation.track_get_key_value(track, 0) if count > 0 else "<none>"
            var last_value: Variant = animation.track_get_key_value(track, count - 1) if count > 0 else "<none>"
            print("[Ara ride track] variant=%s path=%s type=%d keys=%d first=%s last=%s" % [variant, path, animation.track_get_type(track), count, str(first_value), str(last_value)])
        player.play(CLIP)
        player.seek(0.75, true)
        await process_frame
        await process_frame
        var skeleton := _find_skeleton(actor.model_root)
        if skeleton == null:
            continue
        for bone_name in FOCUS_BONES:
            var index := skeleton.find_bone(bone_name)
            if index < 0:
                continue
            var rest := skeleton.get_bone_rest(index)
            var pose := skeleton.get_bone_pose(index)
            var global_pose := skeleton.get_bone_global_pose(index)
            print("[Ara ride pose] variant=%s bone=%s rest=%s pose_origin=%s pose_rotation_deg=%s global_origin=%s" % [
                variant, bone_name, rest.origin, pose.origin, pose.basis.get_euler() * Vector3(180.0 / PI, 180.0 / PI, 180.0 / PI), global_pose.origin
            ])
    quit(0)

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null
