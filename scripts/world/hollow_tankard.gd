class_name HollowTankard
extends Node3D

const ARA_CHARACTER_ACTOR = preload("res://scripts/presentation/ara_character_actor.gd")
const PLAYER_FEMALE_ASSET := "res://art/characters/ara_runtime/ara_person_body.glb"
const PLAYER_CUSTOM_FEMALE_ASSET := "res://art/characters/hollowmere/player_avatar.glb"
const PLAYER_MALE_ASSET := "res://art/characters/ara_runtime/ara_person_male_body.glb"
const REACTION_PROMPT_SCRIPT = preload("res://scripts/ui/reaction_prompt.gd")
const CHARACTER_PANEL_SCRIPT = preload("res://scripts/ui/character_panel.gd")
const WORLD_MAP_PANEL_SCRIPT = preload("res://scripts/ui/main_campaign_world_map.gd")
const CHARACTER_CREATION_RULES = preload("res://scripts/simulation/character_creation_rules.gd")
const AMBIENT_CHATTER_SCRIPT = preload("res://scripts/simulation/ambient_chatter.gd")
const SEASONAL_TREE_SCRIPT = preload("res://scripts/presentation/seasonal_tree_visual.gd")
const RESOURCE_VISUAL_SCRIPT = preload("res://scripts/presentation/wilderness_resource_visual.gd")
const HOLLOWMERE_ENCOUNTER_SCRIPT = preload("res://scripts/simulation/hollowmere_encounter.gd")

const TAVERN_BUILDING_ID := "hollow_tankard"
const TAVERN_FRONT_DOOR_ID := "hollow_tankard_front_door"
const TAVERN_DOOR_HEX := Vector2i(0, 3)
const UPPER_FLOOR_ORIGIN := Vector2i(100, 100)
const UPPER_FLOOR_Y := 3.38
const TAVERN_STAIR_GROUND_HEX := Vector2i(3, 0)
const TAVERN_STAIR_UPPER_HEX := UPPER_FLOOR_ORIGIN + TAVERN_STAIR_GROUND_HEX

# First authored location: the Hollow Tankard and its immediate approach.
# Logical movement remains hex-based; this scene only presents that state.
const HEX_RADIUS: float = HexGrid.DEFAULT_RADIUS_M
const TILE_THICKNESS: float = 0.12
const ROOM_HALF_WIDTH: float = 8.0
const ROOM_HALF_DEPTH: float = 5.5
const WALL_HEIGHT: float = 3.2
const ROOF_RIDGE_HEIGHT: float = 5.8

var simulation: WorldSimulation
var reaction_prompt: CanvasLayer
var character_panel: CharacterPanel
var world_map_panel: CanvasLayer
var camera_rig: OrbitCameraRig
var roof_group: Node3D
var upper_shell_group: Node3D
var upper_floor_group: Node3D
var upper_interior_group: Node3D
var upper_floor_tiles: Node3D
var tavern_door_pivot: Node3D
var tavern_door_leaf: MeshInstance3D
var actor_by_id: Dictionary = {}
var starting_loadouts: Dictionary = {}
var player_profile: Dictionary = {}
var party_member_ids: Array[String] = ["player", "companion_wren_talbot"]
var active_party_index: int = 0
var active_character_id: String = "player"
var party_switch_button: Button
var zoom_slider: HSlider
var rotate_left_button: Button
var rotate_right_button: Button
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
var ambient_chatter: AmbientChatter
var ambient_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var ambient_accumulator: float = 0.0
var ambient_exchange_running: bool = false
var ambient_security: int = 50
var shakedown_started: bool = false
var shakedown_resolved: bool = false
var dialogue_open: bool = false
var dialogue_panel: PanelContainer
var dialogue_speaker_label: Label
var dialogue_body_label: Label
var dialogue_choices_box: VBoxContainer
var attack_button: Button
var end_turn_button: Button
var combat_status_label: Label
var resource_status_label: Label
var resource_visuals_by_hex: Dictionary = {}
var encounter_active: bool = false
var enemy_turn_processed: bool = false
var enemy_turn_waiting_for_reaction: bool = false

func _ready() -> void:
    _create_materials()
    _create_lighting()
    _create_simulation()
    _create_ground_and_hexes()
    _create_wilderness_gatherable_grove()
    _create_building()
    _create_furniture()
    _create_characters()
    HollowmereCampaignContent.initialize_social_standings(simulation.campaign_journal, String(player_profile.get("race", "human")))
    _create_camera()
    _create_hud()
    ambient_chatter = AMBIENT_CHATTER_SCRIPT.new() as AmbientChatter
    ambient_rng.randomize()
    _run_opening_sequence()

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
    simulation.clock.ticked.connect(_on_world_clock_ticked)
    add_child(simulation)
    simulation.campaign_journal.register_quest_definition(HollowmereCampaignContent.shakedown_quest_definition())
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

    # Building definitions are registered against the same continuous village
    # map used by movement and pathfinding. Only mutable door state is saved.
    simulation.building_registry.register_building({
        "id": TAVERN_BUILDING_ID,
        "name": "The Hollow Tankard",
        "entrance_hex": TAVERN_DOOR_HEX,
        "floor_count": 2,
        "virtual_floor_bounds": [96, 104, 96, 104],
        "source_location": "campaign2World.js: Hollow Tankard",
    })
    simulation.building_registry.register_door(TAVERN_FRONT_DOOR_ID, TAVERN_BUILDING_ID, TAVERN_DOOR_HEX, true, false, 20)
    simulation.building_registry.door_state_changed.connect(_on_building_door_state_changed)

    # The upper floor uses its own axial coordinate range. Mapping those cells
    # back onto the tavern footprint avoids collisions with ground-floor NPCs
    # without splitting the building into a second scene or map.
    for q in range(-4, 5):
        var row_shift := -floori(float(q) / 2.0)
        for row in range(-2, 3):
            var local_hex := Vector2i(q, row + row_shift)
            var local_world := HexGrid.axial_to_world(local_hex, HEX_RADIUS)
            var partition_wall := (q == 0 and absf(local_world.z) > 1.1) or (q >= 1 and q <= 4 and absf(local_world.z) < 0.55 and q != 3)
            simulation.map_data.add_cell(UPPER_FLOOR_ORIGIN + local_hex, UPPER_FLOOR_Y, not partition_wall, "timber_floor")

    simulation.character_moved.connect(_on_character_moved)
    simulation.reaction_requested.connect(_on_reaction_requested)
    simulation.reaction_resolved.connect(_on_reaction_resolved)
    simulation.movement_reaction_resolved.connect(_on_movement_reaction_resolved)
    simulation.turn_scheduler.turn_started.connect(_on_combat_turn_started)

func _create_wilderness_gatherable_grove() -> void:
    # Kenney Nature Kit GLBs provide the base trees. These are a compact
    # outdoor test grove immediately outside the tavern's playable footprint.
    var decorative_trees: Array[Dictionary] = [
        {"position": Vector3(-7.5, 0.0, -17.3), "evergreen": false, "seed": 21, "species": "oak"},
        {"position": Vector3(7.5, 0.0, 17.3), "evergreen": false, "seed": 22, "species": "default"},
        {"position": Vector3(-7.5, 0.0, 8.66), "evergreen": true, "seed": 23, "species": "default"},
        {"position": Vector3(7.5, 0.0, -17.3), "evergreen": true, "seed": 24, "species": "default"},
    ]
    for placement in decorative_trees:
        var tree := SEASONAL_TREE_SCRIPT.new() as SeasonalTreeVisual
        tree.evergreen = bool(placement["evergreen"])
        tree.tree_seed = int(placement["seed"])
        tree.tree_scale = 3.4
        tree.species_variant = String(placement["species"])
        tree.position = placement["position"]
        add_child(tree)
        tree.refresh_month(int(simulation.clock.calendar_date()["month_index"]))

    # Authored tutorial gatherables are deliberately close enough to test on
    # the first visit. Random wilderness spawning remains outside Hollowmere.
    var resource_placements: Array[Dictionary] = [
        {"hex": Vector2i(-6, 2), "terrain": "forest", "node": {"type": "fruit_tree", "available": true, "regrow_at": 0.0}},
        {"hex": Vector2i(6, -2), "terrain": "forest", "node": {"type": "timber_tree", "available": true, "regrow_at": 0.0}},
        {"hex": Vector2i(5, 4), "terrain": "grass", "node": {"type": "herb_patch", "available": true, "regrow_at": 0.0}},
        {"hex": Vector2i(4, -5), "terrain": "rocky_outcrop", "node": {"type": "ore_node", "item_id": "ore_iron", "depleted": false, "regrow_at": 0.0}},
        {"hex": Vector2i(-6, -2), "terrain": "rocky_outcrop", "node": {"type": "stone_deposit", "depleted": false, "regrow_at": 0.0}},
    ]
    for placement in resource_placements:
        var hex: Vector2i = placement["hex"]
        var state: Dictionary = placement["node"]
        simulation.set_authored_resource_at(hex, String(placement["terrain"]), state)
        var visual := RESOURCE_VISUAL_SCRIPT.new() as WildernessResourceVisual
        visual.name = "Resource_%d_%d" % [hex.x, hex.y]
        visual.position = HexGrid.axial_to_world(hex, HEX_RADIUS, 0.0)
        add_child(visual)
        visual.refresh(state, int(simulation.clock.calendar_date()["month_index"]))
        resource_visuals_by_hex[hex] = visual

func _on_world_clock_ticked(_tick_index: int, _world_seconds: float) -> void:
    var month_index := int(simulation.clock.calendar_date()["month_index"])
    for tree in get_tree().get_nodes_in_group("seasonal_trees"):
        if tree is SeasonalTreeVisual:
            tree.refresh_month(month_index)
    _refresh_resource_visuals()

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
    tavern_door_pivot = Node3D.new()
    tavern_door_pivot.name = "FrontDoorHinge"
    tavern_door_pivot.position = Vector3(-0.8, 0.0, 5.5)
    building.add_child(tavern_door_pivot)
    tavern_door_leaf = _add_box(tavern_door_pivot, "FrontDoorLeaf", Vector3(0.65, 1.25, 0.0), Vector3(1.3, 2.5, 0.16), dark_wood_material)
    _refresh_tavern_door_presentation()

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

    # Second storey: the upper shell reads as a real two-storey inn from
    # outside. Its floor and interior furnishings are shown when the player
    # climbs up; the shell is cut away while upstairs so the rooms stay legible.
    upper_shell_group = Node3D.new()
    upper_shell_group.name = "UpperStoreyExterior"
    add_child(upper_shell_group)
    _add_box(upper_shell_group, "UpperNorthWall", Vector3(0.0, 5.0, -5.5), Vector3(16.0, 3.2, 0.35), plaster_material)
    _add_box(upper_shell_group, "UpperSouthWallLeft", Vector3(-4.4, 5.0, 5.5), Vector3(7.2, 3.2, 0.35), plaster_material)
    _add_box(upper_shell_group, "UpperSouthWallRight", Vector3(4.4, 5.0, 5.5), Vector3(7.2, 3.2, 0.35), plaster_material)
    _add_box(upper_shell_group, "UpperEastWall", Vector3(8.0, 5.0, 0.0), Vector3(0.35, 3.2, 11.0), plaster_material)
    _add_box(upper_shell_group, "UpperWestWall", Vector3(-8.0, 5.0, 0.0), Vector3(0.35, 3.2, 11.0), plaster_material)
    for x in [-7.7, -4.0, 0.0, 4.0, 7.7]:
        for z in [-5.2, 5.2]:
            _add_box(upper_shell_group, "UpperTimberPost", Vector3(x, 4.95, z), Vector3(0.22, 3.3, 0.22), timber_material)
    _add_box(upper_shell_group, "UpperNorthTieBeam", Vector3(0.0, 6.55, -5.05), Vector3(16.0, 0.22, 0.22), dark_wood_material)
    _add_box(upper_shell_group, "UpperSouthTieBeam", Vector3(0.0, 6.55, 5.05), Vector3(16.0, 0.22, 0.22), dark_wood_material)
    _add_window(upper_shell_group, Vector3(-4.0, 5.1, -5.5), Vector2(1.2, 1.0))
    _add_window(upper_shell_group, Vector3(3.0, 5.1, -5.5), Vector2(1.2, 1.0))
    _add_window(upper_shell_group, Vector3(8.0, 5.1, 0.0), Vector2(1.2, 1.0), true)
    _add_window(upper_shell_group, Vector3(-8.0, 5.1, 0.0), Vector2(1.2, 1.0), true)

    upper_floor_group = Node3D.new()
    upper_floor_group.name = "UpperFloorPresentation"
    add_child(upper_floor_group)
    _add_box(upper_floor_group, "UpperFloorDeck", Vector3(0.0, 3.22, 0.0), Vector3(16.2, 0.24, 11.2), timber_material)
    upper_floor_tiles = Node3D.new()
    upper_floor_tiles.name = "UpperHexFloor"
    upper_floor_group.add_child(upper_floor_tiles)
    for q in range(-4, 5):
        var row_shift := -floori(float(q) / 2.0)
        for row in range(-2, 3):
            var local_hex := Vector2i(q, row + row_shift)
            var local_world := HexGrid.axial_to_world(local_hex, HEX_RADIUS)
            var tile := MeshInstance3D.new()
            tile.mesh = tile_mesh
            tile.position = Vector3(local_world.x, UPPER_FLOOR_Y, local_world.z)
            tile.material_override = floor_material
            upper_floor_tiles.add_child(tile)

    upper_interior_group = Node3D.new()
    upper_interior_group.name = "UpperBedrooms"
    upper_floor_group.add_child(upper_interior_group)
    _create_upper_floor_rooms(upper_interior_group)

    # Staircase rises along the east side from the taproom to the landing.
    for step in range(10):
        var progress := float(step) / 9.0
        var stair := _add_box(building, "StairStep_%02d" % step,
            Vector3(6.05, 0.18 + progress * 3.0, 4.15 - progress * 3.7),
            Vector3(1.35, 0.22, 0.58), timber_material)
        stair.rotation_degrees.x = -38.0
    _add_box(building, "StairStringerLeft", Vector3(5.38, 1.7, 2.3), Vector3(0.16, 3.6, 4.0), dark_wood_material)
    _add_box(building, "StairStringerRight", Vector3(6.72, 1.7, 2.3), Vector3(0.16, 3.6, 4.0), dark_wood_material)
    _refresh_tavern_floor_presentation()

    # The pitched roof now sits above the bedrooms. V toggles this cutaway.
    roof_group = Node3D.new()
    roof_group.name = "RoofCutaway"
    add_child(roof_group)
    var roof_width: float = sqrt(5.5 * 5.5 + 2.6 * 2.6)
    var roof_angle: float = rad_to_deg(atan2(2.6, 5.5))
    var north_roof := _add_box(roof_group, "NorthRoofSlope", Vector3(0.0, 7.75, -2.75), Vector3(16.9, 0.22, roof_width), roof_material)
    north_roof.rotation_degrees.x = -roof_angle
    var south_roof := _add_box(roof_group, "SouthRoofSlope", Vector3(0.0, 7.75, 2.75), Vector3(16.9, 0.22, roof_width), roof_material)
    south_roof.rotation_degrees.x = roof_angle
    _add_box(roof_group, "RidgeBeam", Vector3(0.0, 9.03, 0.0), Vector3(17.0, 0.25, 0.3), dark_wood_material)
    _add_box(roof_group, "Chimney", Vector3(-6.0, 8.0, -1.0), Vector3(0.9, 3.8, 0.9), stone_material)
    roof_group.visible = false

func _create_upper_floor_rooms(parent: Node3D) -> void:
    # The west suite is reserved for Garrick; the east wing contains guest
    # rooms reached from the central landing. Six beds provide modest lodging.
    _add_box(parent, "WestPartitionNorth", Vector3(0.0, 4.85, -3.15), Vector3(0.22, 2.9, 4.7), timber_material)
    _add_box(parent, "WestPartitionSouth", Vector3(0.0, 4.85, 3.15), Vector3(0.22, 2.9, 4.7), timber_material)
    _add_box(parent, "EastPartitionNorth", Vector3(2.95, 4.85, 0.0), Vector3(2.9, 2.9, 0.22), timber_material)
    _add_box(parent, "EastPartitionSouth", Vector3(7.4, 4.85, 0.0), Vector3(1.2, 2.9, 0.22), timber_material)

    _add_room_label(parent, "GARRICK'S ROOM", Vector3(-4.0, 6.35, -4.0))
    _add_room_label(parent, "GUEST ROOM", Vector3(3.8, 6.35, -4.0))
    _add_room_label(parent, "GUEST ROOM", Vector3(3.8, 6.35, 3.8))

    _create_bed_at_hex(parent, "GarrickBed", Vector2i(-3, 0), Color(0.38, 0.16, 0.12))
    _create_bed_at_hex(parent, "GarrickSpareBed", Vector2i(-3, 2), Color(0.34, 0.24, 0.16))
    _create_bed_at_hex(parent, "NorthGuestBedA", Vector2i(2, -2), Color(0.24, 0.28, 0.38))
    _create_bed_at_hex(parent, "NorthGuestBedB", Vector2i(3, -2), Color(0.24, 0.28, 0.38))
    _create_bed_at_hex(parent, "SouthGuestBedA", Vector2i(2, 0), Color(0.24, 0.28, 0.38))
    _create_bed_at_hex(parent, "SouthGuestBedB", Vector2i(3, 0), Color(0.24, 0.28, 0.38))

    for x in [-6.5, -2.8, 1.0, 6.8]:
        _add_box(parent, "BedroomChest", Vector3(x, 3.78, -4.7 if x > 0.0 else 4.6), Vector3(0.9, 0.55, 0.55), dark_wood_material)
    _add_box(parent, "LandingTable", Vector3(0.8, 3.78, 1.7), Vector3(1.2, 0.12, 0.65), timber_material)
    _add_box(parent, "LandingTableLeg", Vector3(0.8, 3.48, 1.7), Vector3(0.12, 0.6, 0.12), dark_wood_material)

func _create_bed_at_hex(parent: Node3D, bed_name: String, local_hex: Vector2i, blanket_colour: Color) -> void:
    var position := HexGrid.axial_to_world(local_hex, HEX_RADIUS, UPPER_FLOOR_Y + 0.17)
    _create_bed(parent, bed_name, position, blanket_colour)

func _create_bed(parent: Node3D, bed_name: String, position: Vector3, blanket_colour: Color) -> void:
    var bed := Node3D.new()
    bed.name = bed_name
    bed.position = position
    parent.add_child(bed)
    _add_box(bed, "BedFrame", Vector3.ZERO, Vector3(1.25, 0.38, 2.15), dark_wood_material)
    _add_box(bed, "Mattress", Vector3(0.0, 0.22, 0.0), Vector3(1.15, 0.18, 2.0), _material(Color(0.78, 0.72, 0.58)))
    _add_box(bed, "Blanket", Vector3(0.0, 0.34, 0.28), Vector3(1.12, 0.12, 1.35), _material(blanket_colour))
    _add_box(bed, "Pillow", Vector3(0.0, 0.36, -0.78), Vector3(0.82, 0.12, 0.38), _material(Color(0.82, 0.79, 0.68)))
    _add_box(bed, "Headboard", Vector3(0.0, 0.55, -1.0), Vector3(1.3, 0.95, 0.12), timber_material)

func _add_room_label(parent: Node3D, text_value: String, position: Vector3) -> void:
    var label := Label3D.new()
    label.text = text_value
    label.position = position
    label.font_size = 30
    label.outline_size = 6
    label.modulate = Color(0.9, 0.82, 0.62)
    parent.add_child(label)

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
    starting_loadouts = _load_starting_loadouts()
    # Player and NPCs use the shared gendered Ara base mesh.
    _spawn_character("player", String(player_profile.get("name", "Adventurer")), Vector2i(-1, 2), Color(0.55, 0.24, 0.18), true)

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
        if str(profile.get("role", "")) == "player avatar":
            continue
        var coordinates: Array = profile.get("hex", [0, 0])
        if coordinates.size() < 2:
            continue
        var spawn := Vector2i(int(coordinates[0]), int(coordinates[1]))
        var actor_id := str(profile.get("game_id", profile.get("id", "")))
        var model_id := str(profile.get("id", ""))
        var display_name := str(profile.get("name", actor_id))
        if actor_id.is_empty() or model_id.is_empty():
            continue
        _spawn_character(actor_id, display_name, spawn, Color(0.42, 0.34, 0.25), false, model_id, profile)

    _refresh_tavern_floor_presentation()


func _load_starting_loadouts() -> Dictionary:
    var file := FileAccess.open("res://data/characters/hollowmere_loadouts.json", FileAccess.READ)
    if file == null:
        push_error("Hollowmere starting loadouts are missing.")
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        push_error("Hollowmere starting loadouts are not valid JSON.")
        return {}
    var characters: Variant = parsed.get("characters", {})
    if characters is Dictionary:
        return characters
    return {}


func _apply_starting_loadout(state: CharacterState) -> void:
    var item_ids: Variant = starting_loadouts.get(state.id, [])
    if not item_ids is Array:
        push_error("Starting loadout for %s is not an array." % state.id)
        return
    for index in range(item_ids.size()):
        var item_id := String(item_ids[index])
        var instance_id := "start_%s_%s_%02d" % [state.id, item_id, index]
        var item := ItemCatalog.create_instance(item_id, instance_id)
        if item.is_empty():
            push_error("Unknown starting item '%s' for %s." % [item_id, state.id])
            continue
        if not state.add_inventory_item(item):
            push_error("Could not add starting item '%s' to %s." % [item_id, state.id])
            continue
        if not state.equip_inventory_item(instance_id):
            push_error("Could not equip starting item '%s' on %s." % [item_id, state.id])


func _apply_npc_clothing_loadout(state: CharacterState, npc_profile: Dictionary) -> void:
    var params: Dictionary = npc_profile.get("params", {})
    var clothing_parameters := [
        {"parameter": "underTop", "slot": "underTop"},
        {"parameter": "underBottom", "slot": "underBottom"},
        {"parameter": "top", "slot": "shirt"},
        {"parameter": "bottom", "slot": "pants"},
        {"parameter": "shoes", "slot": "shoes"}
    ]
    for entry in clothing_parameters:
        var garment_id := String(params.get(entry.parameter, "none"))
        if garment_id.is_empty() or garment_id == "none":
            continue
        var item := ItemCatalog.create_instance(garment_id, "start_%s_clothing_%s" % [state.id, entry.slot])
        if item.is_empty():
            push_warning("NPC %s has Ara garment '%s' without an inventory definition." % [state.id, garment_id])
            continue
        if not state.add_inventory_item(item):
            push_error("Could not add NPC clothing '%s' to %s." % [garment_id, state.id])
            continue
        if not state.equip_inventory_item(String(item.instance_id)):
            push_error("Could not equip NPC clothing '%s' on %s." % [garment_id, state.id])


func _spawn_character(id: String, display_name: String, hex: Vector2i, colour: Color, is_player: bool = false, ara_model_id: String = "", npc_profile: Dictionary = {}) -> void:
    var spawn_hex := _find_valid_spawn_hex(hex)
    var state: CharacterState
    if is_player:
        state = CHARACTER_CREATION_RULES.create_player_state(player_profile, id, spawn_hex)
    else:
        state = CharacterState.new(id, display_name, spawn_hex)
        _apply_starting_loadout(state)
        _apply_npc_clothing_loadout(state, npc_profile)
    state.time_points = state.max_time_points
    simulation.register_character(state)

    var actor := HexActorPresentation.new()
    actor.name = id
    actor.position = _hex_world_position(spawn_hex)
    actor.set_meta("character_id", id)
    actor.set_meta("ambient_enabled", not is_player and id != "companion_wren_talbot")
    actor.set_meta("ambient_role", _ambient_role_for_id(id))
    actor.rotation.y = deg_to_rad(float(state.facing_direction - 2) * 60.0)

    var ara_model := ARA_CHARACTER_ACTOR.new() as AraCharacterActor
    ara_model.name = "CharacterModel"
    actor.add_child(ara_model)
    var body_variant := str(player_profile.get("body_variant", "female")) if is_player else ("male" if int(npc_profile.get("params", {}).get("gender", 0)) == 1 else "female")
    var model_path := PLAYER_MALE_ASSET if body_variant == "male" else PLAYER_FEMALE_ASSET
    if is_player and body_variant == "female" and ResourceLoader.exists(PLAYER_CUSTOM_FEMALE_ASSET):
        model_path = PLAYER_CUSTOM_FEMALE_ASSET
    if not is_player and not ara_model_id.is_empty():
        var authored_npc_path := "res://art/characters/hollowmere/%s.glb" % ara_model_id
        if ResourceLoader.exists(authored_npc_path):
            model_path = authored_npc_path
    var model_loaded := ara_model.configure(model_path)
    if model_loaded:
        if is_player:
            ara_model.apply_player_profile(player_profile)
        else:
            var params: Dictionary = npc_profile.get("params", {})
            ara_model.apply_npc_parameters(params)
        if model_path.contains("/ara_runtime/"):
            _attach_ara_hair(ara_model, body_variant, str(player_profile.get("hair_style_id", "short02")) if is_player else str(npc_profile.get("params", {}).get("hair", "short02")))
        # Authored Hollowmere NPC GLBs already contain their selected Ara garments.
        # Runtime base bodies and the player avatar need the separate modular layer.
        if is_player or model_path.contains("/ara_runtime/"):
            ara_model.configure_modular_garments()
        ara_model.apply_equipment_visuals(state.equipped_item_data)
    else:
        push_error("Character '%s' could not load Ara model '%s'. No primitive substitute will be shown." % [display_name, model_path])
        ara_model.queue_free()

    var name_label := Label3D.new()
    name_label.name = "PlayerNameLabel" if is_player else "CharacterNameLabel"
    name_label.text = "You" if is_player else display_name
    name_label.position.y = 2.08
    name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    name_label.font_size = 32
    name_label.outline_size = 6
    name_label.modulate = Color(1.0, 0.95, 0.82)
    actor.add_child(name_label)

    add_child(actor)
    actor_by_id[id] = actor


func _attach_ara_hair(actor: AraCharacterActor, body_variant: String, hair_id: String) -> void:
    if hair_id.is_empty() or hair_id == "none":
        actor.clear_hairstyle()
        return
    var hair_path := "res://art/characters/ara_runtime/hair/%s_%s.glb" % [body_variant, hair_id]
    if not ResourceLoader.exists(hair_path):
        push_warning("Ara hairstyle '%s' is unavailable at %s; retaining base hair." % [hair_id, hair_path])
        return
    if not actor.set_hairstyle(hair_path):
        push_warning("Ara hairstyle '%s' could not be attached to the shared %s body." % [hair_id, body_variant])

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
    var title_label := Label.new()
    title_label.position = Vector2(22.0, 68.0)
    title_label.text = "LOCATION  /  HOLLOW TANKARD"
    title_label.add_theme_font_size_override("font_size", 20)
    title_label.add_theme_color_override("font_color", Color(0.94, 0.84, 0.62))
    layer.add_child(title_label)

    var menu_button := Button.new()
    menu_button.text = "Menu"
    menu_button.position = Vector2(22.0, 18.0)
    menu_button.custom_minimum_size = Vector2(112.0, 40.0)
    layer.add_child(menu_button)
    var game_menu := PopupMenu.new()
    game_menu.name = "GameMenu"
    game_menu.add_item("Controls", 0)
    game_menu.add_separator()
    game_menu.add_item("Settings — coming later", 1)
    game_menu.add_item("Save game — coming later", 2)
    game_menu.add_item("Load game — coming later", 3)
    game_menu.add_item("Return to main menu — coming later", 4)
    for menu_index in range(1, 5):
        game_menu.set_item_disabled(menu_index, true)
    game_menu.id_pressed.connect(_on_game_menu_selected)
    layer.add_child(game_menu)
    menu_button.pressed.connect(func():
        game_menu.position = Vector2i(22, 62)
        game_menu.popup()
    )

    var controls_dialog := AcceptDialog.new()
    controls_dialog.name = "ControlsDialog"
    controls_dialog.title = "Hollow Tankard — Controls"
    controls_dialog.dialog_text = "MOVE\nW / A / S / D / Q / E — move one hex\nClick a walkable hex — plot a path\n[ and ] — turn active character\n\nINTERACT\nF — use nearby door or talk to nearest person\nG — gather nearby resource\nTab — switch active party member\nC — character sheet\nI — inventory and equipment\n\nCOMBAT\nSpace — attack\nEnter — end turn\n\nWORLD\nV — toggle roof"
    controls_dialog.min_size = Vector2i(420, 430)
    layer.add_child(controls_dialog)
    game_menu.set_meta("controls_dialog", controls_dialog)

    resource_status_label = Label.new()
    resource_status_label.position = Vector2(22.0, 112.0)
    resource_status_label.custom_minimum_size = Vector2(420.0, 36.0)
    resource_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    resource_status_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.64))
    layer.add_child(resource_status_label)

    var gather_button := Button.new()
    gather_button.text = "Gather [G]"
    gather_button.position = Vector2(840.0, 18.0)
    gather_button.custom_minimum_size = Vector2(145.0, 42.0)
    gather_button.pressed.connect(_gather_at_player)
    layer.add_child(gather_button)

    party_switch_button = Button.new()
    party_switch_button.text = "Active: You  [Tab] Switch"
    party_switch_button.position = Vector2(145.0, 18.0)
    party_switch_button.custom_minimum_size = Vector2(230.0, 42.0)
    party_switch_button.pressed.connect(_switch_party_member)
    layer.add_child(party_switch_button)

    var character_panel_button := Button.new()
    character_panel_button.text = "Character  [C]"
    character_panel_button.position = Vector2(385.0, 18.0)
    character_panel_button.custom_minimum_size = Vector2(145.0, 42.0)
    character_panel_button.pressed.connect(_open_character_panel)
    layer.add_child(character_panel_button)

    var inventory_panel_button := Button.new()
    inventory_panel_button.text = "Inventory  [I]"
    inventory_panel_button.position = Vector2(540.0, 18.0)
    inventory_panel_button.custom_minimum_size = Vector2(140.0, 42.0)
    inventory_panel_button.pressed.connect(_open_inventory_panel)
    layer.add_child(inventory_panel_button)

    var world_map_button := Button.new()
    world_map_button.text = "World Map"
    world_map_button.position = Vector2(690.0, 18.0)
    world_map_button.custom_minimum_size = Vector2(140.0, 42.0)
    world_map_button.pressed.connect(_toggle_world_map)
    layer.add_child(world_map_button)

    attack_button = Button.new()
    attack_button.text = "Attack [Space]"
    attack_button.position = Vector2(840.0, 70.0)
    attack_button.custom_minimum_size = Vector2(145.0, 42.0)
    attack_button.visible = false
    attack_button.pressed.connect(_attack_active_character)
    layer.add_child(attack_button)

    end_turn_button = Button.new()
    end_turn_button.text = "End Turn [Enter]"
    end_turn_button.position = Vector2(995.0, 70.0)
    end_turn_button.custom_minimum_size = Vector2(160.0, 42.0)
    end_turn_button.visible = false
    end_turn_button.pressed.connect(_end_active_turn)
    layer.add_child(end_turn_button)

    combat_status_label = Label.new()
    combat_status_label.position = Vector2(610.0, 120.0)
    combat_status_label.custom_minimum_size = Vector2(360.0, 54.0)
    combat_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    combat_status_label.visible = false
    layer.add_child(combat_status_label)

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

    character_panel = CHARACTER_PANEL_SCRIPT.new() as CharacterPanel
    character_panel.name = "CharacterPanel"
    layer.add_child(character_panel)
    character_panel.configure(simulation, active_character_id)
    character_panel.equipment_changed.connect(_on_character_equipment_changed)
    _create_dialogue_panel(layer)

    world_map_panel = WORLD_MAP_PANEL_SCRIPT.new() as CanvasLayer
    world_map_panel.name = "MainCampaignWorldMap"
    add_child(world_map_panel)

    # Reactions are requested by the simulation and displayed here. The UI
    # never decides eligibility or spends TP; it returns a choice ID only.
    reaction_prompt = REACTION_PROMPT_SCRIPT.new()
    reaction_prompt.name = "ReactionPrompt"
    reaction_prompt.choice_selected.connect(_on_reaction_choice_selected)
    add_child(reaction_prompt)


func _on_game_menu_selected(item_id: int) -> void:
    if item_id != 0:
        return
    var menu := get_tree().root.find_child("GameMenu", true, false) as PopupMenu
    if menu != null:
        var dialog := menu.get_meta("controls_dialog") as AcceptDialog
        if dialog != null:
            dialog.popup_centered()


func _create_dialogue_panel(layer: CanvasLayer) -> void:
    dialogue_panel = PanelContainer.new()
    dialogue_panel.name = "CampaignDialoguePanel"
    dialogue_panel.anchor_left = 0.5
    dialogue_panel.anchor_right = 0.5
    dialogue_panel.anchor_top = 1.0
    dialogue_panel.anchor_bottom = 1.0
    dialogue_panel.offset_left = -310.0
    dialogue_panel.offset_right = 310.0
    dialogue_panel.offset_top = -300.0
    dialogue_panel.offset_bottom = -22.0
    dialogue_panel.visible = false
    layer.add_child(dialogue_panel)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 10)
    dialogue_panel.add_child(column)

    dialogue_speaker_label = Label.new()
    dialogue_speaker_label.add_theme_font_size_override("font_size", 22)
    dialogue_speaker_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
    column.add_child(dialogue_speaker_label)

    dialogue_body_label = Label.new()
    dialogue_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    dialogue_body_label.custom_minimum_size = Vector2(580.0, 76.0)
    dialogue_body_label.add_theme_font_size_override("font_size", 18)
    column.add_child(dialogue_body_label)

    dialogue_choices_box = VBoxContainer.new()
    dialogue_choices_box.add_theme_constant_override("separation", 6)
    column.add_child(dialogue_choices_box)


func _show_dialogue(speaker: String, body: String, choices: Array[Dictionary]) -> void:
    if dialogue_panel == null:
        return
    dialogue_open = true
    dialogue_speaker_label.text = speaker
    dialogue_body_label.text = body
    for child in dialogue_choices_box.get_children():
        child.queue_free()
    for choice_value in choices:
        var choice: Dictionary = choice_value
        var button := Button.new()
        button.text = String(choice.get("label", "Continue"))
        button.custom_minimum_size = Vector2(0.0, 38.0)
        button.disabled = not bool(choice.get("available", true))
        if not button.disabled:
            button.pressed.connect(func(): _select_dialogue_choice(choice.duplicate(true)))
        else:
            button.tooltip_text = String(choice.get("unavailable_reason", "Not available yet."))
        dialogue_choices_box.add_child(button)
    dialogue_panel.visible = true


func _select_dialogue_choice(choice: Dictionary) -> void:
    var choice_id := String(choice.get("id", ""))
    if choice_id == "continue":
        _close_dialogue()
        return
    if choice_id == "fight":
        _begin_shakedown_combat()
        return
    if choice.has("ironbond_delta"):
        _resolve_shakedown(choice_id)
        await _move_shakedown_soldiers_outside()
        var response := String(choice.get("response", ""))
        if response.is_empty():
            response = "You stand with Garrick. The encounter is ready to begin once combat targeting and enemy AI are connected."
        _show_dialogue("Hollowmere", response, [{"id": "continue", "label": "Continue", "text": ""}])
        return

    var response_text := String(choice.get("text", ""))
    if choice_id == "spar":
        response_text += "\n\nA full sparring encounter is not connected to the 3D combat interface yet."
    _show_dialogue(dialogue_speaker_label.text, response_text, [{"id": "continue", "label": "Continue", "text": ""}])


func _close_dialogue() -> void:
    dialogue_open = false
    if dialogue_panel != null:
        dialogue_panel.visible = false


func _interact_with_nearest_npc() -> void:
    if dialogue_open or ambient_exchange_running or encounter_active or shakedown_started and not shakedown_resolved:
        return
    var player_state := simulation.get_character(active_character_id)
    if player_state == null:
        return
    var nearest_id := ""
    var nearest_distance := 999
    for actor_id_value in actor_by_id.keys():
        var actor_id := String(actor_id_value)
        if actor_id == active_character_id or party_member_ids.has(actor_id):
            continue
        var state := simulation.get_character(actor_id)
        if state == null or not state.can_act() or state.side == "enemy":
            continue
        var distance := HexGrid.distance(player_state.axial, state.axial)
        if distance <= 2 and distance < nearest_distance:
            nearest_distance = distance
            nearest_id = actor_id
    if nearest_id.is_empty():
        _show_dialogue("No one nearby", "Move closer to someone if you want to speak with them.", [{"id": "continue", "label": "Close", "text": ""}])
        return
    var quest_state := simulation.campaign_journal.quest_state(HollowmereCampaignContent.QUEST_ID)
    var decisions: Dictionary = quest_state.get("decisions", {})
    var response_choice := String(decisions.get("response", ""))
    var standing := simulation.campaign_journal.npc_standing(nearest_id)
    var conversation := HollowmereCampaignContent.npc_greeting(nearest_id, shakedown_resolved, standing, response_choice)
    var choices: Array[Dictionary] = []
    for choice_value in conversation.get("choices", []):
        var choice: Dictionary = choice_value
        choices.append(choice.duplicate(true))
    _show_dialogue(String(conversation.get("speaker", nearest_id)), String(conversation.get("text", "")), choices)


func _resolve_shakedown(choice_id: String) -> void:
    if shakedown_resolved:
        return
    var result := HollowmereCampaignContent.resolve_shakedown(simulation.campaign_journal, choice_id)
    if not bool(result.get("ok", false)):
        return
    shakedown_resolved = true

func _run_opening_sequence() -> void:
    var player_state := simulation.get_character("player")
    if player_state == null or player_state.race in ["goblin", "orc"]:
        return
    simulation.campaign_journal.start_quest(HollowmereCampaignContent.QUEST_ID)
    await get_tree().create_timer(2.0).timeout
    if not is_instance_valid(self):
        return
    _show_speech_bubble("companion_wren_talbot", "Well, here we are then. Try not to get us both killed, yeah?")
    await get_tree().create_timer(6.0).timeout
    if not is_instance_valid(self) or shakedown_started:
        return
    shakedown_started = true
    var opening_lines := HollowmereCampaignContent.opening_lines()
    for index in range(opening_lines.size()):
        var line: Dictionary = opening_lines[index]
        var speaker_id := String(line.get("speaker_id", "dray_coltayne"))
        if speaker_id == "narrator":
            _show_world_narration(String(line.get("text", "")))
            await _move_shakedown_soldiers_inside()
        else:
            _show_speech_bubble(speaker_id, String(line.get("text", "")))
        await get_tree().create_timer(2.25).timeout
    if not shakedown_resolved:
        _show_dialogue("Dray Coltayne", "What do you do?", HollowmereCampaignContent.shakedown_choices())


func _move_shakedown_soldiers_outside() -> void:
    var wait_hexes: Array[Vector2i] = [Vector2i(-1, 6), Vector2i(0, 6), Vector2i(1, 6)]
    for index in range(HOLLOWMERE_ENCOUNTER_SCRIPT.ENEMY_IDS.size()):
        var character_id := HOLLOWMERE_ENCOUNTER_SCRIPT.ENEMY_IDS[index]
        var destination := wait_hexes[index]
        var path := simulation.find_path(character_id, destination)
        for step_index in range(1, path.size()):
            if not simulation.try_move_character_step(character_id, path[step_index]):
                break
            await get_tree().create_timer(0.24).timeout
            if not is_instance_valid(self):
                return


func _move_shakedown_soldiers_inside() -> void:
    var preferred_destinations: Array[Vector2i] = [Vector2i(0, 3), Vector2i(-2, 3), Vector2i(2, 3)]
    var fallback_destinations: Array[Vector2i] = [Vector2i(-1, 3), Vector2i(1, 3), Vector2i(0, 2), Vector2i(2, 2), Vector2i(-2, 2)]
    for index in range(HOLLOWMERE_ENCOUNTER_SCRIPT.ENEMY_IDS.size()):
        var character_id := HOLLOWMERE_ENCOUNTER_SCRIPT.ENEMY_IDS[index]
        var best_path: Array[Vector2i] = []
        var destinations: Array[Vector2i] = [preferred_destinations[index]]
        destinations.append_array(fallback_destinations)
        for destination in destinations:
            if not simulation.map_data.is_walkable(destination) or simulation.occupied_hexes.has(destination):
                continue
            var path := simulation.find_path(character_id, destination)
            if path.size() > 1 and (best_path.is_empty() or path.size() < best_path.size()):
                best_path = path
        for step_index in range(1, best_path.size()):
            if not simulation.try_move_character_step(character_id, best_path[step_index]):
                break
            await get_tree().create_timer(0.24).timeout
            if not is_instance_valid(self):
                return


func _show_world_narration(text: String) -> void:
    var bubble := Label3D.new()
    bubble.name = "NarrationBubble"
    bubble.text = text
    bubble.position = Vector3(0.0, 4.4, 0.0)
    bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    bubble.font_size = 22
    bubble.pixel_size = 0.008
    bubble.outline_size = 6
    bubble.modulate = Color(0.98, 0.96, 0.86)
    add_child(bubble)
    var timer := Timer.new()
    timer.one_shot = true
    timer.wait_time = 2.15
    add_child(timer)
    timer.timeout.connect(func():
        if is_instance_valid(bubble):
            bubble.queue_free()
        if is_instance_valid(timer):
            timer.queue_free()
    )
    timer.start()


func _show_speech_bubble(character_id: String, text: String) -> void:
    var actor := actor_by_id.get(character_id) as Node3D
    if actor == null:
        return
    var bubble := Label3D.new()
    bubble.name = "SpeechBubble"
    bubble.text = text
    bubble.position = Vector3(0.0, 3.0, 0.0)
    bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    bubble.font_size = 22
    bubble.pixel_size = 0.008
    bubble.outline_size = 6
    bubble.modulate = Color(1.0, 0.97, 0.86)
    actor.add_child(bubble)
    var timer := Timer.new()
    timer.one_shot = true
    timer.wait_time = 2.15
    actor.add_child(timer)
    timer.timeout.connect(func():
        if is_instance_valid(bubble):
            bubble.queue_free()
        if is_instance_valid(timer):
            timer.queue_free()
    )
    timer.start()


func _ambient_role_for_id(character_id: String) -> String:
    if character_id in ["dray_coltayne", "tomlin_brask", "hask_greel"]:
        return "guard"
    if character_id == "garrick_holt":
        return "merchant"
    if character_id == "wick_hallow":
        return "merchant"
    if character_id == "companion_wren_talbot":
        return "civilian"
    return "civilian"


func _update_ambient_chatter(delta: float) -> void:
    if dialogue_open or shakedown_started and not shakedown_resolved or simulation == null or simulation.is_in_combat or simulation.clock.paused or ambient_exchange_running:
        return
    ambient_accumulator += delta
    if ambient_accumulator < 16.0:
        return
    ambient_accumulator = 0.0
    var candidates: Array[String] = []
    for actor_id_value in actor_by_id.keys():
        var actor_id := String(actor_id_value)
        var actor := actor_by_id.get(actor_id) as Node3D
        var state := simulation.get_character(actor_id)
        if actor != null and bool(actor.get_meta("ambient_enabled", false)) and state != null and state.can_act() and state.side == "neutral":
            candidates.append(actor_id)
    if candidates.size() < 2:
        return
    var pairs: Array[Array] = []
    for i in range(candidates.size()):
        for j in range(i + 1, candidates.size()):
            var first_state := simulation.get_character(candidates[i])
            var second_state := simulation.get_character(candidates[j])
            if first_state != null and second_state != null and HexGrid.distance(first_state.axial, second_state.axial) <= 2:
                pairs.append([candidates[i], candidates[j]])
    if pairs.is_empty():
        return
    var pair: Array = pairs[ambient_rng.randi_range(0, pairs.size() - 1)]
    var first_id := String(pair[0])
    var second_id := String(pair[1])
    var first_actor := actor_by_id.get(first_id) as Node3D
    var second_actor := actor_by_id.get(second_id) as Node3D
    var hour := int(fposmod(simulation.clock.world_seconds, 86400.0) / 3600.0)
    var quest_state := simulation.campaign_journal.quest_state(HollowmereCampaignContent.QUEST_ID)
    var decisions: Dictionary = quest_state.get("decisions", {})
    var response_choice := String(decisions.get("response", ""))
    var exchange := ambient_chatter.choose_exchange(
        first_id, second_id,
        String(first_actor.get_meta("ambient_role", "civilian")),
        String(second_actor.get_meta("ambient_role", "civilian")),
        simulation.clock.world_seconds, hour, ambient_security, shakedown_resolved, ambient_rng, response_choice
    )
    if exchange.is_empty():
        return
    ambient_chatter.record_exchange(exchange, first_id, second_id, simulation.clock.world_seconds)
    _run_ambient_exchange(first_id, second_id, exchange)


func _run_ambient_exchange(first_id: String, second_id: String, exchange: Dictionary) -> void:
    ambient_exchange_running = true
    var lines: Array = exchange.get("lines", [])
    for index in range(lines.size()):
        var speaker_id := first_id if index % 2 == 0 else second_id
        _show_speech_bubble(speaker_id, String(lines[index]))
        if index < lines.size() - 1:
            await get_tree().create_timer(2.0).timeout
    ambient_exchange_running = false

func _begin_shakedown_combat() -> void:
    _close_dialogue()
    var branch_result := HollowmereCampaignContent.apply_shakedown_choice(simulation.campaign_journal, "fight")
    if not bool(branch_result.get("ok", false)):
        _show_dialogue("Hollowmere", "The choice could not be recorded: " + String(branch_result.get("reason", "unknown error")) + ".", [{"id": "continue", "label": "Continue", "text": ""}])
        return
    shakedown_resolved = true
    var result := HOLLOWMERE_ENCOUNTER_SCRIPT.start(simulation)
    if not bool(result.get("ok", false)):
        simulation.campaign_journal.fail_quest(HollowmereCampaignContent.QUEST_ID, "The fight could not start: " + String(result.get("reason", "unknown error")))
        _show_dialogue("Hollowmere", "The confrontation cannot begin: " + String(result.get("reason", "unknown error")) + ".", [{"id": "continue", "label": "Continue", "text": ""}])
        return
    encounter_active = true
    enemy_turn_processed = false
    enemy_turn_waiting_for_reaction = false
    if not HOLLOWMERE_ENCOUNTER_SCRIPT.PLAYER_CONTROLLED_IDS.has(active_character_id):
        active_character_id = "player"
    _update_combat_ui()


func _on_combat_turn_started(_character_id: String) -> void:
    enemy_turn_processed = false


func _update_combat(_delta: float) -> void:
    if not encounter_active or simulation == null or not simulation.is_in_combat:
        return
    _check_encounter_resolution()
    if not encounter_active or not simulation.is_in_combat:
        return
    if enemy_turn_waiting_for_reaction and simulation.pending_reaction.is_empty():
        enemy_turn_waiting_for_reaction = false
        simulation.try_end_current_turn(true)
        return
    if not simulation.pending_reaction.is_empty():
        return
    var current := simulation.get_current_turn_character()
    if current == null or enemy_turn_processed:
        return
    var is_ai_turn := current.side == "enemy" or (current.side == "player" and not HOLLOWMERE_ENCOUNTER_SCRIPT.PLAYER_CONTROLLED_IDS.has(current.id))
    if not is_ai_turn:
        return
    enemy_turn_processed = true
    _run_ai_combat_turn(current)


func _run_ai_combat_turn(combatant: CharacterState) -> void:
    var target := _nearest_opponent_target(combatant)
    if target == null:
        simulation.try_end_current_turn(true)
        return
    if HexGrid.distance(combatant.axial, target.axial) <= _attack_range_for(combatant):
        var weapon_id := String(combatant.equipment.get("weapon", ""))
        var weapon: Dictionary = combatant.equipped_item_data.get("weapon", {})
        var result := simulation.try_attack_character(combatant.id, target.id, {
            "time_point_cost": 10.0,
            "weapon_id": weapon_id,
            "is_ranged": String(weapon.get("subType", "")) == "ranged"
        }, int(combatant.id.hash()))
        if bool(result.get("pending", false)) or not simulation.pending_reaction.is_empty():
            enemy_turn_waiting_for_reaction = true
        else:
            simulation.try_end_current_turn(true)
        return
    var next_step := _best_enemy_approach_step(combatant, target)
    if next_step == INVALID_HEX:
        simulation.try_end_current_turn(true)
        return
    var moved := simulation.try_move_character_step(combatant.id, next_step)
    if moved and not simulation.pending_reaction.is_empty():
        enemy_turn_waiting_for_reaction = true
    else:
        simulation.try_end_current_turn(true)


func _nearest_opponent_target(combatant: CharacterState) -> CharacterState:
    var best: CharacterState
    var best_distance := 999
    var opponent_ids: Array[String] = HOLLOWMERE_ENCOUNTER_SCRIPT.ENEMY_IDS
    if combatant.side == "enemy":
        opponent_ids = HOLLOWMERE_ENCOUNTER_SCRIPT.COMBAT_ALLY_IDS
    for opponent_id in opponent_ids:
        var opponent := simulation.get_character(opponent_id)
        if opponent == null or not opponent.can_act():
            continue
        var distance := HexGrid.distance(combatant.axial, opponent.axial)
        if distance < best_distance:
            best_distance = distance
            best = opponent
    return best


func _best_enemy_approach_step(enemy: CharacterState, target: CharacterState) -> Vector2i:
    var best_path: Array[Vector2i] = []
    for destination in HexGrid.neighbors(target.axial):
        if not simulation.map_data.is_walkable(destination) or simulation.occupied_hexes.has(destination):
            continue
        var path := simulation.find_path(enemy.id, destination)
        if path.size() < 2:
            continue
        if best_path.is_empty() or path.size() < best_path.size():
            best_path = path
    return best_path[1] if best_path.size() > 1 else INVALID_HEX


func _attack_active_character() -> void:
    if not encounter_active or not simulation.is_in_combat or not simulation.pending_reaction.is_empty():
        return
    var current := simulation.get_current_turn_character()
    if current == null or current.id != active_character_id or current.side != "player":
        combat_status_label.text = "It is not this character turn. Switch party members with Tab."
        return
    var target := _nearest_enemy_in_attack_range(current)
    if target == null:
        combat_status_label.text = "No enemy in reach. Move adjacent to an Ironbond soldier first."
        return
    var weapon_id := String(current.equipment.get("weapon", ""))
    var result := simulation.try_attack_character(current.id, target.id, {
        "time_point_cost": 10.0,
        "weapon_id": weapon_id
    }, int(current.id.hash() + target.id.hash()))
    if bool(result.get("pending", false)) or not simulation.pending_reaction.is_empty():
        combat_status_label.text = "Resolving a defensive reaction..."
    elif bool(result.get("ok", false)):
        combat_status_label.text = "Attack resolved against %s." % target.display_name
    else:
        combat_status_label.text = "Attack unavailable: %s" % String(result.get("reason", "unknown"))
    _check_encounter_resolution()


func _attack_range_for(attacker: CharacterState) -> int:
    if attacker == null:
        return 1
    var weapon: Dictionary = attacker.equipped_item_data.get("weapon", {})
    return maxi(1, 1 + int(weapon.get("range", 0)))

func _nearest_enemy_in_attack_range(attacker: CharacterState) -> CharacterState:
    var best: CharacterState
    var best_distance := 999
    for enemy_id in HOLLOWMERE_ENCOUNTER_SCRIPT.ENEMY_IDS:
        var enemy := simulation.get_character(enemy_id)
        if enemy == null or not enemy.can_act():
            continue
        var distance := HexGrid.distance(attacker.axial, enemy.axial)
        if distance <= _attack_range_for(attacker) and distance < best_distance:
            best_distance = distance
            best = enemy
    return best


func _end_active_turn() -> void:
    if not encounter_active or not simulation.is_in_combat or not simulation.pending_reaction.is_empty():
        return
    var current := simulation.get_current_turn_character()
    if current == null or current.id != active_character_id or current.side != "player":
        return
    simulation.try_end_current_turn(true)


func _update_combat_ui() -> void:
    if attack_button == null or end_turn_button == null or combat_status_label == null:
        return
    var combat_visible := encounter_active and simulation != null and simulation.is_in_combat
    attack_button.visible = combat_visible
    end_turn_button.visible = combat_visible
    combat_status_label.visible = combat_visible
    if not combat_visible:
        return
    var current := simulation.get_current_turn_character()
    var player_turn := current != null and current.side == "player" and current.id == active_character_id and current.can_act() and simulation.pending_reaction.is_empty()
    attack_button.disabled = not player_turn or _nearest_enemy_in_attack_range(current) == null
    end_turn_button.disabled = not player_turn
    if not simulation.pending_reaction.is_empty():
        combat_status_label.text = "Reaction pending..."
    elif current == null:
        combat_status_label.text = "Waiting for the next combat turn..."
    elif current.side == "enemy":
        combat_status_label.text = "%s is acting..." % current.display_name
    elif current.id != active_character_id and HOLLOWMERE_ENCOUNTER_SCRIPT.PLAYER_CONTROLLED_IDS.has(current.id):
        combat_status_label.text = "Switch to %s with Tab." % current.display_name
    elif current.id != active_character_id:
        combat_status_label.text = "%s is acting..." % current.display_name
    else:
        combat_status_label.text = "%s  ·  HP %d/%d  ·  TP %d" % [current.display_name, current.health, current.max_health, roundi(current.time_points)]


func _check_encounter_resolution() -> void:
    if not encounter_active:
        return
    if HOLLOWMERE_ENCOUNTER_SCRIPT.party_defeated(simulation):
        simulation.end_combat()
        HOLLOWMERE_ENCOUNTER_SCRIPT.finish(simulation)
        encounter_active = false
        shakedown_resolved = true
        simulation.campaign_journal.fail_quest(HollowmereCampaignContent.QUEST_ID, "The party was defeated during the Ironbond shakedown.")
        _show_dialogue("Garrick Holt", "The soldiers overpower you. Garrick has no choice but to surrender the due. The confrontation is lost.", [{"id": "continue", "label": "Continue", "text": ""}])
    elif HOLLOWMERE_ENCOUNTER_SCRIPT.enemies_defeated(simulation):
        simulation.end_combat()
        HOLLOWMERE_ENCOUNTER_SCRIPT.finish(simulation)
        encounter_active = false
        HollowmereCampaignContent.complete_shakedown(simulation.campaign_journal)
        _show_speech_bubble("garrick_holt", HollowmereCampaignContent.shakedown_victory_text())
        _show_dialogue("Garrick Holt", HollowmereCampaignContent.shakedown_victory_text(), [{"id": "continue", "label": "Continue", "text": ""}])

func _on_character_equipment_changed(changed_character_id: String) -> void:
    var state := simulation.get_character(changed_character_id) if simulation != null else null
    var actor := actor_by_id.get(changed_character_id) as Node3D
    if state == null or actor == null:
        return
    var ara := actor.get_node_or_null("CharacterModel")
    if ara is AraCharacterActor:
        (ara as AraCharacterActor).apply_equipment_visuals(state.equipped_item_data)


func _toggle_character_panel() -> void:
    _open_character_panel()

func _open_character_panel() -> void:
    if character_panel != null:
        character_panel.set_tab("character")
        if not character_panel.visible:
            character_panel.toggle_panel()

func _open_inventory_panel() -> void:
    if character_panel != null:
        character_panel.set_tab("inventory")
        if not character_panel.visible:
            character_panel.toggle_panel()

func _toggle_world_map() -> void:
    if world_map_panel != null and world_map_panel.has_method("toggle_panel"):
        world_map_panel.toggle_panel()


func _on_reaction_requested(reactor_id: String, options: Array[Dictionary], request_id: int, _source_event_id: String) -> void:
    if not HOLLOWMERE_ENCOUNTER_SCRIPT.PLAYER_CONTROLLED_IDS.has(reactor_id):
        _resolve_ai_reaction(reactor_id, options)
        return
    if reaction_prompt != null:
        reaction_prompt.present(reactor_id, options, request_id)


func _resolve_ai_reaction(reactor_id: String, options: Array[Dictionary]) -> void:
    var selected_id := ""
    var selected_priority := -1
    for option_value in options:
        var option: Dictionary = option_value
        var option_id := String(option.get("id", ""))
        var option_reactor_id := String(option.get("reactor_id", reactor_id))
        var priority := 0
        if option_id == "parry" and option_reactor_id == reactor_id:
            priority = 4
        elif option_id == "protector_parry":
            priority = 3
        elif option_id == "shield_other":
            priority = 2
        if priority > selected_priority:
            selected_priority = priority
            selected_id = option_id
    simulation.resolve_reaction(selected_id)

func _on_reaction_choice_selected(choice_id: String, _request_id: int) -> void:
    if simulation != null:
        simulation.resolve_reaction(choice_id)

func _on_reaction_resolved(_reactor_id: String, _choice_id: String, _request_id: int, _reason: String) -> void:
    if reaction_prompt != null:
        reaction_prompt.dismiss()

func _on_movement_reaction_resolved(_mover_id: String, halted: bool) -> void:
    if halted:
        active_path.clear()
        _clear_path_markers()

func _on_zoom_slider_changed(value: float) -> void:
    camera_rig.set_zoom(value)

func _on_camera_zoom_changed(value: float) -> void:
    if is_instance_valid(zoom_slider):
        zoom_slider.set_value_no_signal(value)

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
    if character_panel != null:
        character_panel.set_character(active_character_id)

func _process(delta: float) -> void:
    _update_ambient_chatter(delta)
    _update_combat(delta)
    _update_combat_ui()
    if active_path.size() < 2:
        return
    path_step_accumulator += delta
    if path_step_accumulator < PATH_STEP_INTERVAL:
        return
    path_step_accumulator = 0.0
    _advance_path_step()


func _gather_at_player() -> void:
    var player := simulation.get_character("player")
    if player == null:
        return
    var result := simulation.harvest_resource_at("player", player.axial)
    if not bool(result.get("ok", false)):
        var reason := String(result.get("reason", "no_resource_here"))
        var messages := {
            "no_resource_here": "Nothing useful to gather on this hex.",
            "resource_depleted": "This resource has been exhausted for now.",
            "resource_regrowing": "This spot needs more time to recover.",
            "requires_pickaxe": "You need to carry a pickaxe to mine this outcrop.",
            "requires_axe": "You need to carry an axe to harvest timber.",
            "character_unavailable": "You cannot gather while incapacitated."
        }
        resource_status_label.text = String(messages.get(reason, "You cannot gather here."))
        return
    var names: Array[String] = []
    for item_id in result.get("item_ids", []):
        var definition := ItemCatalog.get_definition(String(item_id))
        names.append(String(definition.get("name", item_id)))
    var gathered_text := ""
    for item_name in names:
        if not gathered_text.is_empty():
            gathered_text += ", "
        gathered_text += item_name
    resource_status_label.text = "Gathered: " + gathered_text
    _refresh_resource_visual_at(player.axial)

func _refresh_resource_visual_at(hex: Vector2i) -> void:
    if not resource_visuals_by_hex.has(hex):
        return
    var visual := resource_visuals_by_hex[hex] as WildernessResourceVisual
    if not is_instance_valid(visual):
        return
    visual.refresh(simulation.ensure_resource_at(hex), int(simulation.clock.calendar_date()["month_index"]))

func _refresh_resource_visuals() -> void:
    var month_index := int(simulation.clock.calendar_date()["month_index"])
    for key in resource_visuals_by_hex:
        var hex: Vector2i = key
        var visual := resource_visuals_by_hex[key] as WildernessResourceVisual
        if is_instance_valid(visual):
            visual.refresh(simulation.ensure_resource_at(hex), month_index)

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
        if key_event.keycode == KEY_SPACE:
            _attack_active_character()
            get_viewport().set_input_as_handled()
            return
        if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
            _end_active_turn()
            get_viewport().set_input_as_handled()
            return
        if key_event.keycode == KEY_G:
            _gather_at_player()
            get_viewport().set_input_as_handled()
            return
        if key_event.keycode == KEY_F:
            if not _interact_with_tavern_stairs() and not _interact_with_nearest_door():
                _interact_with_nearest_npc()
            get_viewport().set_input_as_handled()
            return
        if key_event.keycode == KEY_TAB:
            _switch_party_member()
            get_viewport().set_input_as_handled()
            return
        if key_event.keycode == KEY_C:
            _toggle_character_panel()
            get_viewport().set_input_as_handled()
            return
        if key_event.keycode == KEY_I:
            _open_inventory_panel()
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
    var active_state := simulation.get_character(active_character_id)
    var upstairs := active_state != null and _is_upper_floor_hex(active_state.axial)
    var plane_y := UPPER_FLOOR_Y if upstairs else 0.0
    var ray_origin := camera.project_ray_origin(screen_position)
    var ray_direction := camera.project_ray_normal(screen_position)
    if absf(ray_direction.y) < 0.0001:
        return INVALID_HEX
    var distance := (plane_y - ray_origin.y) / ray_direction.y
    if distance < 0.0:
        return INVALID_HEX
    var hit := ray_origin + ray_direction * distance
    var hex := HexGrid.world_to_axial(hit, HEX_RADIUS)
    if upstairs:
        hex += UPPER_FLOOR_ORIGIN
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
    if simulation.clock.paused or not simulation.pending_reaction.is_empty():
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

func _on_character_moved(character_id: String, from_hex: Vector2i, to_hex: Vector2i) -> void:
    var actor: HexActorPresentation = actor_by_id.get(character_id) as HexActorPresentation
    if actor != null:
        if _is_upper_floor_hex(from_hex) != _is_upper_floor_hex(to_hex):
            actor.position = _hex_world_position(to_hex)
        else:
            actor.present_move_to(_hex_world_position(to_hex))
    if character_id == active_character_id:
        _refresh_tavern_floor_presentation()

func _is_upper_floor_hex(hex: Vector2i) -> bool:
    return hex.x >= UPPER_FLOOR_ORIGIN.x - 4 and hex.x <= UPPER_FLOOR_ORIGIN.x + 4 and hex.y >= UPPER_FLOOR_ORIGIN.y - 4 and hex.y <= UPPER_FLOOR_ORIGIN.y + 4 and simulation.map_data.has_cell(hex)

func _refresh_tavern_floor_presentation() -> void:
    if upper_shell_group == null or upper_floor_group == null:
        return
    var active_state := simulation.get_character(active_character_id)
    var upstairs := active_state != null and _is_upper_floor_hex(active_state.axial)
    upper_shell_group.visible = not upstairs
    upper_floor_group.visible = upstairs

func _interact_with_tavern_stairs() -> bool:
    var state := simulation.get_character(active_character_id)
    if state == null:
        return false
    var upstairs := _is_upper_floor_hex(state.axial)
    var stair_hex := TAVERN_STAIR_UPPER_HEX if upstairs else TAVERN_STAIR_GROUND_HEX
    if HexGrid.distance(state.axial, stair_hex) > 1:
        return false
    var destination := TAVERN_STAIR_GROUND_HEX if upstairs else TAVERN_STAIR_UPPER_HEX
    active_path.clear()
    _clear_path_markers()
    if not simulation.relocate_character(active_character_id, destination):
        print("The staircase is blocked.")
    return true

func _interact_with_nearest_door() -> bool:
    var state := simulation.get_character(active_character_id)
    if state == null:
        return false
    var door := simulation.building_registry.get_door(TAVERN_FRONT_DOOR_ID)
    if door == null or HexGrid.distance(state.axial, door.hex) > 1:
        return false
    var should_open := not door.is_passable()
    if not should_open and simulation.occupied_hexes.has(door.hex):
        print("The doorway is occupied; move clear before closing it.")
        return true
    var changed := simulation.building_registry.set_door_open(door.id, should_open)
    if not changed:
        print("The Hollow Tankard door is locked or cannot be moved.")
        return true
    return true

func _on_building_door_state_changed(door_id: String) -> void:
    if door_id != TAVERN_FRONT_DOOR_ID:
        return
    _apply_tavern_door_state()

func _apply_tavern_door_state() -> void:
    var door := simulation.building_registry.get_door(TAVERN_FRONT_DOOR_ID)
    if door == null:
        return
    simulation.map_data.set_walkable(door.hex, door.is_passable())
    _refresh_tavern_door_presentation()

func _refresh_tavern_door_presentation() -> void:
    if not is_instance_valid(tavern_door_pivot):
        return
    var door := simulation.building_registry.get_door(TAVERN_FRONT_DOOR_ID)
    if door == null:
        return
    # A broken door hangs open. The hinge pivot keeps the visible leaf aligned
    # with the same open/closed state that controls hex movement.
    tavern_door_pivot.rotation.y = deg_to_rad(82.0) if door.is_passable() else 0.0

func _hex_world_position(hex: Vector2i) -> Vector3:
    if _is_upper_floor_hex(hex):
        var local_hex := hex - UPPER_FLOOR_ORIGIN
        return HexGrid.axial_to_world(local_hex, HEX_RADIUS, UPPER_FLOOR_Y + 0.12)
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
    var ara := actor.get_node_or_null("CharacterModel")
    if ara is AraCharacterActor:
        (ara as AraCharacterActor).apply_player_profile(profile)
    else:
        # The capsule fallback is deliberately neutral when a Workshop body
        # export is unavailable; never silently display the wrong body variant.
        var skin := Color.from_string(str(profile.get("skin_colour", "#b9825f")), Color(0.72, 0.57, 0.43))
        var head := actor.get_node_or_null("PlayerHead") as MeshInstance3D
        if head != null:
            head.material_override = _material(skin)
        var body := actor.get_node_or_null("PlayerBody") as MeshInstance3D
        if body != null:
            body.material_override = _material(skin)
        actor.set_meta("body_variant", str(profile.get("body_variant", "female")))
        actor.set_meta("gender_presentation", str(profile.get("gender_presentation", "Androgynous")))
        actor.set_meta("pronouns", str(profile.get("pronouns", "they/them")))
