class_name HollowTankard
extends Node3D

const MODULAR_CHARACTER_ASSEMBLER = preload("res://scripts/presentation/modular_character_assembler.gd")
const ARA_CHARACTER_ACTOR = preload("res://scripts/presentation/ara_character_actor.gd")

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
var party_member_ids: Array[String] = ["player", "companion_wren_talbot"]
var active_party_index: int = 0
var active_character_id: String = "player"
var party_switch_button: Button
var zoom_slider: HSlider
var bra_toggle_button: Button
var briefs_toggle_button: Button
var rotate_left_button: Button
var rotate_right_button: Button
var wren_bra_enabled: bool = true
var wren_briefs_enabled: bool = true
var tile_mesh: ArrayMesh
var path_material: StandardMaterial3D
var active_path: Array[Vector2i] = []
var path_markers: Array[MeshInstance3D] = []
var path_step_accumulator: float = 0.0
const PATH_STEP_INTERVAL: float = 0.22
const INVALID_HEX := Vector2i(2147483647, 2147483647)

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
    path_material = _material(Color(0.95, 0.72, 0.20, 0.48))
    path_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

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
    # Campaign 2 opens at 11:00 on the first day, matching the browser game.
    simulation.clock.set_world_seconds(11.0 * 3600.0)
    add_child(simulation)

    # Hollowmere, its outlying homes, stream crossing and crossroads share one continuous axial grid.
    for q in range(-HollowmereVillageData.MAP_RADIUS, HollowmereVillageData.MAP_RADIUS + 1):
        for r in range(-HollowmereVillageData.MAP_RADIUS, HollowmereVillageData.MAP_RADIUS + 1):
            var hex := Vector2i(q, r)
            if not HollowmereVillageData.is_in_bounds(hex):
                continue
            var world := HexGrid.axial_to_world(hex, HEX_RADIUS)
            var inside_room: bool = absf(world.x) < ROOM_HALF_WIDTH - 0.2 and absf(world.z) < ROOM_HALF_DEPTH - 0.2
            var blocked: bool = _is_wall_cell_blocked(world) or (inside_room and _is_furniture_cell_blocked(world)) or HollowmereVillageData.is_blocked(hex)
            var terrain_id := "timber_floor" if inside_room else HollowmereVillageData.terrain_id_at(hex)
            simulation.map_data.add_cell(hex, 0.0, not blocked, terrain_id)

    simulation.character_moved.connect(_on_character_moved)

func _is_wall_cell_blocked(world: Vector3) -> bool:
    # The south-wall gap is the only opening. The nearest grid cells to the
    # doorway remain clear; adjacent cells are blocked by the wall.
    if absf(absf(world.x) - ROOM_HALF_WIDTH) < 1.1 and absf(world.z) < ROOM_HALF_DEPTH:
        return true
    if absf(world.z + ROOM_HALF_DEPTH) < 1.1:
        return true # north wall has no doorway
    if absf(world.z - ROOM_HALF_DEPTH) < 1.1 and absf(world.x) > 1.1:
        return true # south wall, except the entrance
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
    for q in range(-7, 8):
        for r in range(-7, 8):
            var hex := Vector2i(q, r)
            if not simulation.map_data.has_cell(hex):
                continue
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

    # North wall is split around two actual window openings.
    _add_wall_segment(building, Vector3(-5.3, 1.8, -5.5), Vector3(1.4, WALL_HEIGHT, 0.35))
    _add_wall_segment(building, Vector3(-0.5, 1.8, -5.5), Vector3(5.8, WALL_HEIGHT, 0.35))
    _add_wall_segment(building, Vector3(5.8, 1.8, -5.5), Vector3(4.4, WALL_HEIGHT, 0.35))
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
    # The player remains a neutral placeholder until a player-appearance
    # choice is made. Every named village character is loaded from the shared
    # Ara profile manifest and its generated GLB when that asset pack is installed.
    _spawn_character("player", "You", Vector2i(-1, 2), Color(0.55, 0.24, 0.18), true)

    var profile_file := FileAccess.open("res://data/characters/hollowmere_npcs.json", FileAccess.READ)
    if profile_file == null:
        push_error("Hollowmere character manifest is missing.")
        return
    var parsed: Variant = JSON.parse_string(profile_file.get_as_text())
    if not parsed is Dictionary:
        push_error("Hollowmere character manifest is not valid JSON.")
        return
    for profile_variant in parsed.get("characters", []):
        if not profile_variant is Dictionary:
            continue
        var profile: Dictionary = profile_variant
        var coordinates: Array = profile.get("hex", [0, 0])
        if coordinates.size() < 2:
            continue
        var spawn := Vector2i(int(coordinates[0]), int(coordinates[1]))
        var actor_id := str(profile.get("game_id", profile.get("id", "")))
        var model_id := str(profile.get("id", ""))
        var display_name := str(profile.get("name", actor_id))
        if actor_id.is_empty() or model_id.is_empty():
            continue
        _spawn_character(actor_id, display_name, spawn, Color(0.42, 0.34, 0.25), false, model_id)

func _spawn_character(id: String, display_name: String, hex: Vector2i, colour: Color, is_player: bool = false, ara_model_id: String = "") -> void:
    var spawn_hex := _find_valid_spawn_hex(hex)
    var state := CharacterState.new(id, display_name, spawn_hex)
    state.time_points = state.max_time_points
    simulation.register_character(state)

    var actor := HexActorPresentation.new()
    actor.name = id
    actor.position = _hex_world_position(spawn_hex)
    actor.set_meta("character_id", id)
    actor.rotation.y = deg_to_rad(float(state.facing_direction - 2) * 60.0)

    var model_loaded := false
    if not ara_model_id.is_empty():
        var ara_model := ARA_CHARACTER_ACTOR.new()
        ara_model.name = "CharacterModel"
        actor.add_child(ara_model)
        model_loaded = ara_model.configure("res://art/characters/hollowmere/%s.glb" % ara_model_id)
        if not model_loaded:
            actor.remove_child(ara_model)
            ara_model.queue_free()

    var is_wren: bool = id == "companion_wren_talbot"
    if not model_loaded and is_wren:
        # Preserve the earlier modular Wren path as a fallback for local
        # checkouts that have not installed the generated Ara village pack.
        var character_model := MODULAR_CHARACTER_ASSEMBLER.new()
        character_model.name = "CharacterModel"
        actor.add_child(character_model)
        model_loaded = character_model.configure({
            "hair": "braid",
            "body_hair": "groomed",
            "weapon": "sword",
            "underwear_bra": "strapless",
            "underwear_briefs": "full_coverage",
            "tattoo": "star_shoulder",
            "piercings": "wren_set",
        })
        if not model_loaded:
            character_model.queue_free()

    # Capsule fallback keeps the map testable before the Ara GLB artifact is
    # copied into art/characters/hollowmere/.
    if not model_loaded:
        var body := MeshInstance3D.new()
        body.name = "PlayerBody"
        var body_mesh := CapsuleMesh.new()
        body_mesh.radius = 0.34
        body_mesh.height = 1.75
        body.mesh = body_mesh
        body.position.y = 0.88
        body.material_override = _material(colour)
        actor.add_child(body)

        var head := MeshInstance3D.new()
        head.name = "PlayerHead"
        var head_mesh := SphereMesh.new()
        head_mesh.radius = 0.22
        head_mesh.height = 0.44
        head.mesh = head_mesh
        head.position.y = 1.78
        head.material_override = _material(Color(0.72, 0.57, 0.43))
        actor.add_child(head)

    var name_label := Label3D.new()
    name_label.name = "PlayerNameLabel" if is_player else "CharacterNameLabel"
    name_label.text = "You" if is_player else display_name
    name_label.position.y = 2.08 if model_loaded else 2.25
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
    camera_rig.max_zoom = 90.0
    camera_rig.zoom_distance = 28.0

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
    label.text = "HOLLOW TANKARD   |   W/A/S/D/Q/E: move one hex   |   Click: pathfind   |   [ ]: turn   |   Right-drag: orbit   |   V: roof"
    label.add_theme_font_size_override("font_size", 18)
    label.add_theme_color_override("font_color", Color(0.94, 0.93, 0.86))
    layer.add_child(label)

    party_switch_button = Button.new()
    party_switch_button.text = "Active: You  [Tab] Switch"
    party_switch_button.position = Vector2(22.0, 54.0)
    party_switch_button.custom_minimum_size = Vector2(230.0, 42.0)
    party_switch_button.pressed.connect(_switch_party_member)
    layer.add_child(party_switch_button)

    bra_toggle_button = Button.new()
    bra_toggle_button.text = "Bra: on"
    bra_toggle_button.position = Vector2(22.0, 104.0)
    bra_toggle_button.custom_minimum_size = Vector2(150.0, 38.0)
    bra_toggle_button.pressed.connect(_toggle_wren_bra)
    layer.add_child(bra_toggle_button)

    briefs_toggle_button = Button.new()
    briefs_toggle_button.text = "Briefs: on"
    briefs_toggle_button.position = Vector2(22.0, 148.0)
    briefs_toggle_button.custom_minimum_size = Vector2(150.0, 38.0)
    briefs_toggle_button.pressed.connect(_toggle_wren_briefs)
    layer.add_child(briefs_toggle_button)

    var facing_panel := HBoxContainer.new()
    facing_panel.position = Vector2(22.0, 194.0)
    facing_panel.add_theme_constant_override("separation", 6)
    layer.add_child(facing_panel)

    rotate_left_button = Button.new()
    rotate_left_button.text = "↶ 60°"
    rotate_left_button.tooltip_text = "Turn active character 60 degrees left"
    rotate_left_button.pressed.connect(func(): _rotate_active_character(-1))
    facing_panel.add_child(rotate_left_button)

    rotate_right_button = Button.new()
    rotate_right_button.text = "↷ 60°"
    rotate_right_button.tooltip_text = "Turn active character 60 degrees right"
    rotate_right_button.pressed.connect(func(): _rotate_active_character(1))
    facing_panel.add_child(rotate_right_button)

    # Dedicated zoom controls for laptops and trackpads without a wheel.
    var zoom_panel := HBoxContainer.new()
    zoom_panel.anchor_left = 1.0
    zoom_panel.anchor_right = 1.0
    zoom_panel.offset_left = -292.0
    zoom_panel.offset_top = 18.0
    zoom_panel.offset_right = -18.0
    zoom_panel.offset_bottom = 62.0
    zoom_panel.add_theme_constant_override("separation", 6)
    layer.add_child(zoom_panel)

    var zoom_label := Label.new()
    zoom_label.text = "Zoom"
    zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    zoom_panel.add_child(zoom_label)

    var zoom_out_button := Button.new()
    zoom_out_button.text = "−"
    zoom_out_button.tooltip_text = "Zoom in"
    zoom_out_button.custom_minimum_size = Vector2(42.0, 40.0)
    zoom_out_button.pressed.connect(func(): camera_rig.zoom_by(-1.5))
    zoom_panel.add_child(zoom_out_button)

    zoom_slider = HSlider.new()
    zoom_slider.custom_minimum_size = Vector2(130.0, 40.0)
    zoom_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    zoom_slider.min_value = camera_rig.min_zoom
    zoom_slider.max_value = camera_rig.max_zoom
    zoom_slider.step = 0.25
    zoom_slider.value = camera_rig.zoom_distance
    zoom_slider.tooltip_text = "Camera distance"
    zoom_slider.value_changed.connect(_on_zoom_slider_changed)
    zoom_panel.add_child(zoom_slider)
    camera_rig.zoom_changed.connect(_on_camera_zoom_changed)

    var zoom_in_button := Button.new()
    zoom_in_button.text = "+"
    zoom_in_button.tooltip_text = "Zoom out"
    zoom_in_button.custom_minimum_size = Vector2(42.0, 40.0)
    zoom_in_button.pressed.connect(func(): camera_rig.zoom_by(1.5))
    zoom_panel.add_child(zoom_in_button)

    add_child(layer)

func _on_zoom_slider_changed(value: float) -> void:
    camera_rig.set_zoom(value)

func _on_camera_zoom_changed(value: float) -> void:
    if is_instance_valid(zoom_slider):
        zoom_slider.set_value_no_signal(value)

func _get_wren_model() -> Node3D:
    var wren: Node3D = actor_by_id.get("companion_wren_talbot") as Node3D
    if wren == null:
        return null
    return wren.get_node_or_null("CharacterModel") as Node3D

func _toggle_wren_bra() -> void:
    var model := _get_wren_model()
    if model == null:
        return
    wren_bra_enabled = not wren_bra_enabled
    if model is AraCharacterActor:
        (model as AraCharacterActor).set_garment_visible("Bra", wren_bra_enabled)
    elif model is ModularCharacterAssembler:
        if wren_bra_enabled:
            (model as ModularCharacterAssembler).set_component("underwear_bra", "strapless")
        else:
            (model as ModularCharacterAssembler).clear_slot("underwear_bra")
    bra_toggle_button.text = "Bra: " + ("on" if wren_bra_enabled else "off")

func _toggle_wren_briefs() -> void:
    var model := _get_wren_model()
    if model == null:
        return
    wren_briefs_enabled = not wren_briefs_enabled
    if model is AraCharacterActor:
        (model as AraCharacterActor).set_garment_visible("Briefs", wren_briefs_enabled)
    elif model is ModularCharacterAssembler:
        if wren_briefs_enabled:
            (model as ModularCharacterAssembler).set_component("underwear_briefs", "full_coverage")
        else:
            (model as ModularCharacterAssembler).clear_slot("underwear_briefs")
    briefs_toggle_button.text = "Briefs: " + ("on" if wren_briefs_enabled else "off")

func _switch_party_member() -> void:
    if party_member_ids.is_empty():
        return
    active_path.clear()
    _clear_path_markers()
    active_party_index = (active_party_index + 1) % party_member_ids.size()
    active_character_id = party_member_ids[active_party_index]
    var target: Node3D = actor_by_id.get(active_character_id) as Node3D
    if target != null:
        camera_rig.follow_target = target
        var display_name := "You" if active_character_id == "player" else "Wren"
        party_switch_button.text = "Active: " + display_name + "  [Tab] Switch"

func _process(delta: float) -> void:
    if active_path.size() < 2:
        return
    path_step_accumulator += delta
    if path_step_accumulator < PATH_STEP_INTERVAL:
        return
    path_step_accumulator = 0.0
    _advance_path_step()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_event := event as InputEventMouseButton
        if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
            var clicked_hex: Vector2i = _screen_position_to_hex(mouse_event.position)
            if clicked_hex != INVALID_HEX:
                _set_move_destination(clicked_hex)
                get_viewport().set_input_as_handled()
            return

    if event is InputEventKey and event.pressed and not event.echo:
        var key_event := event as InputEventKey
        if key_event.keycode == KEY_TAB:
            _switch_party_member()
            get_viewport().set_input_as_handled()
            return
        if key_event.keycode == KEY_V:
            roof_group.visible = not roof_group.visible
            return
        if key_event.keycode == KEY_BRACKETLEFT:
            _rotate_active_character(-1)
            get_viewport().set_input_as_handled()
            return
        if key_event.keycode == KEY_BRACKETRIGHT:
            _rotate_active_character(1)
            get_viewport().set_input_as_handled()
            return

        var relative_step := -1
        match key_event.keycode:
            KEY_Q: relative_step = 5
            KEY_W: relative_step = 0
            KEY_E: relative_step = 1
            KEY_A: relative_step = 4
            KEY_S: relative_step = 3
            KEY_D: relative_step = 2
            _: return
        active_path.clear()
        _clear_path_markers()
        _attempt_move(relative_step)
        get_viewport().set_input_as_handled()

func _screen_position_to_hex(screen_position: Vector2) -> Vector2i:
    var camera := get_viewport().get_camera_3d()
    if camera == null:
        return INVALID_HEX
    var ray_origin := camera.project_ray_origin(screen_position)
    var ray_direction := camera.project_ray_normal(screen_position)
    if absf(ray_direction.y) < 0.0001:
        return INVALID_HEX
    var distance := -ray_origin.y / ray_direction.y
    if distance < 0.0:
        return INVALID_HEX
    var hit := ray_origin + ray_direction * distance
    var hex := HexGrid.world_to_axial(hit, HEX_RADIUS)
    if not simulation.map_data.has_cell(hex):
        return INVALID_HEX
    return hex

func _set_move_destination(destination: Vector2i) -> void:
    var path := simulation.find_path(active_character_id, destination)
    if path.size() < 2:
        active_path.clear()
        _clear_path_markers()
        return
    active_path = path
    path_step_accumulator = PATH_STEP_INTERVAL
    _show_path_markers(path)

func _advance_path_step() -> void:
    if simulation.clock.paused:
        return
    if active_path.size() < 2:
        active_path.clear()
        _clear_path_markers()
        return
    if simulation.is_in_combat:
        var active_turn := simulation.get_current_turn_character()
        if active_turn == null or active_turn.id != active_character_id:
            return
    var next_hex := active_path[1]
    var active_state := simulation.get_character(active_character_id)
    if active_state == null:
        active_path.clear()
        _clear_path_markers()
        return
    if not simulation.is_in_combat and active_state.time_points < simulation.movement_cost(active_character_id, next_hex):
        return # Keep the route queued until exploration TP regenerates.
    if not simulation.try_move_character_step(active_character_id, next_hex):
        # A changed occupancy or depleted movement budget can invalidate the
        # remaining route. Re-plan from the character's actual current hex.
        var destination := active_path[active_path.size() - 1]
        var replacement_path := simulation.find_path(active_character_id, destination)
        if replacement_path.size() < 2:
            active_path.clear()
            _clear_path_markers()
            return
        active_path = replacement_path
        _show_path_markers(active_path)
        return
    active_path.pop_front()
    _show_path_markers(active_path)
    if active_path.size() < 2:
        active_path.clear()
        _clear_path_markers()

func _show_path_markers(path: Array[Vector2i]) -> void:
    _clear_path_markers()
    for i in range(1, path.size()):
        var marker := MeshInstance3D.new()
        marker.mesh = tile_mesh
        marker.material_override = path_material
        marker.position = _hex_world_position(path[i]) + Vector3(0.0, 0.10, 0.0)
        marker.scale = Vector3(0.82, 0.25, 0.82)
        add_child(marker)
        path_markers.append(marker)

func _clear_path_markers() -> void:
    for marker in path_markers:
        if is_instance_valid(marker):
            marker.queue_free()
    path_markers.clear()

func _rotate_active_character(steps: int) -> void:
    var state := simulation.get_character(active_character_id)
    var actor: Node3D = actor_by_id.get(active_character_id) as Node3D
    if state == null or actor == null:
        return
    state.facing_direction = posmod(state.facing_direction + steps, 6)
    actor.rotation.y = deg_to_rad(float(2 - state.facing_direction) * 60.0)

func _attempt_move(relative_step: int) -> void:
    if simulation.clock.paused:
        return
    var state := simulation.get_character(active_character_id)
    if state == null:
        return
    var direction_index := posmod(state.facing_direction + relative_step, 6)
    simulation.try_move_character_step(state.id, state.axial + HexGrid.DIRECTIONS[direction_index])

func _find_valid_spawn_hex(preferred: Vector2i) -> Vector2i:
    # Search outward from the authored staging position to avoid furniture
    # and occupied cells as the blockout changes.
    var candidates: Array[Vector2i] = []
    for key in simulation.map_data.cells.keys():
        var cell: Vector2i = key
        if not simulation.map_data.is_walkable(cell):
            continue
        if simulation.occupied_hexes.has(cell):
            continue
        candidates.append(cell)
    candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
        var da := HexGrid.distance(preferred, a)
        var db := HexGrid.distance(preferred, b)
        if da == db:
            return a.x < b.x if a.x != b.x else a.y < b.y
        return da < db
    )
    if candidates.is_empty():
        push_error("No valid walkable spawn hex available near " + str(preferred))
        return preferred
    return candidates[0]

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


func apply_player_profile(profile: Dictionary) -> void:
    var actor := actor_by_id.get("player") as Node3D
    if actor == null:
        return
    actor.set_meta("player_profile", profile.duplicate(true))
    var name_label := actor.get_node_or_null("PlayerNameLabel") as Label3D
    if name_label != null:
        name_label.text = str(profile.get("name", "Adventurer"))
    # The current capsule placeholder has no authored eyes or hair surfaces.
    # Apply skin tone to its visible head; preserve all other choices in profile
    # data until the generic Ara player model exposes modular material slots.
    var skin := Color.from_string(str(profile.get("skin_colour", "#b9825f")), Color(0.72, 0.57, 0.43))
    var head := actor.get_node_or_null("PlayerHead") as MeshInstance3D
    if head != null:
        head.material_override = _material(skin)
    var body := actor.get_node_or_null("PlayerBody") as MeshInstance3D
    if body != null:
        body.material_override = _material(skin)
    actor.set_meta("gender_presentation", str(profile.get("gender_presentation", "Androgynous")))
    actor.set_meta("pronouns", str(profile.get("pronouns", "they/them")))
