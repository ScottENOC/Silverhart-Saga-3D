class_name CharacterAppearance
extends Resource

## Serializable visual state. Gameplay inventory remains authoritative; this resource
## stores the presentation IDs and per-item material choices needed to rebuild a look.

@export var body_variant: String = "ara_female_slim"
@export var skin_tint: Color = Color.WHITE
@export var hair_id: String = "long01"
@export var hair_tint: Color = Color("#252b62")
@export var face_variant: String = "face_a"
@export var tattoos: Array[String] = []
@export var accessories: Dictionary = {}
@export var equipment: Dictionary = {
    "shirt": "fatigue_shirt",
    "trousers": "fatigue_pants",
    "boots": "combat_boots",
    "torso_armour": "",
    "leg_armour": "",
    "main_hand": "sword",
    "off_hand": ""
}
@export var materials: Dictionary = {
    "shirt": {"colour": "#244b2b", "secondary": "#d94a72", "fabric": "solid", "opacity": 1.0}
}

func to_dict() -> Dictionary:
    return {
        "version": 1,
        "body_variant": body_variant,
        "skin_tint": skin_tint.to_html(true),
        "hair_id": hair_id,
        "hair_tint": hair_tint.to_html(true),
        "face_variant": face_variant,
        "tattoos": tattoos.duplicate(),
        "accessories": accessories.duplicate(true),
        "equipment": equipment.duplicate(true),
        "materials": materials.duplicate(true)
    }

static func from_dict(data: Dictionary) -> CharacterAppearance:
    var result := CharacterAppearance.new()
    result.body_variant = str(data.get("body_variant", result.body_variant))
    result.skin_tint = Color.from_string(str(data.get("skin_tint", "#ffffff")), Color.WHITE)
    result.hair_id = str(data.get("hair_id", result.hair_id))
    result.hair_tint = Color.from_string(str(data.get("hair_tint", "#252b62")), Color("#252b62"))
    result.face_variant = str(data.get("face_variant", result.face_variant))
    var tattoo_values: Variant = data.get("tattoos", [])
    if tattoo_values is Array:
        for value in tattoo_values:
            result.tattoos.append(str(value))
    var accessory_values: Variant = data.get("accessories", {})
    if accessory_values is Dictionary:
        result.accessories = accessory_values.duplicate(true)
    var equipment_values: Variant = data.get("equipment", {})
    if equipment_values is Dictionary:
        result.equipment.merge(equipment_values, true)
    var material_values: Variant = data.get("materials", {})
    if material_values is Dictionary:
        result.materials = material_values.duplicate(true)
    return result
