#!/usr/bin/env python3
"""Create a deterministic, catalogue-validated sample of generic tavern NPCs.

Run from the pinned Ara 3D Gen checkout. The generated profiles use Ara's
normal character parameter schema and are suitable for the existing GLB builder.
"""
import argparse
import json
import random
import re
from pathlib import Path

NAMES = [
    ("Mara", "Fenwick"), ("Tomas", "Reed"), ("Elin", "Marlow"), ("Bram", "Ashford"),
    ("Nessa", "Vale"), ("Orrin", "Thatch"), ("Sella", "Wren"), ("Harlan", "Pike"),
    ("Tilda", "Moss"), ("Corin", "Briar"), ("Anwen", "Fletcher"), ("Dain", "Holt"),
    ("Lysa", "Mere"), ("Perrin", "Cobb"), ("Ivara", "Stone"), ("Jory", "Beck"),
    ("Merrit", "Dale"), ("Runa", "Blackwood"), ("Eamon", "Quill"), ("Vessa", "North"),
    ("Alric", "Fen"), ("Mina", "Rowe"), ("Tarin", "Bell"), ("Sorin", "Wells"),
    ("Ketta", "Brask"), ("Odel", "Wick"), ("Brynn", "Hearth"), ("Cadan", "Marlow"),
    ("Edda", "Thorne"), ("Rafe", "Greel"),
]
FEMALE_FIRST_NAMES = {"Mara", "Elin", "Nessa", "Sella", "Tilda", "Anwen", "Lysa", "Ivara", "Runa", "Mina", "Ketta", "Brynn", "Edda", "Vessa"}
NATURAL_HAIR = ["#17120F", "#30251B", "#49372A", "#75452D", "#87452D", "#A87552", "#8A6A4C", "#898176", "#D0B47A"]
UNNATURAL_HAIR = ["#287BFF", "#7446A8", "#2C9B70"]
SKIN_TINTS = ["#70452F", "#8F6045", "#A87552", "#B98260", "#C99A75", "#DDAE8D", "#E0B99B"]
EARTH_TONES = ["#66513B", "#8B6843", "#48525B", "#4D5140", "#554D40", "#6B604B", "#39332E", "#766D59"]
HAIR_STYLES = ["braid01", "short02", "short03", "short04", "long01", "bob02", "buzz", "cornrows", "box_braids", "mohawk"]
EYES_FALLBACK = ["blackbrown", "darkbrown", "brown", "brownlight", "green", "bluegreen", "grey", "blue", "lightblue", "deepblue", "ice"]
TATTOOS_FALLBACK = ["armband_l", "sleeve_r", "forearm_l", "chest", "back", "face_marks"]

MALE_ANATOMY_MEAN_LENGTH_CM = 13.12
MALE_ANATOMY_SD_LENGTH_CM = 1.66
MALE_ANATOMY_MEAN_CIRCUMFERENCE_CM = 11.66
MALE_ANATOMY_SD_CIRCUMFERENCE_CM = 1.10
MALE_ANATOMY_CLIP_SD = 2.0


def sample_male_anatomy_size(seed: int) -> dict:
    """Deterministic, independent truncated-normal length and circumference draw."""
    rng = random.Random(f"male-anatomy:{seed}")
    z_length = max(-MALE_ANATOMY_CLIP_SD, min(MALE_ANATOMY_CLIP_SD, rng.gauss(0.0, 1.0)))
    z_girth = max(-MALE_ANATOMY_CLIP_SD, min(MALE_ANATOMY_CLIP_SD, rng.gauss(0.0, 1.0)))
    length_cm = MALE_ANATOMY_MEAN_LENGTH_CM + z_length * MALE_ANATOMY_SD_LENGTH_CM
    circumference_cm = MALE_ANATOMY_MEAN_CIRCUMFERENCE_CM + z_girth * MALE_ANATOMY_SD_CIRCUMFERENCE_CM
    return {
        "length_scale": round(length_cm / MALE_ANATOMY_MEAN_LENGTH_CM, 5),
        "girth_scale": round(circumference_cm / MALE_ANATOMY_MEAN_CIRCUMFERENCE_CM, 5),
        "length_cm": round(length_cm, 2),
        "circumference_cm": round(circumference_cm, 2),
        "z_length": round(z_length, 3),
        "z_girth": round(z_girth, 3),
        "distribution": "truncated_normal_2sd",
    }


def ids_from(root: Path, relative: str, pattern: str, fallback: list[str]) -> list[str]:
    path = root / relative
    if not path.exists():
        return fallback
    found = sorted(set(re.findall(pattern, path.read_text())))
    return found or fallback


def garment_ids(ara_root: Path) -> set[str]:
    root = ara_root / "src/core/garments"
    found: set[str] = set()
    for path in root.glob("*.ts"):
        found.update(re.findall(r"\bid:\s*'([^']+)'", path.read_text()))
    return found


def generate(count: int, seed: int, ara_root: Path) -> dict:
    garments = garment_ids(ara_root)
    garments.update({"none", "bra"})
    eyes = ids_from(ara_root, "src/app/ui/quick-data.ts", r"\['([^']+)',\s*'[^']+',\s*'#[0-9a-fA-F]{6}'\]", EYES_FALLBACK)
    tattoos = ids_from(ara_root, "src/core/looks/tattoos.ts", r"'(armband_l|sleeve_r|forearm_l|chest|back|face_marks)'", TATTOOS_FALLBACK)
    tops = [x for x in ["long_tunic", "tunic", "tattered_shirt", "fatigue_shirt", "uniform_shirt", "uniform_shirt_long", "tank_top", "silk_blouse", "camp_shirt", "clerical_shirt"] if x in garments]
    bottoms = [x for x in ["trousers", "wrapper_long", "wrapper_knee", "fatigue_pants", "cargo_shorts", "uniform_trousers", "tattered_pants", "hide_aprons", "loincloth"] if x in garments]
    accessory_options = [x for x in ["belt", "utility_belt", "waist_sash", "shoulder_drape", "bead_necklace", "cowrie_necklace", "amulets", "arm_cuffs", "bead_armbands", "feather_headband", "bead_headband"] if x in garments]
    if not tops or not bottoms:
        raise SystemExit(f"Cannot generate tavern outfits: catalogue tops={tops}, bottoms={bottoms}")

    # Rare styles are enabled only when the pinned Ara catalogue actually has them.
    rare_under_bottoms = [x for x in ["bikini_bottom", "g_string", "g-string", "string_bikini_bottom", "lace_briefs", "fishnet_briefs"] if x in garments]
    rare_under_tops = [x for x in ["bikini_top", "lace_bra", "fishnet_bra", "halter_bra_lace", "halter_bra_fishnet"] if x in garments]
    rare_tops = [x for x in ["lace_shirt", "fishnet_shirt"] if x in garments]
    rare_bottoms = [x for x in ["lace_pants", "fishnet_pants"] if x in garments]
    characters = []
    for index in range(count):
        first, last = NAMES[index % len(NAMES)]
        if index >= len(NAMES):
            last = f"{last}{index // len(NAMES) + 1}"
        character_id = f"tavern_generated_{index + 1:03d}"
        person_seed = seed + index * 7919
        person = random.Random(person_seed)
        # Names in this curated sample are gender-authored; do not randomise a
        # body variant independently of the identity we assigned.
        gender = 0 if first in FEMALE_FIRST_NAMES else 1
        age = person.uniform(0.36, 0.88)
        complexion = [person.uniform(0.02, 0.92) for _ in range(3)]
        total = sum(complexion)
        complexion = [round(v / total, 4) for v in complexion]
        hair_tint = person.choice(NATURAL_HAIR)
        if person.random() < 0.015:
            hair_tint = person.choice(UNNATURAL_HAIR)
        facial_hair = "none"
        if gender == 1 and age > 0.42 and person.random() < 0.38:
            facial_hair = person.choice(["stubble", "mustache", "mustache_stubble", "goatee", "short_beard", "full_beard"])
        tattoo_list = []
        if age >= 0.34375 and tattoos and person.random() < 0.07:
            tattoo_list = [person.choice(tattoos)]
        piercings = []
        if age >= 0.34375 and person.random() < 0.004:
            piercings.append("nipple_left")
        if gender == 0 and age >= 0.34375 and person.random() < 0.001:
            piercings.append("clit")
        top = person.choice(tops)
        bottom = person.choice(bottoms)
        if rare_tops and person.random() < 0.005:
            top = person.choice(rare_tops)
        if rare_bottoms and person.random() < 0.005:
            bottom = person.choice(rare_bottoms)
        under_top = "bra" if gender == 0 and "bra" in garments else "none"
        under_bottom = "briefs" if "briefs" in garments else "none"
        if rare_under_bottoms and person.random() < 0.003:
            under_bottom = person.choice(rare_under_bottoms)
        if gender == 0 and rare_under_tops and person.random() < 0.005:
            under_top = person.choice(rare_under_tops)
        top_colour = person.choice(EARTH_TONES)
        bottom_colour = person.choice(EARTH_TONES)
        accessories = []
        if accessory_options and person.random() < 0.28:
            accessories.append(person.choice(accessory_options))
        if accessory_options and person.random() < 0.05:
            extra_accessory = person.choice(accessory_options)
            if extra_accessory not in accessories:
                accessories.append(extra_accessory)
        params = {
            "seed": person_seed, "gender": gender, "age": round(age, 3),
            "muscle": round(person.uniform(0.22, 0.76), 3),
            "weight": round(person.uniform(0.24, 0.78), 3),
            "height": round(person.uniform(0.30, 0.78), 3),
            "proportions": round(person.uniform(0.35, 0.68), 3),
            "african": complexion[0], "asian": complexion[1], "caucasian": complexion[2],
            "eyes": person.choice(eyes), "hair": person.choice(HAIR_STYLES),
            "hairTint": hair_tint, "hairColor": hair_tint, "facialHair": facial_hair,
            "tattoos": tattoo_list, "tattooInk": "#3b3028", "tattoo_ink": "#3b3028",
            "piercings": piercings,
            "outfit": "none", "top": top, "underTop": under_top,
            "underBottom": under_bottom, "jacket": "none", "bottom": bottom,
            "underwear": True, "shoes": person.choice(["sandals", "combat_boots"]),
            "hat": "none", "weapon": "none", "carry": "none", "accessories": accessories,
            "garmentStyles": {
                top: {"pattern": "solid", "color": top_colour, "color2": top_colour},
                bottom: {"pattern": "solid", "color": bottom_colour, "color2": bottom_colour},
            },
            "detail": "medium", "rig": "game", "restPose": "A", "animations": True,
            "faceBones": True, "faceShapes": True, "speechShapes": False,
            "expression": "neutral", "legs": round(person.uniform(0.30, 0.72), 3),
            "breasts": round(person.uniform(0.20, 0.78), 3) if gender == 0 else 0.0,
            "skinTint": person.choice(SKIN_TINTS),
        }
        character = {
            "id": character_id, "game_id": character_id, "name": f"{first} {last}",
            "role": "tavern patron", "hex": [index % 5, index // 5],
            "detail": "medium", "params": params,
        }
        if gender == 1:
            character["anatomy_size"] = sample_male_anatomy_size(person_seed)
        characters.append(character)
    return {
        "schema_version": 1,
        "generator": "Ara 3D Gen + Silverhart seeded tavern profile generator",
        "generator_commit": "b60b5bece6d383d2cbb7067fd50e7c8e68b5a395",
        "seed": seed,
        "count": count,
        "male_anatomy_distribution": {
            "length_mean_cm": MALE_ANATOMY_MEAN_LENGTH_CM,
            "length_sd_cm": MALE_ANATOMY_SD_LENGTH_CM,
            "circumference_mean_cm": MALE_ANATOMY_MEAN_CIRCUMFERENCE_CM,
            "circumference_sd_cm": MALE_ANATOMY_SD_CIRCUMFERENCE_CM,
            "clip_sd": MALE_ANATOMY_CLIP_SD,
            "length_girth_correlation": 0.0,
            "seed_policy": "independent deterministic draw from each character's person_seed",
        },
        "rarity_policy": {
            "unnatural_hair": 0.015, "tattoos": 0.07,
            "non_ear_piercings": 0.004, "additional_clitoral_piercing": 0.001,
            "rare_underwear_bottom": 0.003, "rare_underwear_top": 0.005,
            "transparent_or_open_weave_shirt": 0.005, "transparent_or_open_weave_pants": 0.005,
            "note": "Rare garment probabilities activate only when those exact IDs exist in the pinned Ara catalogue. Piercing details are carried in the profile for the runtime appearance-details layer; the current Ara export may ignore those Silverhart-only fields."
        },
        "characters": characters,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=20)
    parser.add_argument("--seed", type=int, default=20261120)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    if not 1 <= args.count <= 100:
        raise SystemExit("--count must be between 1 and 100")
    ara_root = Path.cwd()
    if not (ara_root / "package.json").exists():
        raise SystemExit("Run from the pinned Ara 3D Gen repository root")
    manifest = generate(args.count, args.seed, ara_root)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Generated {args.count} deterministic tavern NPC profiles (seed={args.seed}).")
    print("Available rare underwear IDs: " + ", ".join(
        sorted(set(["bikini_bottom", "bikini_top", "g_string", "g-string", "string_bikini_bottom", "lace_briefs", "fishnet_briefs", "lace_bra", "fishnet_bra"]) & garment_ids(ara_root))
    ))


if __name__ == "__main__":
    main()
