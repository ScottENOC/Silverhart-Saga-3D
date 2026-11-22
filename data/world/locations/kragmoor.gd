extends RefCounted
## Loadable Campaign 2 composition for Kragmoor's source-authored Deepholds.

const FLOOR_PRESENTER = preload("res://scripts/world/campaign2_multistory_floor_presenter.gd")

const DEFINITION := {
	"id": "kragmoor",
	"display_name": "Kragmoor",
	"components": [
		{
			"role": "multi_story_floor_presenter",
			"node_name": "KragmoorDeepholds",
			"script": FLOOR_PRESENTER,
			"configure_campaign": true
		}
	]
}
