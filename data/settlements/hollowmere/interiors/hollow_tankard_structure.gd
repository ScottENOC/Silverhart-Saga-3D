extends RefCounted
## Structural presentation data for the Hollow Tankard.
## Runtime door state, floor visibility and roof cutaway remain campaign behaviour.

const BUILDING_SHELL := {
	"id":"HollowTankardBuilding",
	"features":[
		{"name":"StoneFloorFoundation","position":Vector3(0.0,-0.08,0.0),"size":Vector3(16.7,0.16,11.7),"material":"stone"},
		{"name":"PlasterWall","position":Vector3(-5.3,1.8,-5.5),"size":Vector3(1.4,3.2,0.35),"material":"plaster"},
		{"name":"WallTopBeam","position":Vector3(-5.3,3.38,-5.5),"size":Vector3(1.48,0.22,0.43),"material":"timber"},
		{"name":"PlasterWall","position":Vector3(-0.5,1.8,-5.5),"size":Vector3(5.8,3.2,0.35),"material":"plaster"},
		{"name":"WallTopBeam","position":Vector3(-0.5,3.38,-5.5),"size":Vector3(5.88,0.22,0.43),"material":"timber"},
		{"name":"PlasterWall","position":Vector3(5.8,1.8,-5.5),"size":Vector3(4.4,3.2,0.35),"material":"plaster"},
		{"name":"WallTopBeam","position":Vector3(5.8,3.38,-5.5),"size":Vector3(4.48,0.22,0.43),"material":"timber"},
		{"name":"WindowGlass","position":Vector3(-4.0,1.95,-5.5),"size":Vector3(1.2,1.0,0.08),"material":"glass"},
		{"name":"WindowSill","position":Vector3(-4.0,1.45,-5.5),"size":Vector3(1.4,0.12,0.18),"material":"timber"},
		{"name":"WindowGlass","position":Vector3(3.0,1.95,-5.5),"size":Vector3(1.2,1.0,0.08),"material":"glass"},
		{"name":"WindowSill","position":Vector3(3.0,1.45,-5.5),"size":Vector3(1.4,0.12,0.18),"material":"timber"},
		{"name":"PlasterWall","position":Vector3(-4.4,1.8,5.5),"size":Vector3(7.2,3.2,0.35),"material":"plaster"},
		{"name":"WallTopBeam","position":Vector3(-4.4,3.38,5.5),"size":Vector3(7.28,0.22,0.43),"material":"timber"},
		{"name":"PlasterWall","position":Vector3(4.4,1.8,5.5),"size":Vector3(7.2,3.2,0.35),"material":"plaster"},
		{"name":"WallTopBeam","position":Vector3(4.4,3.38,5.5),"size":Vector3(7.28,0.22,0.43),"material":"timber"},
		{"name":"DoorLintel","position":Vector3(0.0,3.0,5.5),"size":Vector3(1.95,0.35,0.48),"material":"timber"},
		{"name":"DoorJambLeft","position":Vector3(-0.95,1.55,5.5),"size":Vector3(0.22,3.1,0.48),"material":"timber"},
		{"name":"DoorJambRight","position":Vector3(0.95,1.55,5.5),"size":Vector3(0.22,3.1,0.48),"material":"timber"},
		{"name":"PlasterWall","position":Vector3(8.0,1.8,-3.45),"size":Vector3(0.35,3.2,4.1),"material":"plaster"},
		{"name":"WallTopBeam","position":Vector3(8.0,3.38,-3.45),"size":Vector3(0.43,0.22,4.18),"material":"timber"},
		{"name":"PlasterWall","position":Vector3(8.0,1.8,3.45),"size":Vector3(0.35,3.2,4.1),"material":"plaster"},
		{"name":"WallTopBeam","position":Vector3(8.0,3.38,3.45),"size":Vector3(0.43,0.22,4.18),"material":"timber"},
		{"name":"WindowGlass","position":Vector3(8.0,1.95,0.0),"size":Vector3(0.08,1.0,1.2),"material":"glass"},
		{"name":"WindowSill","position":Vector3(8.0,1.45,0.0),"size":Vector3(0.18,0.12,1.4),"material":"timber"},
		{"name":"PlasterWall","position":Vector3(-8.0,1.8,-3.45),"size":Vector3(0.35,3.2,4.1),"material":"plaster"},
		{"name":"WallTopBeam","position":Vector3(-8.0,3.38,-3.45),"size":Vector3(0.43,0.22,4.18),"material":"timber"},
		{"name":"PlasterWall","position":Vector3(-8.0,1.8,3.45),"size":Vector3(0.35,3.2,4.1),"material":"plaster"},
		{"name":"WallTopBeam","position":Vector3(-8.0,3.38,3.45),"size":Vector3(0.43,0.22,4.18),"material":"timber"},
		{"name":"WindowGlass","position":Vector3(-8.0,1.95,0.0),"size":Vector3(0.08,1.0,1.2),"material":"glass"},
		{"name":"WindowSill","position":Vector3(-8.0,1.45,0.0),"size":Vector3(0.18,0.12,1.4),"material":"timber"},
		{"name":"TimberPost","position":Vector3(-7.7,1.65,-5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"TimberPost","position":Vector3(-4.0,1.65,-5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"TimberPost","position":Vector3(0.0,1.65,-5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"TimberPost","position":Vector3(4.0,1.65,-5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"TimberPost","position":Vector3(7.7,1.65,-5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"TimberPost","position":Vector3(-7.7,1.65,5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"TimberPost","position":Vector3(-4.0,1.65,5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"TimberPost","position":Vector3(0.0,1.65,5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"TimberPost","position":Vector3(4.0,1.65,5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"TimberPost","position":Vector3(7.7,1.65,5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"NorthTieBeam","position":Vector3(0.0,3.0,-5.05),"size":Vector3(16.0,0.22,0.22),"material":"dark_wood"},
		{"name":"SouthTieBeam","position":Vector3(0.0,3.0,5.05),"size":Vector3(16.0,0.22,0.22),"material":"dark_wood"},
		{"name":"StairStringerLeft","position":Vector3(5.38,1.7,2.3),"size":Vector3(0.16,3.6,4.0),"material":"dark_wood"},
		{"name":"StairStringerRight","position":Vector3(6.72,1.7,2.3),"size":Vector3(0.16,3.6,4.0),"material":"dark_wood"}
	]
}

const UPPER_EXTERIOR := {
	"id":"UpperStoreyExterior",
	"features":[
		{"name":"UpperNorthWall","position":Vector3(0.0,5.0,-5.5),"size":Vector3(16.0,3.2,0.35),"material":"plaster"},
		{"name":"UpperSouthWallLeft","position":Vector3(-4.4,5.0,5.5),"size":Vector3(7.2,3.2,0.35),"material":"plaster"},
		{"name":"UpperSouthWallRight","position":Vector3(4.4,5.0,5.5),"size":Vector3(7.2,3.2,0.35),"material":"plaster"},
		{"name":"UpperEastWall","position":Vector3(8.0,5.0,0.0),"size":Vector3(0.35,3.2,11.0),"material":"plaster"},
		{"name":"UpperWestWall","position":Vector3(-8.0,5.0,0.0),"size":Vector3(0.35,3.2,11.0),"material":"plaster"},
		{"name":"UpperTimberPost","position":Vector3(-7.7,4.95,-5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"UpperTimberPost","position":Vector3(-4.0,4.95,-5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"UpperTimberPost","position":Vector3(0.0,4.95,-5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"UpperTimberPost","position":Vector3(4.0,4.95,-5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"UpperTimberPost","position":Vector3(7.7,4.95,-5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"UpperTimberPost","position":Vector3(-7.7,4.95,5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"UpperTimberPost","position":Vector3(-4.0,4.95,5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"UpperTimberPost","position":Vector3(0.0,4.95,5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"UpperTimberPost","position":Vector3(4.0,4.95,5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"UpperTimberPost","position":Vector3(7.7,4.95,5.2),"size":Vector3(0.22,3.3,0.22),"material":"timber"},
		{"name":"UpperNorthTieBeam","position":Vector3(0.0,6.55,-5.05),"size":Vector3(16.0,0.22,0.22),"material":"dark_wood"},
		{"name":"UpperSouthTieBeam","position":Vector3(0.0,6.55,5.05),"size":Vector3(16.0,0.22,0.22),"material":"dark_wood"},
		{"name":"WindowGlass","position":Vector3(-4.0,5.1,-5.5),"size":Vector3(1.2,1.0,0.08),"material":"glass"},
		{"name":"WindowSill","position":Vector3(-4.0,4.6,-5.5),"size":Vector3(1.4,0.12,0.18),"material":"timber"},
		{"name":"WindowGlass","position":Vector3(3.0,5.1,-5.5),"size":Vector3(1.2,1.0,0.08),"material":"glass"},
		{"name":"WindowSill","position":Vector3(3.0,4.6,-5.5),"size":Vector3(1.4,0.12,0.18),"material":"timber"},
		{"name":"WindowGlass","position":Vector3(8.0,5.1,0.0),"size":Vector3(0.08,1.0,1.2),"material":"glass"},
		{"name":"WindowSill","position":Vector3(8.0,4.6,0.0),"size":Vector3(0.18,0.12,1.4),"material":"timber"},
		{"name":"WindowGlass","position":Vector3(-8.0,5.1,0.0),"size":Vector3(0.08,1.0,1.2),"material":"glass"},
		{"name":"WindowSill","position":Vector3(-8.0,4.6,0.0),"size":Vector3(0.18,0.12,1.4),"material":"timber"}
	]
}

const UPPER_FLOOR := {
	"id":"UpperFloorPresentation",
	"features":[
		{"name":"UpperFloorDeck","position":Vector3(0.0,3.22,0.0),"size":Vector3(16.2,0.24,11.2),"material":"timber"}
	]
}

const ROOF := {
	"id":"RoofCutaway",
	"features":[
		{"name":"NorthRoofSlope","position":Vector3(0.0,7.75,-2.75),"size":Vector3(16.9,0.22,sqrt(5.5*5.5+2.6*2.6)),"material":"roof","rotation_degrees":Vector3(-rad_to_deg(atan2(2.6,5.5)),0.0,0.0)},
		{"name":"SouthRoofSlope","position":Vector3(0.0,7.75,2.75),"size":Vector3(16.9,0.22,sqrt(5.5*5.5+2.6*2.6)),"material":"roof","rotation_degrees":Vector3(rad_to_deg(atan2(2.6,5.5)),0.0,0.0)},
		{"name":"RidgeBeam","position":Vector3(0.0,9.03,0.0),"size":Vector3(17.0,0.25,0.3),"material":"dark_wood"},
		{"name":"Chimney","position":Vector3(-6.0,8.0,-1.0),"size":Vector3(0.9,3.8,0.9),"material":"stone"}
	]
}
