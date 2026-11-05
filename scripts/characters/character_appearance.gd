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
		var slot := str(mesh_instance.get_meta("appearance_slot", mesh_instance.name.to_lower())).to_lower()
		var tint := _tint_for_slot(slot)
		if _is_shirt_slot(slot):
			mesh_instance.visible = shirt_visible
		elif _is_trouser_slot(slot):
			mesh_instance.visible = trousers_visible
		if tint != Color.TRANSPARENT:
			_apply_surface_materials(mesh_instance, tint, slot, _opacity_for_slot(slot))
	for child in node.get_children():
		_apply_recursive(child)

func _is_shirt_slot(slot: String) -> bool:
	return slot.contains("shirt") or slot.contains("top") or slot.contains("jacket")

func _is_trouser_slot(slot: String) -> bool:
	return slot.contains("trouser") or slot.contains("pants") or slot.contains("bottom")

func _opacity_for_slot(slot: String) -> float:
	if _is_shirt_slot(slot):
		return shirt_opacity
	if _is_trouser_slot(slot):
		return trouser_opacity
	return 1.0

func _tint_for_slot(slot: String) -> Color:
	if _is_shirt_slot(slot):
		return shirt_tint
	if _is_trouser_slot(slot):
		return trouser_tint
	if slot.contains("hair"):
		return hair_tint
	if slot.contains("skin") or slot == "body":
		return skin_tint
	return Color.TRANSPARENT

func _apply_surface_materials(mesh_instance: MeshInstance3D, tint: Color, slot: String, opacity: float) -> void:
	if mesh_instance.mesh == null:
		return
	var surface_count := mesh_instance.mesh.get_surface_count()
	if surface_count == 0:
		# Procedural meshes may have no surfaces until generated.
		return
	for surface in range(surface_count):
		var base_key := "appearance_base_material_%d" % surface
		var source: Material
		if mesh_instance.has_meta(base_key):
			source = mesh_instance.get_meta(base_key) as Material
		else:
			source = mesh_instance.get_active_material(surface)
			if source != null:
				mesh_instance.set_meta(base_key, source)
		var material := _make_tinted_material(source, tint, slot, opacity)
		mesh_instance.set_surface_override_material(surface, material)

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
	if _is_shirt_slot(slot):
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
