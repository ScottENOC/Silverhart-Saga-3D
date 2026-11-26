class_name ElderLocketPickupContent
extends RefCounted
## Idempotent inventory grant for the source-authored chapel locket pickup.

const ITEM_ID := "elder_locket"
const INSTANCE_ID := "elder_locket_chapel_pickup"


static func collect(player: CharacterState) -> Dictionary:
	if player == null:
		return {"ok": false, "reason": "missing_player"}
	for item_value in player.inventory:
		if not item_value is Dictionary:
			continue
		var item: Dictionary = item_value
		if String(item.get("id", "")) == ITEM_ID and int(item.get("quantity", 1)) > 0:
			return {"ok": true, "already_owned": true, "item_id": ITEM_ID}
	var instance := ItemCatalog.create_instance(ITEM_ID, INSTANCE_ID)
	if instance.is_empty():
		return {"ok": false, "reason": "item_definition_missing"}
	if not player.add_inventory_item(instance):
		return {"ok": false, "reason": "inventory_rejected_item"}
	return {"ok": true, "already_owned": false, "item_id": ITEM_ID, "instance_id": INSTANCE_ID}
