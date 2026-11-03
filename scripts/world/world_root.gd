extends Node3D

const MAP_RANGE: int = 7
const HEX_RADIUS: float = HexGrid.DEFAULT_RADIUS_M

var simulation: WorldSimulation
var player_visual: HexActorPresentation
var camera_rig: OrbitCameraRig
var tile_material: StandardMaterial3D

var obstacle_hexes: Array[Vector2i] = [
    Vector2i(2, 1),
    Vector2i(-2, 2),
    Vector2i(1, -3),
]

func _ready() -> void:
    _create_lighting()
    _create_simulation()
    _create_terrain()
    _create_player()
    _create_camera()
    _create_hud()

func _create_lighting() -> void:
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
    sun.light_energy = 1.15
    add_child(sun)

    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.48, 0.62, 0.69)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.55, 0.60, 0.66)
    env.ambient_light_energy = 0.55
    environment.environment = env
    add_child(environment)

func _create_simulation() -> void:
    simulation = WorldSimulation.new()
    simulation.name = "WorldSimulation"
    add_child(simulation)

    for q in range(-MAP_RANGE, MAP_RANGE + 1):
        for r in range(-MAP_RANGE, MAP_RANGE + 1):
            var hex := Vector2i(q, r)
            var blocked: bool = obstacle_hexes.has(hex)
            simulation.map_data.add_cell(hex, 0.0, not blocked, "grass")

    var player_state := CharacterState.new("player", "Player", Vector2i.ZERO)
    simulation.register_character(player_state)
    simulation.character_moved.connect(_on_character_moved)

func _create_terrain() -> void:
    tile_material = StandardMaterial3D.new()
    tile_material.albedo_color = Color(0.28, 0.38, 0.27)
    tile_material.roughness = 1.0

    var blocked_material := StandardMaterial3D.new()
    blocked_material.albedo_color = Color(0.30, 0.29, 0.25)
    blocked_material.roughness = 1.0

    for q in range(-MAP_RANGE, MAP_RANGE + 1):
        for r in range(-MAP_RANGE, MAP_RANGE + 1):
            var hex := Vector2i(q, r)
            var tile := MeshInstance3D.new()
            var mesh := CylinderMesh.new()
            mesh.top_radius = HEX_RADIUS
            mesh.bottom_radius = HEX_RADIUS
            mesh.height = 0.12
            mesh.radial_segments = 6
            mesh.rings = 1
            tile.mesh = mesh
            tile.position = HexGrid.axial_to_world(hex, HEX_RADIUS, -0.08)
            tile.material_override = blocked_material if obstacle_hexes.has(hex) else tile_material
            add_child(tile)

func _create_player() -> void:
    player_visual = HexActorPresentation.new()
    player_visual.name = "PlayerPresentation"

    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.34
    capsule.height = 1.8
    body.mesh = capsule
    body.position.y = 0.9

    var body_material := StandardMaterial3D.new()
    body_material.albedo_color = Color(0.55, 0.24, 0.18)
    body_material.roughness = 0.85
    body.material_override = body_material

    player_visual.add_child(body)
    player_visual.position = HexGrid.axial_to_world(Vector2i.ZERO, HEX_RADIUS)
    add_child(player_visual)

func _create_camera() -> void:
    camera_rig = OrbitCameraRig.new()
    camera_rig.name = "OrbitCameraRig"

    var pitch_pivot := Node3D.new()
    pitch_pivot.name = "PitchPivot"
    camera_rig.add_child(pitch_pivot)

    var camera := Camera3D.new()
    camera.name = "Camera3D"
    camera.current = true
    camera.fov = 55.0
    pitch_pivot.add_child(camera)

    add_child(camera_rig)
    camera_rig.follow_target = player_visual

func _create_hud() -> void:
    var layer := CanvasLayer.new()
    var label := Label.new()
    label.position = Vector2(22, 18)
    label.text = "HEX MOVEMENT PROTOTYPE   |   Q W E / A S D: move   |   Right-drag: orbit   |   Wheel: zoom"
    label.add_theme_font_size_override("font_size", 18)
    label.add_theme_color_override("font_color", Color(0.94, 0.93, 0.86))
    layer.add_child(label)
    add_child(layer)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        var key_event := event as InputEventKey
        var direction := Vector2i.ZERO
        match key_event.keycode:
            KEY_Q:
                direction = Vector2i(-1, 0)
            KEY_W:
                direction = Vector2i(0, -1)
            KEY_E:
                direction = Vector2i(1, -1)
            KEY_A:
                direction = Vector2i(-1, 1)
            KEY_S:
                direction = Vector2i(0, 1)
            KEY_D:
                direction = Vector2i(1, 0)
            _:
                return
        _attempt_debug_move(direction)

func _attempt_debug_move(direction: Vector2i) -> void:
    var state := simulation.get_character(simulation.player_character_id)
    if state == null:
        return
    simulation.try_move_character(state.id, state.axial + direction)

func _on_character_moved(character_id: String, _from_hex: Vector2i, to_hex: Vector2i) -> void:
    if character_id != simulation.player_character_id:
        return
    player_visual.present_move_to(HexGrid.axial_to_world(to_hex, HEX_RADIUS))
