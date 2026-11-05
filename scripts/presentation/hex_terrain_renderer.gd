class_name HexTerrainRenderer
extends Node3D

var terrain_mesh_instance: MeshInstance3D
var edge_mesh_instance: MeshInstance3D
var terrain_material: StandardMaterial3D
var edge_material: StandardMaterial3D

func _ready() -> void:
    terrain_material = StandardMaterial3D.new()
    terrain_material.vertex_color_use_as_albedo = true
    terrain_material.roughness = 1.0
    terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    edge_material = StandardMaterial3D.new()
    edge_material.albedo_color = Color(0.12, 0.15, 0.12, 0.55)
    edge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    edge_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func rebuild(map_data: HexMapData, radius: float = HexGrid.DEFAULT_RADIUS_M) -> void:
    if terrain_material == null:
        _ready()
    if is_instance_valid(terrain_mesh_instance):
        terrain_mesh_instance.queue_free()
    if is_instance_valid(edge_mesh_instance):
        edge_mesh_instance.queue_free()

    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var edges := SurfaceTool.new()
    edges.begin(Mesh.PRIMITIVE_LINES)
    var seen_edges: Dictionary = {}
    var corners := HexGrid.corner_offsets(radius)

    for key in map_data.cells:
        var hex: Vector2i = key
        var centre := HexGrid.axial_to_world(hex, radius)
        var centre_height := map_data.elevation_at(hex)
        var centre_colour := _height_colour(centre_height)
        for i in range(HexGrid.SIDE_COUNT):
            var next_i := (i + 1) % HexGrid.SIDE_COUNT
            var a := map_data.corner_world_position(hex, i, radius)
            var b := map_data.corner_world_position(hex, next_i, radius)
            var c := Vector3(centre.x, centre_height, centre.z)
            var blocked_tint := Color(0.22, 0.20, 0.18)
            var centre_tint := centre_colour if map_data.is_walkable(hex) else centre_colour.lerp(blocked_tint, 0.72)
            var b_tint := _height_colour(b.y) if map_data.is_walkable(hex) else _height_colour(b.y).lerp(blocked_tint, 0.72)
            var a_tint := _height_colour(a.y) if map_data.is_walkable(hex) else _height_colour(a.y).lerp(blocked_tint, 0.72)
            surface.set_color(centre_tint)
            surface.add_vertex(c + Vector3.UP * 0.012)
            surface.set_color(b_tint)
            surface.add_vertex(b + Vector3.UP * 0.012)
            surface.set_color(a_tint)
            surface.add_vertex(a + Vector3.UP * 0.012)

            var key_a := HexMapData.vertex_key(a.x, a.z)
            var key_b := HexMapData.vertex_key(b.x, b.z)
            var edge_key := key_a + "|" + key_b if key_a < key_b else key_b + "|" + key_a
            if not seen_edges.has(edge_key):
                seen_edges[edge_key] = true
                edges.add_vertex(a + Vector3.UP * 0.025)
                edges.add_vertex(b + Vector3.UP * 0.025)

    surface.index()
    surface.generate_normals()
    var terrain_instance := MeshInstance3D.new()
    terrain_instance.name = "ContinuousHexTerrain"
    terrain_instance.mesh = surface.commit()
    terrain_instance.material_override = terrain_material
    add_child(terrain_instance)
    terrain_mesh_instance = terrain_instance

    var edge_instance := MeshInstance3D.new()
    edge_instance.name = "HexGridOverlay"
    edge_instance.mesh = edges.commit()
    edge_instance.material_override = edge_material
    add_child(edge_instance)
    edge_mesh_instance = edge_instance

func _height_colour(height: float) -> Color:
    if height < -0.5:
        return Color(0.25, 0.31, 0.29).lerp(Color(0.38, 0.39, 0.31), clampf((height + 3.0) / 2.5, 0.0, 1.0))
    if height < 1.5:
        return Color(0.38, 0.39, 0.31).lerp(Color(0.48, 0.43, 0.32), clampf((height + 0.5) / 2.0, 0.0, 1.0))
    return Color(0.48, 0.43, 0.32).lerp(Color(0.70, 0.66, 0.57), clampf((height - 1.5) / 4.0, 0.0, 1.0))
