extends Resource
class_name CharacterAppearance
## Runtime appearance data shared by all generated NPCs.
## Store only stable values; generated meshes and imported textures remain assets.

@export var schema_version: int = 1
@export var skin_tint: Color = Color(0.78, 0.57, 0.45, 1.0)
@export var shirt_tint: Color = Color(0.18, 0.30, 0.19, 1.0)
@export var shirt_fabric: String = "wool"
@export var trouser_tint: Color = Color(0.16, 0.16, 0.18, 1.0)
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
		"trouser_tint": trouser_tint.to_html(true),
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
	result.trouser_tint = Color.from_string(str(data.get("trouser_tint", "#29292e")), result.trouser_tint)
	result.hair_tint = Color.from_string(str(data.get("hair_tint", "#202457")), result.hair_tint)
	result.accessory_ids = PackedStringArray(data.get("accessory_ids", []))
	result.tattoo_ids = PackedStringArray(data.get("tattoo_ids", []))
	return result

func apply_to(root: Node) -> void:
	_apply_recursive(root)

func _apply_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var slot := str(node.get_meta("appearance_slot", node.name.to_lower()))
		var tint := _tint_for_slot(slot)
		if tint != Color.TRANSPARENT:
			var material := _get_or_make_material(node)
			material.albedo_color = tint
			if slot == "shirt":
				var fabric: Dictionary = FABRIC_PRESETS.get(shirt_fabric, FABRIC_PRESETS["cotton"])
				material.roughness = float(fabric["roughness"])
				material.metallic = float(fabric["metallic"])
	for child in node.get_children():
		_apply_recursive(child)

func _tint_for_slot(slot: String) -> Color:
	if slot.contains("shirt") or slot.contains("top"):
		return shirt_tint
	if slot.contains("trouser") or slot.contains("pants") or slot.contains("bottom"):
		return trouser_tint
	if slot.contains("hair"):
		return hair_tint
	if slot.contains("skin") or slot.contains("body"):
		return skin_tint
	return Color.TRANSPARENT

func _get_or_make_material(mesh_instance: MeshInstance3D) -> StandardMaterial3D:
	var existing := mesh_instance.material_override
	if existing is StandardMaterial3D:
		return existing
	var material := StandardMaterial3D.new()
	if existing != null:
		material.albedo_color = Color.WHITE
	elif mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() > 0:
		var source := mesh_instance.mesh.surface_get_material(0)
		if source is BaseMaterial3D:
			material.albedo_color = source.albedo_color
			material.roughness = source.roughness
	mesh_instance.material_override = material
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
