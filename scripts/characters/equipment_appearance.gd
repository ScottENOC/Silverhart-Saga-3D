extends RefCounted
class_name EquipmentAppearance
## Per-instance PBR finishes for medieval equipment. Surface materials are
## duplicated before modification so one character cannot recolour shared assets.

const PROFILES := {
    "steel": {"colour": "#68727c", "metallic": 0.92, "roughness": 0.30},
    "dark_steel": {"colour": "#303943", "metallic": 0.88, "roughness": 0.38},
    "gold": {"colour": "#d6ad45", "metallic": 0.94, "roughness": 0.24},
    "brass": {"colour": "#a97932", "metallic": 0.88, "roughness": 0.30},
    "wood": {"colour": "#704522", "metallic": 0.0, "roughness": 0.82},
    "painted_wood": {"colour": "#9a302b", "metallic": 0.0, "roughness": 0.72},
    "leather": {"colour": "#49301f", "metallic": 0.0, "roughness": 0.78},
    "cloth": {"colour": "#8b2835", "metallic": 0.0, "roughness": 0.92}
}

const METAL_SLOTS := ["blade", "head", "metal", "rim", "boss", "guard", "pommel", "helmet", "plate", "mail", "trim"]
const WOOD_OR_LEATHER_SLOTS := ["haft", "grip", "handle", "stave", "shield_body", "wood"]
const CLOTH_SLOTS := ["banner", "tabard", "surcoat", "cloth"]

## options is keyed by stable surface slot, e.g. {"blade":{"profile":"gold"}}.
## Unsupported profile/slot combinations are rejected rather than silently
## making wood metallic or leather look like polished steel.
static func apply_to(root: Node, options: Dictionary = {}) -> int:
    if root == null:
        return 0
    return _apply_recursive(root, options)

static func _apply_recursive(node: Node, options: Dictionary) -> int:
    var changed := 0
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        if mesh_instance.mesh != null:
            for surface in range(mesh_instance.mesh.get_surface_count()):
                var source := mesh_instance.get_active_material(surface)
                if source == null:
                    continue
                var slot := _surface_slot(mesh_instance, source, surface)
                var requested: Dictionary = options.get(slot, {})
                var category := _category_for_slot(slot, source.resource_name.to_lower())
                var profile_id := str(requested.get("profile", _default_profile(category)))
                if not _profile_allowed(category, profile_id):
                    push_warning("Rejected equipment finish '%s' for surface '%s' (%s)." % [profile_id, slot, category])
                    profile_id = _default_profile(category)
                var profile: Dictionary = PROFILES[profile_id]
                var material := _duplicate_standard(source)
                var tint := Color.from_string(str(requested.get("colour", profile["colour"])), Color(profile["colour"]))
                material.albedo_color = tint
                material.metallic = float(profile["metallic"])
                material.roughness = float(profile["roughness"])
                mesh_instance.set_surface_override_material(surface, material)
                changed += 1
    for child in node.get_children():
        changed += _apply_recursive(child, options)
    return changed

static func _surface_slot(mesh_instance: MeshInstance3D, source: Material, surface: int) -> String:
    var key := "equipment_surface_%d" % surface
    if mesh_instance.has_meta(key):
        return str(mesh_instance.get_meta(key)).to_lower()
    if mesh_instance.has_meta("equipment_slot"):
        return str(mesh_instance.get_meta("equipment_slot")).to_lower()
    var material_name := source.resource_name.to_lower().replace(" ", "_").replace("-", "_")
    if not material_name.is_empty():
        return material_name
    return mesh_instance.name.to_lower().replace(" ", "_")

static func _category_for_slot(slot: String, material_name: String) -> String:
    var combined := slot + "_" + material_name
    if _contains_any(combined, ["wood", "oak", "haft", "stave", "shield_body"]):
        return "wood"
    if _contains_any(combined, ["leather", "grip", "handle", "wrap"]):
        return "leather"
    if _contains_any(combined, ["cloth", "banner", "tabard", "surcoat"]):
        return "cloth"
    if _contains_any(combined, ["gold", "brass"]):
        return "metal"
    if _contains_any(combined, METAL_SLOTS):
        return "metal"
    return "neutral"

static func _contains_any(value: String, fragments: Array) -> bool:
    for fragment in fragments:
        if value.contains(str(fragment)):
            return true
    return false

static func _default_profile(category: String) -> String:
    match category:
        "wood": return "wood"
        "leather": return "leather"
        "cloth": return "cloth"
        "metal": return "steel"
        _: return "steel"

static func _profile_allowed(category: String, profile_id: String) -> bool:
    if not PROFILES.has(profile_id):
        return false
    match category:
        "wood": return profile_id in ["wood", "painted_wood"]
        "leather": return profile_id == "leather"
        "cloth": return profile_id == "cloth"
        "metal": return profile_id in ["steel", "dark_steel", "gold", "brass"]
        _: return profile_id in ["steel", "dark_steel", "gold", "brass", "wood", "leather", "cloth"]


## Apply heraldry only to the dedicated front-face surface exported by the
## shield builder. Pattern and emblem are data values, not unique shield meshes.
static func apply_shield_heraldry(root: Node, design: Dictionary) -> int:
    if root == null:
        return 0
    var shader := load("res://shaders/shield_heraldry.gdshader") as Shader
    if shader == null:
        push_warning("Shield heraldry shader is unavailable.")
        return 0
    var changed := 0
    var patterns := {"plain": 0, "halves_vertical": 1, "halves_horizontal": 2, "diagonal": 3, "stripe": 4, "cross": 5}
    var emblems := {"none": 0, "roundel": 1, "cross": 2, "lozenge": 3, "star": 4, "tree": 5}
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is MeshInstance3D:
            var mesh_instance := node as MeshInstance3D
            if mesh_instance.mesh != null:
                for surface in range(mesh_instance.mesh.get_surface_count()):
                    var source := mesh_instance.get_active_material(surface)
                    if source == null or not source.resource_name.to_lower().replace(" ", "").contains("heraldryface"):
                        continue
                    var material := ShaderMaterial.new()
                    material.shader = shader
                    material.set_shader_parameter("field_colour", Color.from_string(str(design.get("field_colour", "#9e2424")), Color("#9e2424")))
                    material.set_shader_parameter("secondary_colour", Color.from_string(str(design.get("secondary_colour", "#e7dfc6")), Color("#e7dfc6")))
                    material.set_shader_parameter("emblem_colour", Color.from_string(str(design.get("emblem_colour", "#20232a")), Color("#20232a")))
                    material.set_shader_parameter("field_pattern", int(patterns.get(str(design.get("pattern", "plain")), 0)))
                    material.set_shader_parameter("emblem", int(emblems.get(str(design.get("emblem", "none")), 0)))
                    material.set_shader_parameter("border_width", clampf(float(design.get("border_width", 0.0)), 0.0, 0.18))
                    mesh_instance.set_surface_override_material(surface, material)
                    changed += 1
        for child in node.get_children():
            stack.append(child)
    return changed

static func _duplicate_standard(source: Material) -> StandardMaterial3D:
    if source is StandardMaterial3D:
        return (source as StandardMaterial3D).duplicate() as StandardMaterial3D
    var result := StandardMaterial3D.new()
    if source is BaseMaterial3D:
        var base := source as BaseMaterial3D
        result.albedo_color = base.albedo_color
        result.roughness = base.roughness
        result.metallic = base.metallic
    return result
