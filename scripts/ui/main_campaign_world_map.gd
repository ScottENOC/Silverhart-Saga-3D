extends CanvasLayer
## Strategic reference map for the Main Campaign. This is not yet a travel UI.

const MAP_DATA = preload("res://scripts/world/main_campaign_world_map_data.gd")

var map_view: Control

func _ready() -> void:
	layer = 150
	visible = false
	_build_panel()

func _build_panel() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.02, 0.03, 0.88)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var panel := PanelContainer.new()
	# Keep the reference map inside small portrait and landscape viewports;
	# the old fixed 800x600 minimum clipped the panel on phones.
	panel.custom_minimum_size = Vector2(
		minf(800.0, maxf(280.0, viewport_size.x - 24.0)),
		minf(600.0, maxf(280.0, viewport_size.y - 24.0))
	)
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
	close_button.pressed.connect(func(): hide())
	header.add_child(close_button)

	var subtitle := Label.new()
	subtitle.text = "MAIN CAMPAIGN  •  REGIONAL OVERVIEW  •  16 × 16 HEXES"
	subtitle.add_theme_color_override("font_color", Color(0.78, 0.76, 0.68))
	layout.add_child(subtitle)

	map_view = WorldMapView.new()
	map_view.custom_minimum_size = Vector2(0.0, minf(440.0, maxf(120.0, viewport_size.y * 0.34)))
	map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(map_view)

	var locations := Label.new()
	locations.text = MAP_DATA.strategic_location_legend()
	locations.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	locations.add_theme_font_size_override("font_size", 11)
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
	if not visible or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
		hide()
		get_viewport().set_input_as_handled()

class WorldMapView extends Control:
	const DATA = preload("res://scripts/world/main_campaign_world_map_data.gd")
	const MAX_HEX_RADIUS: float = 14.0

	func _draw() -> void:
		var grid := DATA.generate_grid()
		var dimensions := DATA.strategic_grid_size()
		var river_path := DATA.strategic_river_path()
		var locations := DATA.strategic_locations()
		var horizontal_units := float(maxi(dimensions.x - 1, 1)) * 1.5 + 2.0
		var vertical_units := float(maxi(dimensions.y - 1, 1)) * sqrt(3.0) + sqrt(3.0)
		var available_width := maxf(1.0, size.x - 16.0)
		var available_height := maxf(1.0, size.y - 16.0)
		var hex_radius := maxf(2.0, minf(
			MAX_HEX_RADIUS,
			minf(available_width / horizontal_units, available_height / vertical_units)
		))
		var x_step := hex_radius * 1.5
		var y_step := sqrt(3.0) * hex_radius
		var map_width := float(dimensions.x - 1) * x_step + hex_radius * 2.0
		var map_height := float(dimensions.y - 1) * y_step + y_step
		var origin := Vector2((size.x - map_width) * 0.5 + hex_radius, (size.y - map_height) * 0.5 + hex_radius)
		var outline_width := maxf(0.5, hex_radius * 0.1)
		var marker_radius := maxf(1.5, hex_radius * 0.43)
		var marker_core_radius := maxf(1.0, hex_radius * 0.23)
		var marker_font_size := clampi(roundi(hex_radius * 0.64), 6, 9)

		for column in range(dimensions.x):
			for row in range(dimensions.y):
				var centre := _cell_centre(column, row, origin, x_step, y_step)
				var points := _hex_points(centre, hex_radius)
				var cell: Dictionary = grid[row][column]
				draw_colored_polygon(points, _terrain_colour(String(cell["terrain"])))
				var outline: PackedVector2Array = points.duplicate()
				outline.append(points[0])
				draw_polyline(outline, _faction_colour(String(cell["faction"])), outline_width, true)

		var river_points := PackedVector2Array()
		for cell in river_path:
			river_points.append(_cell_centre(cell.x, cell.y, origin, x_step, y_step))
		draw_polyline(river_points, Color("#62c7e8"), maxf(1.0, hex_radius * 0.22), true)

		for location in locations:
			var cell: Vector2i = location["cell"]
			var centre := _cell_centre(cell.x, cell.y, origin, x_step, y_step)
			draw_circle(centre, marker_radius, Color("#f4d17a"))
			draw_circle(centre, marker_core_radius, Color("#30291b"))
			draw_string(
				ThemeDB.fallback_font,
				centre + Vector2(-hex_radius * 0.22, hex_radius * 0.25),
				String(location["short"]),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				marker_font_size,
				Color("#fff4d4")
			)

	func _cell_centre(column: int, row: int, origin: Vector2, x_step: float, y_step: float) -> Vector2:
		return origin + Vector2(float(column) * x_step, float(row) * y_step + (column % 2) * y_step * 0.5)

	func _hex_points(centre: Vector2, hex_radius: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		for index in range(6):
			var angle := deg_to_rad(-30.0 + float(index) * 60.0)
			points.append(centre + Vector2(cos(angle), sin(angle)) * hex_radius)
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
