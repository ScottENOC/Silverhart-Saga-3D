class_name AraCharacterActor
extends Node3D

const ARA_CHARACTER_DETAILS = preload("res://scripts/presentation/ara_character_details.gd")
const CHARACTER_ANATOMY_SCRIPT = preload("res://scripts/characters/character_anatomy.gd")
const CHARACTER_SURFACE_REGIONS_SCRIPT = preload("res://scripts/characters/character_surface_regions.gd")
const CHARACTER_SURFACE_REGION_MASK_LIBRARY_SCRIPT = preload("res://scripts/characters/character_surface_region_mask_library.gd")
const CHARACTER_GARMENT_GUIDE_LIBRARY_SCRIPT = preload("res://scripts/characters/character_garment_guide_library.gd")
const CHARACTER_SURFACE_LANDMARK_LIBRARY_SCRIPT = preload("res://scripts/characters/character_surface_landmark_library.gd")
const CHARACTER_SURFACE_CONTACT_PATH_LIBRARY_SCRIPT = preload("res://scripts/characters/character_surface_contact_path_library.gd")
## Runtime wrapper for generated Ara GLBs. The selected body asset is supplied
## by the player profile so Workshop exports can be replaced without code edits.

var model_root: Node3D
var animation_player: AnimationPlayer
var loaded_asset_path: String = ""
var hair_instances: Array[MeshInstance3D] = []
var garment_attachments: Dictionary = {}
var equipment_attachments: Dictionary = {}
var body_variant: String = "female"
var appearance_details: AraCharacterDetails
var anatomy: CharacterAnatomy
var surface_regions: CharacterSurfaceRegions
var garment_guide_curves: Array[Resource] = []
var _garment_guides_loaded := false
var surface_landmarks: Array[Resource] = []
var _surface_landmarks_loaded := false
var surface_contact_paths: Array[Resource] = []
var _surface_contact_paths_loaded := false
var body_pressure_controller := BodyPressureController.new()
const GARMENT_ASSET_ROOT := "res://art/characters/ara_runtime/garments/"
const EQUIPMENT_PROP_ROOT := "res://art/characters/ara_runtime/props/"
const GARMENT_VISUALS := ["bra", "briefs", "long_tunic", "trousers", "tunic", "wrapper_long", "uniform_shirt", "fatigue_pants", "wrapper_knee", "tattered_shirt", "fatigue_shirt", "sandals", "combat_boots", "leather armor"]
var current_hair_colour: Color = Color("#49372a")

func _physics_process(delta: float) -> void:
    body_pressure_controller.step(delta)


## Register a canonical anatomy region for pressure response. Region IDs are
## owned by CharacterSurfaceRegionMask; this API does not create new anatomy IDs.
func register_body_pressure_region(region_id: StringName, profile: BodyRegionProfile) -> void:
    body_pressure_controller.register_region(region_id, profile)


func apply_body_pressure(region_id: StringName, force_n: float) -> void:
    body_pressure_controller.apply_pressure(region_id, force_n)


func apply_body_contact(
    region_id: StringName,
    penetration_m: float,
    closing_speed_m_per_s: float,
    contact_stiffness_n_per_m: float = 1800.0,
    contact_damping_ns_per_m: float = 35.0,
    max_force_n: float = 120.0
) -> float:
    return BodyPressureContact.submit_contact(
        body_pressure_controller,
        region_id,
        penetration_m,
        closing_speed_m_per_s,
        contact_stiffness_n_per_m,
        contact_damping_ns_per_m,
        max_force_n
    )


func get_body_pressure_m(region_id: StringName) -> float:
    return body_pressure_controller.get_compression_m(region_id)


func get_body_pressure_region_ids() -> Array[StringName]:
    return body_pressure_controller.get_region_ids()


func configure(glb_path: String) -> bool:
    if model_root != null and is_instance_valid(model_root):
        remove_child(model_root)
        model_root.queue_free()
    model_root = null
    animation_player = null
    anatomy = null
    surface_regions = null
    garment_guide_curves.clear()
    _garment_guides_loaded = false
    surface_landmarks.clear()
    _surface_landmarks_loaded = false
    surface_contact_paths.clear()
    _surface_contact_paths_loaded = false
    hair_instances.clear()
    _clear_garment_attachments()
    loaded_asset_path = ""
    if not ResourceLoader.exists(glb_path):
        push_warning("Ara character asset is not installed: " + glb_path)
        return false
    var packed := load(glb_path) as PackedScene
    if packed == null:
        push_warning("Ara character GLB could not be loaded: " + glb_path)
        return false
    model_root = packed.instantiate() as Node3D
    if model_root == null:
        push_warning("Ara character root is not Node3D: " + glb_path)
        return false
    model_root.name = "AraModel"
    add_child(model_root)
    anatomy = CHARACTER_ANATOMY_SCRIPT.new() as CharacterAnatomy
    if not anatomy.configure(self, model_root):
        push_warning("Ara character has no compatible skeleton for shared anatomy queries: " + glb_path)
        anatomy = null
    # Region weights are prepared lazily: most NPCs never need a full surface
    # query, and eagerly building per-vertex masks for every spawned actor is wasteful.
    surface_regions = CHARACTER_SURFACE_REGIONS_SCRIPT.new() as CharacterSurfaceRegions
    loaded_asset_path = glb_path
    # Register the 145 canonical fine-region IDs from the anatomy resource.
    # Their overlapping surface masks remain the source of contact location.
    BodyPressureProfileLibrary.register_anatomy_regions(body_pressure_controller)
    body_pressure_controller.bind_model(model_root)
    animation_player = _find_animation_player(model_root)
    call_deferred("_play_idle_if_available")
    # Report the loaded character model regardless of whether the separate
    # modular-clothing export is available or successfully attached.
    call_deferred("_dump_garment_surface_report")
    return true

## Shared semantic anatomy API for animation, fitting and gameplay consumers.
func get_anatomy() -> CharacterAnatomy:
    return anatomy


## Shared deformation-aware broad surface-region API for fitting and gameplay consumers.
func get_surface_regions() -> CharacterSurfaceRegions:
    if surface_regions == null or model_root == null or not is_instance_valid(model_root):
        return null
    if not surface_regions.is_configured():
        var fine_masks: Array[Resource] = CHARACTER_SURFACE_REGION_MASK_LIBRARY_SCRIPT.load_for_body(loaded_asset_path)
        if not surface_regions.configure(self, model_root, fine_masks, loaded_asset_path):
            push_warning("Ara character surface-region queries are unavailable: " + surface_regions.get_configuration_error())
            surface_regions = null
            return null
    return surface_regions


## Shared surface-attached garment construction guides for this canonical body.
## An empty result is expected until production guides have been authored.
func get_garment_guide_curves() -> Array[Resource]:
    if model_root == null or not is_instance_valid(model_root):
        return []
    if not _garment_guides_loaded:
        garment_guide_curves = CHARACTER_GARMENT_GUIDE_LIBRARY_SCRIPT.load_for_body(loaded_asset_path, model_root)
        _garment_guides_loaded = true
    return garment_guide_curves.duplicate()


## Shared semantic skin-surface landmarks for animation contacts and garment construction.
## Resources are topology-validated and evaluated against the current deformed body.
func get_surface_landmarks() -> Array[Resource]:
    if model_root == null or not is_instance_valid(model_root):
        return []
    if not _surface_landmarks_loaded:
        surface_landmarks = CHARACTER_SURFACE_LANDMARK_LIBRARY_SCRIPT.load_for_body(loaded_asset_path, model_root)
        _surface_landmarks_loaded = true
    return surface_landmarks.duplicate()


func get_surface_landmark(landmark_id: String) -> Dictionary:
    var regions := get_surface_regions()
    if regions == null:
        return {}
    for resource in get_surface_landmarks():
        if resource is CharacterSurfaceLandmark and resource.landmark_id == landmark_id:
            return resource.evaluate(regions)
    return {}


## Surface-attached control paths for contact choreography.
## Returns evaluated control points and local frames; animation still supplies IK and timing.
func get_surface_contact_paths() -> Array[Resource]:
    if model_root == null or not is_instance_valid(model_root):
        return []
    if not _surface_contact_paths_loaded:
        surface_contact_paths = CHARACTER_SURFACE_CONTACT_PATH_LIBRARY_SCRIPT.load_for_body(loaded_asset_path, model_root)
        _surface_contact_paths_loaded = true
    return surface_contact_paths.duplicate()


func get_surface_contact_path(path_id: String) -> Array[Dictionary]:
    ## Returns evaluated authoring control points for inspection and editing.
    var regions := get_surface_regions()
    if regions == null:
        return []
    for resource in get_surface_contact_paths():
        if resource is CharacterSurfaceContactPath and resource.path_id == path_id:
            return resource.evaluate(regions)
    return []


func get_surface_contact_path_samples(path_id: String) -> Array[Dictionary]:
    ## Returns a dense, mesh-edge-constrained surface route with deformed frames.
    ## This is suitable as the target trajectory for hand/finger IK; timing,
    ## contact offset/pressure and collision constraints remain animation concerns.
    var regions := get_surface_regions()
    if regions == null:
        return []
    for resource in get_surface_contact_paths():
        if resource is CharacterSurfaceContactPath and resource.path_id == path_id:
            return resource.evaluate_surface_path(regions)
    return []


func _dump_garment_surface_report() -> void:
    if has_meta("ara_garment_surface_reported"):
        return
    if model_root == null or not is_instance_valid(model_root):
        print("[Ara garment report] SKIPPED: character model is not configured")
        return
    set_meta("ara_garment_surface_reported", true)

    var actor_path: String = str(get_path()) if is_inside_tree() else String(name)
    print("[Ara garment report] BEGIN actor=%s asset=%s" % [actor_path, loaded_asset_path])
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(model_root, meshes)
    for mesh_instance in meshes:
        if not is_instance_valid(mesh_instance) or mesh_instance.mesh == null:
            continue
        print("[Ara garment report] MESH path=%s mesh=%s surfaces=%d" % [
            str(model_root.get_path_to(mesh_instance)),
            mesh_instance.mesh.resource_name,
            mesh_instance.mesh.get_surface_count()
        ])
        for surface in range(mesh_instance.mesh.get_surface_count()):
            var material := mesh_instance.get_active_material(surface)
            var material_name := material.resource_name if material != null else "<none>"
            print("[Ara garment report] SURFACE mesh=%s index=%d name=%s material=%s" % [
                mesh_instance.name,
                surface,
                mesh_instance.mesh.surface_get_name(surface),
                material_name
            ])
    print("[Ara garment report] END")

func _clear_garment_attachments() -> void:
    for garment_id in garment_attachments:
        for instance in garment_attachments[garment_id]:
            if is_instance_valid(instance):
                instance.queue_free()
    garment_attachments.clear()


func _set_garment_attachment_visible(garment_id: String, visible: bool) -> void:
    if garment_id.is_empty() or body_variant != "female":
        return
    if not garment_attachments.has(garment_id):
        if not visible or not _load_garment_attachment(garment_id):
            return
    for instance in garment_attachments.get(garment_id, []):
        if is_instance_valid(instance):
            instance.visible = visible


func _load_garment_attachment(garment_id: String) -> bool:
    if model_root == null:
        return false
    var path := GARMENT_ASSET_ROOT + "female_" + garment_id + ".glb"
    if not ResourceLoader.exists(path):
        push_warning("Ara garment '%s' is not installed at %s" % [garment_id, path])
        return false
    var target_skeleton := _find_skeleton(model_root)
    if target_skeleton == null:
        push_warning("Cannot attach Ara garment '%s': target body has no Skeleton3D" % garment_id)
        return false
    var packed := load(path) as PackedScene
    if packed == null:
        push_warning("Ara garment '%s' could not be loaded as a PackedScene" % path)
        return false
    var source_root := packed.instantiate()
    var source_skeleton := _find_skeleton(source_root)
    if source_skeleton == null or not _same_skeleton(source_skeleton, target_skeleton):
        source_root.free()
        push_warning("Cannot attach Ara garment '%s': garment skeleton does not match actor skeleton" % garment_id)
        return false
    var source_meshes: Array[MeshInstance3D] = []
    _collect_skinned_meshes(source_root, source_meshes)
    if source_meshes.is_empty():
        source_root.free()
        push_warning("Ara garment '%s' contains no skinned meshes" % garment_id)
        return false
    var attached: Array[MeshInstance3D] = []
    for source_mesh in source_meshes:
        var instance := source_mesh.duplicate() as MeshInstance3D
        if instance == null:
            continue
        instance.name = "Garment_%s_%s" % [garment_id, source_mesh.name]
        instance.set_meta("ara_external_garment", true)
        # The standalone GLB may place its skinned mesh below one or more
        # transformed parent nodes. Reparenting the mesh directly to model_root
        # without carrying those transforms can move a correctly skinned bra
        # away from the torso (historically as far as the head).
        instance.transform = _relative_transform_to_root(source_mesh, source_root)
        model_root.add_child(instance)
        instance.skeleton = instance.get_path_to(target_skeleton)
        instance.visible = false
        attached.append(instance)
    source_root.free()
    if attached.is_empty():
        return false
    garment_attachments[garment_id] = attached
    var current_body_parameters: Dictionary = get_meta("body_parameters", {})
    if not current_body_parameters.is_empty():
        apply_body_parameters(current_body_parameters)
    return true


## Preserve the complete imported node transform when moving a skinned mesh
## from a standalone garment scene under the character model root.
static func _relative_transform_to_root(node: Node3D, root_node: Node) -> Transform3D:
    var result := Transform3D.IDENTITY
    var cursor: Node = node
    while cursor != null and cursor != root_node:
        if cursor is Node3D:
            result = (cursor as Node3D).transform * result
        cursor = cursor.get_parent()
    if cursor != root_node:
        push_warning("Garment mesh is not a descendant of its source scene root.")
        return Transform3D.IDENTITY
    return result


func _surface_label(mesh_instance: MeshInstance3D, surface: int) -> String:
    var material := mesh_instance.mesh.surface_get_material(surface)
    var material_name := material.resource_name.to_lower() if material != null else ""
    return material_name + " " + mesh_instance.mesh.surface_get_name(surface).to_lower()


func _set_modular_surface_visible(mesh_instance: MeshInstance3D, surface: int, visible: bool) -> void:
    var key := "ara_modular_original_%d_%d" % [mesh_instance.get_instance_id(), surface]
    if not mesh_instance.has_meta(key):
        mesh_instance.set_meta(key, mesh_instance.mesh.surface_get_material(surface))
    var original := mesh_instance.get_meta(key) as Material
    if visible:
        mesh_instance.set_surface_override_material(surface, original)
        return
    var hidden := original.duplicate() as StandardMaterial3D if original is StandardMaterial3D else StandardMaterial3D.new()
    hidden.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    hidden.albedo_color.a = 0.0
    hidden.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    mesh_instance.set_surface_override_material(surface, hidden)


## Render the actual equipped item instances from CharacterState.
func apply_equipment_visuals(equipped_item_data: Dictionary) -> void:
    var visible_garments: Array[String] = []
    var weapon_id := ""
    var offhand_id := ""
    var helmet_id := ""
    for slot_variant in equipped_item_data:
        var slot := String(slot_variant)
        var item: Variant = equipped_item_data[slot_variant]
        if not item is Dictionary:
            continue
        var item_id := String(item.get("id", ""))
        var garment_visual := String(item.get("garment_visual", ""))
        if not garment_visual.is_empty() and not visible_garments.has(garment_visual):
            visible_garments.append(garment_visual)
        match slot:
            "armour":
                if item_id in ["reinforced_leather_armor", "light_armor", "medium_armor", "heavy_armor"]:
                    visible_garments.append("leather armor")
            "weapon":
                weapon_id = item_id
            "offhand":
                offhand_id = item_id
            "helmet":
                helmet_id = item_id

    # Authored character GLBs may contain baked clothing. Hide those surfaces
    # and render equipped garments from independent skinned GLBs. The base body
    # remains visible; clothing never replaces or cuts holes in the skin.
    if model_root != null:
        var character_meshes: Array[MeshInstance3D] = []
        _collect_meshes(model_root, character_meshes)
        for mesh_instance in character_meshes:
            if not is_instance_valid(mesh_instance) or mesh_instance.mesh == null:
                continue
            if hair_instances.has(mesh_instance) or bool(mesh_instance.get_meta("ara_external_garment", false)):
                continue
            for surface in range(mesh_instance.mesh.get_surface_count()):
                var label := _surface_label(mesh_instance, surface) + " " + mesh_instance.name
                if _is_known_garment_surface(label):
                    _set_modular_surface_visible(mesh_instance, surface, false)

    for garment_id in garment_attachments.keys():
        _set_garment_attachment_visible(String(garment_id), false)
    for garment_visual in visible_garments:
        _set_garment_attachment_visible(_garment_asset_id(garment_visual), true)

    _set_equipment_prop("weapon", _weapon_prop_id(weapon_id), "WeaponR")
    var shield_prop := "round_shield" if offhand_id == "wooden_shield" else ( "kite_shield" if offhand_id == "bulwark_shield" else "")
    _set_equipment_prop("offhand", shield_prop, "WeaponL")
    _set_equipment_prop("helmet", _helmet_prop_id(helmet_id), "Head")


func _garment_asset_id(value: String) -> String:
    var normalized := value.to_lower().strip_edges().replace("-", "_").replace(" ", "_")
    # Legacy inventory visuals use generic names. Resolve them to the first
    # approved standalone garment rather than looking for nonexistent files.
    match normalized:
        "bra":
            return "halter_bra_lace"
        "briefs":
            return "lace_briefs"
        _:
            return normalized

func _is_known_garment_surface(label: String) -> bool:
    for garment_id in GARMENT_VISUALS:
        if _garment_label_matches(label, garment_id):
            return true
    return false


func _garment_label_matches(label: String, garment_id: String) -> bool:
    # Match complete name tokens, not arbitrary substrings. The old substring
    # test could classify body/skin surfaces as clothing (for example "braid"
    # as "bra") and could confuse "tunic" with "long_tunic".
    var separator_pattern := RegEx.new()
    separator_pattern.compile("[^a-z0-9]+")
    var label_tokens := separator_pattern.sub(label.to_lower(), " ", true).strip_edges().split(" ", false)
    var garment_tokens := separator_pattern.sub(garment_id.to_lower(), " ", true).strip_edges().split(" ", false)
    if garment_tokens.is_empty() or label_tokens.size() < garment_tokens.size():
        return false
    for start in range(label_tokens.size() - garment_tokens.size() + 1):
        # A short tunic must not match the "tunic" component of "long_tunic".
        if garment_tokens.size() == 1 and garment_tokens[0] == "tunic" and start > 0 and label_tokens[start - 1] == "long":
            continue
        var matches := true
        for offset in range(garment_tokens.size()):
            var label_token: String = label_tokens[start + offset]
            var garment_token: String = garment_tokens[offset]
            # Permit numbered exports such as "trousers01", but not unrelated
            # words that merely begin with the garment name.
            if label_token != garment_token:
                if not label_token.begins_with(garment_token):
                    matches = false
                    break
                var suffix := label_token.trim_prefix(garment_token)
                if not suffix.is_valid_int():
                    matches = false
                    break
        if matches:
            return true
    return false


func _weapon_prop_id(item_id: String) -> String:
    match item_id:
        "sword", "sword_arrow_deflection", "starforged_blade": return "sword"
        "dagger", "featherweight_dagger": return "knife"
        "axe", "hatchet": return "axe"
        "spear", "stormcaller_spear": return "spear"
        "bow", "nightowl_bow": return "bow"
        "club", "ashenwood_club": return "club"
        "mace": return "mace"
        _: return ""


func _helmet_prop_id(item_id: String) -> String:
    match item_id:
        "nasal_helm", "huntsman_helm": return "nasal_helm"
        _: return ""


func _set_equipment_prop(slot: String, prop_id: String, socket_name: String) -> void:
    if equipment_attachments.has(slot):
        var previous: Node = equipment_attachments[slot]
        if is_instance_valid(previous):
            previous.queue_free()
        equipment_attachments.erase(slot)
    if prop_id.is_empty():
        return
    var prop_path := EQUIPMENT_PROP_ROOT + prop_id + ".glb"
    if not ResourceLoader.exists(prop_path):
        push_warning("Equipped %s visual '%s' is not installed at %s" % [slot, prop_id, prop_path])
        return
    var skeleton := _find_skeleton(model_root) if model_root != null else null
    if skeleton == null:
        return
    var candidates: Array[String] = []
    match socket_name:
        "WeaponR":
            candidates = ["WeaponR", "Hand.R", "hand_r", "mixamorig:RightHand", "RightHand"]
        "WeaponL":
            candidates = ["WeaponL", "Hand.L", "hand_l", "mixamorig:LeftHand", "LeftHand"]
        _:
            candidates = ["Head", "head", "mixamorig:Head"]
    var bone_name := ""
    for candidate in candidates:
        if skeleton.find_bone(candidate) >= 0:
            bone_name = candidate
            break
    if bone_name.is_empty():
        push_warning("Cannot attach equipped %s: no compatible %s bone in Ara skeleton" % [prop_id, socket_name])
        return
    var packed := load(prop_path) as PackedScene
    if packed == null:
        return
    var attachment := BoneAttachment3D.new()
    attachment.name = "Equipment_" + slot
    attachment.bone_name = bone_name
    skeleton.add_child(attachment)
    var prop := packed.instantiate()
    prop.name = prop_id
    attachment.add_child(prop)
    equipment_attachments[slot] = attachment


func apply_player_profile(profile: Dictionary) -> void:
    if model_root == null:
        return
    var skin := Color.from_string(str(profile.get("skin_colour", "#b9825f")), Color(0.72, 0.57, 0.43))
    var eye_colours := {
        "Brown": Color("#49301f"), "Light brown": Color("#795334"),
        "Dark brown": Color("#24170f"), "Green": Color("#55744b"),
        "Blue": Color("#426f9a"), "Grey": Color("#777d83"),
        "Ice blue": Color("#9bc8df"), "Blue green": Color("#4f8173"),
        "Hazel": Color("#78633c")
    }
    var hair_colours := {
        "Black": Color("#171513"), "Dark brown": Color("#49372a"),
        "Chestnut": Color("#75452d"), "Blonde": Color("#c6a45e"),
        "Red": Color("#9a422e"), "Silver": Color("#aaa9a3"),
        "White": Color("#e4dfd2"), "Blue": Color("#354d91"),
        "Green": Color("#426b49")
    }
    var skin_surfaces_tinted := tint_materials("skin", skin)
    var eye_surfaces_tinted := tint_materials("eye", eye_colours.get(str(profile.get("eye_colour", "Brown")), Color("#49301f")))
    set_meta("skin_surfaces_tinted", skin_surfaces_tinted)
    set_meta("eye_surfaces_tinted", eye_surfaces_tinted)
    print("[Ara appearance] asset=%s skin=%s surfaces=%d eyes=%s surfaces=%d" % [
        loaded_asset_path, skin.to_html(false), skin_surfaces_tinted,
        str(profile.get("eye_colour", "Brown")), eye_surfaces_tinted
    ])
    var hair_colour_value := str(profile.get("hair_colour", "Dark brown"))
    current_hair_colour = Color.from_string(
        hair_colour_value,
        hair_colours.get(hair_colour_value, Color("#49372a"))
    )
    tint_materials("hair", current_hair_colour)
    _tint_attached_hair(current_hair_colour)

    apply_body_parameters(profile)
    var next_body_variant := str(profile.get("body_base", profile.get("body_variant", "female")))
    if next_body_variant != body_variant:
        _clear_garment_attachments()
    body_variant = next_body_variant
    set_meta("body_variant", body_variant)
    set_meta("gender_presentation", str(profile.get("gender_presentation", "Feminine")))
    set_meta("pronouns", str(profile.get("pronouns", "they/them")))
    _apply_appearance_details(profile)

## Attach a standalone Ara hair GLB to this character's existing skeleton.
## Both exports must use the same pinned Ara rig and bone ordering.
func set_hairstyle(glb_path: String) -> bool:
    if model_root == null:
        return false
    if not ResourceLoader.exists(glb_path):
        clear_hairstyle()
        return false
    var target_skeleton := _find_skeleton(model_root)
    if target_skeleton == null:
        push_warning("Cannot attach Ara hair: character has no Skeleton3D")
        return false
    var packed := load(glb_path) as PackedScene
    if packed == null:
        return false
    var source_root := packed.instantiate()
    var source_skeleton := _find_skeleton(source_root)
    if source_skeleton == null:
        source_root.free()
        push_warning("Cannot attach Ara hair: exported GLB has no Skeleton3D")
        return false
    var source_meshes: Array[MeshInstance3D] = []
    _collect_skinned_meshes(source_root, source_meshes)
    if source_meshes.is_empty():
        source_root.free()
        push_warning("Cannot attach Ara hair: GLB contains no skinned MeshInstance3D")
        return false

    clear_hairstyle()
    _set_embedded_hair_visible(false)
    for source_mesh in source_meshes:
        var instance := source_mesh.duplicate() as MeshInstance3D
        if instance == null:
            continue
        if not _remap_hair_skin_to_skeleton(instance, source_skeleton, target_skeleton):
            instance.free()
            source_root.free()
            clear_hairstyle()
            push_warning("Cannot attach Ara hair: its skin references bones absent from the character skeleton")
            return false
        instance.name = "Swappable_" + source_mesh.name
        model_root.add_child(instance)
        instance.skeleton = instance.get_path_to(target_skeleton)
        hair_instances.append(instance)
    source_root.free()
    if hair_instances.is_empty():
        _set_embedded_hair_visible(true)
        return false
    _tint_attached_hair(current_hair_colour)
    return true

func clear_hairstyle() -> void:
    for instance in hair_instances:
        if is_instance_valid(instance):
            instance.queue_free()
    hair_instances.clear()
    _set_embedded_hair_visible(true)

func _remap_hair_skin_to_skeleton(mesh_instance: MeshInstance3D, source_skeleton: Skeleton3D, target_skeleton: Skeleton3D) -> bool:
    if mesh_instance == null or mesh_instance.skin == null:
        push_warning("Ara hair remap: mesh has no Skin resource")
        return false
    var remapped_skin := mesh_instance.skin.duplicate() as Skin
    if remapped_skin == null:
        return false

    # Some exported Ara hairstyles retain auxiliary scalp/physics bones that
    # are not present in the lean runtime body rig. Preserve exact matches;
    # bind only unmatched hair influences to the target Head bone so the
    # hairstyle remains attached and follows head animation rather than being
    # discarded altogether.
    var head_bone := _find_bone_case_insensitive(target_skeleton, "head")
    if head_bone < 0:
        push_warning("Ara hair remap: target skeleton has no Head bone")
        return false
    var remapped_count := 0
    var fallback_count := 0
    for bind_index in range(remapped_skin.get_bind_count()):
        var source_bone_index := remapped_skin.get_bind_bone(bind_index)
        var source_bone_name := ""
        if source_bone_index >= 0 and source_bone_index < source_skeleton.get_bone_count():
            source_bone_name = source_skeleton.get_bone_name(source_bone_index)
        if source_bone_name.is_empty():
            source_bone_name = str(remapped_skin.get_bind_name(bind_index))
        var target_bone_index := target_skeleton.find_bone(source_bone_name)
        if target_bone_index < 0:
            target_bone_index = _find_bone_case_insensitive(target_skeleton, source_bone_name)
        if target_bone_index < 0:
            target_bone_index = head_bone
            fallback_count += 1
        else:
            remapped_count += 1
        remapped_skin.set_bind_bone(bind_index, target_bone_index)
        # Rebuild the inverse bind transform against the target skeleton rest
        # pose; reusing an auxiliary rig's inverse bind can offset the hair.
        remapped_skin.set_bind_pose(bind_index, target_skeleton.get_bone_global_rest(target_bone_index).affine_inverse())

    mesh_instance.skin = remapped_skin
    if fallback_count > 0:
        print("[Ara hair remap] %s: %d named binds, %d auxiliary binds attached to Head" % [
            mesh_instance.name, remapped_count, fallback_count
        ])
    return true


func _find_bone_case_insensitive(skeleton: Skeleton3D, requested_name: String) -> int:
    var wanted := requested_name.to_lower().replace("_", "").replace("-", "").replace(" ", "")
    if wanted.is_empty():
        return -1
    for bone_index in range(skeleton.get_bone_count()):
        var candidate := skeleton.get_bone_name(bone_index).to_lower().replace("_", "").replace("-", "").replace(" ", "")
        if candidate == wanted or candidate.ends_with(wanted) or wanted.ends_with(candidate):
            return bone_index
    return -1

func _same_skeleton(a: Skeleton3D, b: Skeleton3D) -> bool:
    if a.get_bone_count() != b.get_bone_count():
        return false
    for index in range(a.get_bone_count()):
        if a.get_bone_name(index) != b.get_bone_name(index):
            return false
    return true

func _find_skeleton(node: Node) -> Skeleton3D:
    if node is Skeleton3D:
        return node as Skeleton3D
    for child in node.get_children():
        var found := _find_skeleton(child)
        if found != null:
            return found
    return null

func _collect_skinned_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.skin != null and mesh_instance.mesh != null:
            output.append(mesh_instance)
    for child in node.get_children():
        _collect_skinned_meshes(child, output)

func _set_embedded_hair_visible(visible: bool) -> void:
    if model_root == null:
        return
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(model_root, meshes)
    for mesh_instance in meshes:
        if hair_instances.has(mesh_instance) or mesh_instance.mesh == null:
            continue
        for surface in range(mesh_instance.mesh.get_surface_count()):
            var source := mesh_instance.get_active_material(surface)
            var material_name := source.resource_name.to_lower() if source != null else ""
            if not _is_hair_material(material_name):
                continue
            var meta_key := "ara_embedded_hair_material_%d_%d" % [mesh_instance.get_instance_id(), surface]
            if not mesh_instance.has_meta(meta_key):
                mesh_instance.set_meta(meta_key, source)
            var original := mesh_instance.get_meta(meta_key) as Material
            if visible:
                mesh_instance.set_surface_override_material(surface, original)
            else:
                var hidden := original.duplicate() as StandardMaterial3D if original is StandardMaterial3D else StandardMaterial3D.new()
                hidden.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                hidden.albedo_color.a = 0.0
                hidden.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
                mesh_instance.set_surface_override_material(surface, hidden)

func _is_hair_material(material_name: String) -> bool:
    return material_name.contains("hair") or material_name.contains("braid") or material_name.contains("buzz") or material_name.contains("spike")

func _tint_attached_hair(colour: Color) -> void:
    for mesh_instance in hair_instances:
        if not is_instance_valid(mesh_instance) or mesh_instance.mesh == null:
            continue
        for surface in range(mesh_instance.mesh.get_surface_count()):
            var source := mesh_instance.get_active_material(surface)
            var material := source.duplicate() as StandardMaterial3D if source is StandardMaterial3D else StandardMaterial3D.new()
            material.albedo_color = Color(colour.r, colour.g, colour.b, material.albedo_color.a)
            mesh_instance.set_surface_override_material(surface, material)

func _play_idle_if_available() -> void:
    if animation_player == null or not is_instance_valid(animation_player):
        push_warning("Ara character has no AnimationPlayer; it will remain in its exported rest pose.")
        return
    var idle_clip := ""
    for animation_name in animation_player.get_animation_list():
        if String(animation_name).to_lower() == "idle":
            idle_clip = String(animation_name)
            break
        if idle_clip.is_empty() and String(animation_name).to_lower().contains("idle"):
            idle_clip = String(animation_name)
    if idle_clip.is_empty():
        push_warning("Ara character has no idle animation. Available clips: %s" % [", ".join(animation_player.get_animation_list())])
        return
    animation_player.play(idle_clip)

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
    if node is MeshInstance3D:
        output.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_meshes(child, output)

func tint_materials(name_fragment: String, colour: Color) -> int:
    if model_root == null:
        return 0
    var changed := 0
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(model_root, meshes)
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        for surface in range(mesh_instance.mesh.get_surface_count()):
            var source := mesh_instance.get_active_material(surface)
            var material_name := source.resource_name.to_lower() if source != null else ""
            if not material_name.contains(name_fragment.to_lower()) and not mesh_instance.name.to_lower().contains(name_fragment.to_lower()):
                continue
            var original_key := "ara_original_tint_material_%d" % surface
            if not mesh_instance.has_meta(original_key):
                mesh_instance.set_meta(original_key, source)
            var original := mesh_instance.get_meta(original_key) as Material
            var material := original.duplicate() as StandardMaterial3D if original is StandardMaterial3D else StandardMaterial3D.new()
            material.albedo_color = Color(colour.r, colour.g, colour.b, material.albedo_color.a)
            mesh_instance.set_surface_override_material(surface, material)
            changed += 1
    return changed


func apply_body_parameters(profile: Dictionary) -> void:
    if model_root == null:
        return
    var aliases := {
        "muscle": ["muscle", "muscularity", "musclemass", "bodymuscle"],
        "weight": ["weight", "bodyweight", "fat", "bodyfat", "adiposity"],
        "height": ["height", "bodyheight", "stature"],
        "proportions": ["proportion", "proportions", "bodyproportion"],
        "breasts": ["breast", "breasts", "breastsize", "bust", "bustsize", "chestsize"],
        "legs": ["legs", "legsize", "thigh", "thighsize", "calf", "calfsize"]
    }
    var values := {
        "muscle": clampf(float(profile.get("muscle", 0.5)), 0.0, 1.0),
        "weight": clampf(float(profile.get("weight", 0.5)), 0.0, 1.0),
        "height": clampf(float(profile.get("height", 0.5)), 0.0, 1.0),
        "proportions": clampf(float(profile.get("proportions", 0.5)), 0.0, 1.0),
        "breasts": clampf(float(profile.get("breasts", 0.5)), 0.0, 1.0),
        "legs": clampf(float(profile.get("legs", 0.5)), 0.0, 1.0)
    }
    var applied := 0
    var applied_parameters: Dictionary = {}
    var height_morph_applied := false
    var meshes: Array[MeshInstance3D] = []
    _collect_meshes(model_root, meshes)
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        for shape_index in range(mesh_instance.mesh.get_blend_shape_count()):
            var shape_name: String = String(mesh_instance.mesh.get_blend_shape_name(shape_index)).to_lower().replace("_", "").replace("-", "").replace(" ", "")
            for parameter in aliases.keys():
                for alias in aliases[parameter]:
                    if shape_name == alias or shape_name.ends_with(alias):
                        # Body shape keys are authored around the neutral
                        # midpoint (0.5); Godot's relative blend-shape values
                        # therefore run from -0.5 to +0.5.
                        var shape_value: float = float(values[parameter]) - 0.5 if shape_name.begins_with("body") else float(values[parameter])
                        mesh_instance.set_blend_shape_value(shape_index, shape_value)
                        applied += 1
                        applied_parameters[parameter] = true
                        if parameter == "height":
                            height_morph_applied = true
                        break
    # Some Ara exports do not expose a stature blend shape. Preserve the
    # requested height variation with a modest vertical scale in that case.
    var base_scale: Vector3 = get_meta("ara_base_model_scale", model_root.scale)
    if not has_meta("ara_base_model_scale"):
        set_meta("ara_base_model_scale", model_root.scale)
        base_scale = model_root.scale
    model_root.scale = base_scale if height_morph_applied else Vector3(
        base_scale.x,
        base_scale.y * lerpf(0.90, 1.10, values["height"]),
        base_scale.z
    )
    set_meta("body_parameters", values)
    set_meta("body_morph_targets_applied", applied)
    set_meta("body_morph_parameters_applied", applied_parameters)


func _apply_appearance_details(profile: Dictionary) -> void:
    if appearance_details != null and is_instance_valid(appearance_details):
        appearance_details.free()
    appearance_details = null
    var detail_profile: Dictionary = profile.get("character_details", profile)
    var piercings: Array = detail_profile.get("piercings", [])
    var tattoos: Array = detail_profile.get("tattoos", [])
    if model_root == null or (piercings.is_empty() and tattoos.is_empty()):
        return
    appearance_details = ARA_CHARACTER_DETAILS.new() as AraCharacterDetails
    appearance_details.name = "CharacterAppearanceDetails"
    add_child(appearance_details)
    appearance_details.configure(model_root, {
        "piercings": piercings,
        "tattoos": tattoos,
        "tattoo_ink": str(detail_profile.get("tattoo_ink", "#28252d"))
    })

func apply_npc_parameters(params: Dictionary) -> void:
    if model_root == null:
        return
    var gender := int(params.get("gender", 0))
    # Blend the Ara complexion sliders instead of collapsing them into three
    # hard thresholds. An explicit skinTint can refine an individual character.
    var african := maxf(0.0, float(params.get("african", 0.0)))
    var asian := maxf(0.0, float(params.get("asian", 0.0)))
    var caucasian := maxf(0.0, float(params.get("caucasian", 0.0)))
    var complexion_total := african + asian + caucasian
    if complexion_total <= 0.001:
        complexion_total = 1.0
        caucasian = 1.0
    var skin := (
        Color("#70452f") * african
        + Color("#b58a68") * asian
        + Color("#d6a47e") * caucasian
    ) / complexion_total
    if params.has("skinTint"):
        skin = Color.from_string(str(params.get("skinTint")), skin)
    var eye_id := str(params.get("eyes", "brown")).to_lower()
    var eye_map := {
        "brown": "Brown", "brownlight": "Light brown", "darkbrown": "Dark brown",
        "green": "Green", "blue": "Blue", "grey": "Grey",
        "bluegreen": "Blue green", "hazel": "Hazel", "iceblue": "Ice blue"
    }
    var hair_tint := Color.from_string(str(params.get("hairTint", params.get("hairColor", "#49372a"))), Color("#49372a"))
    var profile := {
        "skin_colour": skin.to_html(false),
        "eye_colour": eye_map.get(eye_id, "Brown"),
        "hair_colour": "Dark brown",
        "height": float(params.get("height", 0.5)),
        "muscle": float(params.get("muscle", 0.5)),
        "weight": float(params.get("weight", 0.5)),
        "proportions": float(params.get("proportions", 0.5)),
        "breasts": float(params.get("breasts", 0.5)),
        "legs": float(params.get("legs", 0.5)),
        "body_variant": str(params.get("body_base", "male" if gender == 1 else "female")),
        "gender_presentation": "Masculine" if gender == 1 else "Feminine",
        "pronouns": "they/them"
    }
    apply_player_profile(profile)
    var hair_surfaces_tinted := tint_materials("hair", hair_tint)
    current_hair_colour = hair_tint
    print("[Ara appearance] NPC hair tint=%s base_surfaces=%d style=%s" % [
        hair_tint.to_html(false), hair_surfaces_tinted, str(params.get("hair", "short02"))
    ])
    _apply_appearance_details(params)
