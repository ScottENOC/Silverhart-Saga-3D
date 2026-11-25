extends RefCounted
## Authored partitions, room labels and shared furnishings for the Hollow Tankard upper floor.
## Bed anchors are authored axial placements and are rendered by the shared interior presenter.

const DEFINITION := {
	"id": "UpperRoomPresentation",
	"features": [
		{"name":"WestPartitionNorth","position":Vector3(0.0,4.85,-3.15),"size":Vector3(0.22,2.9,4.7),"material":"timber"},
		{"name":"WestPartitionSouth","position":Vector3(0.0,4.85,3.15),"size":Vector3(0.22,2.9,4.7),"material":"timber"},
		{"name":"EastPartitionNorth","position":Vector3(2.95,4.85,0.0),"size":Vector3(2.9,2.9,0.22),"material":"timber"},
		{"name":"EastPartitionSouth","position":Vector3(7.4,4.85,0.0),"size":Vector3(1.2,2.9,0.22),"material":"timber"},
		{"kind":"label","name":"GarrickRoomLabel","text":"GARRICK'S ROOM","position":Vector3(-4.0,6.35,-4.0),"font_size":30,"outline_size":6,"colour":Color(0.9,0.82,0.62)},
		{"kind":"label","name":"NorthGuestRoomLabel","text":"GUEST ROOM","position":Vector3(3.8,6.35,-4.0),"font_size":30,"outline_size":6,"colour":Color(0.9,0.82,0.62)},
		{"kind":"label","name":"SouthGuestRoomLabel","text":"GUEST ROOM","position":Vector3(3.8,6.35,3.8),"font_size":30,"outline_size":6,"colour":Color(0.9,0.82,0.62)},
		{"name":"BedroomChest","position":Vector3(-6.5,3.78,4.6),"size":Vector3(0.9,0.55,0.55),"material":"dark_wood"},
		{"name":"BedroomChest","position":Vector3(-2.8,3.78,4.6),"size":Vector3(0.9,0.55,0.55),"material":"dark_wood"},
		{"name":"BedroomChest","position":Vector3(1.0,3.78,-4.7),"size":Vector3(0.9,0.55,0.55),"material":"dark_wood"},
		{"name":"BedroomChest","position":Vector3(6.8,3.78,-4.7),"size":Vector3(0.9,0.55,0.55),"material":"dark_wood"},
		{"name":"LandingTable","position":Vector3(0.8,3.78,1.7),"size":Vector3(1.2,0.12,0.65),"material":"timber"},
		{"name":"LandingTableLeg","position":Vector3(0.8,3.48,1.7),"size":Vector3(0.12,0.6,0.12),"material":"dark_wood"}
	]
}

const BEDS := [
	{"name":"GarrickBed","hex":Vector2i(-3, 0),"blanket":Color(0.38, 0.16, 0.12)},
	{"name":"GarrickSpareBed","hex":Vector2i(-3, 2),"blanket":Color(0.34, 0.24, 0.16)},
	{"name":"NorthGuestBedA","hex":Vector2i(2, -2),"blanket":Color(0.24, 0.28, 0.38)},
	{"name":"NorthGuestBedB","hex":Vector2i(3, -2),"blanket":Color(0.24, 0.28, 0.38)},
	{"name":"SouthGuestBedA","hex":Vector2i(2, 0),"blanket":Color(0.24, 0.28, 0.38)},
	{"name":"SouthGuestBedB","hex":Vector2i(3, 0),"blanket":Color(0.24, 0.28, 0.38)}
]
