class_name WildernessResourceVisual
extends Node3D
## Visible representation of a simulation resource node. The logical node and
## harvesting rules remain in WildernessResourceSystem; this script only draws it.

const ASSET_ROOT := "res://art/environment/kenney_nature/"
const TREE_SCRIPT = preload("res://scripts/presentation/seasonal_tree_visual.gd")

var resource_state: Dictionary = {}
var month_index: int = 0

func refresh(state: Dictionary, calendar_month: int = 0) -> void:
    var changed := state != resource_state or calendar_month != month_index
    if not changed:
        return
    resource_state = state.duplicate(true)
    month_index = calendar_month
    _rebuild()

func _rebuild() -> void:
    for child in get_children():
        remove_child(child)
        child.free()
    if resource_state.is_empty():
        return

    var node_type := String(resource_state.get("type", ""))
    match node_type:
        "fruit_tree":
            _build_tree(true, bool(resource_state.get("available", false)))
        "timber_tree":
            _build_tree(false, bool(resource_state.get("available", false)))
        "ore_node":
            _build_ore()
        "stone_deposit":
            _build_stone()
        "herb_patch":
            _build_herbs()
        "fishing_spot":
            _build_fishing_spot()
        _:
            return
    _add_label(_display_name(node_type))

func _build_tree(fruit_tree: bool, available: bool) -> void:
    if not available and not fruit_tree:
        if not _add_asset("stump_round_detailed.glb", Vector3.ONE * 3.2):
            _add_procedural_stump()
        return

    var tree := TREE_SCRIPT.new() as SeasonalTreeVisual
    tree.evergreen = false
    tree.tree_seed = 71 if fruit_tree else 93
    tree.tree_scale = 3.4
    tree.species_variant = "oak" if fruit_tree else "default"
    add_child(tree)
    tree.refresh_month(month_index)

    if fruit_tree and available:
        var fruit_material := _material(Color(0.78, 0.16, 0.10))
        for i in range(7):
            var fruit := SphereMesh.new()
            fruit.radius = 0.13
            fruit.height = 0.16
            fruit.radial_segments = 7
            fruit.rings = 4
            var angle := TAU * float(i) / 7.0
            var instance := MeshInstance3D.new()
            instance.name = "Fruit_%d" % i
            instance.mesh = fruit
            instance.position = Vector3(cos(angle) * 1.0, 2.65 + fposmod(float(i) * 0.31, 0.75), sin(angle) * 0.9)
            instance.material_override = fruit_material
            add_child(instance)

func _build_ore() -> void:
    var ore_item_id := String(resource_state.get("item_id", "ore_iron"))
    var rock := "rock_large_d.glb" if posmod(ore_item_id.hash(), 2) == 0 else "rock_large_a.glb"
    if not _add_asset(rock, Vector3.ONE * 2.1):
        _add_fallback_rock()
    if bool(resource_state.get("depleted", false)):
        return
    var item_id := ore_item_id
    var crystal_colour := Color(0.58, 0.60, 0.62)
    if item_id == "ore_silver":
        crystal_colour = Color(0.72, 0.80, 0.86)
    elif item_id == "ore_gold":
        crystal_colour = Color(0.92, 0.66, 0.16)
    elif item_id.begins_with("gem_"):
        crystal_colour = Color(0.20, 0.66, 0.78) if item_id == "gem_blue" else Color(0.78, 0.22, 0.25)
    elif item_id == "starmetal_ore":
        crystal_colour = Color(0.48, 0.42, 0.82)
    for i in range(3):
        var shard := CylinderMesh.new()
        shard.top_radius = 0.0
        shard.bottom_radius = 0.16
        shard.height = 0.9 + float(i) * 0.18
        shard.radial_segments = 5
        var crystal := MeshInstance3D.new()
        crystal.name = "OreVein_%d" % i
        crystal.mesh = shard
        crystal.position = Vector3(-0.35 + float(i) * 0.34, 0.45, 0.15 if i % 2 == 0 else -0.18)
        crystal.rotation_degrees.z = -12.0 + float(i) * 8.0
        crystal.material_override = _material(crystal_colour)
        add_child(crystal)

func _build_stone() -> void:
    if not _add_asset("rock_large_a.glb", Vector3.ONE * 1.9):
        _add_fallback_rock()
    _add_asset("rock_large_d.glb", Vector3.ONE * 0.9, Vector3(0.9, 0.0, 0.45))

func _build_herbs() -> void:
    _add_asset("plant_bush_detailed.glb", Vector3.ONE * 1.35)
    for i in range(3):
        var flower_name := "flower_purple_a.glb" if i % 2 == 0 else "mushroom_red_group.glb"
        _add_asset(flower_name, Vector3.ONE * 1.2, Vector3(-0.65 + float(i) * 0.65, 0.0, 0.4))
    if not ResourceLoader.exists(ASSET_ROOT + "plant_bush_detailed.glb"):
        _add_fallback_herbs()

func _build_fishing_spot() -> void:
    var water := CylinderMesh.new()
    water.top_radius = 1.05
    water.bottom_radius = 1.05
    water.height = 0.025
    water.radial_segments = 20
    var surface := MeshInstance3D.new()
    surface.name = "FishingPool"
    surface.mesh = water
    surface.position.y = 0.04
    surface.material_override = _material(Color(0.22, 0.48, 0.58, 0.78))
    add_child(surface)
    var ring := TorusMesh.new()
    ring.inner_radius = 0.78
    ring.outer_radius = 0.84
    ring.rings = 4
    ring.ring_segments = 24
    var ripple := MeshInstance3D.new()
    ripple.mesh = ring
    ripple.position.y = 0.08
    ripple.material_override = _material(Color(0.68, 0.79, 0.77, 0.65))
    add_child(ripple)

func _add_asset(file_name: String, model_scale: Vector3, local_position: Vector3 = Vector3.ZERO) -> bool:
    var path := ASSET_ROOT + file_name
    if not ResourceLoader.exists(path):
        return false
    var packed := load(path) as PackedScene
    if packed == null:
        return false
    var model := packed.instantiate() as Node3D
    if model == null:
        return false
    model.scale = model_scale
    model.position = local_position
    add_child(model)
    return true

func _add_fallback_rock() -> void:
    var mesh := SphereMesh.new()
    mesh.radius = 0.9
    mesh.height = 1.25
    mesh.radial_segments = 7
    mesh.rings = 4
    var rock := MeshInstance3D.new()
    rock.mesh = mesh
    rock.position.y = 0.55
    rock.material_override = _material(Color(0.37, 0.38, 0.36))
    add_child(rock)

func _add_procedural_stump() -> void:
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.36
    mesh.bottom_radius = 0.43
    mesh.height = 0.55
    mesh.radial_segments = 8
    var stump := MeshInstance3D.new()
    stump.mesh = mesh
    stump.position.y = 0.28
    stump.material_override = _material(Color(0.32, 0.19, 0.10))
    add_child(stump)

func _add_fallback_herbs() -> void:
    for i in range(5):
        var stem := CylinderMesh.new()
        stem.top_radius = 0.025
        stem.bottom_radius = 0.04
        stem.height = 0.55 + float(i % 3) * 0.12
        var plant := MeshInstance3D.new()
        plant.mesh = stem
        plant.position = Vector3(-0.5 + float(i) * 0.25, 0.3, 0.1 * float(i % 2))
        plant.material_override = _material(Color(0.24, 0.43, 0.20))
        add_child(plant)

func _add_label(text_value: String) -> void:
    var label := Label3D.new()
    label.name = "ResourceLabel"
    label.text = text_value
    label.position = Vector3(0.0, 5.0, 0.0)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 34
    label.outline_size = 7
    label.modulate = Color(0.98, 0.94, 0.82)
    add_child(label)

func _display_name(node_type: String) -> String:
    match node_type:
        "fruit_tree": return "Fruit tree"
        "timber_tree": return "Timber tree"
        "ore_node": return "Ore vein"
        "stone_deposit": return "Stone deposit"
        "herb_patch": return "Herbs"
        "fishing_spot": return "Fishing spot"
    return "Gatherable"

func _material(colour: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = colour
    material.roughness = 0.92
    return material
