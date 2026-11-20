extends RefCounted
## Composition data for the opening Campaign 2 location.
## This file identifies reusable component scripts; it does not construct geometry.

const SETTLEMENT_PRESENTATION = preload("res://scripts/world/hollowmere_village.gd")
const INTERIOR_CONTROLLER = preload("res://scripts/world/hollow_tankard.gd")

const LOCATION_ID := "hollowmere"
const DISPLAY_NAME := "Hollowmere"
const DEFINITION := {
	"id": LOCATION_ID,
	"display_name": DISPLAY_NAME,
	"components": [
		{
			"role": "settlement",
			"node_name": "HollowmereVillage",
			"script": SETTLEMENT_PRESENTATION
		},
		{
			"role": "interior_controller",
			"node_name": "HollowTankard",
			"script": INTERIOR_CONTROLLER,
			"configure_campaign": true
		}
	]
}
