extends Node3D

const TERRAIN_RENDERER = preload("res://scripts/presentation/hex_terrain_renderer.gd")
const ORBIT_CAMERA_RIG = preload("res://scripts/presentation/orbit_camera_rig.gd")
const RADIUS := 1.25

func _ready() -> void:
    _create_environment()
    var map_data := HexMapData.new()
    for q in range(-7, 8):
        for r in range(-7, 8):
            var hex := Vector2i(q, r)
            var centre := HexGrid.axial_to_world(hex, RADIUS)
            map_data.add_cell(hex, _height_at(centre.x, centre.z), true, "grass")
    # Sample a single continuous height function at every shared vertex.
    # Adjacent cells resolve identical world-space vertex keys and therefore
    # cannot develop cracks or vertical seams.
    for key in map_data.cells:
        var hex: Vector2i = key
        var centre := HexGrid.axial_to_world(hex, RADIUS)
        var corner_offsets := HexGrid.corner_offsets(RADIUS)
        for corner_index in range(HexGrid.SIDE_COUNT):
            var corner_offset: Vector2 = corner_offsets[corner_index]
            var world_x := centre.x + corner_offset.x
            var world_z := centre.z + corner_offset.y
            map_data.set_vertex_height(hex, corner_index, _height_at(world_x, world_z), RADIUS)

    var terrain := TERRAIN_RENDERER.new()
    terrain.name = "ElevationPrototypeTerrain"
    add_child(terrain)
    terrain.rebuild(map_data, RADIUS)
    _add_marker("VALLEY FLOOR", Vector3(-4.5, -1.1, 0.0))
    _add_marker("SLOPE", Vector3(1.0, 1.2, 0.0))
    _add_marker("RIDGE / ESCARPMENT", Vector3(7.0, 3.2, 0.0))
    _create_camera()

func _height_at(x: float, z: float) -> float:
    var valley := -1.8 * exp(-pow((x + 4.0) / 3.2, 2.0)) * exp(-pow(z / 7.0, 2.0))
    var ridge := 3.4 * exp(-pow((x - 5.0) / 1.8, 2.0))
    var broad_terrain := 0.012 * (x * x + z * z)
    return valley + ridge + broad_terrain

func _create_environment() -> void:
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    sun.light_energy = 1.5
    sun.shadow_enabled = true
    add_child(sun)
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.48, 0.57, 0.62)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.62, 0.62, 0.58)
    environment.ambient_light_energy = 0.65
    world.environment = environment
    add_child(world)

func _create_camera() -> void:
    var rig: OrbitCameraRig = ORBIT_CAMERA_RIG.new()
    rig.name = "TerrainOrbitCamera"
    rig.position = Vector3(0.0, 0.8, 0.0)
    rig.zoom_distance = 34.0
    var pitch_pivot := Node3D.new()
    pitch_pivot.name = "PitchPivot"
    rig.add_child(pitch_pivot)
    var camera := Camera3D.new()
    camera.name = "Camera3D"
    camera.current = true
    camera.fov = 52.0
    pitch_pivot.add_child(camera)
    add_child(rig)

    var canvas := CanvasLayer.new()
    var label := Label.new()
    label.position = Vector2(22.0, 18.0)
    label.text = "ELEVATION PROTOTYPE  |  Right-drag: orbit  |  Wheel: zoom"
    label.add_theme_font_size_override("font_size", 20)
    label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.88))
    canvas.add_child(label)
    add_child(canvas)

func _add_marker(marker_text: String, world_position: Vector3) -> void:
    var marker := Label3D.new()
    marker.text = marker_text
    marker.position = world_position + Vector3.UP * 0.35
    marker.font_size = 42
    marker.outline_size = 8
    marker.modulate = Color(0.98, 0.91, 0.68)
    marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(marker)
