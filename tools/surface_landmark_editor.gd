extends Control
## Author semantic points directly on the canonical deformed Ara skin surface.
## Each saved point is a topology-validated triangle+barycentric attachment.

const INPUT_ROUTER_SCRIPT = preload("res://tools/anatomy_surface_painter_input.gd")
const BODY_OPTIONS := {
    "Wren (current native build)": "res://build/wren-native/Wren.glb",
    "Aldric (current native build)": "res://build/aldric-native/Aldric.glb"
}
const LANDMARK_LABELS := {
    "upper_lip": "Upper lip contact",
    "lower_lip": "Lower lip contact",
    "mouth_centre": "Mouth centre",
    "sternum": "Sternum",
    "clavicle_left": "Clavicle — left",
    "clavicle_right": "Clavicle — right",
    "breast_apex_left": "Breast apex — left",
    "breast_apex_right": "Breast apex — right",
    "nipple_left": "Nipple — left",
    "nipple_right": "Nipple — right",
    "underbust_left": "Underbust — left",
    "underbust_right": "Underbust — right",
    "waist_front": "Waist — front",
    "waist_left": "Waist — left",
    "waist_right": "Waist — right",
    "iliac_crest_left": "Iliac crest — left",
    "iliac_crest_right": "Iliac crest — right",
    "hip_front_left": "Hip front — left",
    "hip_front_right": "Hip front — right",
    "hip_side_left": "Hip side — left",
    "hip_side_right": "Hip side — right",
    "hip_back_left": "Hip back — left",
    "hip_back_right": "Hip back — right",
    "sacrum": "Sacrum",
    "pubic_symphysis": "Pubic symphysis",
    "crotch_front": "Crotch — front",
    "crotch_back": "Crotch — back",
    "palm_left": "Palm — left",
    "palm_right": "Palm — right",
    "fingertip_index_left": "Index fingertip — left",
    "fingertip_index_right": "Index fingertip — right",
    "fingertip_middle_left": "Middle fingertip — left",
    "fingertip_middle_right": "Middle fingertip — right",
    "heel_left": "Heel — left",
    "heel_right": "Heel — right",
    "toe_left": "Toe — left",
    "toe_right": "Toe — right"
}
const LANDMARK_DIRECTORY := "res://data/characters/surface_landmarks"
const MANIFEST_PATH := LANDMARK_DIRECTORY + "/manifest.tres"

var _viewport: SubViewport
var _world_root: Node3D
var _camera: Camera3D
var _body_root: Node3D
var _descriptors: Array[Dictionary] = []
var _selected_descriptor := -1
var _selected_point: Dictionary = {}
var _body_option: OptionButton
var _surface_option: OptionButton
var _landmark_option: OptionButton
var _save_path: LineEdit
var _status: Label
var _marker: MeshInstance3D
var _normal_mesh: ImmediateMesh
var _normal_instance: MeshInstance3D
var _touch_positions: Dictionary = {}
var _touch_start := Vector2.ZERO
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

    _marker = MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radius = 0.012
    sphere.height = 0.024
    var marker_material := StandardMaterial3D.new()
    marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    marker_material.albedo_color = Color(0.15, 0.9, 1.0)
    marker_material.no_depth_test = true
    sphere.material = marker_material
    _marker.mesh = sphere
    _marker.visible = false
    _world_root.add_child(_marker)
    _normal_mesh = ImmediateMesh.new()
    _normal_instance = MeshInstance3D.new()
    _normal_instance.mesh = _normal_mesh
    var normal_material := StandardMaterial3D.new()
    normal_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    normal_material.albedo_color = Color(1.0, 0.72, 0.12)
    normal_material.no_depth_test = true
    _normal_instance.material_override = normal_material
    _world_root.add_child(_normal_instance)

    var panel := PanelContainer.new()
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.anchor_bottom = 1.0
    panel.offset_left = -360.0
    add_child(panel)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(scroll)
    var column := VBoxContainer.new()
    column.custom_minimum_size.x = 336.0
    column.add_theme_constant_override("separation", 8)
    scroll.add_child(column)
    var heading := Label.new()
    heading.text = "Wren / Aldric surface landmark editor"
    heading.add_theme_font_size_override("font_size", 18)
    column.add_child(heading)
    _caption(column, "Tap/click the body to place one precise anatomical point. Drag with one finger or right mouse to orbit; pinch or wheel to zoom. The yellow line shows the surface normal.")
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
    _caption(column, "Anatomical landmark")
    _landmark_option = OptionButton.new()
    for landmark_id in LANDMARK_LABELS:
        _landmark_option.add_item(LANDMARK_LABELS[landmark_id])
        _landmark_option.set_item_metadata(_landmark_option.get_item_count() - 1, landmark_id)
    _landmark_option.select(0)
    _landmark_option.item_selected.connect(_on_landmark_selected)
    column.add_child(_landmark_option)
    var clear := Button.new()
    clear.text = "Clear selected point"
    clear.pressed.connect(_clear_point)
    column.add_child(clear)
    _caption(column, "Save resource path")
    _save_path = LineEdit.new()
    column.add_child(_save_path)
    var save := Button.new()
    save.text = "Save and register landmark"
    save.pressed.connect(_save_landmark)
    column.add_child(save)
    _status = Label.new()
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status.text = "Loading native companion…"
    column.add_child(_status)
    _caption(column, "Wren and Aldric landmarks are authored separately. A semantic ID is shared vocabulary, not a claim that both bodies have identical geometry. Only save after checking the point from front, side and rear views.")


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
    _selected_point.clear()
    _marker.visible = false
    _normal_mesh.clear_surfaces()
    var packed := load(String(BODY_OPTIONS.get(body_name, ""))) as PackedScene
    if packed == null:
        _set_status("Could not load selected native companion body.")
        return
    _body_root = packed.instantiate() as Node3D
    if _body_root == null:
        _set_status("Ara body scene root is not Node3D.")
        return
    _world_root.add_child(_body_root)
    _collect_surfaces(_body_root)
    _surface_option.clear()
    for descriptor in _descriptors:
        var mesh: MeshInstance3D = descriptor["mesh"]
        _surface_option.add_item("%s / surface %d (%d vertices)" % [
            str(_body_root.get_path_to(mesh)), int(descriptor["surface_index"]), descriptor["vertices"].size()
        ])
    if _descriptors.is_empty():
        _set_status("No skinned triangle surfaces found.")
        return
    _selected_descriptor = 0
    _surface_option.select(0)
    _set_default_path()
    _frame_body()
    _set_status("Loaded %s. Choose a semantic landmark and place it on the skin." % body_name)


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
                        triangle_ids.append_array(PackedInt32Array([index, index + 1, index + 2]))
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
                body.name = "LandmarkPickSurface_%d" % descriptor_index
                body.set_meta("descriptor_index", descriptor_index)
                var collision := CollisionShape3D.new()
                collision.shape = shape
                body.add_child(collision)
                _world_root.add_child(body)
                body.global_transform = mesh_instance.global_transform
    for child in node.get_children():
        _collect_surfaces(child)


func _on_surface_selected(index: int) -> void:
    _selected_descriptor = index
    _clear_point()
    _set_default_path()
    _set_status("Surface changed. Place a new landmark point.")


func _on_landmark_selected(_index: int) -> void:
    _clear_point()
    _set_default_path()
    _set_status("Landmark changed. Place its point on the skin.")


func _on_viewport_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.button_index == MOUSE_BUTTON_RIGHT:
            _touch_dragged = mouse.pressed
        elif mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
            _place_point(mouse.position)
        elif mouse.button_index == MOUSE_BUTTON_WHEEL_UP and mouse.pressed:
            _camera_distance = maxf(0.7, _camera_distance * 0.9)
            _update_camera()
        elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse.pressed:
            _camera_distance = minf(5.0, _camera_distance * 1.1)
            _update_camera()
    elif event is InputEventMouseMotion and _touch_dragged:
        _orbit_camera((event as InputEventMouseMotion).relative)
    elif event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            _touch_positions[touch.index] = touch.position
            if _touch_positions.size() == 1:
                _touch_start = touch.position
                _touch_dragged = false
            elif _touch_positions.size() == 2:
                _touch_dragged = true
                var values: Array = _touch_positions.values()
                _pinch_distance = (values[0] as Vector2).distance_to(values[1])
        else:
            if _touch_positions.has(touch.index):
                if _touch_positions.size() == 1 and not _touch_dragged:
                    _place_point(touch.position)
                _touch_positions.erase(touch.index)
                if _touch_positions.size() < 2:
                    _pinch_distance = 0.0
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if _touch_positions.size() >= 2:
            _touch_positions[drag.index] = drag.position
            var values: Array = _touch_positions.values()
            var distance: float = (values[0] as Vector2).distance_to(values[1])
            if _pinch_distance > 1.0 and distance > 1.0:
                _camera_distance = clampf(_camera_distance * _pinch_distance / distance, 0.7, 5.0)
                _update_camera()
            _pinch_distance = distance
        elif _touch_positions.size() == 1:
            _touch_positions[drag.index] = drag.position
            if drag.position.distance_to(_touch_start) > 8.0:
                _touch_dragged = true
            if _touch_dragged:
                _orbit_camera(drag.relative)


func _orbit_camera(relative: Vector2) -> void:
    _camera_yaw -= relative.x * 0.008
    _camera_pitch = clampf(_camera_pitch + relative.y * 0.008, -1.1, 1.1)
    _update_camera()


func _place_point(screen_position: Vector2) -> void:
    if _selected_descriptor < 0 or _selected_descriptor >= _descriptors.size():
        return
    var query := PhysicsRayQueryParameters3D.create(
        _camera.project_ray_origin(screen_position),
        _camera.project_ray_origin(screen_position) + _camera.project_ray_normal(screen_position) * 10.0
    )
    query.collision_mask = 1
    var hit := _viewport.world_3d.direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return
    var collider := hit["collider"] as Node
    if not collider.has_meta("descriptor_index") or int(collider.get_meta("descriptor_index")) != _selected_descriptor:
        _set_status("Hit a different surface. Select that surface first.")
        return
    var face_index := int(hit.get("face_index", -1))
    var descriptor: Dictionary = _descriptors[_selected_descriptor]
    var triangle_ids: PackedInt32Array = descriptor["triangle_ids"]
    var offset := face_index * 3
    if face_index < 0 or offset + 2 >= triangle_ids.size():
        _set_status("Could not map hit face to source triangle.")
        return
    var triangle := PackedInt32Array([triangle_ids[offset], triangle_ids[offset + 1], triangle_ids[offset + 2]])
    var mesh: MeshInstance3D = descriptor["mesh"]
    var vertices: PackedVector3Array = descriptor["vertices"]
    var local_hit: Vector3 = mesh.global_transform.affine_inverse() * hit["position"]
    var barycentric := _barycentric(local_hit, vertices[triangle[0]], vertices[triangle[1]], vertices[triangle[2]])
    if barycentric.is_empty():
        _set_status("Could not calculate a stable triangle attachment.")
        return
    _selected_point = {"triangle_indices": triangle, "barycentric": barycentric}
    _refresh_marker()
    _set_status("Placed %s. Inspect front, side and rear before saving." % _selected_landmark_id())


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
    var wb := (d11 * d20 - d01 * d21) / denominator
    var wc := (d00 * d21 - d01 * d20) / denominator
    var wa := 1.0 - wb - wc
    if minf(wa, minf(wb, wc)) < -0.02:
        return PackedFloat32Array()
    var result := PackedFloat32Array([maxf(0.0, wa), maxf(0.0, wb), maxf(0.0, wc)])
    var total := result[0] + result[1] + result[2]
    if total <= 0.000001:
        return PackedFloat32Array()
    for index in range(3):
        result[index] /= total
    return result


func _refresh_marker() -> void:
    _normal_mesh.clear_surfaces()
    if _selected_point.is_empty() or _selected_descriptor < 0:
        _marker.visible = false
        return
    var descriptor: Dictionary = _descriptors[_selected_descriptor]
    var mesh: MeshInstance3D = descriptor["mesh"]
    var vertices: PackedVector3Array = descriptor["vertices"]
    var triangle: PackedInt32Array = _selected_point["triangle_indices"]
    var weights: PackedFloat32Array = _selected_point["barycentric"]
    var local_position := Vector3.ZERO
    for corner in range(3):
        local_position += vertices[triangle[corner]] * weights[corner]
    var world_position := mesh.global_transform * local_position
    var local_normal := (vertices[triangle[1]] - vertices[triangle[0]]).cross(vertices[triangle[2]] - vertices[triangle[0]]).normalized()
    var world_normal := (mesh.global_transform.basis * local_normal).normalized()
    _marker.global_position = world_position
    _marker.visible = true
    _normal_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _normal_instance.material_override)
    _normal_mesh.surface_add_vertex(world_position)
    _normal_mesh.surface_add_vertex(world_position + world_normal * 0.12)
    _normal_mesh.surface_end()


func _clear_point() -> void:
    _selected_point.clear()
    _refresh_marker()


func _save_landmark() -> void:
    if _selected_descriptor < 0 or _selected_point.is_empty():
        _set_status("Place a point on the selected body surface first.")
        return
    var descriptor: Dictionary = _descriptors[_selected_descriptor]
    var mesh: MeshInstance3D = descriptor["mesh"]
    var landmark := CharacterSurfaceLandmark.new()
    landmark.body_asset_path = String(BODY_OPTIONS.get(_body_option.get_item_text(_body_option.selected), ""))
    landmark.mesh_node_path = _body_root.get_path_to(mesh)
    landmark.surface_index = int(descriptor["surface_index"])
    landmark.surface_name = mesh.mesh.surface_get_name(landmark.surface_index)
    landmark.vertex_count = descriptor["vertices"].size()
    landmark.surface_signature = CharacterSurfaceRegionMask.build_surface_signature(mesh.mesh, landmark.surface_index)
    landmark.landmark_id = _selected_landmark_id()
    landmark.triangle_indices = _selected_point["triangle_indices"]
    landmark.barycentric = _selected_point["barycentric"]
    var validation := landmark.validate_for_mesh(mesh, _body_root, landmark.body_asset_path)
    if not validation.is_empty():
        _set_status("Landmark rejected: " + validation)
        return
    var path := _save_path.text.strip_edges()
    if not path.begins_with("res://") or not path.ends_with(".tres"):
        _set_status("Save path must be a project res:// .tres path.")
        return
    var error := ResourceSaver.save(landmark, path)
    if error != OK:
        _set_status("Could not save landmark resource. Error code: %d" % error)
        return
    var manifest := load(MANIFEST_PATH) as CharacterSurfaceLandmarkManifest
    if manifest == null:
        _set_status("Could not load surface landmark manifest.")
        return
    var updated: Array[Resource] = []
    for existing in manifest.landmarks:
        if existing == null or existing.resource_path != path:
            updated.append(existing)
    updated.append(load(path))
    manifest.landmarks = updated
    error = ResourceSaver.save(manifest, MANIFEST_PATH)
    if error != OK:
        _set_status("Landmark saved, but manifest update failed. Error code: %d" % error)
        return
    _set_status("Saved and registered %s for %s." % [path, landmark.landmark_id])


func _selected_landmark_id() -> String:
    var value: Variant = _landmark_option.get_item_metadata(_landmark_option.selected)
    return String(value) if value != null else ""


func _set_default_path() -> void:
    if _selected_descriptor < 0 or _selected_descriptor >= _descriptors.size():
        return
    var descriptor: Dictionary = _descriptors[_selected_descriptor]
    var mesh: MeshInstance3D = descriptor["mesh"]
    var prefix := "wren" if _body_option.get_item_text(_body_option.selected).begins_with("Wren") else "aldric"
    _save_path.text = "%s/%s_%s_surface_%d_%s.tres" % [
        LANDMARK_DIRECTORY, prefix, String(mesh.name).to_snake_case(),
        int(descriptor["surface_index"]), _selected_landmark_id()
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
    var direction := Vector3(sin(_camera_yaw) * cos(_camera_pitch), sin(_camera_pitch), cos(_camera_yaw) * cos(_camera_pitch))
    _camera.global_position = _camera_target + direction * _camera_distance
    _camera.look_at(_camera_target, Vector3.UP)


func _set_status(value: String) -> void:
    if _status != null:
        _status.text = value
