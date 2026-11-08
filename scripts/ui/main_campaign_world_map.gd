extends CanvasLayer
## Strategic reference map for the Main Campaign. This is not yet a travel UI.

const MAP_DATA = preload("res://scripts/world/main_campaign_world_map_data.gd")

var map_view: Control

func _ready() -> void:
    layer = 150
    visible = false
    _build_panel()

func _build_panel() -> void:
    var backdrop := ColorRect.new()
    backdrop.color = Color(0.015, 0.02, 0.03, 0.88)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(backdrop)

    var centre := CenterContainer.new()
    centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(centre)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(840.0, 640.0)
    centre.add_child(panel)

    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation", 8)
    panel.add_child(layout)

    var header := HBoxContainer.new()
    layout.add_child(header)

    var title := Label.new()
    title.text = "THE SILVERHART REALMS"
    title.add_theme_font_size_override("font_size", 22)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)

    var close_button := Button.new()
    close_button.text = "Close"
    close_button.pressed.connect(hide)
    header.add_child(close_button)

    var subtitle := Label.new()
    subtitle.text = "MAIN CAMPAIGN  •  REGIONAL OVERVIEW  •  16 × 16 HEXES"
    subtitle.add_theme_color_override("font_color", Color(0.78, 0.76, 0.68))
    layout.add_child(subtitle)

    map_view = WorldMapView.new()
    map_view.custom_minimum_size = Vector2(800.0, 470.0)
    map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    layout.add_child(map_view)

    var locations := Label.new()
    locations.text = "K  Silverhart     V  Millbrook     V  Hollowmere (start)     T  Reddale\nV  Emberlode     F  Old Mac's Farmstead"
    locations.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    locations.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(locations)

    var note := Label.new()
    note.text = "Human lands: west and centre  •  Orc tribes: east  •  Dwarven mountains: north-east  •  Elven forest: south\nReference map only: travel routes, fog of war and location discovery are future campaign work."
    note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    note.add_theme_font_size_override("font_size", 12)
    note.add_theme_color_override("font_color", Color(0.72, 0.73, 0.70))
    layout.add_child(note)

func toggle_panel() -> void:
    visible = not visible
    if visible and map_view != null:
        map_view.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
    if not visible or not event is InputEventKey:
        return
    var key_event := event as InputEventKey
    if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
        hide()
        get_viewport().set_input_as_handled()

class WorldMapView extends Control:
    const DATA = preload("res://scripts/world/main_campaign_world_map_data.gd")
    const HEX_RADIUS: float = 14.0

    func _draw() -> void:
        var grid := DATA.generate_grid()
        var x_step := HEX_RADIUS * 1.5
        var y_step := sqrt(3.0) * HEX_RADIUS
        var map_width := float(DATA.WORLD_SIZE - 1) * x_step + HEX_RADIUS * 2.0
        var map_height := float(DATA.WORLD_SIZE - 1) * y_step + y_step
        var origin := Vector2((size.x - map_width) * 0.5 + HEX_RADIUS, (size.y - map_height) * 0.5 + HEX_RADIUS)

        for column in range(DATA.WORLD_SIZE):
            for row in range(DATA.WORLD_SIZE):
                var centre := _cell_centre(column, row, origin, x_step, y_step)
                var points := _hex_points(centre)
                var cell: Dictionary = grid[row][column]
                draw_colored_polygon(points, _terrain_colour(String(cell["terrain"])))
                var outline := PackedVector2Array(points)
                outline.append(points[0])
                draw_polyline(outline, _faction_colour(String(cell["faction"])), 1.4, true)

        var river_points := PackedVector2Array()
        for cell in DATA.RIVER_PATH:
            river_points.append(_cell_centre(cell.x, cell.y, origin, x_step, y_step))
        draw_polyline(river_points, Color("#62c7e8"), 3.0, true)

        for location in DATA.LOCATIONS:
            var cell: Vector2i = location["cell"]
            var centre := _cell_centre(cell.x, cell.y, origin, x_step, y_step)
            draw_circle(centre, 6.0, Color("#f4d17a"))
            draw_circle(centre, 3.2, Color("#30291b"))
            draw_string(ThemeDB.fallback_font, centre + Vector2(-3.0, 3.5), String(location["short"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#fff4d4"))

    func _cell_centre(column: int, row: int, origin: Vector2, x_step: float, y_step: float) -> Vector2:
        return origin + Vector2(float(column) * x_step, float(row) * y_step + (column % 2) * y_step * 0.5)

    func _hex_points(centre: Vector2) -> PackedVector2Array:
        var points := PackedVector2Array()
        for index in range(6):
            var angle := deg_to_rad(-30.0 + float(index) * 60.0)
            points.append(centre + Vector2(cos(angle), sin(angle)) * HEX_RADIUS)
        return points

    func _terrain_colour(terrain: String) -> Color:
        match terrain:
            "ocean": return Color("#075b91")
            "forest": return Color("#245b32")
            "mountain": return Color("#777b7c")
            "hills": return Color("#9b806c")
            _: return Color("#63834d")

    func _faction_colour(faction: String) -> Color:
        match faction:
            "humans": return Color("#e6e2d4")
            "elves": return Color("#00d878")
            "dwarves": return Color("#f4d000")
            "orcs": return Color("#ff563e")
            _: return Color("#416c86")
