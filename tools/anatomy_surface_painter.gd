extends Control
## Standalone Godot-native vertex mask authoring tool.
## Open res://tools/anatomy_surface_painter.tscn and run it from the editor.

const MASK_SCRIPT = preload("res://scripts/characters/character_surface_region_mask.gd")
const PARTITION_SCRIPT = preload("res://scripts/characters/character_surface_region_partition.gd")
const PARTITION_REGION_IDS := ["head_neck", "torso", "pelvis", "upper_arm_left", "upper_arm_right", "forearm_left", "forearm_right", "hand_left", "hand_right", "thigh_left", "thigh_right", "lower_leg_left", "lower_leg_right", "foot_left", "foot_right"]
const PARTITION_REGION_LABELS := ["Head and neck", "Torso", "Pelvis", "Upper arm — left", "Upper arm — right", "Forearm — left", "Forearm — right", "Hand — left", "Hand — right", "Thigh — left", "Thigh — right", "Lower leg — left", "Lower leg — right", "Foot — left", "Foot — right"]
const PARTITION_DIRECTORY := "res://data/characters/anatomy_partitions"
const INPUT_ROUTER_SCRIPT = preload("res://tools/anatomy_surface_painter_input.gd")
const BODY_OPTIONS := {
    "Wren (current native build)": "res://build/wren-native/Wren.glb",
    "Aldric (current native build)": "res://build/aldric-native/Aldric.glb"
}
const REGION_LABELS := {
    "face_front": "Face — front",
    "lips": "Lips / mouth contact",
    "ear_left": "Ear — left",
    "ear_right": "Ear — right",
    "neck_front": "Neck — front",
    "neck_back": "Neck — back",
    "neck_left": "Neck — left",
    "neck_right": "Neck — right",
    "clavicle_left": "Clavicle — left",
    "clavicle_right": "Clavicle — right",
    "chest_front_left": "Chest front — left",
    "chest_front_right": "Chest front — right",
    "pectoral_left": "Pectoral — left",
    "pectoral_right": "Pectoral — right",
    "sternum": "Sternum / centre chest",
    "ribcage_left": "Ribcage — left",
    "ribcage_right": "Ribcage — right",
    "lower_back": "Lower back",
    "breast_left": "Breast — left",
    "breast_right": "Breast — right",
    "areola_left": "Areola — left",
    "areola_right": "Areola — right",
    "nipple_left": "Nipple — left",
    "nipple_right": "Nipple — right",
    "underbust": "Underbust",
    "chest_back": "Upper / mid back",
    "abdomen_upper": "Abdomen — upper",
    "abdomen_lower": "Abdomen — lower",
    "waist": "Waist — general",
    "waist_front": "Waist — front",
    "waist_back": "Waist — back",
    "waist_left": "Waist — left side",
    "waist_right": "Waist — right side",
    "flank_left": "Flank — left",
    "flank_right": "Flank — right",
    "pelvis_front": "Pelvis — front",
    "pelvis_back": "Pelvis — back",
    "hip_left": "Hip — left",
    "hip_right": "Hip — right",
    "buttock_left": "Buttock — left",
    "buttock_right": "Buttock — right",
    "groin": "Groin — general",
    "perineum": "Perineum",
    "anal_region": "Anal / perianal surface",
    "vulva_external": "External vulvar region",
    "penis_external": "External penile region",
    "scrotum": "Scrotal region",
    "shoulder_left": "Shoulder — left",
    "shoulder_right": "Shoulder — right",
    "elbow_left": "Elbow — left",
    "elbow_right": "Elbow — right",
    "forearm_left": "Forearm — left",
    "forearm_right": "Forearm — right",
    "wrist_left": "Wrist — left",
    "wrist_right": "Wrist — right",
    "palm_left": "Palm — left",
    "palm_right": "Palm — right",
    "hand_back_left": "Back of hand — left",
    "hand_back_right": "Back of hand — right",
    "thigh_inner_left": "Inner thigh — left",
    "thigh_inner_right": "Inner thigh — right",
    "thigh_outer_left": "Outer thigh — left",
    "thigh_outer_right": "Outer thigh — right",
    "knee_left": "Knee — left",
    "knee_right": "Knee — right",
    "calf_left": "Calf — left",
    "calf_right": "Calf — right",
    "ankle_left": "Ankle — left",
    "ankle_right": "Ankle — right",
    "foot_top_left": "Top of foot — left",
    "foot_top_right": "Top of foot — right",
    "foot_sole_left": "Sole — left",
    "foot_sole_right": "Sole — right"
}
const REGION_GROUPS := [
    {"label": "HEAD AND NECK", "ids": ["face_front", "head_top", "head_back", "head_left", "head_right", "forehead", "temple_left", "temple_right", "brow_left", "brow_right", "eye_socket_left", "eye_socket_right", "eyelid_upper_left", "eyelid_upper_right", "eyelid_lower_left", "eyelid_lower_right", "cheek_left", "cheek_right", "nose_bridge", "nose_tip", "nostril_left", "nostril_right", "jaw_left", "jaw_right", "chin", "face_side_left", "face_side_right", "lips", "ear_left", "ear_right", "ear_inner_left", "ear_inner_right", "ear_lobe_left", "ear_lobe_right", "neck_front", "neck_back", "neck_left", "neck_right", "upper_neck_front", "upper_neck_back", "throat", "nape"]},
    {"label": "TORSO AND CHEST", "ids": ["clavicle_left", "clavicle_right", "chest_front_left", "chest_front_right", "pectoral_left", "pectoral_right", "sternum", "ribcage_left", "ribcage_right", "lower_back", "upper_back", "mid_back", "scapula_left", "scapula_right", "lumbar_back", "sacrum", "breast_left", "breast_right", "areola_left", "areola_right", "nipple_left", "nipple_right", "underbust", "chest_back", "abdomen_upper", "abdomen_lower", "upper_abdomen_left", "upper_abdomen_right", "lower_abdomen_left", "lower_abdomen_right", "waist", "waist_front", "waist_back", "waist_left", "waist_right", "flank_left", "flank_right"]},
    {"label": "PELVIS AND EXTERNAL ANATOMY", "ids": ["pelvis_front", "pelvis_back", "hip_left", "hip_right", "iliac_crest_left", "iliac_crest_right", "buttock_left", "buttock_right", "gluteal_left", "gluteal_right", "inguinal_left", "inguinal_right", "groin", "perineum", "anal_region", "vulva_external", "penis_external", "scrotum"]},
    {"label": "ARMS AND HANDS", "ids": ["shoulder_left", "shoulder_right", "upper_arm_left", "upper_arm_right", "bicep_left", "bicep_right", "tricep_left", "tricep_right", "elbow_left", "elbow_right", "forearm_left", "forearm_right", "wrist_left", "wrist_right", "palm_left", "palm_right", "hand_back_left", "hand_back_right", "thumb_left", "thumb_right", "index_finger_left", "index_finger_right", "middle_finger_left", "middle_finger_right", "ring_finger_left", "ring_finger_right", "little_finger_left", "little_finger_right"]},
    {"label": "LEGS AND FEET", "ids": ["thigh_inner_left", "thigh_inner_right", "thigh_outer_left", "thigh_outer_right", "knee_left", "knee_right", "calf_left", "calf_right", "ankle_left", "ankle_right", "foot_top_left", "foot_top_right", "foot_sole_left", "foot_sole_right", "heel_left", "heel_right", "toes_left", "toes_right", "instep_left", "instep_right"]}
]
const REGION_PAIRS := {
    "breast_left": "breast_right", "breast_right": "breast_left",
    "areola_left": "areola_right", "areola_right": "areola_left",
    "nipple_left": "nipple_right", "nipple_right": "nipple_left",
    "ear_left": "ear_right", "ear_right": "ear_left",
    "neck_left": "neck_right", "neck_right": "neck_left",
    "clavicle_left": "clavicle_right", "clavicle_right": "clavicle_left",
    "chest_front_left": "chest_front_right", "chest_front_right": "chest_front_left",
    "pectoral_left": "pectoral_right", "pectoral_right": "pectoral_left",
    "ribcage_left": "ribcage_right", "ribcage_right": "ribcage_left",
    "hip_left": "hip_right", "hip_right": "hip_left",
    "buttock_left": "buttock_right", "buttock_right": "buttock_left",
    "flank_left": "flank_right", "flank_right": "flank_left",
    "waist_left": "waist_right", "waist_right": "waist_left",
    "shoulder_left": "shoulder_right", "shoulder_right": "shoulder_left",
    "elbow_left": "elbow_right", "elbow_right": "elbow_left",
    "forearm_left": "forearm_right", "forearm_right": "forearm_left",
    "wrist_left": "wrist_right", "wrist_right": "wrist_left",
    "palm_left": "palm_right", "palm_right": "palm_left",
    "hand_back_left": "hand_back_right", "hand_back_right": "hand_back_left",
    "thigh_inner_left": "thigh_inner_right", "thigh_inner_right": "thigh_inner_left",
    "thigh_outer_left": "thigh_outer_right", "thigh_outer_right": "thigh_outer_left",
    "knee_left": "knee_right", "knee_right": "knee_left",
    "calf_left": "calf_right", "calf_right": "calf_left",
    "ankle_left": "ankle_right", "ankle_right": "ankle_left",
    "foot_top_left": "foot_top_right", "foot_top_right": "foot_top_left",
    "foot_sole_left": "foot_sole_right", "foot_sole_right": "foot_sole_left"
}
const MASK_DIRECTORY := "res://data/characters/anatomy_masks"
const MASK_MANIFEST_PATH := "res://data/characters/anatomy_masks/manifest.tres"

var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _world_root: Node3D
var _camera: Camera3D
var _body_root: Node3D
var _body_asset_path := ""
var _descriptors: Array[Dictionary] = []
var _selected_descriptor := -1
var _weights_by_region: Dictionary = {}
var _mirror_map_cache: Dictionary = {}
var _point_cloud: MultiMeshInstance3D
var _region_option: OptionButton
var _progress_label: Label
var _partition_mode_check: CheckButton
var _partition_region_option: OptionButton
var _partition_assignments := PackedInt32Array()
var _surface_option: OptionButton
var _body_option: OptionButton
var _radius_spin: SpinBox
var _strength_slider: HSlider
var _mirror_check: CheckButton
var _mode_option: OptionButton
var _status_label: Label
var _inspect_check: CheckButton
var _membership_label: Label
var _inspected_point_marker: MeshInstance3D
var _save_path_edit: LineEdit
var _selected_region := "breast_left"
var _brush_radius := 0.045
var _brush_strength := 0.35
var _painting := false
var _orbiting := false
var _camera_yaw := PI
var _camera_pitch := 0.12
var _camera_distance := 2.2
var _camera_target := Vector3(0.0, 0.85, 0.0)
var _last_paint_position := Vector2(-10000, -10000)
var _touch_positions: Dictionary = {}
var _touch_start_position := Vector2.ZERO
var _touch_dragged := false
var _pinch_distance := 0.0


func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_interface()
    _load_body("Wren (current native build)")


func _build_interface() -> void:
    _viewport_container = SubViewportContainer.new()
    _viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _viewport_container.stretch = true
    add_child(_viewport_container)

    _viewport = SubViewport.new()
    _viewport.size = Vector2i(1280, 900)
    _viewport.own_world_3d = true
    _viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    _viewport_container.add_child(_viewport)
    _world_root = Node3D.new()
    _viewport.add_child(_world_root)
    var input_router := Node3D.new()
    input_router.name = "PainterInputRouter"
    input_router.set_script(INPUT_ROUTER_SCRIPT)
    input_router.connect("input_event_received", _on_viewport_gui_input)
    _world_root.add_child(input_router)
    var environment := WorldEnvironment.new()
    var world_environment := Environment.new()
    world_environment.background_mode = Environment.BG_COLOR
    world_environment.background_color = Color(0.075, 0.09, 0.11)
    world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    world_environment.ambient_light_color = Color(0.65, 0.68, 0.72)
    world_environment.ambient_light_energy = 0.8
    environment.environment = world_environment
    _world_root.add_child(environment)

    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-28.0, -32.0, 0.0)
    key_light.light_energy = 1.5
    _world_root.add_child(key_light)

    _camera = Camera3D.new()
    _camera.current = true
    _world_root.add_child(_camera)
    _update_camera()

    _point_cloud = MultiMeshInstance3D.new()
    _point_cloud.name = "PaintedVertexWeights"
    var marker_mesh := SphereMesh.new()
    marker_mesh.radius = 0.006
    marker_mesh.height = 0.012
    marker_mesh.radial_segments = 6
    marker_mesh.rings = 3
    var marker_material := StandardMaterial3D.new()
    marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    marker_material.vertex_color_use_as_albedo = true
    marker_material.no_depth_test = true
    marker_mesh.material = marker_material
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = marker_mesh
    _point_cloud.multimesh = multi
    _world_root.add_child(_point_cloud)

    _inspected_point_marker = MeshInstance3D.new()
    var inspected_sphere := SphereMesh.new()
    inspected_sphere.radius = 0.014
    inspected_sphere.height = 0.028
    var inspected_material := StandardMaterial3D.new()
    inspected_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    inspected_material.albedo_color = Color(1.0, 0.72, 0.12)
    inspected_material.no_depth_test = true
    inspected_sphere.material = inspected_material
    _inspected_point_marker.mesh = inspected_sphere
    _inspected_point_marker.visible = false
    _world_root.add_child(_inspected_point_marker)

    var panel := PanelContainer.new()
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.anchor_top = 0.0
    panel.anchor_bottom = 1.0
    panel.offset_left = -340.0
    panel.offset_right = 0.0
    panel.offset_top = 0.0
    panel.offset_bottom = 0.0
    add_child(panel)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(scroll)
    var column := VBoxContainer.new()
    column.custom_minimum_size.x = 316.0
    column.add_theme_constant_override("separation", 8)
    scroll.add_child(column)

    var heading := Label.new()
    heading.text = "Wren / Aldric anatomy mask painter"
    heading.add_theme_font_size_override("font_size", 18)
    column.add_child(heading)
    _add_caption(column, "Paints exact imported GLB vertices. Start with one region and inspect from all angles.")

    _add_caption(column, "Body")
    _body_option = OptionButton.new()
    for body_name in BODY_OPTIONS:
        _body_option.add_item(body_name)
    _body_option.select(0)
    _body_option.item_selected.connect(_on_body_selected)
    column.add_child(_body_option)

    _add_caption(column, "Mesh surface")
    _surface_option = OptionButton.new()
    _surface_option.item_selected.connect(_on_surface_selected)
    column.add_child(_surface_option)

    _partition_mode_check = CheckButton.new()
    _partition_mode_check.text = "Exclusive primary partition (draft)"
    _partition_mode_check.tooltip_text = "Separate one-owner-per-vertex map. Does not alter overlapping feature masks."
    _partition_mode_check.toggled.connect(_on_partition_mode_toggled)
    column.add_child(_partition_mode_check)
    _partition_region_option = OptionButton.new()
    for label in PARTITION_REGION_LABELS:
        _partition_region_option.add_item(label)
    _partition_region_option.visible = false
    _partition_region_option.item_selected.connect(func(index: int):
        if index >= 0 and index < PARTITION_REGION_IDS.size():
            _selected_region = String(PARTITION_REGION_IDS[index])
            _rebuild_markers()
    )
    column.add_child(_partition_region_option)
    _add_caption(column, "Overlapping anatomical feature")
    _region_option = OptionButton.new()
    for group in REGION_GROUPS:
        _region_option.get_popup().add_separator(String(group["label"]))
        for region_id in group["ids"]:
            _region_option.add_item(String(REGION_LABELS.get(region_id, region_id.replace("_", " ").capitalize())))
            _region_option.set_item_metadata(_region_option.get_item_count() - 1, region_id)
    _region_option.select(1)
    _region_option.item_selected.connect(_on_region_selected)
    column.add_child(_region_option)

    _progress_label = Label.new()
    _progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _progress_label.text = "Mask authoring progress: loading…"
    column.add_child(_progress_label)
    var next_region_button := Button.new()
    next_region_button.text = "Next region without weights"
    next_region_button.pressed.connect(_select_next_region_without_weights)
    column.add_child(next_region_button)

    _add_caption(column, "Brush radius (metres)")
    _radius_spin = SpinBox.new()
    _radius_spin.min_value = 0.005
    _radius_spin.max_value = 0.2
    _radius_spin.step = 0.005
    _radius_spin.value = _brush_radius
    _radius_spin.value_changed.connect(func(value: float): _brush_radius = value)
    column.add_child(_radius_spin)

    _add_caption(column, "Brush strength")
    _strength_slider = HSlider.new()
    _strength_slider.min_value = 0.05
    _strength_slider.max_value = 1.0
    _strength_slider.step = 0.05
    _strength_slider.value = _brush_strength
    _strength_slider.value_changed.connect(func(value: float): _brush_strength = value)
    column.add_child(_strength_slider)

    _mode_option = OptionButton.new()
    _mode_option.add_item("Paint / add")
    _mode_option.add_item("Erase / subtract")
    column.add_child(_mode_option)

    _mirror_check = CheckButton.new()
    _mirror_check.text = "Mirror paired left/right region"
    column.add_child(_mirror_check)

    _inspect_check = CheckButton.new()
    _inspect_check.text = "Inspect point memberships"
    _inspect_check.tooltip_text = "Tap a surface point to inspect all authored region memberships at that location."
    _inspect_check.toggled.connect(func(enabled: bool):
        _painting = false
        _set_status("Membership inspection enabled. Tap a point on the selected surface." if enabled else "Painting mode enabled.")
    )
    column.add_child(_inspect_check)
    _membership_label = Label.new()
    _membership_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _membership_label.text = "Point inspector: no surface point selected."
    column.add_child(_membership_label)

    var clear_button := Button.new()
    clear_button.text = "Clear selected region"
    clear_button.pressed.connect(_clear_selected_region)
    column.add_child(clear_button)

    var save_heading := Label.new()
    save_heading.text = "Save mask resource"
    save_heading.add_theme_font_size_override("font_size", 16)
    column.add_child(save_heading)
    _save_path_edit = LineEdit.new()
    _save_path_edit.text = MASK_DIRECTORY + "/wren_body_surface_0.tres"
    column.add_child(_save_path_edit)
    var save_button := Button.new()
    save_button.text = "Save validated .tres mask"
    save_button.pressed.connect(_save_mask)
    column.add_child(save_button)

    _status_label = Label.new()
    _status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _status_label.text = "Loading body…"
    column.add_child(_status_label)

    var help := Label.new()
    help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    help.text = "Mouse: left-drag paints, right-drag orbits, wheel zooms. Touch: one-finger drag paints, two-finger drag orbits and pinches to zoom. Inspect point memberships to tap a point and see all overlapping authored regions. Blue markers show the selected region only."
    column.add_child(help)


func _add_caption(parent: VBoxContainer, text_value: String) -> void:
    var label := Label.new()
    label.text = text_value
    label.add_theme_color_override("font_color", Color(0.72, 0.78, 0.83))
    parent.add_child(label)


func _on_partition_mode_toggled(enabled: bool) -> void:
    _painting = false
    _partition_region_option.visible = enabled
    _region_option.visible = not enabled
    _mirror_check.disabled = enabled
    _inspect_check.button_pressed = false
    if enabled:
        _selected_region = String(PARTITION_REGION_IDS[_partition_region_option.selected])
        if _selected_descriptor >= 0:
            var descriptor: Dictionary = _descriptors[_selected_descriptor]
            var body_prefix := "wren" if _body_asset_path.ends_with("/Wren.glb") else "aldric"
            var mesh_name := String((descriptor["mesh"] as MeshInstance3D).name).to_snake_case()
            _save_path_edit.text = "%s/%s_%s_surface_%d_primary.tres" % [PARTITION_DIRECTORY, body_prefix, mesh_name, int(descriptor["surface_index"])]
        _set_status("Exclusive partition draft mode. Paint assigns one owner; erase leaves vertices unassigned. Save checks coverage and connectivity.")
    else:
        if _selected_descriptor >= 0:
            _save_path_edit.text = _default_save_path(_descriptors[_selected_descriptor])
        _set_status("Overlapping feature-mask mode restored.")
    _rebuild_markers()


func _on_body_selected(index: int) -> void:
    _load_body(_body_option.get_item_text(index))


func _load_body(body_name: String) -> void:
    _clear_body()
    _body_asset_path = String(BODY_OPTIONS.get(body_name, ""))
    var packed := load(_body_asset_path) as PackedScene
    if packed == null:
        _set_status("Could not load body scene: " + _body_asset_path)
        return
    _body_root = packed.instantiate() as Node3D
    if _body_root == null:
        _set_status("Companion GLB root is not Node3D")
        return
    _world_root.add_child(_body_root)
    _descriptors.clear()
    _mirror_map_cache.clear()
    _collect_surface_descriptors(_body_root)
    if _descriptors.is_empty():
        _set_status("No skinned mesh surfaces found in this companion build")
        return
    _surface_option.clear()
    for descriptor in _descriptors:
        var mesh_instance: MeshInstance3D = descriptor["mesh"]
        _surface_option.add_item("%s / surface %d (%d vertices)" % [
            str(_body_root.get_path_to(mesh_instance)),
            int(descriptor["surface_index"]),
            (descriptor["vertices"] as PackedVector3Array).size()
        ])
    _selected_descriptor = 0
    _surface_option.select(0)
    if _partition_mode_check.button_pressed:
        var body_prefix := "wren" if _body_asset_path.ends_with("/Wren.glb") else "aldric"
        var mesh_name := String((_descriptors[0]["mesh"] as MeshInstance3D).name).to_snake_case()
        _save_path_edit.text = "%s/%s_%s_surface_%d_primary.tres" % [PARTITION_DIRECTORY, body_prefix, mesh_name, int(_descriptors[0]["surface_index"])]
    else:
        _save_path_edit.text = _default_save_path(_descriptors[0])
    _frame_body()
    _load_current_mask()
    _rebuild_markers()
    _set_status("Loaded %s. Choose a region and paint on the mesh. Masks are tied to this exact native build topology." % body_name)


func _clear_body() -> void:
    if is_instance_valid(_body_root):
        _body_root.queue_free()
    for child in _world_root.get_children():
        if child is StaticBody3D:
            child.queue_free()
    _descriptors.clear()
    _weights_by_region.clear()
    _partition_assignments = PackedInt32Array()
    _mirror_map_cache.clear()
    _point_cloud.multimesh.instance_count = 0
    if is_instance_valid(_inspected_point_marker):
        _inspected_point_marker.visible = false
    if is_instance_valid(_membership_label):
        _membership_label.text = "Point inspector: no surface point selected."


func _collect_surface_descriptors(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh is ArrayMesh and mesh_instance.skin != null:
            var array_mesh := mesh_instance.mesh as ArrayMesh
            for surface_index in range(array_mesh.get_surface_count()):
                var arrays := array_mesh.surface_get_arrays(surface_index)
                var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
                var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
                if vertices.is_empty() or normals.size() != vertices.size():
                    continue
                var triangle_ids := PackedInt32Array()
                var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
                if indices.is_empty():
                    for vertex_index in range(0, vertices.size() - 2, 3):
                        triangle_ids.append(vertex_index)
                        triangle_ids.append(vertex_index + 1)
                        triangle_ids.append(vertex_index + 2)
                else:
                    triangle_ids = indices
                if triangle_ids.is_empty():
                    continue
                var descriptor_index := _descriptors.size()
                var descriptor := {
                    "mesh": mesh_instance,
                    "surface_index": surface_index,
                    "vertices": vertices,
                    "normals": normals,
                    "triangle_ids": triangle_ids,
                    "weights": {}
                }
                _descriptors.append(descriptor)

                # Headless validation only needs the imported vertex/index data and
                # must not cook a full concave physics collider for every GLB surface.
                # The interactive painter still gets exact triangle picking in GUI runs.
                if DisplayServer.get_name() != "headless":
                    var faces := PackedVector3Array()
                    for vertex_id in triangle_ids:
                        faces.append(vertices[vertex_id])
                    var shape := ConcavePolygonShape3D.new()
                    shape.backface_collision = true
                    shape.set_faces(faces)
                    var collision_body := StaticBody3D.new()
                    collision_body.name = "PaintCollider_%d" % descriptor_index
                    collision_body.set_meta("descriptor_index", descriptor_index)
                    collision_body.collision_layer = 1
                    collision_body.collision_mask = 1
                    var collision_shape := CollisionShape3D.new()
                    collision_shape.shape = shape
                    collision_body.add_child(collision_shape)
                    _world_root.add_child(collision_body)
                    collision_body.global_transform = mesh_instance.global_transform
    for child in node.get_children():
        _collect_surface_descriptors(child)


func _on_surface_selected(index: int) -> void:
    if index < 0 or index >= _descriptors.size():
        return
    _selected_descriptor = index
    _mirror_map_cache.erase(index)
    _partition_assignments = PackedInt32Array()
    _load_current_mask()
    _rebuild_markers()
    var descriptor: Dictionary = _descriptors[index]
    if _partition_mode_check.button_pressed:
        var body_prefix := "wren" if _body_asset_path.ends_with("/Wren.glb") else "aldric"
        var mesh_name := String((descriptor["mesh"] as MeshInstance3D).name).to_snake_case()
        _save_path_edit.text = "%s/%s_%s_surface_%d_primary.tres" % [PARTITION_DIRECTORY, body_prefix, mesh_name, int(descriptor["surface_index"])]
    else:
        _save_path_edit.text = _default_save_path(descriptor)


func _on_region_selected(index: int) -> void:
    if index < 0 or index >= _region_option.get_item_count():
        return
    var selected_id: Variant = _region_option.get_item_metadata(index)
    if selected_id == null:
        return
    _selected_region = String(selected_id)
    _rebuild_markers()


func _default_save_path(descriptor: Dictionary) -> String:
    var body_prefix := "wren" if _body_asset_path.ends_with("/Wren.glb") else "aldric"
    var mesh_instance: MeshInstance3D = descriptor["mesh"]
    var mesh_name := String(mesh_instance.name).to_snake_case()
    return "%s/%s_%s_surface_%d.tres" % [
        MASK_DIRECTORY, body_prefix, mesh_name, int(descriptor["surface_index"])
    ]


func _load_current_mask() -> void:
    _weights_by_region.clear()
    if _selected_descriptor < 0 or _selected_descriptor >= _descriptors.size():
        return
    var descriptor: Dictionary = _descriptors[_selected_descriptor]
    _save_path_edit.text = _default_save_path(descriptor)
    var path := _save_path_edit.text
    if not ResourceLoader.exists(path):
        descriptor["weights"] = _weights_by_region
        return
    var loaded := load(path) as CharacterSurfaceRegionMask
    if loaded == null:
        _set_status("Existing mask path is not a CharacterSurfaceRegionMask resource")
        return
    var mesh_instance: MeshInstance3D = descriptor["mesh"]
    var validation := loaded.validate_for_mesh(mesh_instance, _body_root, _body_asset_path)
    if not validation.is_empty():
        _set_status("Existing mask rejected: " + validation)
        return
    _weights_by_region = loaded.region_weights.duplicate(true)
    descriptor["weights"] = _weights_by_region


func _on_viewport_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_button := event as InputEventMouseButton
        if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
            _orbiting = mouse_button.pressed
            _viewport.set_input_as_handled()
        elif mouse_button.button_index == MOUSE_BUTTON_LEFT:
            _painting = mouse_button.pressed and not _inspect_check.button_pressed
            if mouse_button.pressed:
                if _inspect_check.button_pressed:
                    _inspect_at(mouse_button.position)
                else:
                    _paint_at(mouse_button.position)
            _viewport.set_input_as_handled()
        elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_button.pressed:
            _camera_distance = maxf(0.7, _camera_distance * 0.9)
            _update_camera()
            _viewport.set_input_as_handled()
        elif mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_button.pressed:
            _camera_distance = minf(5.0, _camera_distance * 1.1)
            _update_camera()
            _viewport.set_input_as_handled()
    elif event is InputEventMouseMotion:
        var motion := event as InputEventMouseMotion
        if _orbiting:
            _camera_yaw -= motion.relative.x * 0.008
            _camera_pitch = clampf(_camera_pitch + motion.relative.y * 0.008, -1.1, 1.1)
            _update_camera()
        elif _painting and motion.position.distance_to(_last_paint_position) >= 3.0:
            _paint_at(motion.position)
        _viewport.set_input_as_handled()
    elif event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            _touch_positions[touch.index] = touch.position
            if _touch_positions.size() == 1:
                _touch_start_position = touch.position
                _touch_dragged = false
            elif _touch_positions.size() == 2:
                _painting = false
                var values: Array = _touch_positions.values()
                _pinch_distance = (values[0] as Vector2).distance_to(values[1])
        else:
            if _touch_positions.has(touch.index):
                if _touch_positions.size() == 1 and not _touch_dragged:
                    if _inspect_check.button_pressed:
                        _inspect_at(touch.position)
                    else:
                        _paint_at(touch.position)
                _touch_positions.erase(touch.index)
                if _touch_positions.size() < 2:
                    _pinch_distance = 0.0
                    _painting = false
        _viewport.set_input_as_handled()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if _touch_positions.size() >= 2:
            _touch_positions[drag.index] = drag.position
            var values: Array = _touch_positions.values()
            var distance: float = (values[0] as Vector2).distance_to(values[1])
            if _pinch_distance > 1.0 and distance > 1.0:
                _camera_distance = clampf(_camera_distance * _pinch_distance / distance, 0.7, 5.0)
            _camera_yaw -= drag.relative.x * 0.004
            _camera_pitch = clampf(_camera_pitch + drag.relative.y * 0.004, -1.1, 1.1)
            _pinch_distance = distance
            _update_camera()
        elif _touch_positions.size() == 1:
            _touch_positions[drag.index] = drag.position
            if drag.position.distance_to(_touch_start_position) > 8.0:
                _touch_dragged = true
            if _touch_dragged:
                if _inspect_check.button_pressed:
                    _camera_yaw -= drag.relative.x * 0.008
                    _camera_pitch = clampf(_camera_pitch + drag.relative.y * 0.008, -1.1, 1.1)
                    _update_camera()
                else:
                    _paint_at(drag.position)
        _viewport.set_input_as_handled()

## Inspect a point on the selected native mesh and report all authored
## semantic memberships using barycentric interpolation across its hit triangle.
func _inspect_at(screen_position: Vector2) -> void:
    if _selected_descriptor < 0 or _selected_descriptor >= _descriptors.size():
        return
    var ray_origin := _camera.project_ray_origin(screen_position)
    var ray_direction := _camera.project_ray_normal(screen_position)
    var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 10.0)
    query.collision_mask = 1
    var hit := _viewport.world_3d.direct_space_state.intersect_ray(query)
    if hit.is_empty():
        _membership_label.text = "Point inspector: no surface hit."
        _inspected_point_marker.visible = false
        return
    var collider := hit["collider"] as Node
    if not collider.has_meta("descriptor_index") or int(collider.get_meta("descriptor_index")) != _selected_descriptor:
        _membership_label.text = "Point inspector: select the mesh surface that was hit."
        return
    _inspected_point_marker.global_position = hit["position"]
    _inspected_point_marker.visible = true
    var descriptor: Dictionary = _descriptors[_selected_descriptor]
    var triangle_ids: PackedInt32Array = descriptor["triangle_ids"]
    var face_index := int(hit.get("face_index", -1))
    var offset := face_index * 3
    if face_index < 0 or offset + 2 >= triangle_ids.size():
        _membership_label.text = "Point inspector: hit triangle could not be resolved."
        return
    var triangle := PackedInt32Array([triangle_ids[offset], triangle_ids[offset + 1], triangle_ids[offset + 2]])
    var vertices: PackedVector3Array = descriptor["vertices"]
    var mesh: MeshInstance3D = descriptor["mesh"]
    var local_hit: Vector3 = mesh.global_transform.affine_inverse() * hit["position"]
    var barycentric := _barycentric_weights(local_hit, vertices[triangle[0]], vertices[triangle[1]], vertices[triangle[2]])
    if barycentric.is_empty():
        _membership_label.text = "Point inspector: barycentric interpolation failed."
        return
    var membership_values: Array[Dictionary] = []
    for region_variant in _weights_by_region:
        var region_id := String(region_variant)
        var values: PackedFloat32Array = _weights_by_region[region_id]
        if values.size() != vertices.size():
            continue
        var interpolated := 0.0
        for corner in range(3):
            interpolated += values[triangle[corner]] * barycentric[corner]
        if interpolated >= 0.05:
            membership_values.append({"id": region_id, "weight": interpolated})
    membership_values.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return float(a["weight"]) > float(b["weight"])
    )
    var memberships: Array[String] = []
    for membership in membership_values:
        memberships.append("%s %.2f" % [String(membership["id"]), float(membership["weight"])])
    var point_text := "Surface point\nTriangle vertices: %d, %d, %d\nBarycentric: %.3f / %.3f / %.3f\n" % [
        triangle[0], triangle[1], triangle[2], barycentric[0], barycentric[1], barycentric[2]
    ]
    if memberships.is_empty():
        point_text += "No authored memberships at threshold 0.05."
    else:
        point_text += "Authored memberships (weight):\n" + "\n".join(memberships)
    _membership_label.text = point_text
    _set_status("Inspected %d authored region memberships on %s." % [membership_values.size(), String(mesh.name)])


func _barycentric_weights(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> PackedFloat32Array:
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


func _paint_at(screen_position: Vector2) -> void:
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
        _set_status("That hit belongs to another surface. Select it in the Mesh surface list first.")
        return
    var face_index := int(hit.get("face_index", -1))
    var descriptor: Dictionary = _descriptors[descriptor_index]
    var triangle_ids: PackedInt32Array = descriptor["triangle_ids"]
    var triangle_offset := face_index * 3
    if face_index < 0 or triangle_offset + 2 >= triangle_ids.size():
        _set_status("Could not resolve the hit triangle to source vertices")
        return
    var hit_position: Vector3 = hit["position"]
    var hit_normal: Vector3 = hit["normal"]
    var vertices: PackedVector3Array = descriptor["vertices"]
    var normals: PackedVector3Array = descriptor["normals"]
    var mesh_instance: MeshInstance3D = descriptor["mesh"]
    var mesh_transform := mesh_instance.global_transform
    var normal_transform := mesh_transform.basis.inverse().transposed()
    if _partition_mode_check.button_pressed:
        _paint_partition_vertices(descriptor, hit_position, hit_normal, screen_position)
        return
    var weights: PackedFloat32Array = _get_or_create_weights(_selected_region, vertices.size())
    var erase_mode := _mode_option.selected == 1
    var paired_region := _paired_region_id(_selected_region)
    var paired_weights := _get_or_create_weights(paired_region, vertices.size()) if _mirror_check.button_pressed else PackedFloat32Array()
    var mirror_map: PackedInt32Array = _get_mirror_map(descriptor_index) if _mirror_check.button_pressed else PackedInt32Array()
    var touched := 0
    for vertex_index in range(vertices.size()):
        var world_position := mesh_transform * vertices[vertex_index]
        var distance := world_position.distance_to(hit_position)
        if distance > _brush_radius:
            continue
        var world_normal := (normal_transform * normals[vertex_index]).normalized()
        if world_normal.dot(hit_normal) < 0.15:
            continue
        var falloff := 1.0 - distance / _brush_radius
        falloff = falloff * falloff * (3.0 - 2.0 * falloff)
        var amount := _brush_strength * falloff
        weights[vertex_index] = maxf(0.0, weights[vertex_index] - amount) if erase_mode else minf(1.0, weights[vertex_index] + amount)
        if _mirror_check.button_pressed and vertex_index < mirror_map.size():
            var mirror_index := mirror_map[vertex_index]
            if mirror_index >= 0 and mirror_index < paired_weights.size():
                paired_weights[mirror_index] = maxf(0.0, paired_weights[mirror_index] - amount) if erase_mode else minf(1.0, paired_weights[mirror_index] + amount)
        touched += 1
    _weights_by_region[_selected_region] = weights
    if _mirror_check.button_pressed:
        _weights_by_region[paired_region] = paired_weights
    descriptor["weights"] = _weights_by_region
    _last_paint_position = screen_position
    _rebuild_markers()
    _set_status("Painted %s: %d vertices affected%s" % [
        _selected_region, touched, " (mirrored)" if _mirror_check.button_pressed else ""
    ])


func _paint_partition_vertices(descriptor: Dictionary, hit_position: Vector3, hit_normal: Vector3, screen_position: Vector2) -> void:
    var vertices: PackedVector3Array = descriptor["vertices"]
    var normals: PackedVector3Array = descriptor["normals"]
    if _partition_assignments.size() != vertices.size():
        _partition_assignments.resize(vertices.size())
        _partition_assignments.fill(-1)
    var mesh_instance: MeshInstance3D = descriptor["mesh"]
    var mesh_transform := mesh_instance.global_transform
    var normal_transform := mesh_transform.basis.inverse().transposed()
    var selected_owner := PARTITION_REGION_IDS.find(_selected_region)
    if selected_owner < 0:
        _set_status("Select a valid primary region")
        return
    var erase_mode := _mode_option.selected == 1
    var touched := 0
    for vertex_index in vertices.size():
        var world_position: Vector3 = mesh_transform * vertices[vertex_index]
        var distance := world_position.distance_to(hit_position)
        if distance > _brush_radius:
            continue
        var world_normal := (normal_transform * normals[vertex_index]).normalized()
        if world_normal.dot(hit_normal) < 0.15:
            continue
        _partition_assignments[vertex_index] = -1 if erase_mode else selected_owner
        touched += 1
    _last_paint_position = screen_position
    _rebuild_markers()
    _set_status("Primary partition: %s %d vertices %s." % [_selected_region, touched, "cleared" if erase_mode else "assigned"])


func _paired_region_id(region_id: String) -> String:
    if REGION_PAIRS.has(region_id):
        return String(REGION_PAIRS[region_id])
    if region_id.ends_with("_left"):
        var candidate := region_id.trim_suffix("_left") + "_right"
        if MASK_SCRIPT.REGION_IDS.has(candidate):
            return candidate
    elif region_id.ends_with("_right"):
        var candidate := region_id.trim_suffix("_right") + "_left"
        if MASK_SCRIPT.REGION_IDS.has(candidate):
            return candidate
    return region_id


func _get_or_create_weights(region_id: String, vertex_count: int) -> PackedFloat32Array:
    if _weights_by_region.has(region_id):
        var existing: PackedFloat32Array = _weights_by_region[region_id]
        if existing.size() == vertex_count:
            return existing
    var created := PackedFloat32Array()
    created.resize(vertex_count)
    _weights_by_region[region_id] = created
    return created


func _get_mirror_map(descriptor_index: int) -> PackedInt32Array:
    if _mirror_map_cache.has(descriptor_index):
        return _mirror_map_cache[descriptor_index]
    var descriptor: Dictionary = _descriptors[descriptor_index]
    var vertices: PackedVector3Array = descriptor["vertices"]
    const CELL := 0.004
    var grid: Dictionary = {}
    for index in range(vertices.size()):
        var cell := _position_cell(vertices[index], CELL)
        if not grid.has(cell):
            grid[cell] = []
        grid[cell].append(index)
    var result := PackedInt32Array()
    result.resize(vertices.size())
    result.fill(-1)
    var tolerance_squared := 0.012 * 0.012
    for index in range(vertices.size()):
        var target := Vector3(-vertices[index].x, vertices[index].y, vertices[index].z)
        var base_cell := _position_cell(target, CELL)
        var best_index := -1
        var best_distance := tolerance_squared
        for x in range(-1, 2):
            for y in range(-1, 2):
                for z in range(-1, 2):
                    var cell := base_cell + Vector3i(x, y, z)
                    if not grid.has(cell):
                        continue
                    for candidate in grid[cell]:
                        var distance := vertices[candidate].distance_squared_to(target)
                        if distance < best_distance:
                            best_distance = distance
                            best_index = candidate
        result[index] = best_index
    _mirror_map_cache[descriptor_index] = result
    var matched := 0
    for value in result:
        if value >= 0:
            matched += 1
    _set_status("Mirror map: %d / %d vertices paired" % [matched, vertices.size()])
    return result


func _position_cell(position: Vector3, cell_size: float) -> Vector3i:
    return Vector3i(
        floori(position.x / cell_size),
        floori(position.y / cell_size),
        floori(position.z / cell_size)
    )


func _rebuild_markers() -> void:
    _update_region_progress()
    if _selected_descriptor < 0 or _selected_descriptor >= _descriptors.size():
        _point_cloud.multimesh.instance_count = 0
        return
    var descriptor: Dictionary = _descriptors[_selected_descriptor]
    var vertices: PackedVector3Array = descriptor["vertices"]
    if _partition_mode_check.button_pressed:
        if _partition_assignments.size() != vertices.size():
            _partition_assignments.resize(vertices.size())
            _partition_assignments.fill(-1)
        var multi_partition := _point_cloud.multimesh
        var assigned_count := 0
        for owner_index in _partition_assignments:
            if owner_index >= 0:
                assigned_count += 1
        multi_partition.instance_count = assigned_count
        var cursor := 0
        var partition_transform: Transform3D = descriptor["mesh"].global_transform
        for vertex_index in vertices.size():
            var owner_index: int = _partition_assignments[vertex_index]
            if owner_index < 0:
                continue
            var marker_position: Vector3 = partition_transform * vertices[vertex_index]
            multi_partition.set_instance_transform(cursor, Transform3D(Basis().scaled(Vector3.ONE * 0.9), marker_position))
            multi_partition.set_instance_color(cursor, Color.from_hsv(float(owner_index) / float(PARTITION_REGION_IDS.size()), 0.78, 1.0))
            cursor += 1
        return
    var weights: PackedFloat32Array = _get_or_create_weights(_selected_region, vertices.size())
    var mesh_instance: MeshInstance3D = descriptor["mesh"]
    var transform := mesh_instance.global_transform
    var count := 0
    for weight in weights:
        if weight > 0.015:
            count += 1
    var multi := _point_cloud.multimesh
    multi.instance_count = count
    var marker_index := 0
    for vertex_index in range(weights.size()):
        var weight := weights[vertex_index]
        if weight <= 0.015:
            continue
        var position := transform * vertices[vertex_index]
        var scale := lerpf(0.55, 1.4, weight)
        multi.set_instance_transform(marker_index, Transform3D(Basis().scaled(Vector3.ONE * scale), position))
        multi.set_instance_color(marker_index, Color(0.05 + 0.1 * weight, 0.35 + 0.55 * weight, 1.0, 1.0))
        marker_index += 1


func _update_region_progress() -> void:
    if not is_instance_valid(_progress_label):
        return
    var total_regions := 0
    var regions_with_weights := 0
    var selected_vertex_count := 0
    for group in REGION_GROUPS:
        for region_variant in group["ids"]:
            var region_id := String(region_variant)
            total_regions += 1
            var values: PackedFloat32Array = _weights_by_region.get(region_id, PackedFloat32Array())
            var region_vertex_count := 0
            for weight in values:
                if weight > 0.015:
                    region_vertex_count += 1
            if region_vertex_count > 0:
                regions_with_weights += 1
            if region_id == _selected_region:
                selected_vertex_count = region_vertex_count
    _progress_label.text = "Mask authoring: %d / %d channels contain weights\nSelected: %s — %d vertices\nA non-empty channel is not yet anatomically reviewed or approved." % [
        regions_with_weights, total_regions, _selected_region, selected_vertex_count
    ]


func _select_next_region_without_weights() -> void:
    for group in REGION_GROUPS:
        for region_variant in group["ids"]:
            var region_id := String(region_variant)
            var values: PackedFloat32Array = _weights_by_region.get(region_id, PackedFloat32Array())
            var has_weights := false
            for weight in values:
                if weight > 0.015:
                    has_weights = true
                    break
            if has_weights:
                continue
            for option_index in range(_region_option.get_item_count()):
                if String(_region_option.get_item_metadata(option_index)) != region_id:
                    continue
                _region_option.select(option_index)
                _on_region_selected(option_index)
                _set_status("Next region without authored weights: " + region_id)
                return
    _set_status("Every listed region channel currently contains weights. Visual anatomical review is still required.")


func _clear_selected_region() -> void:
    if _selected_descriptor < 0:
        return
    var descriptor: Dictionary = _descriptors[_selected_descriptor]
    var vertices: PackedVector3Array = descriptor["vertices"]
    if _partition_mode_check.button_pressed:
        if _partition_assignments.size() != vertices.size():
            _partition_assignments.resize(vertices.size())
            _partition_assignments.fill(-1)
        var selected_owner := PARTITION_REGION_IDS.find(_selected_region)
        for vertex_index in _partition_assignments.size():
            if _partition_assignments[vertex_index] == selected_owner:
                _partition_assignments[vertex_index] = -1
        _rebuild_markers()
        _set_status("Cleared %s; those vertices are now unassigned." % _selected_region)
        return
    var empty := PackedFloat32Array()
    empty.resize(vertices.size())
    _weights_by_region[_selected_region] = empty
    descriptor["weights"] = _weights_by_region
    _rebuild_markers()
    _set_status("Cleared " + _selected_region + " in the current unsaved mask")


func _save_mask() -> void:
    if _partition_mode_check.button_pressed:
        _save_primary_partition()
        return
    if _selected_descriptor < 0:
        _set_status("Select a skinned mesh surface first")
        return
    var descriptor: Dictionary = _descriptors[_selected_descriptor]
    var mesh_instance: MeshInstance3D = descriptor["mesh"]
    var vertices: PackedVector3Array = descriptor["vertices"]
    var nonempty: Dictionary = {}
    for region_id in _weights_by_region:
        var values: PackedFloat32Array = _weights_by_region[region_id]
        if values.size() != vertices.size():
            _set_status("Cannot save: %s has %d weights for %d vertices" % [region_id, values.size(), vertices.size()])
            return
        var has_weight := false
        for value in values:
            if value > 0.0:
                has_weight = true
                break
        if has_weight:
            nonempty[region_id] = values
    if nonempty.is_empty():
        _set_status("Paint at least one region before saving")
        return
    var path := _save_path_edit.text.strip_edges()
    if not path.begins_with("res://") or not path.ends_with(".tres"):
        _set_status("Save path must be a res:// .tres path")
        return
    var absolute_directory := ProjectSettings.globalize_path(path.get_base_dir())
    var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
    if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
        _set_status("Could not create mask directory (error %d)" % directory_error)
        return
    var mask := CharacterSurfaceRegionMask.new()
    mask.body_asset_path = _body_asset_path
    mask.mesh_node_path = _body_root.get_path_to(mesh_instance)
    mask.surface_index = int(descriptor["surface_index"])
    mask.surface_name = mesh_instance.mesh.surface_get_name(mask.surface_index)
    mask.vertex_count = vertices.size()
    mask.surface_signature = CharacterSurfaceRegionMask.build_surface_signature(mesh_instance.mesh, mask.surface_index)
    mask.region_weights = nonempty
    var validation := mask.validate_for_mesh(mesh_instance, _body_root, _body_asset_path)
    if not validation.is_empty():
        _set_status("Mask failed validation: " + validation)
        return
    var save_error := ResourceSaver.save(mask, path)
    if save_error != OK:
        _set_status("ResourceSaver failed (error %d)" % save_error)
        return
    if not _register_saved_mask(path, mask):
        _set_status("Mask saved, but manifest registration failed. Check manifest.tres before using it in-game.")
        return
    _weights_by_region = nonempty
    descriptor["weights"] = _weights_by_region
    _set_status("Saved and validated %s (%d semantic regions)" % [path, nonempty.size()])
    _update_region_progress()


func _save_primary_partition() -> void:
    if _selected_descriptor < 0:
        _set_status("Select a skinned mesh surface first")
        return
    var descriptor: Dictionary = _descriptors[_selected_descriptor]
    var mesh_instance: MeshInstance3D = descriptor["mesh"]
    var vertices: PackedVector3Array = descriptor["vertices"]
    if _partition_assignments.size() != vertices.size():
        _set_status("Partition not saved: no complete assignment array exists for this surface")
        return
    var partition := PARTITION_SCRIPT.new()
    var setup_error: String = partition.configure_for_mesh(mesh_instance, _body_root, _body_asset_path, int(descriptor["surface_index"]), PackedStringArray(PARTITION_REGION_IDS))
    if not setup_error.is_empty():
        _set_status("Partition setup failed: " + setup_error)
        return
    partition.vertex_region_indices = _partition_assignments.duplicate()
    var validation: String = partition.validate_for_mesh(mesh_instance, _body_root, _body_asset_path)
    if not validation.is_empty():
        _set_status("Partition not saved: " + validation)
        return
    var path := _save_path_edit.text.strip_edges()
    if not path.begins_with(PARTITION_DIRECTORY + "/") or not path.ends_with(".tres"):
        _set_status("Primary partitions must be saved under %s as a .tres resource" % PARTITION_DIRECTORY)
        return
    var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
    if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
        _set_status("Could not create partition directory (error %d)" % directory_error)
        return
    var save_error := ResourceSaver.save(partition, path)
    if save_error != OK:
        _set_status("Partition save failed (error %d)" % save_error)
        return
    _set_status("Saved validated draft primary partition: %s. Not registered for runtime use." % path)


func _register_saved_mask(mask_path: String, saved_mask: CharacterSurfaceRegionMask) -> bool:
    var manifest := load(MASK_MANIFEST_PATH) as CharacterSurfaceRegionMaskManifest
    if manifest == null:
        _set_status("Could not load anatomy mask manifest: " + MASK_MANIFEST_PATH)
        return false
    var updated_masks: Array[Resource] = []
    for existing_resource in manifest.masks:
        if existing_resource is CharacterSurfaceRegionMask:
            var existing_mask := existing_resource as CharacterSurfaceRegionMask
            var same_target := existing_mask.body_asset_path == saved_mask.body_asset_path and existing_mask.mesh_node_path == saved_mask.mesh_node_path and existing_mask.surface_index == saved_mask.surface_index
            if same_target:
                continue
        updated_masks.append(existing_resource)
    var registered_mask := load(mask_path) as CharacterSurfaceRegionMask
    if registered_mask == null:
        return false
    updated_masks.append(registered_mask)
    manifest.masks = updated_masks
    return ResourceSaver.save(manifest, MASK_MANIFEST_PATH) == OK


func _frame_body() -> void:
    if _body_root == null:
        return
    var bounds := AABB()
    var has_bounds := false
    for descriptor in _descriptors:
        var mesh_instance: MeshInstance3D = descriptor["mesh"]
        var local_bounds := mesh_instance.mesh.get_aabb()
        var global_bounds := AABB(mesh_instance.global_transform * local_bounds.position, local_bounds.size)
        if not has_bounds:
            bounds = global_bounds
            has_bounds = true
        else:
            bounds = bounds.merge(global_bounds)
    if has_bounds:
        _camera_target = bounds.get_center()
        _camera_target.y += 0.02
        _camera_distance = maxf(1.5, bounds.size.length() * 1.45)
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


func _set_status(message: String) -> void:
    if is_instance_valid(_status_label):
        _status_label.text = message
