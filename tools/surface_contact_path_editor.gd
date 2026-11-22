extends "res://tools/surface_landmark_editor.gd"
## Sequential authoring UI for topology-bound surface contact paths.
## Inherits the native companion body picker, triangle hit testing and touch orbit controls.

const CONTACT_MANIFEST_PATH := "res://data/characters/surface_contact_paths/manifest.tres"
const CONTACT_DIRECTORY := "res://data/characters/surface_contact_paths"

var _path_id_input: LineEdit
var _path_points: Array[Dictionary] = []
var _path_closed := false
var _path_preview_mesh: ImmediateMesh
var _path_preview_instance: MeshInstance3D
var _path_point_markers: Array[MeshInstance3D] = []
var _point_count_label: Label
var _surface_regions: CharacterSurfaceRegions
var _preview_contact_path: CharacterSurfaceContactPath


func _ready() -> void:
    super._ready()
    _landmark_option.hide()
    for child in _landmark_option.get_parent().get_children():
        if child is Label and (child as Label).text == "Anatomical landmark":
            child.hide()
    _build_contact_controls()
    _setup_path_preview()
    _set_contact_default_path()
    _set_status("Contact-path mode. Tap the skin to add ordered points; inspect the path from multiple angles before saving.")


func _build_contact_controls() -> void:
    var panel := PanelContainer.new()
    panel.anchor_left = 0.0
    panel.anchor_top = 0.0
    panel.offset_left = 12.0
    panel.offset_top = 12.0
    panel.offset_right = 300.0
    panel.offset_bottom = 206.0
    add_child(panel)
    var column := VBoxContainer.new()
    panel.add_child(column)
    var heading := Label.new()
    heading.text = "Surface contact path"
    heading.add_theme_font_size_override("font_size", 17)
    column.add_child(heading)
    var help := Label.new()
    help.text = "Tap points in travel order. The cyan preview follows the source mesh triangle-edge graph between anchors (a surface-constrained approximation, not an exact geodesic)."
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(help)
    _path_id_input = LineEdit.new()
    _path_id_input.placeholder_text = "e.g. fingertip_trace_left"
    _path_id_input.text = "contact_path_01"
    _path_id_input.text_changed.connect(func(_value: String): _set_contact_default_path())
    column.add_child(_path_id_input)
    var actions := HBoxContainer.new()
    column.add_child(actions)
    var undo := Button.new()
    undo.text = "Undo point"
    undo.pressed.connect(_undo_path_point)
    actions.add_child(undo)
    var clear := Button.new()
    clear.text = "Clear"
    clear.pressed.connect(_clear_path)
    actions.add_child(clear)
    var close := Button.new()
    close.text = "Close loop"
    close.pressed.connect(_toggle_closed_loop)
    actions.add_child(close)
    _point_count_label = Label.new()
    _point_count_label.text = "0 points"
    column.add_child(_point_count_label)


func _setup_path_preview() -> void:
    _path_preview_mesh = ImmediateMesh.new()
    _path_preview_instance = MeshInstance3D.new()
    _path_preview_instance.mesh = _path_preview_mesh
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(0.1, 0.95, 0.95)
    material.no_depth_test = true
    _path_preview_instance.material_override = material
    _world_root.add_child(_path_preview_instance)


func _load_body(body_name: String) -> void:
    super._load_body(body_name)
    _path_points.clear()
    _path_closed = false
    _surface_regions = null
    _preview_contact_path = CharacterSurfaceContactPath.new()
    if _body_root != null:
        _surface_regions = CharacterSurfaceRegions.new()
        var body_asset := String(BODY_OPTIONS.get(body_name, ""))
        var masks: Array[Resource] = CharacterSurfaceRegionMaskLibrary.load_for_body(body_asset)
        if not _surface_regions.configure(_body_root, _body_root, masks, body_asset):
            _set_status("Contact preview unavailable: " + _surface_regions.get_configuration_error())
            _surface_regions = null
    if _path_preview_mesh != null:
        _refresh_marker()
    _update_point_count()
    # The base editor writes a landmark resource path during body changes;
    # restore the contact-path-specific path for the newly selected body.
    _set_contact_default_path()


func _place_point(screen_position: Vector2) -> void:
    _selected_point.clear()
    super._place_point(screen_position)
    if _selected_point.is_empty():
        return
    _path_points.append({
        "triangle_indices": _selected_point["triangle_indices"].duplicate(),
        "barycentric": _selected_point["barycentric"].duplicate()
    })
    _refresh_marker()
    _update_point_count()
    _set_status("Added path point %d. Continue along the skin in travel order." % _path_points.size())


func _refresh_marker() -> void:
    super._refresh_marker()
    if _path_preview_mesh == null:
        return
    _path_preview_mesh.clear_surfaces()
    if _path_points.size() >= 2 and _selected_descriptor >= 0 and _surface_regions != null:
        var descriptor: Dictionary = _descriptors[_selected_descriptor]
        var mesh: MeshInstance3D = descriptor["mesh"]
        _preview_contact_path.body_asset_path = String(BODY_OPTIONS.get(_body_option.get_item_text(_body_option.selected), ""))
        _preview_contact_path.mesh_node_path = _body_root.get_path_to(mesh)
        _preview_contact_path.surface_index = int(descriptor["surface_index"])
        _preview_contact_path.surface_name = mesh.mesh.surface_get_name(_preview_contact_path.surface_index)
        _preview_contact_path.vertex_count = (descriptor["vertices"] as PackedVector3Array).size()
        _preview_contact_path.surface_signature = CharacterSurfaceRegionMask.build_surface_signature(mesh.mesh, _preview_contact_path.surface_index)
        _preview_contact_path.path_id = _path_id_input.text.strip_edges().to_snake_case()
        _preview_contact_path.closed_loop = _path_closed
        _preview_contact_path.points = _path_points.duplicate(true)
        var dense_path := _preview_contact_path.evaluate_surface_path(_surface_regions)
        if not dense_path.is_empty():
            _path_preview_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _path_preview_instance.material_override)
            for sample in dense_path:
                _path_preview_mesh.surface_add_vertex(_body_root.global_transform * sample["position"])
            _path_preview_mesh.surface_end()
        else:
            _set_status("Surface route could not be evaluated: " + _preview_contact_path.last_evaluation_error)
    _update_point_count()


func _world_point(point: Dictionary) -> Vector3:
    if _selected_descriptor < 0 or _selected_descriptor >= _descriptors.size():
        return Vector3.ZERO
    var descriptor: Dictionary = _descriptors[_selected_descriptor]
    var mesh: MeshInstance3D = descriptor["mesh"]
    var vertices: PackedVector3Array = descriptor["vertices"]
    var triangle: PackedInt32Array = point["triangle_indices"]
    var weights: PackedFloat32Array = point["barycentric"]
    var local_position := Vector3.ZERO
    for corner in range(3):
        local_position += vertices[triangle[corner]] * weights[corner]
    return mesh.global_transform * local_position


func _undo_path_point() -> void:
    if _path_points.is_empty():
        return
    _path_points.pop_back()
    _selected_point.clear()
    _refresh_marker()
    _update_point_count()
    _set_status("Removed the last path point.")


func _clear_path() -> void:
    _path_points.clear()
    _selected_point.clear()
    _path_closed = false
    _refresh_marker()
    _update_point_count()
    _set_status("Contact path cleared.")


func _toggle_closed_loop() -> void:
    if _path_points.size() < 3:
        _set_status("A closed loop needs at least three control points.")
        return
    _path_closed = not _path_closed
    _refresh_marker()
    _set_status("Closed loop enabled." if _path_closed else "Closed loop disabled.")


func _on_surface_selected(index: int) -> void:
    _clear_path()
    super._on_surface_selected(index)
    _set_contact_default_path()


func _set_contact_default_path() -> void:
    if _selected_descriptor < 0 or _selected_descriptor >= _descriptors.size() or _path_id_input == null:
        return
    var descriptor: Dictionary = _descriptors[_selected_descriptor]
    var mesh: MeshInstance3D = descriptor["mesh"]
    var prefix := "wren" if _body_option.get_item_text(_body_option.selected).begins_with("Wren") else "aldric"
    var safe_id := _path_id_input.text.strip_edges().to_snake_case()
    if safe_id.is_empty():
        safe_id = "contact_path_01"
    _save_path.text = "%s/%s_%s_surface_%d_%s.tres" % [
        CONTACT_DIRECTORY, prefix, String(mesh.name).to_snake_case(),
        int(descriptor["surface_index"]), safe_id
    ]


func _save_landmark() -> void:
    if _selected_descriptor < 0:
        _set_status("Select a body surface first.")
        return
    if _path_points.size() < (3 if _path_closed else 2):
        _set_status("Add at least %d points before saving." % (3 if _path_closed else 2))
        return
    var descriptor: Dictionary = _descriptors[_selected_descriptor]
    var mesh: MeshInstance3D = descriptor["mesh"]
    var contact_path := CharacterSurfaceContactPath.new()
    contact_path.body_asset_path = String(BODY_OPTIONS.get(_body_option.get_item_text(_body_option.selected), ""))
    contact_path.mesh_node_path = _body_root.get_path_to(mesh)
    contact_path.surface_index = int(descriptor["surface_index"])
    contact_path.surface_name = mesh.mesh.surface_get_name(contact_path.surface_index)
    contact_path.vertex_count = descriptor["vertices"].size()
    contact_path.surface_signature = CharacterSurfaceRegionMask.build_surface_signature(mesh.mesh, contact_path.surface_index)
    contact_path.path_id = _path_id_input.text.strip_edges().to_snake_case()
    contact_path.closed_loop = _path_closed
    contact_path.points = _path_points.duplicate(true)
    var validation := contact_path.validate_for_mesh(mesh, _body_root, contact_path.body_asset_path)
    if not validation.is_empty():
        _set_status("Contact path rejected: " + validation)
        return
    var path := _save_path.text.strip_edges()
    if not path.begins_with("res://") or not path.ends_with(".tres"):
        _set_status("Save path must be a project res:// .tres path.")
        return
    var error := ResourceSaver.save(contact_path, path)
    if error != OK:
        _set_status("Could not save contact path resource. Error code: %d" % error)
        return
    var manifest := load(CONTACT_MANIFEST_PATH) as CharacterSurfaceContactPathManifest
    if manifest == null:
        _set_status("Could not load contact path manifest.")
        return
    var updated: Array[Resource] = []
    for existing in manifest.paths:
        if existing == null or existing.resource_path != path:
            updated.append(existing)
    updated.append(load(path))
    manifest.paths = updated
    error = ResourceSaver.save(manifest, CONTACT_MANIFEST_PATH)
    if error != OK:
        _set_status("Path saved, but manifest update failed. Error code: %d" % error)
        return
    _set_status("Saved and registered %s with %d control points." % [contact_path.path_id, contact_path.points.size()])


func _update_point_count() -> void:
    if _path_id_input == null:
        return
    if _point_count_label != null:
        _point_count_label.text = "%d points%s" % [_path_points.size(), " · closed" if _path_closed else ""]
