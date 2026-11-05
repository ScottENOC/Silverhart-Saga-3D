import json
import sys
from pathlib import Path

source = Path(sys.argv[1])
out = Path(sys.argv[2])
data = json.loads(source.read_text())
out.mkdir(parents=True, exist_ok=True)

for character in data["characters"]:
    cid = character["id"]
    params = dict(character["params"])
    params.update({
        "name": character["name"],
        "detail": "low",
        "rig": "game",
        "restPose": "A",
        "animations": False,
        "faceBones": True,
        "faceShapes": True,
        "speechShapes": True,
        "outfit": "none",
        "jacket": "none",
        "hat": "none",
        "weapon": "none",
        "carry": "none",
        "accessories": [],
        "underwear": True,
    })
    # The full preview retains its clothing, hair, tattoos and earrings.
    full = dict(params)
    full["name"] = character["name"] + " - NPC preview"
    (out / f"{cid}-full.json").write_text(json.dumps(full, indent=2))

    # Components are generated independently from the same body parameters.
    base = dict(params)
    base.update({
        "name": character["name"] + " - modular base",
        "top": "none",
        "bottom": "none",
        "shoes": "none",
        "hair": "none",
        "tattoos": params.get("tattoos", []),
        "earrings": "none",
    })
    for slot, changes in {
        "body": {},
        "hair": {"hair": params.get("hair", "none"), "hairTint": params.get("hairTint", "#ffffff"), "hairColor": params.get("hairColor", "#2a1e16")},
        "shirt": {"top": params.get("top", "none")},
        "trousers": {"bottom": params.get("bottom", "none")},
        "shirt_alt": {"top": "tank_top" if params.get("top") != "tank_top" else "fatigue_shirt"},
        "trousers_alt": {"bottom": "cargo_shorts" if params.get("bottom") != "cargo_shorts" else "fatigue_pants"},
    }.items():
        component = dict(base)
        component.update(changes)
        component["name"] = f"{character['name']} - {slot}"
        component["garmentStyles"] = params.get("garmentStyles", {})
        (out / f"{cid}-{slot}.json").write_text(json.dumps(component, indent=2))
    print(f"Prepared {cid}: body/hair/shirt/trousers + full preview")
