#!/usr/bin/env python3
"""Create a labelled front/side comparison sheet for Ara muscle morph previews."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

STATES = ("neutral", "low", "high")
VIEWS = ("front", "side")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    source = Path(args.input_dir)
    cell_w, cell_h, label_h = 640, 800, 42
    margin, gap = 24, 18
    sheet_w = margin * 2 + len(STATES) * cell_w + (len(STATES) - 1) * gap
    sheet_h = margin * 2 + len(VIEWS) * (cell_h + label_h) + (len(VIEWS) - 1) * gap
    sheet = Image.new("RGB", (sheet_w, sheet_h), "#20252b")
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 22)
    except OSError:
        font = ImageFont.load_default()

    for row, view in enumerate(VIEWS):
        for col, state in enumerate(STATES):
            path = source / f"{view}-{state}.png"
            if not path.is_file():
                raise FileNotFoundError(path)
            image = Image.open(path).convert("RGB")
            image = image.resize((cell_w, cell_h), Image.Resampling.LANCZOS)
            x = margin + col * (cell_w + gap)
            y = margin + row * (cell_h + label_h + gap)
            sheet.paste(image, (x, y + label_h))
            title = f"{view.upper()}  |  {state.upper()}"
            draw.text((x + 8, y + 7), title, fill="#f0e6d2", font=font)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, quality=95)
    print(f"Wrote {output} ({sheet.width}x{sheet.height})")


if __name__ == "__main__":
    main()
