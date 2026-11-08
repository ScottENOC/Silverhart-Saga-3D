class_name ItemCatalog
extends RefCounted
## Data-backed item definitions migrated from the original Hex-crpg catalogue.

const DEFINITIONS_PATH := "res://data/items/item_definitions.json"
const ICON_ATLAS_PATH := "res://art/ui/item_icon_atlas.svg"
const ICON_COLUMNS := 8
const ICON_CELL_SIZE := 64

static var _definitions_cache: Dictionary = {}
static var _icon_atlas: Texture2D


static func _definitions() -> Dictionary:
    if not _definitions_cache.is_empty():
        return _definitions_cache
    var file := FileAccess.open(DEFINITIONS_PATH, FileAccess.READ)
    if file == null:
        push_error("Item definitions file is missing: %s" % DEFINITIONS_PATH)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        push_error("Item definitions file is not valid JSON.")
        return {}
    var item_data: Variant = parsed.get("items", {})
    if item_data is Dictionary:
        _definitions_cache = item_data.duplicate(true)
    return _definitions_cache


static func get_item_ids() -> Array[String]:
    var result: Array[String] = []
    for item_id in _definitions().keys():
        result.append(String(item_id))
    result.sort()
    return result


static func get_all_definitions() -> Dictionary:
    return _definitions().duplicate(true)


static func get_definition(item_id: String) -> Dictionary:
    var definitions := _definitions()
    var value: Variant = definitions.get(item_id, {})
    if value is Dictionary:
        return value.duplicate(true)
    return {}


static func create_instance(item_id: String, instance_id: String) -> Dictionary:
    if instance_id.is_empty():
        return {}
    var item := get_definition(item_id)
    if item.is_empty():
        return {}
    item["instance_id"] = instance_id
    item["quantity"] = 1
    return item


static func get_icon_texture(item: Dictionary) -> Texture2D:
    var icon_index := int(item.get("icon_index", -1))
    if icon_index < 0:
        return null
    if _icon_atlas == null:
        _icon_atlas = load(ICON_ATLAS_PATH) as Texture2D
    if _icon_atlas == null:
        return null
    var texture := AtlasTexture.new()
    texture.atlas = _icon_atlas
    var cell_x := float(icon_index % ICON_COLUMNS) * ICON_CELL_SIZE
    var cell_y := float(icon_index / ICON_COLUMNS) * ICON_CELL_SIZE
    texture.region = Rect2(cell_x, cell_y, ICON_CELL_SIZE, ICON_CELL_SIZE)
    return texture
