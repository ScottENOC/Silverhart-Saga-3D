class_name ModularCharacterAssembler
extends Node3D

## Runtime appearance assembly. Body supplies the canonical Skeleton3D;
## every optional component is rebound to that skeleton after instantiation.
## Simulation data should store the IDs passed to configure/set_component.

const COMPONENTS := {
    "hair": {
        "braid": "res://art/characters/wren/hair_braid.glb",
    },
    "weapon": {
        "sword": "res://art/characters/wren/weapon_sword.glb",
    },
    "torso_garment": {
        "base": "res://art/characters/wren/garment_torso_base.glb",
    },
    "leg_garment": {
        "base": "res://art/characters/wren/garment_legs_base.glb",
    },
    "torso_armour": {
        "base": "res://art/characters/wren/armour_torso_base.glb",
    },
    "leg_armour": {
        "base": "res://art/characters/wren/armour_legs_base.glb",
    },
}

const BODY_SCENE := "res://art/characters/wren/body.glb"

var shared_skeleton: Skeleton3D
var body_instance: Node3D
var slot_mounts: Dictionary = {}
var active_components: Dictionary = {}

func configure(appearance: Dictionary) -> bool:
    _clear_all()
    var body_resource := load(BODY_SCENE) as PackedScene
    if body_resource == null:
        push_error("Modular character body is missing: " + BODY_SCENE)
        return false

    body_instance = body_resource.instantiate() as Node3D
    if body_instance == null:
        push_error("Modular character body root is not Node3D.")
        return false
    body_instance.name = "BodyComponent"
    add_child(body_instance)
    shared_skeleton = _find_skeleton(body_instance)
    if shared_skeleton == null:
        push_error("Body component does not contain a Skeleton3D.")
        body_instance.queue_free()
        body_instance = null
        return false

    for slot in COMPONENTS.keys():
        var mount := Node3D.new()
        mount.name = _slot_node_name(slot)
        add_child(mount)
        slot_mounts[slot] = mount

    for slot_variant in appearance.keys():
        var slot := str(slot_variant)
        var component_id := str(appearance[slot_variant])
        if component_id.is_empty():
            continue
        if not set_component(slot, component_id):
            push_warning("Could not equip appearance component %s in slot %s." % [component_id, slot])
    return true

func set_component(slot: String, component_id: String) -> bool:
    if not slot_mounts.has(slot) or not COMPONENTS.has(slot):
        push_warning("Unknown appearance slot: " + slot)
        return false
    var slot_catalog: Dictionary = COMPONENTS[slot]
    if not slot_catalog.has(component_id):
        push_warning("Unknown component ID %s for slot %s." % [component_id, slot])
        return false

    clear_slot(slot)
    var path: String = slot_catalog[component_id]
    var resource := load(path) as PackedScene
    if resource == null:
        push_warning("Appearance asset has not been exported/imported yet: " + path)
        return false
    var source := resource.instantiate() as Node3D
    if source == null:
        push_warning("Appearance asset root is not Node3D: " + path)
        return false

    var mount: Node3D = slot_mounts[slot]
    mount.add_child(source)
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(source, meshes)
    if meshes.is_empty():
        source.queue_free()
        push_warning("Appearance asset contains no MeshInstance3D nodes: " + path)
        return false

    # Imported component GLBs contain a duplicate copy of the canonical rig.
    # Move their skinned meshes under this character and point each at the
    # body's Skeleton3D. All exports must use the exact same bone layout/order.
    for mesh_instance in meshes:
        mesh_instance.reparent(mount, true)
        mesh_instance.skeleton = mesh_instance.get_path_to(shared_skeleton)

    source.queue_free()
    active_components[slot] = component_id
    return true

func clear_slot(slot: String) -> void:
    if not slot_mounts.has(slot):
        return
    var mount: Node3D = slot_mounts[slot]
    for child in mount.get_children():
        child.queue_free()
    active_components.erase(slot)

func get_appearance() -> Dictionary:
    return active_components.duplicate(true)

func _clear_all() -> void:
    for child in get_children():
        child.queue_free()
    shared_skeleton = null
    body_instance = null
    slot_mounts.clear()
    active_components.clear()

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
