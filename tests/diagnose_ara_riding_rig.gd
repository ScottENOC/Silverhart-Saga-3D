extends SceneTree
## Inspect the actual Ara male/female rigs before authoring a reusable riding pose.

const ARA_ACTOR = preload("res://scripts/presentation/ara_character_actor.gd")
const BODY_PATHS := {
    "female": "res://art/characters/ara_runtime/ara_person_body.glb",
    "male": "res://art/characters/ara_runtime/ara_person_male_body.glb"
}

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var actors: Dictionary = {}
    for variant in BODY_PATHS:
        var actor := ARA_ACTOR.new() as AraCharacterActor
        actor.name = "Rig_" + variant
        root.add_child(actor)
        if not actor.configure(BODY_PATHS[variant]):
            push_error("Could not load Ara %s body" % variant)
            quit(1)
            return
        actors[variant] = actor

    for _frame in range(5):
        await process_frame

    var signatures: Dictionary = {}
    for variant in actors:
        var actor: AraCharacterActor = actors[variant]
        var skeleton := _find_skeleton(actor.model_root)
        if skeleton == null:
            push_error("Ara %s model has no Skeleton3D" % variant)
            quit(1)
            return
        print("[Ara riding rig] VARIANT=%s BONES=%d ANIMATIONS=%s" % [
            variant, skeleton.get_bone_count(),
            ", ".join(actor.animation_player.get_animation_list()) if actor.animation_player != null else "<none>"
        ])
        var signature: Array[String] = []
        for index in range(skeleton.get_bone_count()):
            var parent := skeleton.get_bone_parent(index)
            var rest := skeleton.get_bone_rest(index)
            signature.append(skeleton.get_bone_name(index))
            print("[Ara riding rig] %s bone=%d name=%s parent=%d rest_origin=%s" % [
                variant, index, skeleton.get_bone_name(index), parent, rest.origin
            ])
        signatures[variant] = signature

    print("[Ara riding rig] SAME_BONE_ORDER=%s" % str(signatures["female"] == signatures["male"]))
    quit(0)

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null
