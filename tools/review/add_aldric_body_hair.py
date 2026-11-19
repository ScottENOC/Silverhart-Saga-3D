#!/usr/bin/env python3
"""Bake restrained armpit and pubic hair into Ara's skin diffuse texture.

This is shared by the native Ara companion builds. It uses the exported skin mesh's own UVs,
so the markings follow the body and survive GLB import without extra geometry.
The placement is intentionally sparse and is reported for review.
"""
import argparse
import json
import random
import struct
from io import BytesIO
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageChops


def parse_glb(data):
    magic, version, total = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2 or total != len(data):
        raise ValueError("Invalid GLB")
    chunks, offset = [], 12
    while offset < len(data):
        size, kind = struct.unpack_from("<I4s", data, offset)
        offset += 8
        chunks.append([kind, data[offset:offset + size]])
        offset += size
    doc = json.loads(next(p for k, p in chunks if k == b"JSON").decode().rstrip("\x00 "))
    binary = next(p for k, p in chunks if k == b"BIN\x00")
    return doc, binary, chunks


def accessor(doc, binary, index):
    a = doc["accessors"][index]
    view = doc["bufferViews"][a["bufferView"]]
    dtype = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}[a["componentType"]]
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
    item = np.dtype(dtype).itemsize * width
    stride = view.get("byteStride", item)
    start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.vstack([np.frombuffer(binary, dtype=dtype, count=width, offset=start + i * stride) for i in range(a["count"])])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True, type=Path)
    ap.add_argument("--seed", type=int, default=1401)
    ap.add_argument("--coverage", choices=("restrained", "aldric", "wren", "reyna", "dagna"), default="restrained")
    ap.add_argument("--hair-colour", default="", help="Hex RGB body-hair colour")
    args = ap.parse_args()
    doc, old_binary, chunks = parse_glb(args.model.read_bytes())

    skin_material = next(i for i, m in enumerate(doc["materials"]) if m.get("name", "").strip().lower() == "skin" or m.get("name", "").strip().lower().startswith("skin_anatomy"))
    texture_index = doc["materials"][skin_material]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    image_index = doc["textures"][texture_index]["source"]
    image = doc["images"][image_index]
    view_index = image["bufferView"]
    view = doc["bufferViews"][view_index]
    raw = old_binary[view.get("byteOffset", 0):view.get("byteOffset", 0) + view["byteLength"]]
    source = Image.open(BytesIO(raw)).convert("RGB")
    width, height = source.size

    skin_primitive = next(p for m in doc["meshes"] for p in m["primitives"] if p.get("material") == skin_material)
    positions = accessor(doc, old_binary, skin_primitive["attributes"]["POSITION"]).astype(float)
    uvs = accessor(doc, old_binary, skin_primitive["attributes"]["TEXCOORD_0"]).astype(float)
    indices = accessor(doc, old_binary, skin_primitive["indices"]).reshape(-1).astype(int)
    bounds = positions.max(axis=0) - positions.min(axis=0)
    vertical_axis = int(np.argmax(bounds))
    if vertical_axis != 1:
        raise RuntimeError(f"Expected Ara's exported Y-up body, found vertical axis {vertical_axis}")
    height_m = float(bounds[1])
    rng = random.Random(args.seed)

    if args.coverage == "wren":
        names = ["landing_strip"]
    elif args.coverage == "reyna":
        names = ["armpits", "pubic"]
    elif args.coverage == "dagna":
        names = ["pubic"]
    else:
        names = ["armpits", "pubic"] + (["chest", "snail_trail", "scrotum"] if args.coverage == "aldric" else [])
    masks = {name: Image.new("L", (width, height), 0) for name in names}
    draws = {key: ImageDraw.Draw(mask) for key, mask in masks.items()}
    regions = {name: 0 for name in names}
    for tri in indices.reshape(-1, 3):
        p = positions[tri]
        centre = p.mean(axis=0)
        x, y, z = centre
        yn = (y - float(positions[:, 1].min())) / height_m
        # Front torso hair is restricted to +Z; arms and legs use both
        # front and rear UV faces so the texture wraps around the limbs.
        front = z > 0.035
        region = None
        uv = uvs[tri]
        polygon = [(float(u * (width - 1)), float((1.0 - v) * (height - 1))) for u, v in uv]
        # The Ara export can combine the scrotal surface with the lower pubic
        # UV island. Paint this sub-region independently before the broader
        # pubic classification so it is not swallowed by that mask.
        if args.coverage == "aldric" and front and 0.265 <= yn <= 0.405 and abs(x) <= 0.125:
            draws["scrotum"].polygon(polygon, fill=255)
            regions["scrotum"] += 1
        if args.coverage == "wren":
            # The landing strip belongs on the pubic mound, not the lower
            # abdomen. Ara exports Y-up; this band maps to the pelvis.
            # On Wren's exported Ara body, the pubic mound maps to the
            # 0.55-0.62 Y-up height band. The 0.36-0.45 trial selected the
            # lower abdomen beneath the breasts, so keep the strip down here.
            # A 50 mm total width keeps the denser strokes tightly centred.
            if front and 0.565 <= yn <= 0.605 and abs(x) <= 0.009:
                region = "landing_strip"
        elif args.coverage == "reyna":
            if 0.66 <= yn <= 0.80 and 0.075 <= abs(x) <= 0.19 and abs(z) > 0.035:
                region = "armpits"
            elif front and 0.36 <= yn <= 0.49 and abs(x) <= 0.13:
                region = "pubic"
        elif args.coverage == "dagna":
            if front and 0.43 <= yn <= 0.50 and abs(x) <= 0.075:
                region = "pubic"
        else:
            if args.coverage == "aldric":
                # Keep Aldric's hair in the compact axillary band only. The
                # lateral arms/legs masks below previously painted long strips
                # down the flanks and around the back.
                if 0.75 <= yn <= 0.82 and 0.14 <= abs(x) <= 0.23 and z > 0.0:
                    region = "armpits"
            elif front and 0.70 <= yn <= 0.76 and 0.105 <= abs(x) <= 0.155:
                region = "armpits"
            if args.coverage == "aldric":
                if region is None and front and 0.40 <= yn <= 0.56 and abs(x) <= 0.008:
                    region = "snail_trail"
                elif region is None and front and 0.34 <= yn <= 0.49 and abs(x) <= 0.060:
                    region = "pubic"
                elif region is None and front:
                    # A compact sternum diamond: broadest through the centre,
                    # tapering symmetrically toward the collarbone and navel.
                    diamond_half_width = 0.028 * max(0.0, 1.0 - abs(yn - 0.65) / 0.050)
                    if 0.60 <= yn <= 0.70 and abs(x) <= diamond_half_width:
                        region = "chest"
            elif region is None and front and 0.36 <= yn <= 0.49 and abs(x) <= 0.13:
                region = "pubic"
        if region is None:
            continue
        draws[region].polygon(polygon, fill=255)
        regions[region] += 1

    required = list(names)
    missing = [name for name in required if not regions.get(name)]
    if missing:
        raise RuntimeError(f"Hair placement found no UV faces for {missing}: {regions}; body bounds={bounds.tolist()}")

    # Texture-only hair: no extra meshes, curves, cards or particles.
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    counts = {name: 0 for name in required}
    densities = {"armpits": 170, "pubic": 520}
    if args.coverage == "wren":
        densities = {"landing_strip": 1300}
    elif args.coverage == "reyna":
        densities = {"armpits": 1250, "pubic": 520}
    elif args.coverage == "dagna":
        densities = {"pubic": 2200}
    elif args.coverage == "aldric":
        # Keep hair localised: compact axillae, a narrow sternum diamond,
        # central snail trail and pubic/scrotal regions. No arm or leg masks.
        densities.update({"armpits": 250, "chest": 300, "snail_trail": 500, "scrotum": 320, "pubic": 650})
    default_colours = {"wren": "#287BFF", "reyna": "#17120F", "dagna": "#C65A32", "aldric": "#08090A", "restrained": "#302018"}
    colour_hex = (args.hair_colour or default_colours[args.coverage]).lstrip("#")
    if len(colour_hex) != 6:
        raise ValueError("--hair-colour must be a six-digit RGB hex value")
    hair_rgb = tuple(int(colour_hex[i:i + 2], 16) for i in (0, 2, 4))
    for region, count in densities.items():
        mask = masks[region]
        # Sample directly from eligible UV pixels. Repeated random guesses over
        # the entire 2048x2048 texture under-filled small regions (notably the
        # narrow Aldric snail trail and Wren's landing strip).
        valid_pixels = np.argwhere(np.asarray(mask) > 0)
        if not len(valid_pixels):
            raise RuntimeError(f"No eligible UV pixels remain for body-hair region {region!r}")
        for _ in range(count):
            pixel_y, pixel_x = valid_pixels[rng.randrange(len(valid_pixels))]
            x, y = int(pixel_x), int(pixel_y)
            length = rng.uniform(3.0, 8.0) if region == "armpits" else rng.uniform(4.0, 11.0)
            if region == "landing_strip":
                length = rng.uniform(3.0, 6.0)
                angle = rng.uniform(-0.08, 0.08)
            else:
                angle = rng.uniform(-1.1, 1.1) if region == "armpits" else rng.uniform(-0.85, 0.85)
            dx, dy = np.cos(angle) * length, np.sin(angle) * length
            alpha_range = (210, 240) if args.coverage == "dagna" and region == "pubic" else (175, 215)
            shade = (*hair_rgb, rng.randint(*alpha_range))
            if region == "snail_trail":
                stroke_width = 1
            else:
                stroke_width = 2 if region == "landing_strip" else (2 if (args.coverage == "aldric" and region != "armpits") or (args.coverage == "dagna" and region == "pubic") else 1)
            draw.line((x, y, x + dx, y + dy), fill=shade, width=stroke_width)
            counts[region] += 1

    # Clip the marks to the actual skin UV triangles, then composite gently.
    combined_mask = Image.new("L", (width, height), 0)
    for mask in masks.values():
        combined_mask = ImageChops.lighter(combined_mask, mask)
    alpha = ImageChops.multiply(layer.getchannel("A"), combined_mask)
    layer.putalpha(alpha)
    result = Image.alpha_composite(source.convert("RGBA"), layer).convert("RGB")
    output = BytesIO()
    result.save(output, format="PNG", optimize=True)
    png = output.getvalue()
    image["mimeType"] = "image/png"

    rebuilt = bytearray()
    for index, buffer_view in enumerate(doc["bufferViews"]):
        start = buffer_view.get("byteOffset", 0)
        end = start + buffer_view["byteLength"]
        payload = png if index == view_index else old_binary[start:end]
        while len(rebuilt) % 4:
            rebuilt.append(0)
        buffer_view["byteOffset"] = len(rebuilt)
        buffer_view["byteLength"] = len(payload)
        rebuilt.extend(payload)
    buffer_length = len(rebuilt)
    while len(rebuilt) % 4:
        rebuilt.append(0)
    doc["buffers"][0]["byteLength"] = buffer_length

    packed = []
    for kind, payload in chunks:
        if kind == b"JSON":
            payload = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode()
            payload += b" " * ((-len(payload)) % 4)
        elif kind == b"BIN\x00":
            payload = bytes(rebuilt)
        packed.append((kind, payload))
    total = 12 + sum(8 + len(p) for _, p in packed)
    out = bytearray(struct.pack("<4sII", b"glTF", 2, total))
    for kind, payload in packed:
        out.extend(struct.pack("<I4s", len(payload), kind))
        out.extend(payload)
    args.model.write_bytes(out)
    print(json.dumps({"ok": True, "coverage": args.coverage, "hair_colour": "#" + colour_hex.upper(), "texture_only": True, "regions": regions, "strokes": counts, "texture": [width, height], "glb_bytes": len(out)}, indent=2))


if __name__ == "__main__":
    main()
