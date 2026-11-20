#!/usr/bin/env python3
"""Compose individual tavern NPC renders into a labelled contact sheet."""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--images", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--columns", type=int, default=5)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text())
    characters = manifest.get("characters", [])
    if not characters:
        raise SystemExit("No generated NPCs in manifest")
    columns = max(1, args.columns)
    rows = (len(characters) + columns - 1) // columns
    cell_w, image_h, label_h = 260, 320, 42
    sheet = Image.new("RGB", (columns * cell_w, rows * (image_h + label_h)), "#e7e2d8")
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
    for index, character in enumerate(characters):
        image_path = args.images / f"{character['id']}.png"
        if not image_path.is_file():
            raise SystemExit(f"Missing NPC review image: {image_path}")
        image = Image.open(image_path).convert("RGB")
        image.thumbnail((cell_w - 12, image_h - 8), Image.Resampling.LANCZOS)
        x = (index % columns) * cell_w
        y = (index // columns) * (image_h + label_h)
        paste_x = x + (cell_w - image.width) // 2
        paste_y = y + (image_h - image.height) // 2
        sheet.paste(image, (paste_x, paste_y))
        name = str(character.get("name", character["id"]))
        role = str(character.get("role", "NPC"))
        draw.text((x + 8, y + image_h + 4), name[:28], fill="#211d19", font=font)
        draw.text((x + 8, y + image_h + 23), role[:30], fill="#62594e", font=font)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output, quality=92)
    print(f"Wrote contact sheet: {args.output} ({len(characters)} NPCs)")


if __name__ == "__main__":
    main()
