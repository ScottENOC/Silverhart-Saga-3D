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
    def clip_polygon(poly, signed_distance):
        """Clip an interpolated (x,y,z,u,v) polygon to signed_distance <= 0."""
        if not poly:
            return []
        result = []
        previous = poly[-1]
        previous_d = signed_distance(previous)
        for current in poly:
            current_d = signed_distance(current)
            if (previous_d <= 0) != (current_d <= 0):
                denom = previous_d - current_d
                t = previous_d / denom if abs(denom) > 1e-12 else 0.0
                result.append(tuple(previous[i] + t * (current[i] - previous[i]) for i in range(5)))
            if current_d <= 0:
                result.append(current)
            previous, previous_d = current, current_d
        return result

    def paint_clipped(region, tri, constraints):
        # Clip the actual UV triangle against the requested 3D body-space
        # region. glTF UVs use the image top-left origin; do not invert V.\n        # Painting whole UV triangles based on their centroid caused
        # large stray patches on adjacent abdomen, chest and thigh surfaces.
        poly = []
        for vertex in tri:
            p = positions[vertex]
            uv = uvs[vertex]
            poly.append((float(p[0]), float(p[1]), float(p[2]), float(uv[0]), float(uv[1])))
        for constraint in constraints:
            poly = clip_polygon(poly, constraint)
            if len(poly) < 3:
                return False
        uv_polygon = [(v[3] * (width - 1), v[4] * (height - 1)) for v in poly]
        draws[region].polygon(uv_polygon, fill=255)
        regions[region] += 1
        return True

    y_min = float(positions[:, 1].min())
    def yn_of(p):
        return (p[1] - y_min) / height_m

    def band(y0, y1, x0, x1, front=True):
        constraints = [
            lambda p, y0=y0: y0 - yn_of(p),
            lambda p, y1=y1: yn_of(p) - y1,
            lambda p, x0=x0: x0 - p[0],
            lambda p, x1=x1: p[0] - x1,
        ]
        if front is True:
            constraints.append(lambda p: 0.035 - p[2])
        elif front is False:
            constraints.append(lambda p: p[2] + 0.035)
        return constraints

    for tri in indices.reshape(-1, 3):
        if args.coverage == "wren":
            # Keep the lower edge at the existing clitoral-hood start, shorten
            # the strip by 40%, and flare only the upper edge by 75%.
            y0, y1 = 0.49, 0.52
            base_half_width = 0.0065
            top_half_width = base_half_width * 1.75
            slope = (top_half_width - base_half_width) / (y1 - y0)
            constraints = [
                lambda p: y0 - yn_of(p),
                lambda p: yn_of(p) - y1,
                lambda p: p[0] - (base_half_width + slope * (yn_of(p) - y0)),
                lambda p: -p[0] - (base_half_width + slope * (yn_of(p) - y0)),
                lambda p: 0.035 - p[2],
            ]
            paint_clipped("landing_strip", tri, constraints)
        elif args.coverage == "reyna":
            # Separate left/right axillae; keep the markings on the lateral
            # upper torso rather than allowing a broad triangle to reach the
            # chest or flank.
            for side in (-1, 1):
                paint_clipped("armpits", tri, band(0.82, 0.89, side * 0.19 if side < 0 else 0.075,
                                                     side * 0.075 if side < 0 else 0.19, front=True))
                paint_clipped("armpits", tri, band(0.82, 0.89, side * 0.19 if side < 0 else 0.075,
                                                     side * 0.075 if side < 0 else 0.19, front=False))
            paint_clipped("pubic", tri, band(0.28, 0.37, -0.045, 0.045))
        elif args.coverage == "dagna":
            paint_clipped("pubic", tri, band(0.28, 0.37, -0.055, 0.055))
        elif args.coverage == "aldric":
            # Keep axillary hair high and lateral. The previous 0.75-0.82
            # band selected the lower pectoral/rib area, not the armpit.
            paint_clipped("armpits", tri, band(0.82, 0.89, -0.23, -0.16, front=True))
            paint_clipped("armpits", tri, band(0.82, 0.89, 0.16, 0.23, front=True))
            paint_clipped("snail_trail", tri, band(0.38, 0.48, -0.004, 0.004))
            paint_clipped("pubic", tri, band(0.28, 0.38, -0.045, 0.045))
            paint_clipped("scrotum", tri, band(0.24, 0.34, -0.080, 0.080))
            # A true narrow diamond, clipped as two linear wedges.
            lower = [lambda p: 0.60 - yn_of(p), lambda p: yn_of(p) - 0.65,
                     lambda p: p[0] - 0.56 * p[1] + 0.336,
                     lambda p: -p[0] - 0.56 * p[1] + 0.336,
                     lambda p: 0.035 - p[2]]
            upper = [lambda p: 0.65 - yn_of(p), lambda p: yn_of(p) - 0.70,
                     lambda p: p[0] + 0.56 * p[1] - 0.392,
                     lambda p: -p[0] + 0.56 * p[1] - 0.392,
                     lambda p: 0.035 - p[2]]
            paint_clipped("chest", tri, lower)
            paint_clipped("chest", tri, upper)
        else:
            paint_clipped("armpits", tri, band(0.70, 0.76, -0.155, -0.105, front=True))
            paint_clipped("armpits", tri, band(0.70, 0.76, 0.105, 0.155, front=True))
            paint_clipped("pubic", tri, band(0.27, 0.35, -0.13, 0.13))

    required = list(names)
    missing = [name for name in required if not regions.get(name)]
    if args.coverage in ("aldric", "reyna", "dagna") and "pubic" in missing:
        # Some Ara body variants have no separate pubic UV island after the
        # integrated anatomy pass. Keep the export valid and retain any other
        # verified body-hair regions rather than failing over an optional detail.
        print(f"Warning: no separate pubic skin UV faces for {args.coverage}; skipping only that body-hair region.")
        required.remove("pubic")
        names.remove("pubic")
        masks.pop("pubic", None)
        missing.remove("pubic")
    if missing:
        raise RuntimeError(f"Hair placement found no UV faces for {missing}: {regions}; body bounds={bounds.tolist()}")

    # Texture-only hair: no extra meshes, curves, cards or particles.
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    counts = {name: 0 for name in required}
    densities = {"armpits": 170, "pubic": 520}
    if args.coverage == "wren":
        densities = {"landing_strip": 1500}
    elif args.coverage == "reyna":
        densities = {"armpits": 700, "pubic": 650}
    elif args.coverage == "dagna":
        densities = {"pubic": 1800}
    elif args.coverage == "aldric":
        # Keep hair localised: compact axillae, a narrow sternum diamond,
        # central snail trail and pubic/scrotal regions. No arm or leg masks.
        densities.update({"armpits": 300, "chest": 260, "snail_trail": 350, "scrotum": 260, "pubic": 650})
        if "pubic" not in masks:
            densities.pop("pubic", None)
    # A missing optional UV island is removed from masks above; never index it later.
    densities = {region: count for region, count in densities.items() if region in masks}
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
