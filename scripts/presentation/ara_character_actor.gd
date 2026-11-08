class_name AraCharacterActor
extends Node3D
## Runtime wrapper for generated Ara GLBs. The selected body asset is supplied
## by the player profile so Workshop exports can be replaced without code edits.

var model_root: Node3D
var animation_player: AnimationPlayer
var loaded_asset_path: String = ""

func configure(glb_path: String) -> bool:
    if model_root != null and is_instance_valid(model_root):
        remove_child(model_root)
        model_root.queue_free()
    model_root = null
    animation_player = null
    loaded_asset_path = ""
    if not ResourceLoader.exists(glb_path):
        push_warning("Ara character asset is not installed: " + glb_path)
        return false
    var packed := load(glb_path) as PackedScene
    if packed == null:
        push_warning("Ara character GLB could not be loaded: " + glb_path)
        return false
    model_root = packed.instantiate() as Node3D
    if model_root == null:
        push_warning("Ara character root is not Node3D: " + glb_path)
        return false
    model_root.name = "AraModel"
    add_child(model_root)
    loaded_asset_path = glb_path
    animation_player = _find_animation_player(model_root)
    _play_idle_if_available()
    return true

func apply_player_profile(profile: Dictionary) -> void:
    if model_root == null:
        return
    var skin := Color.from_string(str(profile.get("skin_colour", "#b9825f")), Color(0.72, 0.57, 0.43))
    var eye_colours := {
        "Brown": Color("#49301f"), "Light brown": Color("#795334"),
        "Dark brown": Color("#24170f"), "Green": Color("#55744b"),
        "Blue": Color("#426f9a"), "Grey": Color("#777d83"),
        "Ice blue": Color("#9bc8df")
    }
    var hair_colours := {
        "Black": Color("#171513"), "Dark brown": Color("#49372a"),
        "Chestnut": Color("#75452d"), "Blonde": Color("#c6a45e"),
        "Red": Color("#9a422e"), "Silver": Color("#aaa9a3"),
        "White": Color("#e4dfd2"), "Blue": Color("#354d91"),
        "Green": Color("#426b49")
    }
    tint_materials("skin", skin)
    tint_materials("eye", eye_colours.get(str(profile.get("eye_colour", "Brown")), Color("#49301f")))
    tint_materials("hair", hair_colours.get(str(profile.get("hair_colour", "Dark brown")), Color("#49372a")))

    # Height and build are intentionally modest whole-model proportion controls
    # until the Ara exports expose validated body morph targets.
    var height_factor := clampf(float(profile.get("height_scale", 1.0)), 0.90, 1.10)
    var build_factor := clampf(float(profile.get("build_scale", 1.0)), 0.92, 1.08)
    model_root.scale = Vector3(build_factor, height_factor, build_factor)
    set_meta("body_variant", str(profile.get("body_variant", "female")))
    set_meta("gender_presentation", str(profile.get("gender_presentation", "Feminine")))
    set_meta("pronouns", str(profile.get("pronouns", "they/them")))

func set_garment_visible(material_fragment: String, visible: bool) -> bool:
    if model_root == null:
        return false
    var needle := material_fragment.to_lower()
    var changed := false
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(model_root, meshes)
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        for surface in range(mesh_instance.mesh.get_surface_count()):
            var source := mesh_instance.get_active_material(surface)
            var material_name := source.resource_name.to_lower() if source != null else ""
            if not material_name.contains(needle) and not mesh_instance.name.to_lower().contains(needle):
                continue
            var meta_key := "ara_original_material_%d" % surface
            if not mesh_instance.has_meta(meta_key):
                mesh_instance.set_meta(meta_key, source)
            var original := mesh_instance.get_meta(meta_key) as Material
            if visible:
                mesh_instance.set_surface_override_material(surface, original)
            else:
                var hidden := original.duplicate() as StandardMaterial3D if original is StandardMaterial3D else StandardMaterial3D.new()
                hidden.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                hidden.albedo_color.a = 0.0
                hidden.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
                mesh_instance.set_surface_override_material(surface, hidden)
            changed = true
    return changed

func _play_idle_if_available() -> void:
    if animation_player == null:
        return
    for animation_name in animation_player.get_animation_list():
        if str(animation_name).to_lower().contains("idle"):
            animation_player.play(animation_name)
            return

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)

func tint_materials(name_fragment: String, colour: Color) -> int:
    if model_root == null:
        return 0
    var changed := 0
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(model_root, meshes)
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        for surface in range(mesh_instance.mesh.get_surface_count()):
            var source := mesh_instance.get_active_material(surface)
            var material_name := source.resource_name.to_lower() if source != null else ""
            if not material_name.contains(name_fragment.to_lower()) and not mesh_instance.name.to_lower().contains(name_fragment.to_lower()):
                continue
            var original_key := "ara_original_tint_material_%d" % surface
            if not mesh_instance.has_meta(original_key):
                mesh_instance.set_meta(original_key, source)
            var original := mesh_instance.get_meta(original_key) as Material
            var material := original.duplicate() as StandardMaterial3D if original is StandardMaterial3D else StandardMaterial3D.new()
            material.albedo_color = Color(colour.r, colour.g, colour.b, material.albedo_color.a)
            mesh_instance.set_surface_override_material(surface, material)
            changed += 1
    return changed
