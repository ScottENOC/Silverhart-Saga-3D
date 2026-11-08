class_name SeasonalTreeVisual
extends Node3D
## Lightweight procedural tree placeholder with calendar-driven seasonal forms.
## The visual interface is intentionally asset-agnostic so GLB trees can replace
## these meshes later without changing world-season logic.

const SPRING := "spring"
const SUMMER := "summer"
const AUTUMN := "autumn"
const WINTER := "winter"

@export var evergreen: bool = false
@export var tree_seed: int = 1
@export var tree_scale: float = 1.0

var current_season: String = ""

func _ready() -> void:
    add_to_group("seasonal_trees")
    refresh_month(0)

func refresh_month(month_index: int) -> void:
    var next_season := season_for_month(month_index)
    if next_season == current_season:
        return
    current_season = next_season
    _rebuild_visual()

static func season_for_month(month_index: int) -> String:
    var month := posmod(month_index, 12)
    if month == 11 or month <= 1:
        return SPRING
    if month <= 4:
        return SUMMER
    if month <= 7:
        return AUTUMN
    return WINTER

func _rebuild_visual() -> void:
    for child in get_children():
        child.queue_free()

    var rng := RandomNumberGenerator.new()
    rng.seed = abs(tree_seed) + 1

    var trunk := CylinderMesh.new()
    trunk.top_radius = 0.13
    trunk.bottom_radius = 0.21
    trunk.height = 2.1
    trunk.radial_segments = 7
    _add_mesh("Trunk", trunk, Vector3(0.0, 1.05, 0.0), _material(Color(0.25, 0.14, 0.075)))

    if evergreen:
        _build_evergreen(rng)
    elif current_season == WINTER:
        _build_bare_branches(rng)
    else:
        _build_deciduous_canopy(rng)

    if current_season == WINTER:
        _add_snow_accents(rng)

func _build_deciduous_canopy(rng: RandomNumberGenerator) -> void:
    var palette: Array[Color]
    var clusters := 3
    match current_season:
        SPRING:
            palette = [Color(0.48, 0.68, 0.34), Color(0.61, 0.76, 0.43), Color(0.76, 0.78, 0.48)]
        SUMMER:
            palette = [Color(0.20, 0.42, 0.19), Color(0.27, 0.52, 0.22), Color(0.34, 0.58, 0.26)]
        AUTUMN:
            palette = [Color(0.78, 0.39, 0.12), Color(0.84, 0.58, 0.16), Color(0.62, 0.20, 0.10)]
        _:
            palette = [Color(0.3, 0.45, 0.25)]
    if current_season == AUTUMN and rng.randf() < 0.35:
        clusters = 2
    for i in range(clusters):
        var canopy := SphereMesh.new()
        canopy.radius = rng.randf_range(0.82, 1.08)
        canopy.height = canopy.radius * 1.75
        canopy.radial_segments = 7
        canopy.rings = 4
        var offset := Vector3(rng.randf_range(-0.34, 0.34), 2.35 + rng.randf_range(-0.12, 0.55), rng.randf_range(-0.34, 0.34))
        _add_mesh("Canopy_%d" % i, canopy, offset, _material(palette[rng.randi_range(0, palette.size() - 1)]))
    if current_season == SPRING and rng.randf() < 0.65:
        for i in range(4):
            var blossom := SphereMesh.new()
            blossom.radius = 0.13
            blossom.height = 0.2
            blossom.radial_segments = 5
            blossom.rings = 3
            var blossom_pos := Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(2.3, 3.1), rng.randf_range(-0.7, 0.7))
            _add_mesh("Blossom_%d" % i, blossom, blossom_pos, _material(Color(0.95, 0.78, 0.82)))

func _build_evergreen(rng: RandomNumberGenerator) -> void:
    var green := Color(0.12, 0.31, 0.23) if current_season != WINTER else Color(0.16, 0.34, 0.27)
    for i in range(3):
        var cone := CylinderMesh.new()
        cone.top_radius = 0.0
        cone.bottom_radius = 0.92 - float(i) * 0.17
        cone.height = 1.35
        cone.radial_segments = 7
        _add_mesh("Needles_%d" % i, cone, Vector3(0.0, 1.55 + float(i) * 0.65, 0.0), _material(green))
    if current_season == WINTER:
        _add_snow_accents(rng)

func _build_bare_branches(rng: RandomNumberGenerator) -> void:
    for i in range(6):
        var branch := CylinderMesh.new()
        branch.top_radius = 0.025
        branch.bottom_radius = 0.075
        branch.height = rng.randf_range(0.75, 1.25)
        branch.radial_segments = 5
        var angle := TAU * float(i) / 6.0 + rng.randf_range(-0.2, 0.2)
        var branch_node := MeshInstance3D.new()
        branch_node.name = "BareBranch_%d" % i
        branch_node.mesh = branch
        branch_node.position = Vector3(cos(angle) * 0.42, 2.25 + rng.randf_range(0.1, 0.45), sin(angle) * 0.42)
        branch_node.rotation = Vector3(cos(angle) * -0.7, 0.0, sin(angle) * 0.7)
        branch_node.material_override = _material(Color(0.25, 0.14, 0.075))
        branch_node.scale = Vector3.ONE * tree_scale
        add_child(branch_node)

func _add_snow_accents(rng: RandomNumberGenerator) -> void:
    for i in range(3):
        var snow := SphereMesh.new()
        snow.radius = 0.24
        snow.height = 0.2
        snow.radial_segments = 5
        snow.rings = 3
        var position := Vector3(rng.randf_range(-0.55, 0.55), rng.randf_range(2.2, 3.1), rng.randf_range(-0.55, 0.55))
        _add_mesh("Snow_%d" % i, snow, position, _material(Color(0.82, 0.87, 0.88)))

func _add_mesh(node_name: String, mesh: Mesh, local_position: Vector3, material: Material) -> void:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.position = local_position
    instance.material_override = material
    instance.scale = Vector3.ONE * tree_scale
    add_child(instance)

func _material(colour: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = colour
    material.roughness = 1.0
    return material
