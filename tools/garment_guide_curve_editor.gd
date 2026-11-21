extends Control
## Surface-attached garment guide authoring tool for current native Wren and Aldric builds.
## Click the body to add points; each point is saved as a triangle+barycentric attachment.

const INPUT_ROUTER_SCRIPT = preload("res://tools/anatomy_surface_painter_input.gd")
const BODY_OPTIONS := {
    "Wren (current native build)": "res://build/wren-native/Wren.glb",
    "Aldric (current native build)": "res://build/aldric-native/Aldric.glb"
}
const GUIDE_LABELS := {
    "neckline": "Neckline circumference",
    "collar": "Collar circumference",
    "shoulder_seam_left": "Shoulder seam — left",
    "shoulder_seam_right": "Shoulder seam — right",
    "armhole_left": "Armhole — left",
    "armhole_right": "Armhole — right",
    "chest_line": "Chest / bust line",
    "cup_apex_left": "Cup apex — left",
    "cup_apex_right": "Cup apex — right",
    "underbust": "Underbust circumference",
    "waist_natural": "Natural waist",
    "hip_high": "High hip",
    "hip_full": "Full hip",
    "seat": "Seat line",
    "crotch_front": "Crotch junction — front",
    "crotch_back": "Crotch junction — back",
    "inseam_left": "Inseam — left",
    "inseam_right": "Inseam — right",
    "outseam_left": "Outseam — left",
    "outseam_right": "Outseam — right",
    "elbow_opening_left": "Elbow opening — left",
    "elbow_opening_right": "Elbow opening — right",
    "wrist_opening_left": "Wrist opening — left",
    "wrist_opening_right": "Wrist opening — right",
    "knee_opening_left": "Knee opening — left",
    "knee_opening_right": "Knee opening — right",
    "ankle_opening_left": "Ankle opening — left",
    "ankle_opening_right": "Ankle opening — right",
    "foot_opening_left": "Foot opening — left",
    "foot_opening_right": "Foot opening — right",
    "heel_alignment": "Heel alignment",
    "toe_alignment": "Toe alignment",
    "cup_perimeter_left": "Bra cup perimeter — left (closed)",
    "cup_perimeter_right": "Bra cup perimeter — right (closed)",
    "centre_gore": "Bra centre gore boundary (closed)",
    "underband_front": "Bra underband — front edge",
    "underband_back": "Bra underband — back edge",
    "strap_left": "Bra strap — left",
    "strap_right": "Bra strap — right"
}
## Bra panel outlines are closed loops; underband edges and straps are open paths.
## Locking these requirements in the editor prevents an accidentally open cup or closed strap.
const GUIDE_LOOP_REQUIREMENTS := {
    "cup_perimeter_left": true,
    "cup_perimeter_right": true,
    "centre_gore": true,
    "underband_front": false,
    "underband_back": false,
    "strap_left": false,
    "strap_right": false
}
const GUIDE_PAIRS := {
    "shoulder_seam_left": "shoulder_seam_right", "shoulder_seam_right": "shoulder_seam_left",
    "armhole_left": "armhole_right", "armhole_right": "armhole_left",
    "cup_apex_left": "cup_apex_right", "cup_apex_right": "cup_apex_left",
    "inseam_left": "inseam_right", "inseam_right": "inseam_left",
    "outseam_left": "outseam_right", "outseam_right": "outseam_left",
    "elbow_opening_left": "elbow_opening_right", "elbow_opening_right": "elbow_opening_left",
    "wrist_opening_left": "wrist_opening_right", "wrist_opening_right": "wrist_opening_left",
    "knee_opening_left": "knee_opening_right", "knee_opening_right": "knee_opening_left",
    "ankle_opening_left": "ankle_opening_right", "ankle_opening_right": "ankle_opening_left",
    "foot_opening_left": "foot_opening_right", "foot_opening_right": "foot_opening_left",
    "cup_perimeter_left": "cup_perimeter_right", "cup_perimeter_right": "cup_perimeter_left",
    "strap_left": "strap_right", "strap_right": "strap_left"
}
const GUIDE_DIRECTORY := "res://data/characters/garment_guides"
const GUIDE_MANIFEST_PATH := GUIDE_DIRECTORY + "/manifest.tres"

var _viewport: SubViewport
var _world_root: Node3D
var _camera: Camera3D
var _body_root: Node3D
var _descriptors: Array[Dictionary] = []
var _selected_descriptor := -1
var _guide_points: Array[Dictionary] = []
var _surface_regions: CharacterSurfaceRegions
var _preview_guide: CharacterGarmentGuideCurve
var _line_instance: MeshInstance3D
var _line_mesh: ImmediateMesh
var _marker_cloud: MultiMeshInstance3D
var _body_option: OptionButton
var _surface_option: OptionButton
var _guide_option: OptionButton
var _closed_check: CheckButton
var _save_path_edit: LineEdit
var _status: Label
var _orbiting := false
var _touch_positions: Dictionary = {}
var _touch_start_position := Vector2.ZERO
var _touch_dragged := false
var _pinch_distance := 0.0
var _camera_yaw := PI
var _camera_pitch := 0.12
var _camera_distance := 2.2
var _camera_target := Vector3(0.0, 0.85, 0.0)


func _ready() -> void:
    _build_interface()
    _load_body("Wren (current native build)")


func _build_interface() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var viewport_container := SubViewportContainer.new()
    viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    viewport_container.stretch = true
    add_child(viewport_container)

    _viewport = SubViewport.new()
    _viewport.size = Vector2i(1280, 900)
    _viewport.own_world_3d = true
    _viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport_container.add_child(_viewport)
    _world_root = Node3D.new()
    _viewport.add_child(_world_root)
    var router := Node3D.new()
    router.set_script(INPUT_ROUTER_SCRIPT)
    router.connect("input_event_received", _on_viewport_input)
    _world_root.add_child(router)

    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.075, 0.09, 0.11)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.68, 0.7, 0.74)
    env.ambient_light_energy = 0.85
    environment.environment = env
    _world_root.add_child(environment)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-28.0, -32.0, 0.0)
    light.light_energy = 1.5
    _world_root.add_child(light)

    _camera = Camera3D.new()
    _camera.current = true
    _world_root.add_child(_camera)
    _update_camera()

    _line_mesh = ImmediateMesh.new()
    _line_instance = MeshInstance3D.new()
    _line_instance.mesh = _line_mesh
    var line_material := StandardMaterial3D.new()
    line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    line_material.albedo_color = Color(1.0, 0.72, 0.12)
    line_material.no_depth_test = true
    _line_instance.material_override = line_material
    _world_root.add_child(_line_instance)

    _marker_cloud = MultiMeshInstance3D.new()
    var marker := SphereMesh.new()
    marker.radius = 0.009
    marker.height = 0.018
    marker.radial_segments = 8
    marker.rings = 4
    var marker_material := StandardMaterial3D.new()
    marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    marker_material.albedo_color = Color(0.2, 0.85, 1.0)
    marker_material.no_depth_test = true
    marker.material = marker_material
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = marker
    _marker_cloud.multimesh = multi
    _world_root.add_child(_marker_cloud)

    var panel := PanelContainer.new()
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.anchor_top = 0.0
    panel.anchor_bottom = 1.0
    panel.offset_left = -360.0
    panel.offset_right = 0.0
    add_child(panel)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(scroll)
    var column := VBoxContainer.new()
    column.custom_minimum_size.x = 336.0
    column.add_theme_constant_override("separation", 8)
    scroll.add_child(column)

    var heading := Label.new()
    heading.text = "Wren / Aldric garment guide editor"
    heading.add_theme_font_size_override("font_size", 18)
    column.add_child(heading)
    _caption(column, "Click or tap the body to place guide points. Right-drag / one-finger drag orbits; wheel / pinch zooms.")
    _caption(column, "Body")
    _body_option = OptionButton.new()
    for body_name in BODY_OPTIONS:
        _body_option.add_item(body_name)
    _body_option.select(0)
    _body_option.item_selected.connect(func(index: int): _load_body(_body_option.get_item_text(index)))
    column.add_child(_body_option)

    _caption(column, "Mesh surface")
    _surface_option = OptionButton.new()
    _surface_option.item_selected.connect(_on_surface_selected)
    column.add_child(_surface_option)

    _caption(column, "Guide")
    _guide_option = OptionButton.new()
    for guide_id in GUIDE_LABELS:
        _guide_option.add_item(GUIDE_LABELS[guide_id])
        _guide_option.set_item_metadata(_guide_option.get_item_count() - 1, guide_id)
    _guide_option.select(0)
    _guide_option.item_selected.connect(_on_guide_selected)
    column.add_child(_guide_option)

    _closed_check = CheckButton.new()
    _closed_check.text = "Closed loop (neckline, waist, etc.)"
    column.add_child(_closed_check)

    var undo_button := Button.new()
    undo_button.text = "Undo last point"
    undo_button.pressed.connect(_undo_point)
    column.add_child(undo_button)
    var clear_button := Button.new()
    clear_button.text = "Clear current guide"
    clear_button.pressed.connect(_clear_points)
    column.add_child(clear_button)

    _caption(column, "Save resource path")
    _save_path_edit = LineEdit.new()
    column.add_child(_save_path_edit)
    var save_button := Button.new()
    save_button.text = "Save validated guide"
    save_button.pressed.connect(_save_guide)
    column.add_child(save_button)

    _status = Label.new()
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status.text = "Loading native companion…"
    column.add_child(_status)
    _caption(column, "Trace a complete circumference or seam by clicking sequentially around the body. Each point stores its source triangle and barycentric position, so it follows skinning and supported body morphs. Review the line from several angles before saving. Wren and Aldric guides are authored separately.")


func _caption(parent: VBoxContainer, value: String) -> void:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.83))
    parent.add_child(label)


func _load_body(body_name: String) -> void:
    if is_instance_valid(_body_root):
        _body_root.queue_free()
    for child in _world_root.get_children():
        if child is StaticBody3D:
            child.queue_free()
    _body_root = null
    _descriptors.clear()
    _guide_points.clear()
    _selected_descriptor = -1
    _refresh_guide_display()
    var asset_path := String(BODY_OPTIONS.get(body_name, ""))
    var packed := load(asset_path) as PackedScene
    if packed == null:
        _set_status("Could not load body: " + asset_path)
        return
    _body_root = packed.instantiate() as Node3D
    if _body_root == null:
        _set_status("Native companion scene root is not Node3D")
        return
    _world_root.add_child(_body_root)
    _collect_surfaces(_body_root)
    _surface_regions = CharacterSurfaceRegions.new()
    var masks: Array[Resource] = CharacterSurfaceRegionMaskLibrary.load_for_body(asset_path)
    if not _surface_regions.configure(_body_root, _body_root, masks, asset_path):
        _set_status("Guide preview unavailable: " + _surface_regions.get_configuration_error())
        _surface_regions = null
    _surface_option.clear()
    for descriptor in _descriptors:
        var mesh: MeshInstance3D = descriptor["mesh"]
        _surface_option.add_item("%s / surface %d (%d vertices)" % [
            str(_body_root.get_path_to(mesh)), int(descriptor["surface_index"]), descriptor["vertices"].size()
        ])
    if _descriptors.is_empty():
        _set_status("No skinned triangle surfaces found")
        return
    _selected_descriptor = 0
    _surface_option.select(0)
    _set_default_save_path()
    _frame_body()
    _set_status("Loaded %s. Select a guide and click the body to add points." % body_name)


func _collect_surfaces(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh is ArrayMesh and mesh_instance.skin != null:
            var array_mesh := mesh_instance.mesh as ArrayMesh
            for surface_index in range(array_mesh.get_surface_count()):
                var arrays := array_mesh.surface_get_arrays(surface_index)
                var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
                var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
                if vertices.is_empty():
                    continue
                var triangle_ids := PackedInt32Array()
                if indices.is_empty():
                    for index in range(0, vertices.size() - 2, 3):
                        triangle_ids.append(index)
                        triangle_ids.append(index + 1)
                        triangle_ids.append(index + 2)
                else:
                    triangle_ids = indices
                if triangle_ids.size() < 3:
                    continue
                var faces := PackedVector3Array()
                for vertex_index in triangle_ids:
                    if vertex_index >= 0 and vertex_index < vertices.size():
                        faces.append(vertices[vertex_index])
                if faces.size() < 3 or faces.size() % 3 != 0:
                    continue
                var descriptor_index := _descriptors.size()
                _descriptors.append({
                    "mesh": mesh_instance,
                    "surface_index": surface_index,
                    "vertices": vertices,
                    "triangle_ids": triangle_ids
                })
                var shape := ConcavePolygonShape3D.new()
                shape.backface_collision = true
                shape.set_faces(faces)
                var body := StaticBody3D.new()
                body.name = "GuidePickSurface_%d" % descriptor_index
                body.set_meta("descriptor_index", descriptor_index)
                body.collision_layer = 1
                body.collision_mask = 1
                var collision := CollisionShape3D.new()
                collision.shape = shape
                body.add_child(collision)
                _world_root.add_child(body)
                body.global_transform = mesh_instance.global_transform
    for child in node.get_children():
        _collect_surfaces(child)


func _on_surface_selected(index: int) -> void:
    if index < 0 or index >= _descriptors.size():
        return
    _selected_descriptor = index
    _guide_points.clear()
    _set_default_save_path()
    _refresh_guide_display()
    _set_status("Surface changed. Start a new guide on this surface.")


func _on_guide_selected(_index: int) -> void:
    _guide_points.clear()
    var guide_id := _selected_guide_id()
    if GUIDE_LOOP_REQUIREMENTS.has(guide_id):
        _closed_check.button_pressed = bool(GUIDE_LOOP_REQUIREMENTS[guide_id])
        _closed_check.disabled = true
        _closed_check.text = "Closed loop required" if _closed_check.button_pressed else "Open path required"
    else:
        _closed_check.disabled = false
        _closed_check.text = "Closed loop (neckline, waist, etc.)"
    _set_default_save_path()
    _refresh_guide_display()
    _set_status("Guide type changed. Start tracing its points.")


func _on_viewport_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.button_index == MOUSE_BUTTON_RIGHT:
            _orbiting = mouse.pressed
            _viewport.set_input_as_handled()
        elif mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
            _add_guide_point(mouse.position)
            _viewport.set_input_as_handled()
        elif mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
            _camera_distance = maxf(0.7, _camera_distance * 0.9)
            _update_camera()
            _viewport.set_input_as_handled()
        elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
            _camera_distance = minf(5.0, _camera_distance * 1.1)
            _update_camera()
            _viewport.set_input_as_handled()
    elif event is InputEventMouseMotion and _orbiting:
        var motion := event as InputEventMouseMotion
        _orbit_camera(motion.relative)
        _viewport.set_input_as_handled()
    elif event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            _touch_positions[touch.index] = touch.position
            if _touch_positions.size() == 1:
                _touch_start_position = touch.position
                _touch_dragged = false
            elif _touch_positions.size() == 2:
                _touch_dragged = true
                var values: Array = _touch_positions.values()
                var first_position: Vector2 = values[0]
                var second_position: Vector2 = values[1]
                _pinch_distance = first_position.distance_to(second_position)
        else:
            if _touch_positions.has(touch.index):
                if _touch_positions.size() == 1 and not _touch_dragged:
                    _add_guide_point(touch.position)
                _touch_positions.erase(touch.index)
                if _touch_positions.size() < 2:
                    _pinch_distance = 0.0
        _viewport.set_input_as_handled()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if _touch_positions.size() >= 2:
            _touch_positions[drag.index] = drag.position
            var values: Array = _touch_positions.values()
            var first_position: Vector2 = values[0]
            var second_position: Vector2 = values[1]
            var distance: float = first_position.distance_to(second_position)
            if _pinch_distance > 1.0 and distance > 1.0:
                _camera_distance = clampf(_camera_distance * _pinch_distance / distance, 0.7, 5.0)
                _update_camera()
            _pinch_distance = distance
        elif _touch_positions.size() == 1:
            _touch_positions[drag.index] = drag.position
            if drag.position.distance_to(_touch_start_position) > 8.0:
                _touch_dragged = true
            if _touch_dragged:
                _orbit_camera(drag.relative)
        _viewport.set_input_as_handled()


func _orbit_camera(relative: Vector2) -> void:
    _camera_yaw -= relative.x * 0.008
    _camera_pitch = clampf(_camera_pitch + relative.y * 0.008, -1.1, 1.1)
    _update_camera()


func _add_guide_point(screen_position: Vector2) -> void:
    if _selected_descriptor < 0 or _selected_descriptor >= _descriptors.size():
        return
    var ray_origin := _camera.project_ray_origin(screen_position)
    var ray_direction := _camera.project_ray_normal(screen_position)
    var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 10.0)
    query.collision_mask = 1
    var hit := _viewport.world_3d.direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return
    var collider := hit["collider"] as Node
    if not collider.has_meta("descriptor_index"):
        return
    var descriptor_index := int(collider.get_meta("descriptor_index"))
    if descriptor_index != _selected_descriptor:
        _set_status("That hit belongs to another mesh surface. Select it first.")
        return
    var face_index := int(hit.get("face_index", -1))
    var descriptor: Dictionary = _descriptors[descriptor_index]
    var triangle_ids: PackedInt32Array = descriptor["triangle_ids"]
    var offset := face_index * 3
    if face_index < 0 or offset + 2 >= triangle_ids.size():
        _set_status("Could not map the hit face to source triangle vertices.")
        return
    var triangle := PackedInt32Array([
        triangle_ids[offset], triangle_ids[offset + 1], triangle_ids[offset + 2]
    ])
    var mesh: MeshInstance3D = descriptor["mesh"]
    var vertices: PackedVector3Array = descriptor["vertices"]
    var local_hit: Vector3 = mesh.global_transform.affine_inverse() * hit["position"]
    var barycentric := _barycentric(local_hit, vertices[triangle[0]], vertices[triangle[1]], vertices[triangle[2]])
    if barycentric.is_empty():
        _set_status("Could not calculate a stable triangle attachment.")
        return
    _guide_points.append({
        "triangle_indices": triangle,
        "barycentric": barycentric
    })
    _refresh_guide_display()
    _set_status("Added point %d to %s." % [_guide_points.size(), _selected_guide_id()])


func _barycentric(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> PackedFloat32Array:
    var edge_0 := b - a
    var edge_1 := c - a
    var relative := point - a
    var d00 := edge_0.dot(edge_0)
    var d01 := edge_0.dot(edge_1)
    var d11 := edge_1.dot(edge_1)
    var d20 := relative.dot(edge_0)
    var d21 := relative.dot(edge_1)
    var denominator := d00 * d11 - d01 * d01
    if absf(denominator) < 0.0000001:
        return PackedFloat32Array()
    var weight_b := (d11 * d20 - d01 * d21) / denominator
    var weight_c := (d00 * d21 - d01 * d20) / denominator
    var weight_a := 1.0 - weight_b - weight_c
    if weight_a < -0.02 or weight_b < -0.02 or weight_c < -0.02:
        return PackedFloat32Array()
    var result := PackedFloat32Array([
        clampf(weight_a, 0.0, 1.0),
        clampf(weight_b, 0.0, 1.0),
        clampf(weight_c, 0.0, 1.0)
    ])
    var total := result[0] + result[1] + result[2]
    if total <= 0.000001:
        return PackedFloat32Array()
    for index in range(3):
        result[index] /= total
    return result


func _refresh_guide_display() -> void:
    _line_mesh.clear_surfaces()
    var positions: Array[Vector3] = []
    if _selected_descriptor >= 0 and _selected_descriptor < _descriptors.size():
        var descriptor: Dictionary = _descriptors[_selected_descriptor]
        var mesh: MeshInstance3D = descriptor["mesh"]
        if _guide_points.size() >= 2 and _surface_regions != null:
            if _preview_guide == null:
                _preview_guide = CharacterGarmentGuideCurve.new()
            var guide := _preview_guide
            guide.body_asset_path = String(BODY_OPTIONS.get(_body_option.get_item_text(_body_option.selected), ""))
            guide.mesh_node_path = _body_root.get_path_to(mesh)
            guide.surface_index = int(descriptor["surface_index"])
            guide.surface_name = mesh.mesh.surface_get_name(guide.surface_index)
            guide.vertex_count = (descriptor["vertices"] as PackedVector3Array).size()
            guide.surface_signature = CharacterSurfaceRegionMask.build_surface_signature(mesh.mesh, guide.surface_index)
            guide.guide_id = _selected_guide_id()
            guide.closed_loop = _closed_check.button_pressed
            guide.points = _guide_points.duplicate(true)
            var dense_path := guide.evaluate_surface_path(_surface_regions)
            if dense_path.is_empty():
                _set_status("Surface guide route could not be evaluated: " + guide.last_evaluation_error)
            else:
                for sample in dense_path:
                    positions.append(_body_root.global_transform * sample["position"])
    var multi := _marker_cloud.multimesh
    multi.instance_count = _guide_points.size()
    if _selected_descriptor >= 0 and _selected_descriptor < _descriptors.size():
        var descriptor: Dictionary = _descriptors[_selected_descriptor]
        var mesh: MeshInstance3D = descriptor["mesh"]
        var vertices: PackedVector3Array = descriptor["vertices"]
        for index in range(_guide_points.size()):
            var point: Dictionary = _guide_points[index]
            var triangle: PackedInt32Array = point["triangle_indices"]
            var barycentric: PackedFloat32Array = point["barycentric"]
            var local_position := Vector3.ZERO
            for corner in range(3):
                local_position += vertices[triangle[corner]] * barycentric[corner]
            multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, mesh.global_transform * local_position))
    if positions.size() >= 2:
        _line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _line_instance.material_override)
        for position in positions:
            _line_mesh.surface_add_vertex(position)
        _line_mesh.surface_end()


func _undo_point() -> void:
    if not _guide_points.is_empty():
        _guide_points.pop_back()
        _refresh_guide_display()
        _set_status("Removed last point. %d points remain." % _guide_points.size())


func _clear_points() -> void:
    _guide_points.clear()
    _refresh_guide_display()
    _set_status("Cleared current guide points.")


func _save_guide() -> void:
    if _selected_descriptor < 0 or _selected_descriptor >= _descriptors.size():
        _set_status("Select a mesh surface before saving.")
        return
    var descriptor: Dictionary = _descriptors[_selected_descriptor]
    var mesh: MeshInstance3D = descriptor["mesh"]
    var guide := CharacterGarmentGuideCurve.new()
    guide.body_asset_path = String(BODY_OPTIONS.get(_body_option.get_item_text(_body_option.selected), ""))
    guide.mesh_node_path = _body_root.get_path_to(mesh)
    guide.surface_index = int(descriptor["surface_index"])
    guide.surface_name = mesh.mesh.surface_get_name(guide.surface_index)
    guide.vertex_count = descriptor["vertices"].size()
    guide.surface_signature = CharacterSurfaceRegionMask.build_surface_signature(mesh.mesh, guide.surface_index)
    guide.guide_id = _selected_guide_id()
    guide.paired_guide_id = String(GUIDE_PAIRS.get(guide.guide_id, ""))
    if GUIDE_LOOP_REQUIREMENTS.has(guide.guide_id):
        var required_closed := bool(GUIDE_LOOP_REQUIREMENTS[guide.guide_id])
        if _closed_check.button_pressed != required_closed:
            _set_status("Guide rejected: %s must be %s." % [guide.guide_id, "a closed loop" if required_closed else "an open path"])
            return
    guide.closed_loop = _closed_check.button_pressed
    guide.points = _guide_points.duplicate(true)
    var validation := guide.validate_for_mesh(mesh, _body_root, guide.body_asset_path)
    if not validation.is_empty():
        _set_status("Guide rejected: " + validation)
        return
    var path := _save_path_edit.text.strip_edges()
    if not path.begins_with("res://") or not path.ends_with(".tres"):
        _set_status("Save path must be a project res:// .tres path.")
        return
    var error := ResourceSaver.save(guide, path)
    if error != OK:
        _set_status("Could not save guide resource. Error code: %d" % error)
        return
    var manifest := load(GUIDE_MANIFEST_PATH) as CharacterGarmentGuideManifest
    if manifest == null:
        _set_status("Could not load garment guide manifest.")
        return
    var updated: Array[Resource] = []
    for existing in manifest.guides:
        if existing == null or existing.resource_path != path:
            updated.append(existing)
    updated.append(load(path))
    manifest.guides = updated
    error = ResourceSaver.save(manifest, GUIDE_MANIFEST_PATH)
    if error != OK:
        _set_status("Guide saved, but manifest update failed. Error code: %d" % error)
        return
    _set_status("Saved and registered %s (%d points)." % [path, _guide_points.size()])


func _selected_guide_id() -> String:
    var value: Variant = _guide_option.get_item_metadata(_guide_option.selected)
    return String(value) if value != null else ""


func _set_default_save_path() -> void:
    if _selected_descriptor < 0 or _selected_descriptor >= _descriptors.size():
        return
    var descriptor: Dictionary = _descriptors[_selected_descriptor]
    var mesh: MeshInstance3D = descriptor["mesh"]
    var prefix := "wren" if _body_option.get_item_text(_body_option.selected).begins_with("Wren") else "aldric"
    _save_path_edit.text = "%s/%s_%s_surface_%d_%s.tres" % [
        GUIDE_DIRECTORY, prefix, String(mesh.name).to_snake_case(),
        int(descriptor["surface_index"]), _selected_guide_id()
    ]


func _frame_body() -> void:
    var points: Array[Vector3] = []
    for descriptor in _descriptors:
        var mesh: MeshInstance3D = descriptor["mesh"]
        for vertex in descriptor["vertices"]:
            points.append(mesh.global_transform * vertex)
    if points.is_empty():
        return
    var bounds := AABB(points[0], Vector3.ZERO)
    for point in points:
        bounds = bounds.expand(point)
    _camera_target = bounds.get_center()
    _camera_distance = maxf(1.0, bounds.size.length() * 0.9)
    _update_camera()


func _update_camera() -> void:
    if _camera == null:
        return
    var direction := Vector3(
        sin(_camera_yaw) * cos(_camera_pitch),
        sin(_camera_pitch),
        cos(_camera_yaw) * cos(_camera_pitch)
    )
    _camera.global_position = _camera_target + direction * _camera_distance
    _camera.look_at(_camera_target, Vector3.UP)


func _set_status(value: String) -> void:
    if _status != null:
        _status.text = value
