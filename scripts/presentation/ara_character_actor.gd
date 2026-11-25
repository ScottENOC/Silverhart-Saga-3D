class_name AraCharacterActor
extends Node3D

const ARA_CHARACTER_DETAILS = preload("res://scripts/presentation/ara_character_details.gd")
const ARA_ANIMATION_CARRIER_PATH := "res://art/characters/ara_runtime/ara_person_benchmark.glb"
const ARA_SKELETON_RETARGETER = preload("res://scripts/presentation/ara_skeleton_retargeter.gd")
## Ara GLB exports face +Z; the world actor convention faces -Z at zero yaw.
const MODEL_FORWARD_YAW_OFFSET: float = PI
## Runtime wrapper for generated Ara GLBs. The selected body asset is supplied
## by the player profile so Workshop exports can be replaced without code edits.

var model_root: Node3D
var animation_source_root: Node3D
var skeleton_retargeter: SkeletonModifier3D
var animation_player: AnimationPlayer
var portrait_renderer: CharacterPortraitRenderer
var loaded_asset_path: String = ""
var hair_instances: Array[MeshInstance3D] = []
var garment_attachments: Dictionary = {}
var equipment_attachments: Dictionary = {}
var body_variant: String = "female"
var appearance_details: AraCharacterDetails
const GARMENT_ASSET_ROOT := "res://art/characters/ara_runtime/garments/"
const EQUIPMENT_PROP_ROOT := "res://art/characters/ara_runtime/props/"
const GARMENT_VISUALS := ["bra", "briefs", "long_tunic", "trousers", "tunic", "wrapper_long", "uniform_shirt", "fatigue_pants", "wrapper_knee", "tattered_shirt", "fatigue_shirt", "sandals", "combat_boots", "leather armor"]
var current_hair_colour: Color = Color("#49372a")

func configure(glb_path: String) -> bool:
	if model_root != null and is_instance_valid(model_root):
		remove_child(model_root)
		model_root.queue_free()
	if animation_source_root != null and is_instance_valid(animation_source_root):
		remove_child(animation_source_root)
		animation_source_root.queue_free()
	model_root = null
	animation_source_root = null
	skeleton_retargeter = null
	animation_player = null
	hair_instances.clear()
	_clear_garment_attachments()
	loaded_asset_path = ""
	if not ResourceLoader.exists(glb_path):
		push_warning("Ara character asset is not installed: " + glb_path)
		return false
	var body_packed := load(glb_path) as PackedScene
	if body_packed == null:
		push_warning("Ara character GLB could not be loaded: " + glb_path)
		return false
	var body_root := body_packed.instantiate() as Node3D
	if body_root == null:
		push_warning("Ara character root is not Node3D: " + glb_path)
		return false

	# Keep each imported character's own Skeleton3D and skin binding. The
	# benchmark is an animation source only; its pose deltas are retargeted
	# onto the character's native bone rests by AraSkeletonRetargeter.
	var carrier_root: Node3D
	if ResourceLoader.exists(ARA_ANIMATION_CARRIER_PATH):
		var carrier_packed := load(ARA_ANIMATION_CARRIER_PATH) as PackedScene
		if carrier_packed != null:
			carrier_root = carrier_packed.instantiate() as Node3D

	var body_skeleton := _find_skeleton(body_root)
	var carrier_skeleton := _find_skeleton(carrier_root) if carrier_root != null else null
	var carrier_animation_player := _find_animation_player(carrier_root) if carrier_root != null else null
	var retargeted := false
	if body_skeleton != null and carrier_skeleton != null and carrier_animation_player != null:
		# Keep the source skeleton and AnimationPlayer alive, but hide its
		# benchmark meshes. No character mesh is reparented or rebound.
		var carrier_meshes: Array[MeshInstance3D] = []
		_collect_meshes(carrier_root, carrier_meshes)
		for mesh in carrier_meshes:
			mesh.visible = false
		skeleton_retargeter = ARA_SKELETON_RETARGETER.new() as SkeletonModifier3D
		skeleton_retargeter.name = "AraAnimationRetargeter"
		var mapped_bones: int = skeleton_retargeter.configure(carrier_skeleton, body_skeleton)
		if mapped_bones >= 20:
			animation_source_root = carrier_root
			animation_source_root.name = "AraAnimationSource"
			add_child(animation_source_root)
			model_root = body_root
			model_root.name = "AraModel"
			add_child(model_root)
			body_skeleton.add_child(skeleton_retargeter)
			animation_player = carrier_animation_player
			retargeted = true
		else:
			push_warning("Ara character '%s' only maps %d animation bones; leaving its native rig unmodified." % [glb_path, mapped_bones])
			skeleton_retargeter.free()
			skeleton_retargeter = null
	if not retargeted:
		if carrier_root != null and is_instance_valid(carrier_root) and carrier_root.get_parent() == null:
			carrier_root.free()
		model_root = body_root
		model_root.name = "AraModel"
		add_child(model_root)
		animation_player = _find_animation_player(model_root)
		if body_skeleton != null and ResourceLoader.exists(ARA_ANIMATION_CARRIER_PATH):
			push_warning("Ara animation retargeting unavailable; retaining native character rig: " + glb_path)

	model_root.name = "AraModel"
	model_root.rotation.y += MODEL_FORWARD_YAW_OFFSET
	loaded_asset_path = glb_path
	if portrait_renderer == null:
		portrait_renderer = CharacterPortraitRenderer.new()
		portrait_renderer.name = "PortraitRenderer"
		add_child(portrait_renderer)
	portrait_renderer.configure(model_root)
	if animation_player == null:
		animation_player = _find_animation_player(model_root)
	call_deferred("_play_idle_if_available")
	call_deferred("_dump_garment_surface_report")
	return true
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
		# Garment GLBs may nest skinned meshes beneath transformed scene nodes.
		# Reparenting the mesh directly under model_root without carrying that
		# accumulated transform moves the garment away from its bind pose (in
		# practice, underwear can appear at the head or far from the body).
		instance.transform = _transform_from_scene_root(source_mesh, source_root)
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


## Return a Node3D's accumulated local transform in its imported scene-root
## coordinate frame. This is required when flattening imported GLB hierarchies.
func _transform_from_scene_root(node: Node3D, scene_root: Node3D) -> Transform3D:
	var chain: Array[Transform3D] = []
	var cursor: Node = node
	while cursor != null and cursor != scene_root:
		if cursor is Node3D:
			chain.push_front((cursor as Node3D).transform)
		cursor = cursor.get_parent()
	if cursor != scene_root:
		push_warning("Ara attachment mesh is not a descendant of its imported scene root")
		return Transform3D.IDENTITY
	var result := scene_root.transform
	for local_transform in chain:
		result = result * local_transform
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

	# Shared Ara runtime bases use modular equipment. Native companion and
	# Hollowmere GLBs may contain authored outfits; keep those baked surfaces
	# visible because no complete male/female garment pack is installed yet.
	if model_root != null and not loaded_asset_path.contains("/hollowmere/") and not loaded_asset_path.contains("/companions/"):
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
	refresh_portrait()


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
	var next_body_variant := str(profile.get("body_variant", "female"))
	if next_body_variant != body_variant:
		_clear_garment_attachments()
	body_variant = next_body_variant
	set_meta("body_variant", body_variant)
	set_meta("gender_presentation", str(profile.get("gender_presentation", "Feminine")))
	set_meta("pronouns", str(profile.get("pronouns", "they/them")))
	_apply_appearance_details(profile)
	if body_variant == "male":
		apply_male_anatomy_size(
			float(profile.get("male_anatomy_length_scale", 1.0)),
			float(profile.get("male_anatomy_girth_scale", 1.0))
		)
	refresh_portrait()

## Apply independent, measured-range size multipliers to the dedicated anatomy rig.
## AnatomyRoot is the parent of the shaft chain, so one local scale affects both
## flaccid and erect morph states without changing the rest of the body.
func apply_male_anatomy_size(length_scale: float, girth_scale: float) -> bool:
	if model_root == null or body_variant != "male":
		return false
	var skeleton := _find_skeleton(model_root)
	if skeleton == null:
		return false
	var root_bone := skeleton.find_bone("AnatomyRoot")
	if root_bone < 0:
		push_warning("Male anatomy size controls unavailable: AnatomyRoot is missing from %s" % loaded_asset_path)
		return false
	var base_scale: Vector3
	if has_meta("male_anatomy_base_pose_scale"):
		base_scale = get_meta("male_anatomy_base_pose_scale")
	else:
		base_scale = skeleton.get_bone_pose_scale(root_bone)
		set_meta("male_anatomy_base_pose_scale", base_scale)
	var safe_length := clampf(length_scale, 0.70, 1.30)
	var safe_girth := clampf(girth_scale, 0.70, 1.30)
	skeleton.set_bone_pose_scale(root_bone, base_scale * Vector3(safe_girth, safe_length, safe_girth))
	set_meta("male_anatomy_size_scales", {"length": safe_length, "girth": safe_girth})
	return true

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
		instance.transform = _transform_from_scene_root(source_mesh, source_root)
		model_root.add_child(instance)
		instance.skeleton = instance.get_path_to(target_skeleton)
		hair_instances.append(instance)
	source_root.free()
	if hair_instances.is_empty():
		_set_embedded_hair_visible(true)
		return false
	_tint_attached_hair(current_hair_colour)
	refresh_portrait()
	return true

func clear_hairstyle() -> void:
	for instance in hair_instances:
		if is_instance_valid(instance):
			instance.queue_free()
	hair_instances.clear()
	_set_embedded_hair_visible(true)
	refresh_portrait()

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
		# Convert the original bind pose from the source rig into the target
		# rig's rest space. Replacing it with only target_rest.affine_inverse()
		# loses any mesh-space offset encoded by the source GLB's inverse bind
		# matrix; that can make an otherwise valid hairstyle float above the
		# scalp. At rest, target_rest * converted_bind must equal the original
		# source_rest * source_bind transform.
		var source_rest := target_skeleton.get_bone_global_rest(target_bone_index)
		if source_bone_index >= 0 and source_bone_index < source_skeleton.get_bone_count():
			source_rest = source_skeleton.get_bone_global_rest(source_bone_index)
		var source_bind := remapped_skin.get_bind_pose(bind_index)
		var target_rest := target_skeleton.get_bone_global_rest(target_bone_index)
		var converted_bind := target_rest.affine_inverse() * source_rest * source_bind
		remapped_skin.set_bind_pose(bind_index, converted_bind)

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

## Extend the shared animation rig with source-only character bones.
## Male body exports append anatomy bones for independently controlled poses;
## ordinary clips leave these bones alone unless they contain explicit tracks.
## Keeping the shared prefix unchanged preserves the Skin's original bone indices.
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
			var mesh_name := mesh_instance.name.to_lower()
			var surface_name: String = String(mesh_instance.mesh.surface_get_name(surface)).to_lower()
			# Ara exports do not always preserve a useful material resource name.
			# Inspect the mesh and surface labels as well, otherwise the embedded
			# default hairstyle can remain visible under the selected replacement.
			var hair_identity: String = material_name + " " + mesh_name + " " + surface_name
			if not _is_hair_material(hair_identity):
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


func get_portrait_texture() -> Texture2D:
	return portrait_renderer.get_texture() if portrait_renderer != null else null


func set_portrait_live(enabled: bool) -> void:
	if portrait_renderer != null:
		portrait_renderer.set_live(enabled)


func set_portrait_expression(expression: String) -> void:
	if portrait_renderer != null:
		portrait_renderer.set_expression(expression)


func refresh_portrait() -> void:
	if portrait_renderer != null and model_root != null and is_instance_valid(model_root):
		portrait_renderer.refresh_source(model_root)


## Play the closest shipped Ara clip for a camp job. Looping clips stay active;
## one-shot interactions are replayed after they finish by the camp director.
static func camp_activity_animation_hints(activity: String) -> PackedStringArray:
	match activity:
		"gather_wood":
			return PackedStringArray(["pick_up", "carry_idle"])
		"set_up_tents":
			return PackedStringArray(["pick_up", "use_press"])
		"fetch_water", "care_horse_water":
			return PackedStringArray(["pick_up", "carry_idle"])
		"care_horse_feed", "care_horse_groom", "care_horse_tether":
			return PackedStringArray(["use_press"])
		"cook":
			return PackedStringArray(["use_press"])
		"repair_gear":
			return PackedStringArray(["use_press"])
		"study_map":
			return PackedStringArray(["use_press"])
		# The current Ara package has no dedicated squat/push-up, talk-gesture
		# or lookout clips. Use its real crouch, Talk and Idle clips instead.
		"train":
			return PackedStringArray(["crouch_idle", "jump"])
		"socialise":
			return PackedStringArray(["talk", "idle"])
		"watch":
			return PackedStringArray(["idle"])
		"sleep":
			return PackedStringArray(["sleep", "lie_down"])
		"wake":
			return PackedStringArray(["stretch", "idle"])
		"dress":
			return PackedStringArray(["use_press", "pick_up"])
		"breakfast":
			return PackedStringArray(["use_press", "sit", "idle"])
		"extinguish_fire":
			return PackedStringArray(["pick_up", "crouch_idle", "use_press"])
		"pack_camp":
			return PackedStringArray(["pick_up", "carry_idle"])
		_:
			return PackedStringArray(["idle"])

func play_camp_activity(activity: String) -> bool:
	if animation_player == null or not is_instance_valid(animation_player):
		return false
	var current := String(animation_player.current_animation).to_lower()
	var current_playing := animation_player.is_playing()
	var preferred: Array[String] = []
	for hint in camp_activity_animation_hints(activity):
		preferred.append(String(hint))
	var clip := ""
	if activity == "gather_wood" or activity == "set_up_tents" or activity == "fetch_water":
		var pickup := _find_animation_clip(["pick_up"])
		var follow_up := _find_animation_clip(["carry_idle"] if activity != "set_up_tents" else ["use_press"])
		if pickup.is_empty():
			clip = follow_up
		elif current == pickup.to_lower() and current_playing:
			return true
		elif current == follow_up.to_lower() and current_playing:
			return true
		elif current == pickup.to_lower() and not current_playing and not follow_up.is_empty():
			clip = follow_up
		else:
			clip = pickup
	elif activity == "sleep":
		var lie_down := _find_animation_clip(["lie_down"])
		var sleep := _find_animation_clip(["sleep"])
		if current == lie_down.to_lower() and current_playing:
			return true
		if current == sleep.to_lower() and current_playing:
			return true
		clip = sleep if lie_down.is_empty() or (current == lie_down.to_lower() and not current_playing) else lie_down
	else:
		clip = _find_animation_clip(preferred)
	if clip.is_empty():
		return false
	if animation_player.current_animation == StringName(clip) and animation_player.is_playing():
		return true
	animation_player.play(clip, 0.18)
	return true


func set_moving(is_moving: bool) -> bool:
	if animation_player == null or not is_instance_valid(animation_player):
		return false
	var clip := _find_animation_clip(["walk", "locomotion", "run"]) if is_moving else _find_animation_clip(["idle", "stand"])
	if clip.is_empty():
		return false
	if animation_player.current_animation == clip and animation_player.is_playing():
		return true
	animation_player.play(clip, 0.12)
	return true

func play_walk() -> bool:
	return set_moving(true)

func play_idle() -> bool:
	return set_moving(false)

func _find_animation_clip(preferred_tokens: Array) -> String:
	if animation_player == null:
		return ""
	var available := animation_player.get_animation_list()
	for token_value in preferred_tokens:
		var token := _normalise_animation_token(String(token_value))
		if token.is_empty():
			continue
		for animation_name in available:
			if _normalise_animation_token(String(animation_name)) == token:
				return String(animation_name)
		for animation_name in available:
			if _normalise_animation_token(String(animation_name)).contains(token):
				return String(animation_name)
	return ""


## Ara exports may use CamelCase or spaced clip labels while gameplay uses
## snake_case semantic hints. Compare names independently of separators.
func _normalise_animation_token(value: String) -> String:
	var normalized := value.to_lower()
	for separator in ["_", "-", " ", ".", ":"]:
		normalized = normalized.replace(separator, "")
	return normalized

func _play_idle_if_available() -> void:
	if animation_player == null or not is_instance_valid(animation_player):
		push_warning("Ara character has no AnimationPlayer; it will remain in its exported rest pose.")
		return
	if not play_idle():
		push_warning("Ara character has no idle animation. Available clips: %s" % [", ".join(animation_player.get_animation_list())])
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
		"body_variant": "male" if gender == 1 else "female",
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
	refresh_portrait()
