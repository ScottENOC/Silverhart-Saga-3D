extends RefCounted

## Bridge presentation assembly at the settlement's world-anchored crossing.

const SETTLEMENT = preload("res://data/settlements/hollowmere/settlement_definition.gd")

const BRIDGE := SETTLEMENT.BRIDGE



const BRIDGE_PRESENTATION := {
	"id": "NarrowRiverBridge",
	"centre": BRIDGE,
	"rotation_degrees": -5.0,
	"parts": [
		{"name": "StreamBridgeDeck", "position": Vector3(0.0, 0.18, 0.0), "size": Vector3(2.8, 0.24, 4.8), "material": "timber"},
		{"name": "BridgeRail_Left", "position": Vector3(-1.22, 0.62, 0.0), "size": Vector3(0.16, 0.72, 4.6), "material": "dark_wood"},
		{"name": "BridgeRail_Right", "position": Vector3(1.22, 0.62, 0.0), "size": Vector3(0.16, 0.72, 4.6), "material": "dark_wood"},
		{"name": "BridgePost_Left_North", "position": Vector3(-1.22, 0.55, -2.0), "size": Vector3(0.2, 0.95, 0.2), "material": "timber"},
		{"name": "BridgePost_Left_Centre", "position": Vector3(-1.22, 0.55, 0.0), "size": Vector3(0.2, 0.95, 0.2), "material": "timber"},
		{"name": "BridgePost_Left_South", "position": Vector3(-1.22, 0.55, 2.0), "size": Vector3(0.2, 0.95, 0.2), "material": "timber"},
		{"name": "BridgePost_Right_North", "position": Vector3(1.22, 0.55, -2.0), "size": Vector3(0.2, 0.95, 0.2), "material": "timber"},
		{"name": "BridgePost_Right_Centre", "position": Vector3(1.22, 0.55, 0.0), "size": Vector3(0.2, 0.95, 0.2), "material": "timber"},
		{"name": "BridgePost_Right_South", "position": Vector3(1.22, 0.55, 2.0), "size": Vector3(0.2, 0.95, 0.2), "material": "timber"}
	]
}
