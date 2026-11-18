#!/usr/bin/env python3
"""Bake restrained armpit and pubic hair into Ara's skin diffuse texture.

This is an Aldric-only post-process. It uses the exported skin mesh's own UVs,
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
from PIL import Image, ImageDraw


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
    args = ap.parse_args()
    doc, old_binary, chunks = parse_glb(args.model.read_bytes())

    skin_material = next(i for i, m in enumerate(doc["materials"]) if m.get("name", "").lower() == "skin")
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

    masks = {"armpits": Image.new("L", (width, height), 0), "pubic": Image.new("L", (width, height), 0)}
    draws = {key: ImageDraw.Draw(mask) for key, mask in masks.items()}
    regions = {"armpits": 0, "pubic": 0}
    for tri in indices.reshape(-1, 3):
        p = positions[tri]
        centre = p.mean(axis=0)
        x, y, z = centre
        yn = y / height_m
        # Ara exports the face and chest toward +Z. Keep the hair on that side.
        if z <= 0:
            continue
        region = None
        if 0.67 <= yn <= 0.79 and 0.075 <= abs(x) <= 0.19:
            region = "armpits"
        elif 0.36 <= yn <= 0.49 and abs(x) <= 0.13 and z > 0.035:
            region = "pubic"
        if region is None:
            continue
        uv = uvs[tri]
        polygon = [(float(u * (width - 1)), float((1.0 - v) * (height - 1))) for u, v in uv]
        draws[region].polygon(polygon, fill=255)
        regions[region] += 1

    if not regions["armpits"] or not regions["pubic"]:
        raise RuntimeError(f"Hair placement found no suitable UV faces: {regions}; body bounds={bounds.tolist()}")

    # Draw short, low-contrast strokes and clip them to the selected skin faces.
    layer = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    counts = {"armpits": 0, "pubic": 0}
    for region, count in (("armpits", 170), ("pubic", 520)):
        mask = masks[region]
        pixels = mask.load()
        for _ in range(count):
            for _attempt in range(100):
                x = rng.randrange(width)
                y = rng.randrange(height)
                if pixels[x, y] > 0:
                    break
            else:
                continue
            length = rng.uniform(3.0, 8.0) if region == "armpits" else rng.uniform(4.0, 11.0)
            angle = rng.uniform(-1.1, 1.1) if region == "armpits" else rng.uniform(-0.85, 0.85)
            dx, dy = np.cos(angle) * length, np.sin(angle) * length
            shade = rng.choice([(30, 23, 19, 95), (38, 28, 22, 115), (48, 35, 27, 90)])
            draw.line((x, y, x + dx, y + dy), fill=shade, width=1)
            counts[region] += 1

    # Clip the marks to the actual skin UV triangles, then composite gently.
    alpha = layer.getchannel("A")
    for region, mask in masks.items():
        alpha = Image.composite(alpha, Image.new("L", (width, height), 0), mask)
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
    print(json.dumps({"ok": True, "regions": regions, "strokes": counts, "texture": [width, height], "glb_bytes": len(out)}, indent=2))


if __name__ == "__main__":
    main()
