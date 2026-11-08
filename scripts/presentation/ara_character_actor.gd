class_name AraCharacterActor
extends Node3D
## Runtime wrapper for generated Ara GLBs. The selected body asset is supplied
## by the player profile so Workshop exports can be replaced without code edits.

var model_root: Node3D
var animation_player: AnimationPlayer
var loaded_asset_path: String = ""
var hair_instances: Array[MeshInstance3D] = []
var modular_garment_meshes: Array[MeshInstance3D] = []
var equipment_attachments: Dictionary = {}
const MODULAR_GARMENT_ASSET := "res://art/characters/ara_runtime/ara_person_modular.glb"
const EQUIPMENT_PROP_ROOT := "res://art/characters/ara_runtime/props/"
var current_hair_colour: Color = Color("#49372a")

func configure(glb_path: String) -> bool:
    if model_root != null and is_instance_valid(model_root):
        remove_child(model_root)
        model_root.queue_free()
    model_root = null
    animation_player = null
    hair_instances.clear()
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

## Attach modular garment surfaces to this actor's own Ara skeleton.
## The original body mesh remains visible, preventing transparent clothing from
## cutting holes in the skin beneath it.
func configure_modular_garments(glb_path: String = MODULAR_GARMENT_ASSET) -> bool:
    _clear_modular_garments()
    if model_root == null or not ResourceLoader.exists(glb_path):
        return false
    var target_skeleton := _find_skeleton(model_root)
    if target_skeleton == null:
        push_warning("Cannot attach modular garments: target Ara body has no Skeleton3D")
        return false
    var packed := load(glb_path) as PackedScene
    if packed == null:
        return false
    var source_root := packed.instantiate()
    var source_skeleton := _find_skeleton(source_root)
    if source_skeleton == null or not _same_skeleton(source_skeleton, target_skeleton):
        source_root.free()
        push_warning("Cannot attach modular garments: Workshop skeleton does not match actor skeleton")
        return false
    var source_meshes: Array[MeshInstance3D] = []
    _collect_skinned_meshes(source_root, source_meshes)
    if source_meshes.is_empty():
        source_root.free()
        push_warning("Modular garment export contains no skinned meshes")
        return false
    for source_mesh in source_meshes:
        var instance := MeshInstance3D.new()
        instance.name = "AraModularGarments_" + source_mesh.name
        instance.mesh = source_mesh.mesh
        instance.skin = source_mesh.skin
        instance.transform = source_mesh.transform
        model_root.add_child(instance)
        instance.skeleton = instance.get_path_to(target_skeleton)
        modular_garment_meshes.append(instance)
        for surface in range(instance.mesh.get_surface_count()):
            _set_modular_surface_visible(instance, surface, false)
    source_root.free()
    set_meta("modular_garments_loaded", not modular_garment_meshes.is_empty())
    return not modular_garment_meshes.is_empty()


func _clear_modular_garments() -> void:
    for instance in modular_garment_meshes:
        if is_instance_valid(instance):
            instance.queue_free()
    modular_garment_meshes.clear()


func _surface_label(mesh_instance: MeshInstance3D, surface: int) -> String:
    var material := mesh_instance.mesh.surface_get_material(surface)
    var material_name := material.resource_name.to_lower() if material != null else ""
    return material_name + " " + mesh_instance.mesh.surface_get_name(surface).to_lower()


func _set_modular_surface_visible(mesh_instance: MeshInstance3D, surface: int, visible: bool) -> void:
    var key := "ara_modular_original_%d" % surface
    if not mesh_instance.has_meta(key):
        mesh_instance.set_meta(key, mesh_instance.mesh.surface_get_material(surface))
    var original := mesh_instance.get_meta(key) as Material
    if visible:
        mesh_instance.set_surface_override_material(surface, original)
        return
    var hidden := original.duplicate() as StandardMaterial3D if original is StandardMaterial3D else StandardMaterial3D.new()
    hidden.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    hidden.albedo_color.a = 0.0
    hidden.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    mesh_instance.set_surface_override_material(surface, hidden)


## Render the actual equipped item instances from CharacterState.
func apply_equipment_visuals(equipped_item_data: Dictionary) -> void:
    if modular_garment_meshes.is_empty():
        configure_modular_garments()
    var visible_garments: Array[String] = []
    var weapon_id := ""
    var offhand_id := ""
    var helmet_id := ""
    for slot_variant in equipped_item_data:
        var slot := String(slot_variant)
        var item: Variant = equipped_item_data[slot_variant]
        if not item is Dictionary:
            continue
        var item_id := String(item.get("id", ""))
        match slot:
            "armour":
                if item_id in ["reinforced_leather_armor", "light_armor", "medium_armor", "heavy_armor"]:
                    visible_garments.append("leather armor")
            "weapon":
                weapon_id = item_id
            "offhand":
                offhand_id = item_id
            "helmet":
                helmet_id = item_id
    for mesh_instance in modular_garment_meshes:
        if not is_instance_valid(mesh_instance) or mesh_instance.mesh == null:
            continue
        for surface in range(mesh_instance.mesh.get_surface_count()):
            var label := _surface_label(mesh_instance, surface)
            var show_surface := false
            for fragment in visible_garments:
                if label.contains(fragment):
                    show_surface = true
                    break
            _set_modular_surface_visible(mesh_instance, surface, show_surface)
    _set_equipment_prop("weapon", _weapon_prop_id(weapon_id), "WeaponR")
    var shield_prop := "round_shield" if offhand_id == "wooden_shield" else ("kite_shield" if offhand_id == "bulwark_shield" else "")
    _set_equipment_prop("offhand", shield_prop, "WeaponL")
    _set_equipment_prop("helmet", _helmet_prop_id(helmet_id), "Head")


func _weapon_prop_id(item_id: String) -> String:
    match item_id:
        "sword", "sword_arrow_deflection", "starforged_blade": return "sword"
        "dagger", "featherweight_dagger": return "knife"
        "axe", "hatchet": return "axe"
        "spear", "stormcaller_spear": return "spear"
        "bow", "nightowl_bow": return "bow"
        "club", "ashenwood_club": return "club"
        "mace": return "mace"
        _: return ""


func _helmet_prop_id(item_id: String) -> String:
    match item_id:
        "nasal_helm", "huntsman_helm": return "nasal_helm"
        _: return ""


func _set_equipment_prop(slot: String, prop_id: String, socket_name: String) -> void:
    if equipment_attachments.has(slot):
        var previous: Node = equipment_attachments[slot]
        if is_instance_valid(previous):
            previous.queue_free()
        equipment_attachments.erase(slot)
    if prop_id.is_empty():
        return
    var prop_path := EQUIPMENT_PROP_ROOT + prop_id + ".glb"
    if not ResourceLoader.exists(prop_path):
        push_warning("Equipped %s visual '%s' is not installed at %s" % [slot, prop_id, prop_path])
        return
    var skeleton := _find_skeleton(model_root) if model_root != null else null
    if skeleton == null:
        return
    var candidates: Array[String] = []
    match socket_name:
        "WeaponR":
            candidates = ["WeaponR", "Hand.R", "hand_r", "mixamorig:RightHand", "RightHand"]
        "WeaponL":
            candidates = ["WeaponL", "Hand.L", "hand_l", "mixamorig:LeftHand", "LeftHand"]
        _:
            candidates = ["Head", "head", "mixamorig:Head"]
    var bone_name := ""
    for candidate in candidates:
        if skeleton.find_bone(candidate) >= 0:
            bone_name = candidate
            break
    if bone_name.is_empty():
        push_warning("Cannot attach equipped %s: no compatible %s bone in Ara skeleton" % [prop_id, socket_name])
        return
    var packed := load(prop_path) as PackedScene
    if packed == null:
        return
    var attachment := BoneAttachment3D.new()
    attachment.name = "Equipment_" + slot
    attachment.bone_name = bone_name
    skeleton.add_child(attachment)
    var prop := packed.instantiate()
    prop.name = prop_id
    attachment.add_child(prop)
    equipment_attachments[slot] = attachment


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
    current_hair_colour = hair_colours.get(str(profile.get("hair_colour", "Dark brown")), Color("#49372a"))
    tint_materials("hair", current_hair_colour)
    _tint_attached_hair(current_hair_colour)

    apply_body_parameters(profile)
    set_meta("body_variant", str(profile.get("body_variant", "female")))
    set_meta("gender_presentation", str(profile.get("gender_presentation", "Feminine")))
    set_meta("pronouns", str(profile.get("pronouns", "they/them")))

## Attach a standalone Ara hair GLB to this character's existing skeleton.
## Both exports must use the same pinned Ara rig and bone ordering.
func set_hairstyle(glb_path: String) -> bool:
    if model_root == null:
        return false
    if not ResourceLoader.exists(glb_path):
        clear_hairstyle()
        return false
    var target_skeleton := _find_skeleton(model_root)
    if target_skeleton == null:
        push_warning("Cannot attach Ara hair: character has no Skeleton3D")
        return false
    var packed := load(glb_path) as PackedScene
    if packed == null:
        return false
    var source_root := packed.instantiate()
    var source_skeleton := _find_skeleton(source_root)
    if source_skeleton == null or not _same_skeleton(source_skeleton, target_skeleton):
        source_root.free()
        push_warning("Cannot attach Ara hair: exported skeleton does not match the character")
        return false
    var source_meshes: Array[MeshInstance3D] = []
    _collect_skinned_meshes(source_root, source_meshes)
    if source_meshes.is_empty():
        source_root.free()
        push_warning("Cannot attach Ara hair: GLB contains no skinned MeshInstance3D")
        return false

    clear_hairstyle()
    _set_embedded_hair_visible(false)
    for source_mesh in source_meshes:
        var instance := source_mesh.duplicate() as MeshInstance3D
        if instance == null:
            continue
        instance.name = "Swappable_" + source_mesh.name
        model_root.add_child(instance)
        instance.skeleton = instance.get_path_to(target_skeleton)
        hair_instances.append(instance)
    source_root.free()
    if hair_instances.is_empty():
        _set_embedded_hair_visible(true)
        return false
    _tint_attached_hair(current_hair_colour)
    return true

func clear_hairstyle() -> void:
    for instance in hair_instances:
        if is_instance_valid(instance):
            instance.queue_free()
    hair_instances.clear()
    _set_embedded_hair_visible(true)

func _same_skeleton(a: Skeleton3D, b: Skeleton3D) -> bool:
    if a.get_bone_count() != b.get_bone_count():
        return false
    for index in range(a.get_bone_count()):
        if a.get_bone_name(index) != b.get_bone_name(index):
            return false
    return true

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _collect_skinned_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.skin != null and mesh_instance.mesh != null:
            output.append(mesh_instance)
    for child in node.get_children():
        _collect_skinned_meshes(child, output)

func _set_embedded_hair_visible(visible: bool) -> void:
    if model_root == null:
        return
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(model_root, meshes)
    for mesh_instance in meshes:
        if hair_instances.has(mesh_instance) or mesh_instance.mesh == null:
            continue
        for surface in range(mesh_instance.mesh.get_surface_count()):
            var source := mesh_instance.get_active_material(surface)
            var material_name := source.resource_name.to_lower() if source != null else ""
            if not _is_hair_material(material_name):
                continue
            var meta_key := "ara_embedded_hair_material_%d" % surface
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

func _is_hair_material(material_name: String) -> bool:
    return material_name.contains("hair") or material_name.contains("braid") or material_name.contains("buzz") or material_name.contains("spike")

func _tint_attached_hair(colour: Color) -> void:
    for mesh_instance in hair_instances:
        if not is_instance_valid(mesh_instance) or mesh_instance.mesh == null:
            continue
        for surface in range(mesh_instance.mesh.get_surface_count()):
            var source := mesh_instance.get_active_material(surface)
            var material := source.duplicate() as StandardMaterial3D if source is StandardMaterial3D else StandardMaterial3D.new()
            material.albedo_color = Color(colour.r, colour.g, colour.b, material.albedo_color.a)
            mesh_instance.set_surface_override_material(surface, material)

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


func apply_body_parameters(profile: Dictionary) -> void:
    if model_root == null:
        return
    var aliases := {
        "muscle": ["muscle", "muscularity", "musclemass", "bodymuscle"],
        "weight": ["weight", "bodyweight", "fat", "bodyfat", "adiposity"],
        "height": ["height", "bodyheight", "stature"],
        "proportions": ["proportion", "proportions", "bodyproportion"]
    }
    var values := {
        "muscle": clampf(float(profile.get("muscle", 0.5)), 0.0, 1.0),
        "weight": clampf(float(profile.get("weight", 0.5)), 0.0, 1.0),
        "height": clampf(float(profile.get("height", 0.5)), 0.0, 1.0),
        "proportions": clampf(float(profile.get("proportions", 0.5)), 0.0, 1.0)
    }
    var applied := 0
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(model_root, meshes)
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        for shape_index in range(mesh_instance.mesh.get_blend_shape_count()):
            var shape_name: String = String(mesh_instance.mesh.get_blend_shape_name(shape_index)).to_lower().replace("_", "").replace("-", "").replace(" ", "")
            for parameter in aliases.keys():
                for alias in aliases[parameter]:
                    if shape_name == alias or shape_name.ends_with(alias):
                        mesh_instance.set_blend_shape_value(shape_index, values[parameter])
                        applied += 1
                        break
    set_meta("body_parameters", values)
    set_meta("body_morph_targets_applied", applied)

func apply_npc_parameters(params: Dictionary) -> void:
    if model_root == null:
        return
    var gender := int(params.get("gender", 0))
    var skin := Color("#b9825f")
    var african := float(params.get("african", 0.0))
    var asian := float(params.get("asian", 0.0))
    if african >= 0.6:
        skin = Color("#70452f")
    elif asian >= 0.5:
        skin = Color("#b58a68")
    elif float(params.get("caucasian", 0.0)) >= 0.6:
        skin = Color("#d6a47e")
    var eye_id := str(params.get("eyes", "brown")).to_lower()
    var eye_map := {"brown": "Brown", "brownlight": "Light brown", "darkbrown": "Dark brown", "green": "Green", "blue": "Blue", "grey": "Grey"}
    var hair_tint := Color.from_string(str(params.get("hairTint", "#49372a")), Color("#49372a"))
    var profile := {
        "skin_colour": skin.to_html(false),
        "eye_colour": eye_map.get(eye_id, "Brown"),
        "hair_colour": "Dark brown",
        "height": float(params.get("height", 0.5)),
        "muscle": float(params.get("muscle", 0.5)),
        "weight": float(params.get("weight", 0.5)),
        "proportions": float(params.get("proportions", 0.5)),
        "body_variant": "male" if gender == 1 else "female",
        "gender_presentation": "Masculine" if gender == 1 else "Feminine",
        "pronouns": "they/them"
    }
    apply_player_profile(profile)
    tint_materials("hair", hair_tint)
    current_hair_colour = hair_tint
