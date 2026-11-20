extends RefCounted
## Authored opening-scene actor placements for Hollowmere.
## Character appearance lives in the character manifest; this file alone owns
## where those characters and settlement creatures begin in the continuous world.

const PLAYER_START_HEX := Vector2i(-1, 2)
const CHARACTER_STARTS := {
	"wren_talbot": Vector2i(-2, 1),
	"garrick_holt": Vector2i(-3, -2),
	"mira_ashbrook": Vector2i(2, -2),
	"oskar_vinn": Vector2i(3, -2),
	"wick_hallow": Vector2i(0, 15),
	"dray": Vector2i(-1, 6),
	"tomlin": Vector2i(0, 6),
	"hask": Vector2i(1, 6),
	"yvette": Vector2i(-2, 2),
	"hendra": Vector2i(-3, 2),
	"tavern_patron": Vector2i(3, -2),
	"elder_marta": Vector2i(0, -9),
	"rowan_fletcher": Vector2i(12, 26),
	"reyna_fletcher": Vector2i(17, 57),
	"mirabel_quill": Vector2i(17, -11)
}

## These companions have recruitment arcs, but their home/recruitment regions are
## not part of the opening world yet. They must not be staged at arbitrary
## Hollowmere coordinates; their actual placements will be authored with those regions.
const DEFERRED_COMPANIONS := {
	"ser_aldric_thorne": "awaiting_recruitment_region",
	"nix_sharpear": "awaiting_recruitment_region",
	"warlord_grukk_ironhide": "awaiting_recruitment_region",
	"fenn_oakheart": "awaiting_recruitment_region",
	"brother_alden": "awaiting_recruitment_region",
	"snik_fangtooth": "awaiting_recruitment_region"
}
const OLD_MAC_START_HEX := Vector2i(12, 58)
const MISSING_CHILD_START_HEX := Vector2i(27, 62)
const REYNA_SHELTER_HEX := Vector2i(27, 62)
const REYNA_CLUE_HEX := Vector2i(22, 61)
const FARMSTEAD_DIRE_WOLF_HEX := Vector2i(30, 58)
const OLD_MAC_RESCUE_DESTINATION_HEX := Vector2i(13, 58)
const FARM_ANIMALS := [
	{"id": "FarmCowA", "kind": "cow", "behaviour": "farm", "hex": Vector2i(5, 66), "scale": 0.82},
	{"id": "FarmCowB", "kind": "cow", "behaviour": "farm", "hex": Vector2i(10, 69), "scale": 0.82},
	{"id": "FarmCowC", "kind": "cow", "behaviour": "farm", "hex": Vector2i(13, 64), "scale": 0.82},
	{"id": "FarmHorse", "kind": "horse", "behaviour": "mount", "hex": Vector2i(24, 57), "scale": 0.82},
	{"id": "FarmWhiteHorse", "kind": "horse", "behaviour": "mount", "hex": Vector2i(27, 61), "scale": 0.82, "asset": "Horse_White.gltf"},
	{"id": "FarmShiba", "kind": "shiba_inu", "behaviour": "farm", "hex": Vector2i(19, 60), "scale": 0.48, "asset": "ShibaInu.gltf"}
]
const WILDERNESS_ANIMALS := [
	{"id": "WildernessDeer", "kind": "deer", "behaviour": "passive_wildlife", "hex": Vector2i(-34, 18), "scale": 0.78},
	{"id": "WildernessStag", "kind": "stag", "behaviour": "passive_wildlife", "hex": Vector2i(37, -12), "scale": 0.82},
	{"id": "WildernessFox", "kind": "fox", "behaviour": "passive_wildlife", "hex": Vector2i(-29, -30), "scale": 0.72},
	{"id": "WildernessWolf", "kind": "wolf", "behaviour": "predator", "hex": Vector2i(39, 39), "scale": 0.76}
]
