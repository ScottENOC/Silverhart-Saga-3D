extends RefCounted
## Composition data for the opening Campaign 2 location.
## This file identifies reusable component scripts; it does not construct geometry.

const SETTLEMENT_PRESENTATION = preload("res://scripts/world/world_settlement_presenter.gd")
const SETTLEMENT_PRESENTATION_DATA = preload("res://data/settlements/hollowmere/presentation.gd")
const INTERIOR_CONTROLLER = preload("res://scripts/world/hollow_tankard.gd")
const REGIONAL_TERRAIN_STREAM = preload("res://scripts/world/campaign2_campaign_terrain_stream.gd")

const LOCATION_ID := "hollowmere"
const DISPLAY_NAME := "Hollowmere"
const DEFINITION := {
	"id": LOCATION_ID,
	"display_name": DISPLAY_NAME,
	"components": [
		{
			"role": "settlement",
			"node_name": "SettlementPresentation",
			"script": SETTLEMENT_PRESENTATION,
			"configure_location": true,
			"location_data": SETTLEMENT_PRESENTATION_DATA.DEFINITION
		},
		{
			"role": "interior_controller",
			"node_name": "HollowTankard",
			"script": INTERIOR_CONTROLLER,
			"configure_campaign": true
		},
		{
			"role": "regional_terrain_stream",
			"node_name": "CampaignTerrainStream",
			"script": REGIONAL_TERRAIN_STREAM,
			"configure_campaign": true
		}
	]
}
