class_name CampaignFurnitureCatalog
extends RefCounted
## Shared furniture catalogue, capital shop stock and crafting recipes.

const SHOP_ID := "silverhart_furnishings"
const SHOP_NAME := "Silverhart Furnishings"
const SHOP_LOCATION_ID := "silverhart_palace"

const DEFINITIONS := {
	"bed_single": {
		"name": "Single bed", "category": "sleeping", "sleeping_capacity": 1,
		"footprint": Vector2(2.1, 1.0), "price": 26, "materials": {"wood": 8, "hide": 2}
	},
	"bed_double": {
		"name": "Double bed", "category": "sleeping", "sleeping_capacity": 2,
		"footprint": Vector2(2.2, 1.8), "price": 48, "materials": {"wood": 12, "hide": 4}
	},
	"bed_bunk": {
		"name": "Bunk bed", "category": "sleeping", "sleeping_capacity": 2,
		"footprint": Vector2(2.0, 1.0), "price": 52, "materials": {"wood": 14, "hide": 4}
	},
	"storage_chest": {
		"name": "Storage chest", "category": "storage",
		"footprint": Vector2(1.1, 0.7), "price": 18, "materials": {"wood": 6}
	},
	"dining_table": {
		"name": "Dining table", "category": "social",
		"footprint": Vector2(2.0, 1.0), "price": 28, "materials": {"wood": 8}
	},
	"chair": {
		"name": "Chair", "category": "social",
		"footprint": Vector2(0.65, 0.65), "price": 9, "materials": {"wood": 3}
	},
	"workbench": {
		"name": "Work bench", "category": "crafting",
		"footprint": Vector2(2.0, 1.0), "price": 58, "materials": {"wood": 10, "ore_iron": 2}
	},
	"forge": {
		"name": "Forge and anvil", "category": "crafting",
		"footprint": Vector2(2.5, 1.8), "price": 125, "materials": {"stone": 12, "ore_iron": 8, "wood": 6}
	}
}


static func definition(item_id: String) -> Dictionary:
	var value: Variant = DEFINITIONS.get(item_id, {})
	return value.duplicate(true) if value is Dictionary else {}


static func shop_catalogue() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in DEFINITIONS:
		var entry: Dictionary = definition(String(item_id))
		entry["id"] = String(item_id)
		result.append(entry)
	return result
