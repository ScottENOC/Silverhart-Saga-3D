class_name ModularCharacterAssembler
extends Node3D

## Reusable Ara component assembler. The body owns the canonical Skeleton3D;
## garments and hair are skinned to that rig. Equipment/appearance IDs are data,
## not node names or one-off character scenes.

const BODY_VARIANTS := {
    "ara_female_slim": {"folder": "npc_female_slim", "hair": "long01", "shirt": "fatigue_shirt", "shirt_alt": "tank_top", "trousers": "fatigue_pants", "trousers_alt": "cargo_shorts", "boots": "combat_boots", "main_hand": "sword"},
    "ara_male_heavy": {"folder": "npc_male_heavy", "hair": "short02", "shirt": "fatigue_shirt", "shirt_alt": "tank_top", "trousers": "fatigue_pants", "trousers_alt": "cargo_shorts", "boots": "combat_boots", "main_hand": "sword"},
    "ara_female_athletic": {"folder": "npc_female_athletic", "hair": "ponytail01", "shirt": "tank_top", "shirt_alt": "fatigue_shirt", "trousers": "cargo_shorts", "trousers_alt": "fatigue_pants", "boots": "combat_boots", "main_hand": "sword"}
}
const EQUIPMENT_SLOTS := ["shirt", "trousers", "boots", "torso_armour", "leg_armour", "main_hand", "off_hand"]

var current_body_variant: String = ""
var shared_skeleton: Skeleton3D
var body_instance: Node3D
var slot_mounts: Dictionary = {}
var active_components: Dictionary = {}
var active_materials: Dictionary = {}

func configure(appearance: CharacterAppearance) -> bool:
    if appearance == null:
        return false
    _clear_all()
    current_body_variant = appearance.body_variant
    var variant: Dictionary = BODY_VARIANTS.get(current_body_variant, {})
    var folder := str(variant.get("folder", ""))
    var body_path := "res://art/characters/ara/npcs/%s/body.glb" % folder if not folder.is_empty() else ""
    if body_path.is_empty():
        push_error("Unknown body variant: " + appearance.body_variant)
        return false
    var body_resource := load(body_path) as PackedScene
    if body_resource == null:
        push_error("Body asset is missing: " + body_path)
        return false
    body_instance = body_resource.instantiate() as Node3D
    if body_instance == null:
        return false
    body_instance.name = "BodyComponent"
    add_child(body_instance)
    shared_skeleton = _find_skeleton(body_instance)
    if shared_skeleton == null:
        push_error("Body component has no Skeleton3D.")
        _clear_all()
        return false
    for slot in ["hair", "shirt", "trousers", "boots", "torso_armour", "leg_armour", "main_hand", "off_hand"]:
        var mount := Node3D.new()
        mount.name = _slot_node_name(slot)
        add_child(mount)
        slot_mounts[slot] = mount
    set_component("hair", appearance.hair_id)
    for slot in EQUIPMENT_SLOTS:
        var default_id := str(variant.get(slot, ""))
        var item_id := str(appearance.equipment.get(slot, default_id))
        if not item_id.is_empty():
            set_component(slot, item_id)
    for slot in appearance.materials:
        var material_data: Dictionary = appearance.materials[slot]
        set_garment_material(str(slot), material_data)
    return true

func set_component(slot: String, component_id: String) -> bool:
    if not slot_mounts.has(slot):
        push_warning("Unknown appearance slot: " + slot)
        return false
    var path := _component_path(slot, component_id)
    if path.is_empty():
        push_warning("No generated asset for %s in slot %s on body %s." % [component_id, slot, current_body_variant])
        return false
    clear_slot(slot)
    var resource := load(path) as PackedScene
    if resource == null:
        push_warning("Appearance asset is not imported: " + path)
        return false
    var source := resource.instantiate() as Node3D
    if source == null:
        return false
    var mount: Node3D = slot_mounts[slot]
    mount.add_child(source)
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(source, meshes)
    if meshes.is_empty():
        source.queue_free()
        return false
    for mesh_instance in meshes:
        mesh_instance.skeleton = mesh_instance.get_path_to(shared_skeleton)
    active_components[slot] = component_id
    return true

func _component_path(slot: String, component_id: String) -> String:
    var variant: Dictionary = BODY_VARIANTS.get(current_body_variant, {})
    var folder := str(variant.get("folder", ""))
    if folder.is_empty():
        return ""
    var root := "res://art/characters/ara/npcs/%s/" % folder
    if slot == "hair":
        return root + "hair.glb" if component_id == str(variant.get("hair", "")) else ""
    if slot == "shirt":
        if component_id == str(variant.get("shirt", "")):
            return root + "shirt.glb"
        if component_id == str(variant.get("shirt_alt", "")):
            return root + "shirt_alt.glb"
        return ""
    if slot == "trousers":
        if component_id == str(variant.get("trousers", "")):
            return root + "trousers.glb"
        if component_id == str(variant.get("trousers_alt", "")):
            return root + "trousers_alt.glb"
        return ""
    if slot == "boots" and component_id == str(variant.get("boots", "")):
        return root + "boots.glb"
    if slot == "main_hand" and component_id == str(variant.get("main_hand", "")):
        return root + "weapon_sword.glb"
    return ""

func clear_slot(slot: String) -> void:
    if not slot_mounts.has(slot):
        return
    var mount: Node3D = slot_mounts[slot]
    for child in mount.get_children():
        child.queue_free()
    active_components.erase(slot)

func set_garment_material(slot: String, data: Dictionary) -> bool:
    if not slot_mounts.has(slot):
        return false
    var changed := false
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(slot_mounts[slot], meshes)
    var colour := Color.from_string(str(data.get("colour", "#ffffff")), Color.WHITE)
    var opacity := clampf(float(data.get("opacity", 1.0)), 0.0, 1.0)
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        for surface_index in range(mesh_instance.mesh.get_surface_count()):
            var source := mesh_instance.get_active_material(surface_index)
            if source == null:
                continue
            var material_copy := source.duplicate(true) as BaseMaterial3D
            if material_copy == null:
                continue
            material_copy.albedo_color = Color(colour.r, colour.g, colour.b, opacity)
            material_copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if opacity < 0.999 else BaseMaterial3D.TRANSPARENCY_DISABLED
            mesh_instance.set_surface_override_material(surface_index, material_copy)
            changed = true
    if changed:
        active_materials[slot] = data.duplicate(true)
    return changed

func get_appearance() -> Dictionary:
    return {"components": active_components.duplicate(true), "materials": active_materials.duplicate(true)}

func _clear_all() -> void:
    for child in get_children():
        child.queue_free()
    shared_skeleton = null
    body_instance = null
    current_body_variant = ""
    slot_mounts.clear()
    active_components.clear()
    active_materials.clear()

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)

func _slot_node_name(slot: String) -> String:
    return slot.capitalize().replace("_", "") + "Slot"
