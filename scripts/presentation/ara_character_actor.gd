class_name AraCharacterActor
extends Node3D
## Loads a complete character exported by the pinned Ara build pipeline.
## Appearance is baked at build time; this node only handles presentation.

var model_root: Node3D
var animation_player: AnimationPlayer

func configure(glb_path: String) -> bool:
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
    animation_player = _find_animation_player(model_root)
    _play_idle_if_available()
    return true

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
    var names := animation_player.get_animation_list()
    for animation_name in names:
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
