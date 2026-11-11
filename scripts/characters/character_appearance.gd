extends Resource
class_name CharacterAppearance
## Serializable NPC appearance. Material instances are duplicated per surface so
## recolouring one character never mutates a shared imported GLB material.

@export var schema_version: int = 1
@export var skin_tint: Color = Color(0.78, 0.57, 0.45, 1.0)
@export var shirt_tint: Color = Color(0.18, 0.30, 0.19, 1.0)
@export var shirt_fabric: String = "wool"
@export_range(0.0, 1.0, 0.01) var shirt_opacity: float = 1.0
@export var shirt_visible: bool = true
@export var bra_tint: Color = Color(0.18, 0.18, 0.20, 1.0)
@export_range(0.0, 1.0, 0.01) var bra_opacity: float = 1.0
@export var bra_visible: bool = true
@export var briefs_tint: Color = Color(0.20, 0.20, 0.22, 1.0)
@export_range(0.0, 1.0, 0.01) var briefs_opacity: float = 1.0
@export var briefs_visible: bool = true
@export var trouser_tint: Color = Color(0.16, 0.16, 0.18, 1.0)
@export_range(0.0, 1.0, 0.01) var trouser_opacity: float = 1.0
@export var trousers_visible: bool = true
@export var hair_tint: Color = Color(0.12, 0.14, 0.34, 1.0)
@export var accessory_ids: PackedStringArray = []
@export var tattoo_ids: PackedStringArray = []

const FABRIC_PRESETS := {
	"cotton": {"roughness": 0.88, "metallic": 0.0},
	"linen": {"roughness": 0.96, "metallic": 0.0},
	"wool": {"roughness": 0.98, "metallic": 0.0},
	"leather": {"roughness": 0.72, "metallic": 0.0},
	"silk": {"roughness": 0.34, "metallic": 0.0}
}

func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"skin_tint": skin_tint.to_html(true),
		"shirt_tint": shirt_tint.to_html(true),
		"shirt_fabric": shirt_fabric,
		"shirt_opacity": shirt_opacity,
		"shirt_visible": shirt_visible,
		"bra_tint": bra_tint.to_html(true),
		"bra_opacity": bra_opacity,
		"bra_visible": bra_visible,
		"briefs_tint": briefs_tint.to_html(true),
		"briefs_opacity": briefs_opacity,
		"briefs_visible": briefs_visible,
		"trouser_tint": trouser_tint.to_html(true),
		"trouser_opacity": trouser_opacity,
		"trousers_visible": trousers_visible,
		"hair_tint": hair_tint.to_html(true),
		"accessory_ids": Array(accessory_ids),
		"tattoo_ids": Array(tattoo_ids)
	}

static func from_dict(data: Dictionary) -> CharacterAppearance:
	var result := CharacterAppearance.new()
	result.schema_version = int(data.get("schema_version", 1))
	result.skin_tint = Color.from_string(str(data.get("skin_tint", "#c79173")), result.skin_tint)
	result.shirt_tint = Color.from_string(str(data.get("shirt_tint", "#2e4d31")), result.shirt_tint)
	result.shirt_fabric = str(data.get("shirt_fabric", "wool"))
	result.shirt_opacity = clampf(float(data.get("shirt_opacity", 1.0)), 0.0, 1.0)
	result.shirt_visible = bool(data.get("shirt_visible", true))
	result.bra_tint = Color.from_string(str(data.get("bra_tint", "#2e2e33")), result.bra_tint)
	result.bra_opacity = clampf(float(data.get("bra_opacity", 1.0)), 0.0, 1.0)
	result.bra_visible = bool(data.get("bra_visible", true))
	result.briefs_tint = Color.from_string(str(data.get("briefs_tint", "#333338")), result.briefs_tint)
	result.briefs_opacity = clampf(float(data.get("briefs_opacity", 1.0)), 0.0, 1.0)
	result.briefs_visible = bool(data.get("briefs_visible", true))
	result.trouser_tint = Color.from_string(str(data.get("trouser_tint", "#29292e")), result.trouser_tint)
	result.trouser_opacity = clampf(float(data.get("trouser_opacity", 1.0)), 0.0, 1.0)
	result.trousers_visible = bool(data.get("trousers_visible", true))
	result.hair_tint = Color.from_string(str(data.get("hair_tint", "#202457")), result.hair_tint)
	result.accessory_ids = PackedStringArray(data.get("accessory_ids", []))
	result.tattoo_ids = PackedStringArray(data.get("tattoo_ids", []))
	return result

func apply_to(root: Node) -> void:
	if root == null:
		return
	_apply_recursive(root)

func _apply_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var has_clothing := false
			var all_hidden := true
			for surface in range(mesh_instance.mesh.get_surface_count()):
				var slot := _slot_for_surface(mesh_instance, surface)
				var tint := _tint_for_slot(slot)
				if tint != Color.TRANSPARENT:
					_apply_surface_material(mesh_instance, tint, slot, _opacity_for_slot(slot), surface)
				if _is_shirt_slot(slot) or _is_bra_slot(slot) or _is_briefs_slot(slot) or _is_trouser_slot(slot):
					has_clothing = true
					if _visible_for_slot(slot):
						all_hidden = false
			if has_clothing:
				mesh_instance.visible = not all_hidden
	for child in node.get_children():
		_apply_recursive(child)

func _slot_for_surface(mesh_instance: MeshInstance3D, surface: int) -> String:
	if mesh_instance.has_meta("appearance_slot"):
		return str(mesh_instance.get_meta("appearance_slot")).to_lower()
	var material := _source_surface_material(mesh_instance, surface)
	if material != null and not material.resource_name.is_empty():
		return material.resource_name.to_lower()
	return mesh_instance.name.to_lower()

func _visible_for_slot(slot: String) -> bool:
	if _is_shirt_slot(slot):
		return shirt_visible
	if _is_bra_slot(slot):
		return bra_visible
	if _is_briefs_slot(slot):
		return briefs_visible
	if _is_trouser_slot(slot):
		return trousers_visible
	return true

func _is_shirt_slot(slot: String) -> bool:
	return slot.contains("shirt") or slot.contains("top") or slot.contains("jacket")

func _is_bra_slot(slot: String) -> bool:
	return slot.contains("bra")

func _is_briefs_slot(slot: String) -> bool:
	return slot.contains("brief") or slot.contains("underwear")

func _is_trouser_slot(slot: String) -> bool:
	return slot.contains("trouser") or slot.contains("pants") or slot.contains("bottom")

func _opacity_for_slot(slot: String) -> float:
	if _is_shirt_slot(slot):
		return shirt_opacity
	if _is_bra_slot(slot):
		return bra_opacity
	if _is_briefs_slot(slot):
		return briefs_opacity
	if _is_trouser_slot(slot):
		return trouser_opacity
	return 1.0

func _tint_for_slot(slot: String) -> Color:
	if _is_shirt_slot(slot):
		return shirt_tint
	if _is_bra_slot(slot):
		return bra_tint
	if _is_briefs_slot(slot):
		return briefs_tint
	if _is_trouser_slot(slot):
		return trouser_tint
	if slot.contains("hair"):
		return hair_tint
	if slot.contains("skin") or slot == "body":
		return skin_tint
	return Color.TRANSPARENT

func _apply_surface_material(mesh_instance: MeshInstance3D, tint: Color, slot: String, opacity: float, surface: int) -> void:
	if mesh_instance.mesh == null or surface < 0 or surface >= mesh_instance.mesh.get_surface_count():
		return
	var base_key := "appearance_base_material_%d" % surface
	var source: Material
	if mesh_instance.has_meta(base_key):
		source = mesh_instance.get_meta(base_key) as Material
	else:
		source = _source_surface_material(mesh_instance, surface)
		if source != null:
			mesh_instance.set_meta(base_key, source)
	if source == null:
		return
	var material := _make_tinted_material(source, tint, slot, opacity)
	mesh_instance.set_surface_override_material(surface, material)

func _source_surface_material(mesh_instance: MeshInstance3D, surface: int) -> Material:
	# Avoid relying on a RenderingServer instance: these meshes are also used by
	# headless appearance tests and by character previews before scene instancing.
	var material := mesh_instance.get_surface_override_material(surface)
	if material == null:
		material = mesh_instance.material_override
	if material == null and mesh_instance.mesh != null and surface >= 0 and surface < mesh_instance.mesh.get_surface_count():
		material = mesh_instance.mesh.surface_get_material(surface)
	return material

func _make_tinted_material(source: Material, tint: Color, slot: String, opacity: float) -> StandardMaterial3D:
	var material: StandardMaterial3D
	if source is StandardMaterial3D:
		material = (source as StandardMaterial3D).duplicate() as StandardMaterial3D
	elif source is BaseMaterial3D:
		var base := source as BaseMaterial3D
		material = StandardMaterial3D.new()
		material.albedo_color = base.albedo_color
		material.roughness = base.roughness
		material.metallic = base.metallic
	else:
		material = StandardMaterial3D.new()
	# Preserve the imported albedo map and multiply it by the selected dye colour.
	material.albedo_color = material.albedo_color * tint
	material.albedo_color.a *= clampf(opacity, 0.0, 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if opacity < 0.999 else BaseMaterial3D.TRANSPARENCY_DISABLED
	if _is_shirt_slot(slot) or _is_bra_slot(slot):
		var fabric: Dictionary = FABRIC_PRESETS.get(shirt_fabric, FABRIC_PRESETS["cotton"])
		material.roughness = float(fabric["roughness"])
		material.metallic = float(fabric["metallic"])
	return material

func save_json(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return OK

static func load_json(path: String) -> CharacterAppearance:
	if not FileAccess.file_exists(path):
		return CharacterAppearance.new()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return CharacterAppearance.new()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return from_dict(parsed)
	return CharacterAppearance.new()
