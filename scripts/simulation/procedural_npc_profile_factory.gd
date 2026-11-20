class_name ProceduralNpcProfileFactory
extends RefCounted
## Deterministic appearance profiles for background campaign NPCs.
## A character ID is the seed: the same NPC is stable across sessions and builds.

const HAIR_STYLES := ["short02", "short03", "short04", "long01", "bob02", "buzz", "cornrows", "box_braids", "mohawk", "braid01"]
const EYE_COLOURS := ["brown", "brownlight", "darkbrown", "green", "bluegreen", "grey", "blue", "hazel"]
const NATURAL_HAIR := ["#17120F", "#30251B", "#49372A", "#75452D", "#87452D", "#A87552", "#8A6A4C", "#898176"]
const UNNATURAL_HAIR := ["#287BFF", "#7446A8", "#2C9B70"]
const SKIN_TINTS := ["#70452F", "#8F6045", "#A87552", "#B98260", "#C99A75", "#DDAE8D", "#E0B99B"]

static func create_profile(character_id: String, display_name: String, context: String = "villager") -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = abs(hash(character_id))
    var gender := rng.randi_range(0, 1)
    var age := rng.randf_range(0.36, 0.88)
    var complexion := _complexion_mix(rng)
    var hair_tint := NATURAL_HAIR[rng.randi_range(0, NATURAL_HAIR.size() - 1)]
    if rng.randf() < 0.015:
        hair_tint = UNNATURAL_HAIR[rng.randi_range(0, UNNATURAL_HAIR.size() - 1)]
    var facial_hair := "none"
    if gender == 1 and age > 0.42 and rng.randf() < 0.38:
        facial_hair = ["stubble", "mustache", "goatee", "short_beard"][rng.randi_range(0, 3)]
    var tattoos: Array[String] = []
    if age >= 0.34375 and rng.randf() < 0.07:
        tattoos.append(["armband_l", "forearm_l", "sleeve_r", "chest", "back"][rng.randi_range(0, 4)])
    var top_options := ["long_tunic", "tunic", "tattered_shirt"]
    if context in ["guard", "soldier"]:
        top_options.append("uniform_shirt")
    var bottom_options := ["trousers", "wrapper_long"]
    var top := top_options[rng.randi_range(0, top_options.size() - 1)]
    var bottom := bottom_options[rng.randi_range(0, bottom_options.size() - 1)]
    var top_colour := _earth_tone(rng)
    var bottom_colour := _earth_tone(rng)
    var hair_styles := ["short02", "short03", "short04", "long01", "bob02", "buzz", "cornrows", "box_braids", "mohawk", "braid01"]
    var params := {
        "seed": int(hash(character_id)),
        "gender": gender,
        "age": age,
        "muscle": rng.randf_range(0.22, 0.76),
        "weight": rng.randf_range(0.24, 0.78),
        "height": rng.randf_range(0.30, 0.78),
        "proportions": rng.randf_range(0.35, 0.68),
        "african": complexion.x,
        "asian": complexion.y,
        "caucasian": complexion.z,
        "eyes": EYE_COLOURS[rng.randi_range(0, EYE_COLOURS.size() - 1)],
        "hair": hair_styles[rng.randi_range(0, hair_styles.size() - 1)],
        "hairTint": hair_tint,
        "hairColor": hair_tint,
        "facialHair": facial_hair,
        "tattoos": tattoos,
        "tattoo_ink": "#3b3028",
        "outfit": "none",
        "top": top,
        "underTop": "bra" if gender == 0 else "none",
        "underBottom": "briefs",
        "jacket": "none",
        "bottom": bottom,
        "underwear": true,
        "shoes": "sandals",
        "hat": "none",
        "weapon": "none",
        "carry": "none",
        "accessories": [],
        "garmentStyles": {
            top: {"pattern": "solid", "color": top_colour, "color2": top_colour},
            bottom: {"pattern": "solid", "color": bottom_colour, "color2": bottom_colour}
        },
        "legs": rng.randf_range(0.30, 0.72),
        "breasts": rng.randf_range(0.20, 0.78) if gender == 0 else 0.0,
        "skinTint": SKIN_TINTS[rng.randi_range(0, SKIN_TINTS.size() - 1)]
    }
    return {"id": character_id, "name": display_name, "role": context, "params": params}


static func _complexion_mix(rng: RandomNumberGenerator) -> Vector3:
    var a := rng.randf_range(0.02, 0.92)
    var b := rng.randf_range(0.02, 0.92)
    var c := rng.randf_range(0.02, 0.92)
    var total := a + b + c
    return Vector3(a / total, b / total, c / total)


static func _earth_tone(rng: RandomNumberGenerator) -> String:
    var colours := ["#66513B", "#8B6843", "#48525B", "#4D5140", "#554D40", "#6B604B", "#39332E", "#766D59"]
    return colours[rng.randi_range(0, colours.size() - 1)]
