class_name ProceduralNpcProfileFactory
extends RefCounted
## Deterministic appearance profiles for background campaign NPCs.
## A character ID is the seed: the same NPC is stable across sessions and builds.

const EYE_COLOURS := ["brown", "brownlight", "darkbrown", "green", "bluegreen", "grey", "blue", "hazel"]
const NATURAL_HAIR := ["#17120F", "#30251B", "#49372A", "#75452D", "#87452D", "#A87552", "#8A6A4C", "#898176"]
const UNNATURAL_HAIR := ["#287BFF", "#7446A8", "#2C9B70"]
const SKIN_TINTS := ["#70452F", "#8F6045", "#A87552", "#B98260", "#C99A75", "#DDAE8D", "#E0B99B"]
const HOLLOWMERE_NPCS_PATH := "res://data/characters/hollowmere_npcs.json"
const LEGACY_NAMED_NPCS_PATH := "res://data/characters/legacy_named_npcs.json"
static var _named_appearance_index: Dictionary = {}
static var _named_appearance_loaded := false

static func create_profile(character_id: String, display_name: String, context: String = "villager") -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = abs(hash(character_id))
    var authored := _find_authored_appearance(character_id, display_name)
    var gender := int(authored.get("gender", rng.randi_range(0, 1)))
    var authored_appearance: Dictionary = authored.get("appearance", {})
    var age := rng.randf_range(0.36, 0.88)
    var complexion := _complexion_mix(rng)
    var hair_tint: String = NATURAL_HAIR[rng.randi_range(0, NATURAL_HAIR.size() - 1)]
    if rng.randf() < 0.015:
        hair_tint = UNNATURAL_HAIR[rng.randi_range(0, UNNATURAL_HAIR.size() - 1)]
    var facial_hair := "none"
    if gender == 1 and age > 0.42 and rng.randf() < 0.38:
        facial_hair = ["stubble", "mustache", "goatee", "short_beard"][rng.randi_range(0, 3)]
    var tattoos: Array[Dictionary] = []
    if age >= 0.34375 and rng.randf() < 0.07:
        tattoos.append({"design": "mirabel_arcane" if rng.randf() < 0.5 else "reyna_shoulder_back"})
    var piercings: Array[String] = []
    if rng.randf() < 0.10:
        piercings.append("earrings")
    if age >= 0.34375 and rng.randf() < 0.004:
        piercings.append("nipple_left")
    if age >= 0.34375 and rng.randf() < 0.001:
        piercings.append("clit")
    var top_options := ["long_tunic", "tunic", "tattered_shirt", "fatigue_shirt"]
    if context in ["guard", "soldier"]:
        top_options.append("uniform_shirt")
    var bottom_options := ["trousers", "wrapper_long", "wrapper_knee", "fatigue_pants"]
    var top: String = top_options[rng.randi_range(0, top_options.size() - 1)]
    var bottom: String = bottom_options[rng.randi_range(0, bottom_options.size() - 1)]
    var top_colour := _earth_tone(rng)
    var bottom_colour := _earth_tone(rng)
    var hair_styles := ["afro01", "bob01", "bob02", "braid01", "short01", "short02", "short03", "short04", "long01", "ponytail01", "buzz", "cornrows", "box_braids", "mohawk"]
    var params := {
        "seed": int(hash(character_id)),
        "gender": gender,
        "age": float(authored_appearance.get("age", age)),
        "muscle": float(authored_appearance.get("muscle", rng.randf_range(0.22, 0.76))),
        "weight": float(authored_appearance.get("weight", rng.randf_range(0.24, 0.78))),
        "height": float(authored_appearance.get("height", rng.randf_range(0.30, 0.78))),
        "proportions": float(authored_appearance.get("proportions", rng.randf_range(0.35, 0.68))),
        "african": complexion.x,
        "asian": complexion.y,
        "caucasian": complexion.z,
        "eyes": String(authored_appearance.get("eye_colour", EYE_COLOURS[rng.randi_range(0, EYE_COLOURS.size() - 1)])),
        "hair": String(authored_appearance.get("hair_style", hair_styles[rng.randi_range(0, hair_styles.size() - 1)])),
        "hairTint": String(authored_appearance.get("hair_colour", hair_tint)),
        "hairColor": String(authored_appearance.get("hair_colour", hair_tint)),
        "facialHair": facial_hair,
        "tattoos": tattoos,
        "piercings": piercings,
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
        "legs": float(authored_appearance.get("legs", rng.randf_range(0.30, 0.72))),
        "breasts": float(authored_appearance.get("breasts", rng.randf_range(0.20, 0.78) if gender == 0 else 0.0)),
        "skinTint": String(authored_appearance.get("skin_colour", SKIN_TINTS[rng.randi_range(0, SKIN_TINTS.size() - 1)]))
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


## Load authored identities before randomising a generic NPC. The legacy roster
## stores gender and, for many named characters, a complete appearance profile.
static func _find_authored_appearance(character_id: String, display_name: String) -> Dictionary:
    if not _named_appearance_loaded:
        _load_named_appearance_index()
    var id_key := _normalise_identity(character_id)
    var name_key := _normalise_identity(display_name)
    if _named_appearance_index.has(id_key):
        return _named_appearance_index[id_key]
    if _named_appearance_index.has(name_key):
        return _named_appearance_index[name_key]
    return {}


static func _load_named_appearance_index() -> void:
    _named_appearance_loaded = true
    _index_character_file(HOLLOWMERE_NPCS_PATH, "characters", true)
    _index_character_file(LEGACY_NAMED_NPCS_PATH, "named_npcs", false)


static func _index_character_file(path: String, collection_key: String, hollowmere_format: bool) -> void:
    if not FileAccess.file_exists(path):
        return
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Could not read authored NPC identities: " + path)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not parsed is Dictionary:
        push_warning("Invalid authored NPC identity data: " + path)
        return
    var entries: Variant = parsed.get(collection_key, [])
    if not entries is Array:
        return
    for entry_value in entries:
        if not entry_value is Dictionary:
            continue
        var entry: Dictionary = entry_value
        var gender_value: Variant = entry.get("gender", null)
        var appearance: Dictionary = entry.get("appearance", {})
        if hollowmere_format:
            var params: Dictionary = entry.get("params", {})
            gender_value = params.get("gender", gender_value)
            appearance = {
                "age": params.get("age", 0.5),
                "muscle": params.get("muscle", 0.5),
                "weight": params.get("weight", 0.5),
                "height": params.get("height", 0.5),
                "proportions": params.get("proportions", 0.5),
                "eye_colour": params.get("eyes", ""),
                "hair_colour": params.get("hairTint", ""),
                "hair_style": params.get("hair", ""),
                "skin_colour": params.get("skinTint", "")
            }
        if gender_value == null:
            continue
        var gender_text := str(gender_value).to_lower()
        var gender_index := 0 if gender_text in ["female", "feminine", "0"] else 1
        var record := {"gender": gender_index, "appearance": appearance}
        for key in ["id", "game_id", "name", "display_name"]:
            var identity := String(entry.get(key, ""))
            if not identity.is_empty():
                _named_appearance_index[_normalise_identity(identity)] = record


static func _normalise_identity(value: String) -> String:
    var result := value.to_lower().strip_edges()
    result = result.replace("_", "").replace("-", "").replace(" ", "").replace("'", "")
    return result
