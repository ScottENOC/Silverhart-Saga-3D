class_name HollowTankard
extends Node3D

# First authored location: the Hollow Tankard and its immediate approach.
# Logical movement remains hex-based; this scene only presents that state.
const HEX_RADIUS: float = HexGrid.DEFAULT_RADIUS_M
const TILE_THICKNESS: float = 0.12
const ROOM_HALF_WIDTH: float = 8.0
const ROOM_HALF_DEPTH: float = 5.5
const WALL_HEIGHT: float = 3.2
const ROOF_RIDGE_HEIGHT: float = 5.8

var simulation: WorldSimulation
var camera_rig: OrbitCameraRig
var roof_group: Node3D
var actor_by_id: Dictionary = {}
var tile_mesh: ArrayMesh

var grass_material: StandardMaterial3D
var floor_material: StandardMaterial3D
var blocked_material: StandardMaterial3D
var stone_material: StandardMaterial3D
var timber_material: StandardMaterial3D
var dark_wood_material: StandardMaterial3D
var plaster_material: StandardMaterial3D
var roof_material: StandardMaterial3D
var glass_material: StandardMaterial3D

func _ready() -> void:
    _create_materials()
    _create_lighting()
    _create_simulation()
    _create_ground_and_hexes()
    _create_building()
    _create_furniture()
    _create_characters()
    _create_camera()
    _create_hud()

func _create_materials() -> void:
    grass_material = _material(Color(0.28, 0.38, 0.27))
    floor_material = _material(Color(0.35, 0.25, 0.16))
    blocked_material = _material(Color(0.30, 0.29, 0.25))
    stone_material = _material(Color(0.34, 0.34, 0.31))
    timber_material = _material(Color(0.25, 0.13, 0.075))
    dark_wood_material = _material(Color(0.13, 0.075, 0.045))
    plaster_material = _material(Color(0.55, 0.48, 0.36))
    roof_material = _material(Color(0.19, 0.22, 0.23))
    glass_material = _material(Color(0.28, 0.42, 0.48, 0.68))
    glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _material(colour: Color) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = colour
    result.roughness = 0.88
    result.cull_mode = BaseMaterial3D.CULL_DISABLED
    return result

func _create_lighting() -> void:
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
    sun.light_energy = 1.2
    add_child(sun)

    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.48, 0.62, 0.69)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.62, 0.59, 0.51)
    environment.ambient_light_energy = 0.7
    environment_node.environment = environment
    add_child(environment_node)

func _create_simulation() -> void:
    simulation = WorldSimulation.new()
    simulation.name = "WorldSimulation"
    add_child(simulation)

    # A small ring of outdoor cells surrounds the building. The room and
    # exterior use the same continuous axial grid.
    for q in range(-7, 8):
        for r in range(-7, 8):
            var hex := Vector2i(q, r)
            var world := HexGrid.axial_to_world(hex, HEX_RADIUS)
            if absf(world.x) > 12.0 or absf(world.z) > 10.0:
                continue
            var inside_room: bool = absf(world.x) < ROOM_HALF_WIDTH - 0.2 and absf(world.z) < ROOM_HALF_DEPTH - 0.2
            var blocked: bool = _is_wall_cell_blocked(world) or (inside_room and _is_furniture_cell_blocked(world))
            simulation.map_data.add_cell(hex, 0.0, not blocked, "timber_floor" if inside_room else "grass")

    simulation.character_moved.connect(_on_character_moved)

func _is_wall_cell_blocked(world: Vector3) -> bool:
    # The south-wall gap is the only opening. The nearest grid cells to the
    # doorway remain clear; adjacent cells are blocked by the wall.
    if absf(absf(world.x) - ROOM_HALF_WIDTH) < 1.1 and absf(world.z) < ROOM_HALF_DEPTH:
        return true
    if absf(absf(world.z) - ROOM_HALF_DEPTH) < 1.1 and absf(world.x) > 1.1:
        return true
    return false

func _is_furniture_cell_blocked(world: Vector3) -> bool:
    # These are coarse logical footprints, deliberately separate from meshes.
    # The clear central aisle and door approach remain walkable.
    if world.z < -4.0 and world.x > -1.2 and world.x < 6.2:
        return true # bar and working space
    if world.x < -6.0 and world.z > -3.8 and world.z < 1.5:
        return true # fireplace/hearth
    if absf(world.z) < 0.95 and ((world.x > -4.0 and world.x < -1.2) or (world.x > 1.2 and world.x < 4.0)):
        return true # two tables
    if absf(world.z) > 1.0 and absf(world.z) < 2.0 and ((world.x > -4.0 and world.x < -1.2) or (world.x > 1.2 and world.x < 4.0)):
        return true # benches
    return false

func _create_ground_and_hexes() -> void:
    var ground := MeshInstance3D.new()
    var ground_mesh := PlaneMesh.new()
    ground_mesh.size = Vector2(34.0, 30.0)
    ground.mesh = ground_mesh
    ground.position.y = -0.18
    ground.material_override = grass_material
    add_child(ground)

    tile_mesh = _create_hex_tile_mesh()
    for hex_variant in simulation.map_data.cells.keys():
        var hex: Vector2i = hex_variant
        var center := HexGrid.axial_to_world(hex, HEX_RADIUS)
        var inside_room: bool = absf(center.x) < ROOM_HALF_WIDTH - 0.2 and absf(center.z) < ROOM_HALF_DEPTH - 0.2
        var cell_world := HexGrid.axial_to_world(hex, HEX_RADIUS, 0.06 if inside_room else -0.07)
        var tile := MeshInstance3D.new()
        tile.mesh = tile_mesh
        tile.position = cell_world
        if not simulation.map_data.is_walkable(hex):
            tile.material_override = blocked_material
        else:
            tile.material_override = floor_material if inside_room else grass_material
        add_child(tile)

func _create_hex_tile_mesh() -> ArrayMesh:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var corners := HexGrid.corner_offsets(HEX_RADIUS)
    var half_height: float = TILE_THICKNESS * 0.5

    for i in range(HexGrid.SIDE_COUNT):
        var next_i: int = (i + 1) % HexGrid.SIDE_COUNT
        surface.set_normal(Vector3.UP)
        surface.add_vertex(Vector3(0.0, half_height, 0.0))
        surface.add_vertex(Vector3(corners[next_i].x, half_height, corners[next_i].y))
        surface.add_vertex(Vector3(corners[i].x, half_height, corners[i].y))

    for i in range(HexGrid.SIDE_COUNT):
        var next_i: int = (i + 1) % HexGrid.SIDE_COUNT
        var a := Vector3(corners[i].x, half_height, corners[i].y)
        var b := Vector3(corners[next_i].x, half_height, corners[next_i].y)
        var c := Vector3(corners[next_i].x, -half_height, corners[next_i].y)
        var d := Vector3(corners[i].x, -half_height, corners[i].y)
        var angle := deg_to_rad(60.0 * (float(i) + 0.5))
        var normal := Vector3(cos(angle), 0.0, sin(angle))
        surface.set_normal(normal)
        surface.add_vertex(a)
        surface.add_vertex(b)
        surface.add_vertex(c)
        surface.set_normal(normal)
        surface.add_vertex(a)
        surface.add_vertex(c)
        surface.add_vertex(d)
    return surface.commit()

func _create_building() -> void:
    var building := Node3D.new()
    building.name = "HollowTankardBuilding"
    add_child(building)

    # Stone plinth and timber-framed plaster walls.
    _add_box(building, "StoneFloorFoundation", Vector3(0.0, -0.08, 0.0), Vector3(16.7, 0.16, 11.7), stone_material)

    # North wall: one continuous wall with a pair of small glazed windows.
    _add_wall_segment(building, Vector3(-3.0, 1.8, -5.5), Vector3(9.7, WALL_HEIGHT, 0.35))
    _add_wall_segment(building, Vector3(5.0, 1.8, -5.5), Vector3(6.7, WALL_HEIGHT, 0.35))
    _add_window(building, Vector3(-4.0, 1.95, -5.5), Vector2(1.2, 1.0))
    _add_window(building, Vector3(3.0, 1.95, -5.5), Vector2(1.2, 1.0))

    # South wall leaves a centred 1.6m entrance.
    _add_wall_segment(building, Vector3(-4.4, 1.8, 5.5), Vector3(7.2, WALL_HEIGHT, 0.35))
    _add_wall_segment(building, Vector3(4.4, 1.8, 5.5), Vector3(7.2, WALL_HEIGHT, 0.35))
    _add_box(building, "DoorLintel", Vector3(0.0, 3.0, 5.5), Vector3(1.95, 0.35, 0.48), timber_material)
    _add_box(building, "DoorJambLeft", Vector3(-0.95, 1.55, 5.5), Vector3(0.22, 3.1, 0.48), timber_material)
    _add_box(building, "DoorJambRight", Vector3(0.95, 1.55, 5.5), Vector3(0.22, 3.1, 0.48), timber_material)
    var door := _add_box(building, "OpenEntranceDoor", Vector3(-0.65, 1.25, 5.28), Vector3(1.3, 2.5, 0.16), dark_wood_material)
    door.rotation_degrees.y = -48.0

    # East and west walls, each with a window opening.
    _add_wall_segment(building, Vector3(8.0, 1.8, -3.45), Vector3(0.35, WALL_HEIGHT, 4.1))
    _add_wall_segment(building, Vector3(8.0, 1.8, 3.45), Vector3(0.35, WALL_HEIGHT, 4.1))
    _add_window(building, Vector3(8.0, 1.95, 0.0), Vector2(1.2, 1.0), true)
    _add_wall_segment(building, Vector3(-8.0, 1.8, -3.45), Vector3(0.35, WALL_HEIGHT, 4.1))
    _add_wall_segment(building, Vector3(-8.0, 1.8, 3.45), Vector3(0.35, WALL_HEIGHT, 4.1))
    _add_window(building, Vector3(-8.0, 1.95, 0.0), Vector2(1.2, 1.0), true)

    # Exposed posts and roof beams give the hall a readable timber structure.
    for x in [-7.7, -4.0, 0.0, 4.0, 7.7]:
        for z in [-5.2, 5.2]:
            _add_box(building, "TimberPost", Vector3(x, 1.65, z), Vector3(0.22, 3.3, 0.22), timber_material)
    _add_box(building, "NorthTieBeam", Vector3(0.0, 3.0, -5.05), Vector3(16.0, 0.22, 0.22), dark_wood_material)
    _add_box(building, "SouthTieBeam", Vector3(0.0, 3.0, 5.05), Vector3(16.0, 0.22, 0.22), dark_wood_material)

    # Roof is a separate cutaway layer. V toggles it so the interior can be
    # inspected without permanently sacrificing the building silhouette.
    roof_group = Node3D.new()
    roof_group.name = "RoofCutaway"
    add_child(roof_group)
    var roof_width: float = sqrt(5.5 * 5.5 + 2.6 * 2.6)
    var roof_angle: float = rad_to_deg(atan2(2.6, 5.5))
    var north_roof := _add_box(roof_group, "NorthRoofSlope", Vector3(0.0, 4.5, -2.75), Vector3(16.9, 0.22, roof_width), roof_material)
    north_roof.rotation_degrees.x = -roof_angle
    var south_roof := _add_box(roof_group, "SouthRoofSlope", Vector3(0.0, 4.5, 2.75), Vector3(16.9, 0.22, roof_width), roof_material)
    south_roof.rotation_degrees.x = roof_angle
    _add_box(roof_group, "RidgeBeam", Vector3(0.0, 5.78, 0.0), Vector3(17.0, 0.25, 0.3), dark_wood_material)
    _add_box(roof_group, "Chimney", Vector3(-6.0, 5.0, -1.0), Vector3(0.9, 2.4, 0.9), stone_material)
    roof_group.visible = false

func _add_wall_segment(parent: Node3D, position: Vector3, size: Vector3) -> void:
    _add_box(parent, "PlasterWall", position, size, plaster_material)
    var beam_y: float = position.y + size.y * 0.5 - 0.12
    _add_box(parent, "WallTopBeam", Vector3(position.x, beam_y, position.z), Vector3(size.x + 0.08, 0.22, size.z + 0.08), timber_material)

func _add_window(parent: Node3D, position: Vector3, dimensions: Vector2, on_side_wall: bool = false) -> void:
    var pane_size := Vector3(0.08, dimensions.y, dimensions.x) if on_side_wall else Vector3(dimensions.x, dimensions.y, 0.08)
    _add_box(parent, "WindowGlass", position, pane_size, glass_material)
    if on_side_wall:
        _add_box(parent, "WindowSill", position + Vector3(0.0, -dimensions.y * 0.5, 0.0), Vector3(0.18, 0.12, dimensions.x + 0.2), timber_material)
    else:
        _add_box(parent, "WindowSill", position + Vector3(0.0, -dimensions.y * 0.5, 0.0), Vector3(dimensions.x + 0.2, 0.12, 0.18), timber_material)

func _create_furniture() -> void:
    var furniture := Node3D.new()
    furniture.name = "TavernFurniture"
    add_child(furniture)

    # North-wall bar and shelving.
    _add_box(furniture, "BarFront", Vector3(2.5, 0.62, -4.45), Vector3(5.2, 1.15, 0.85), dark_wood_material)
    _add_box(furniture, "BarTop", Vector3(2.5, 1.25, -4.45), Vector3(5.45, 0.16, 1.0), timber_material)
    _add_box(furniture, "BackBarShelf", Vector3(2.5, 1.75, -5.0), Vector3(4.5, 0.18, 0.3), timber_material)
    for i in range(5):
        _add_box(furniture, "Bottle", Vector3(0.8 + float(i) * 0.8, 1.98, -5.0), Vector3(0.18, 0.34, 0.18), _material(Color(0.22, 0.34, 0.20)))

    # Hearth against the west wall.
    _add_box(furniture, "FireplaceStone", Vector3(-7.15, 0.75, -1.0), Vector3(1.35, 1.5, 2.0), stone_material)
    _add_box(furniture, "FireplaceOpening", Vector3(-6.42, 0.62, -1.0), Vector3(0.08, 0.85, 1.05), dark_wood_material)
    _add_box(furniture, "HearthStone", Vector3(-6.4, 0.12, -1.0), Vector3(1.6, 0.22, 2.2), stone_material)
    _add_box(furniture, "ChimneyBreast", Vector3(-7.2, 2.55, -1.0), Vector3(1.1, 2.1, 1.4), stone_material)

    # Two tables with benches; the middle aisle stays open.
    for table_x in [-2.65, 2.65]:
        _add_box(furniture, "TableTop", Vector3(table_x, 0.88, 0.0), Vector3(2.0, 0.16, 1.0), timber_material)
        for leg_x in [-0.82, 0.82]:
            for leg_z in [-0.32, 0.32]:
                _add_box(furniture, "TableLeg", Vector3(table_x + leg_x, 0.43, leg_z), Vector3(0.14, 0.86, 0.14), dark_wood_material)
        _add_box(furniture, "Bench", Vector3(table_x, 0.48, -1.45), Vector3(2.0, 0.18, 0.42), timber_material)
        _add_box(furniture, "Bench", Vector3(table_x, 0.48, 1.45), Vector3(2.0, 0.18, 0.42), timber_material)

    # A few grounded details, not a fully dressed prop set.
    _add_box(furniture, "StorageChest", Vector3(6.7, 0.48, -3.2), Vector3(1.0, 0.9, 0.8), dark_wood_material)
    _add_box(furniture, "Stool", Vector3(5.9, 0.42, -2.2), Vector3(0.65, 0.8, 0.65), timber_material)
    _add_box(furniture, "StoolSeat", Vector3(5.9, 0.85, -2.2), Vector3(0.7, 0.12, 0.7), dark_wood_material)

func _create_characters() -> void:
    _spawn_character("player", "You", Vector2i(-1, 2), Color(0.55, 0.24, 0.18), true)
    _spawn_character("companion_wren_talbot", "Wren Talbot", Vector2i(-3, 3), Color(0.20, 0.30, 0.48))
    _spawn_character("garrick_holt", "Garrick Holt", Vector2i(3, -3), Color(0.46, 0.34, 0.18))
    _spawn_character("mira_ashbrook", "Mira Ashbrook", Vector2i(1, -2), Color(0.38, 0.24, 0.43))
    _spawn_character("oskar_vinn", "Oskar Vinn", Vector2i(2, -2), Color(0.22, 0.39, 0.32))
    _spawn_character("dray_coltayne", "Dray Coltayne", Vector2i(-1, 4), Color(0.40, 0.22, 0.20))
    _spawn_character("tomlin_brask", "Tomlin Brask", Vector2i(0, 4), Color(0.42, 0.32, 0.23))
    _spawn_character("hask_greel", "Hask Greel", Vector2i(1, 3), Color(0.31, 0.30, 0.27))

func _spawn_character(id: String, display_name: String, hex: Vector2i, colour: Color, is_player: bool = false) -> void:
    var state := CharacterState.new(id, display_name, hex)
    simulation.register_character(state)

    var actor := HexActorPresentation.new()
    actor.name = id
    actor.position = _hex_world_position(hex)
    actor.set_meta("character_id", id)

    var body := MeshInstance3D.new()
    var body_mesh := CapsuleMesh.new()
    body_mesh.radius = 0.34
    body_mesh.height = 1.75
    body.mesh = body_mesh
    body.position.y = 0.88
    body.material_override = _material(colour)
    actor.add_child(body)

    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.22
    head_mesh.height = 0.44
    head.mesh = head_mesh
    head.position.y = 1.78
    head.material_override = _material(Color(0.72, 0.57, 0.43))
    actor.add_child(head)

    var name_label := Label3D.new()
    name_label.text = "You" if is_player else display_name
    name_label.position.y = 2.25
    name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    name_label.font_size = 32
    name_label.outline_size = 6
    name_label.modulate = Color(1.0, 0.95, 0.82)
    actor.add_child(name_label)

    add_child(actor)
    actor_by_id[id] = actor

func _create_camera() -> void:
    camera_rig = OrbitCameraRig.new()
    camera_rig.name = "OrbitCameraRig"
    camera_rig.zoom_distance = 22.0

    var pitch_pivot := Node3D.new()
    pitch_pivot.name = "PitchPivot"
    camera_rig.add_child(pitch_pivot)

    var camera := Camera3D.new()
    camera.name = "Camera3D"
    camera.current = true
    camera.fov = 55.0
    pitch_pivot.add_child(camera)

    add_child(camera_rig)
    camera_rig.follow_target = actor_by_id["player"]

func _create_hud() -> void:
    var layer := CanvasLayer.new()
    var label := Label.new()
    label.position = Vector2(22.0, 18.0)
    label.text = "HOLLOW TANKARD   |   Q W E / A S D: move   |   Right-drag: orbit   |   Wheel: zoom   |   V: roof"
    label.add_theme_font_size_override("font_size", 18)
    label.add_theme_color_override("font_color", Color(0.94, 0.93, 0.86))
    layer.add_child(label)
    add_child(layer)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        var key_event := event as InputEventKey
        if key_event.keycode == KEY_V:
            roof_group.visible = not roof_group.visible
            return

        var direction := Vector2i.ZERO
        match key_event.keycode:
            KEY_Q: direction = Vector2i(-1, 0)
            KEY_W: direction = Vector2i(0, -1)
            KEY_E: direction = Vector2i(1, -1)
            KEY_A: direction = Vector2i(-1, 1)
            KEY_S: direction = Vector2i(0, 1)
            KEY_D: direction = Vector2i(1, 0)
            _: return
        _attempt_move(direction)

func _attempt_move(direction: Vector2i) -> void:
    var state := simulation.get_character(simulation.player_character_id)
    if state == null:
        return
    simulation.try_move_character(state.id, state.axial + direction)

func _on_character_moved(character_id: String, _from_hex: Vector2i, to_hex: Vector2i) -> void:
    var actor: HexActorPresentation = actor_by_id.get(character_id) as HexActorPresentation
    if actor != null:
        actor.present_move_to(_hex_world_position(to_hex))

func _hex_world_position(hex: Vector2i) -> Vector3:
    var centre := HexGrid.axial_to_world(hex, HEX_RADIUS)
    var inside_room: bool = absf(centre.x) < ROOM_HALF_WIDTH - 0.2 and absf(centre.z) < ROOM_HALF_DEPTH - 0.2
    return HexGrid.axial_to_world(hex, HEX_RADIUS, 0.12 if inside_room else 0.0)

func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.name = node_name
    var box := BoxMesh.new()
    box.size = size
    instance.mesh = box
    instance.position = position
    instance.material_override = material
    parent.add_child(instance)
    return instance
