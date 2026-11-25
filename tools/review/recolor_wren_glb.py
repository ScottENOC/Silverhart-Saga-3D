#!/usr/bin/env python3
"""Apply the character profile's skin/hair tints to a final embedded GLB.

Ara's MakeHuman hair proxy texture is unusually dark. A gentle gamma lift makes
its blue material tint visible without replacing the braid texture or geometry.
"""
import argparse
import json
import struct
from io import BytesIO
from pathlib import Path
import math
import random

from PIL import Image, ImageChops, ImageDraw


def parse_hex(value: str):
    value = value.strip().lstrip("#")
    if len(value) == 3:
        value = "".join(ch * 2 for ch in value)
    if len(value) != 6:
        raise ValueError(f"Expected #RRGGBB colour, got {value!r}")
    return [int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] + [1.0]


def parse_glb(data: bytes):
    if len(data) < 20:
        raise ValueError("Input is too short to be a GLB")
    magic, version, total_length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2 or total_length != len(data):
        raise ValueError("Invalid GLB header")
    chunks = []
    offset = 12
    while offset < len(data):
        length, kind = struct.unpack_from("<I4s", data, offset)
        offset += 8
        payload = data[offset:offset + length]
        if len(payload) != length:
            raise ValueError("Truncated GLB chunk")
        chunks.append([kind, payload])
        offset += length
    json_chunk = next((payload for kind, payload in chunks if kind == b"JSON"), None)
    bin_chunk = next((payload for kind, payload in chunks if kind == b"BIN\x00"), None)
    if json_chunk is None or bin_chunk is None:
        raise ValueError("Expected JSON and BIN chunks in GLB")
    document = json.loads(json_chunk.decode("utf-8").rstrip("\x00 "))
    return document, bin_chunk, chunks


def material_by_name(document, name):
    materials = document.get("materials", [])
    target = name.strip().lower()
    for material in materials:
        if material.get("name", "").strip().lower() == target:
            return material
    # The surface-following anatomy workflow isolates the skin shader as
    # Skin_Anatomy so it cannot mutate shared materials. Treat that as the
    # same logical skin material for downstream recolouring.
    for material in materials:
        actual = material.get("name", "").strip().lower()
        if target == "skin" and actual.startswith("skin_anatomy"):
            return material
    raise ValueError(f"Could not find GLB material named {name!r}")


def procedural_grey_strands(source_image, hair_rgb, seed=4821):
    """Create sparse, fine grey fibres over Ara's otherwise flat hair-card texture.

    The exported Ara short-hair diffuse has virtually no strand luminance detail:
    almost every opaque texel is RGB 18, while the few bright texels are the
    MakeHuman watermark. Do not mistake those pixels for strands. Preserve the
    real hair-card alpha, discard watermark-coloured pixels, and draw restrained
    curved fibres into the UV islands instead.
    """
    alpha = source_image.getchannel("A")
    luminance = source_image.convert("L")
    hair_mask = ImageChops.multiply(
        alpha, luminance.point(lambda value: 255 if value < 80 else 0)
    )
    if hair_mask.getbbox() is None:
        hair_mask = alpha

    size = source_image.size
    base = Image.new("RGB", size, hair_rgb)
    strand_rgb = base.copy()
    strand_mask = Image.new("L", size, 0)
    colour_draw = ImageDraw.Draw(strand_rgb)
    mask_draw = ImageDraw.Draw(strand_mask)
    valid = hair_mask.load()
    width, height = size
    rng = random.Random(seed)

    # Ara's two short-hair UV islands flow predominantly across the image.
    # Long, gently curved strokes remain narrow after texture mipmapping.
    strand_count = 170
    for _ in range(strand_count):
        for _attempt in range(120):
            x = rng.randrange(width)
            y = rng.randrange(height)
            if valid[x, y] > 0:
                break
        else:
            continue

        angle = rng.uniform(-0.18, 0.18)
        length = rng.uniform(130.0, 360.0)
        bend = rng.uniform(-0.018, 0.018)
        dx, dy = math.cos(angle), math.sin(angle)
        points = []
        for step in range(9):
            t = step / 8.0
            px = x + (t - 0.5) * length * dx
            py = y + (t - 0.5) * length * dy + math.sin(t * math.pi) * bend * length
            points.append((px, py))

        tone = rng.random()
        if tone < 0.62:
            shade = (35, 38, 43)       # charcoal grey
        elif tone < 0.93:
            shade = (52, 56, 63)       # visible grey
        else:
            shade = (82, 87, 94)       # a few silver hairs
        stroke_width = rng.choice((2, 3, 3, 4))
        opacity = rng.randint(160, 220)
        colour_draw.line(points, fill=shade, width=stroke_width)
        mask_draw.line(points, fill=opacity, width=stroke_width)

    clipped_mask = ImageChops.multiply(strand_mask, hair_mask)
    result_rgb = Image.composite(strand_rgb, base, clipped_mask)
    return Image.merge("RGBA", (*result_rgb.split(), hair_mask))


def recolor(path: Path, profile_path: Path, hair_gamma: float, grey_strands: bool = False, bake_hair_tint: bool = False):
    profile = json.loads(profile_path.read_text())
    params = profile.get("params", {})
    skin_factor = parse_hex(params.get("skinTint", "#FFFFFF"))
    hair_factor = [1.0, 1.0, 1.0, 1.0] if (grey_strands or bake_hair_tint) else parse_hex(params.get("hairTint", "#FFFFFF"))

    document, old_binary, chunks = parse_glb(path.read_bytes())
    skin_material = material_by_name(document, "Skin")
    hair_material = material_by_name(document, "Hair")
    skin_pbr = skin_material.setdefault("pbrMetallicRoughness", {})
    hair_pbr = hair_material.setdefault("pbrMetallicRoughness", {})
    # Ara's native export can omit these factors when a texture is connected.
    # Explicit factors ensure the profile colours survive the anatomy pass.
    skin_pbr["baseColorFactor"] = skin_factor
    hair_pbr["baseColorFactor"] = hair_factor

    texture_index = hair_pbr.get("baseColorTexture", {}).get("index")
    if texture_index is None:
        raise ValueError("Hair material has no base-colour texture")
    texture = document.get("textures", [])[texture_index]
    image_index = texture.get("source")
    if image_index is None:
        raise ValueError("Hair texture has no embedded image source")
    image = document.get("images", [])[image_index]
    view_index = image.get("bufferView")
    if view_index is None:
        raise ValueError("Hair image is not embedded in a GLB bufferView")

    views = document.get("bufferViews", [])
    view = views[view_index]
    if view.get("buffer", 0) != 0:
        raise ValueError("Only the primary embedded GLB buffer is supported")
    start = view.get("byteOffset", 0)
    source_bytes = old_binary[start:start + view["byteLength"]]
    source_image = Image.open(BytesIO(source_bytes)).convert("RGBA")

    # Preserve the strand texture and alpha. For Aldric, map the texture's
    # natural strand highlights to restrained silver-grey over a near-black base.
    red, green, blue, alpha = source_image.split()
    if grey_strands:
        # Apply the requested base colour directly, then add synthetic fibres.
        # Ara's source diffuse has no usable per-strand luminance variation.
        hair_rgb = tuple(int(round(channel * 255.0)) for channel in parse_hex(params.get("hairTint", "#08090A"))[:3])
        lifted = procedural_grey_strands(source_image, hair_rgb)
    elif bake_hair_tint:
        # Bake the profile tint into Ara's pale photo-based hair diffuse.
        # This avoids relying on material multipliers behaving consistently
        # across GLB importers.
        tint = parse_hex(params.get("hairTint", "#FFFFFF"))[:3]
        channels = [
            channel.point(lambda value, factor=factor: int(round(value * factor)))
            for channel, factor in zip((red, green, blue), tint)
        ]
        lifted = Image.merge("RGBA", (*channels, alpha))
    else:
        lut = [
            min(255, int(round(((value / 255.0) ** hair_gamma) * 255.0)))
            for value in range(256)
        ]
        lifted = Image.merge(
            "RGBA",
            (red.point(lut), green.point(lut), blue.point(lut), alpha),
        )
    output = BytesIO()
    lifted.save(output, format="PNG", optimize=True)
    hair_png = output.getvalue()
    image["mimeType"] = "image/png"

    # Repack the BIN chunk and update every bufferView offset/length.
    new_binary = bytearray()
    for index, buffer_view in enumerate(views):
        old_start = buffer_view.get("byteOffset", 0)
        old_end = old_start + buffer_view["byteLength"]
        payload = hair_png if index == view_index else old_binary[old_start:old_end]
        while len(new_binary) % 4:
            new_binary.append(0)
        buffer_view["byteOffset"] = len(new_binary)
        buffer_view["byteLength"] = len(payload)
        new_binary.extend(payload)
    buffer_length = len(new_binary)
    while len(new_binary) % 4:
        new_binary.append(0)
    document["buffers"][0]["byteLength"] = buffer_length

    rebuilt_chunks = []
    for kind, payload in chunks:
        if kind == b"JSON":
            payload = json.dumps(
                document, separators=(",", ":"), ensure_ascii=False
            ).encode("utf-8")
            payload += b" " * ((-len(payload)) % 4)
        elif kind == b"BIN\x00":
            payload = bytes(new_binary)
        rebuilt_chunks.append((kind, payload))

    total_length = 12 + sum(8 + len(payload) for _, payload in rebuilt_chunks)
    result = bytearray(struct.pack("<4sII", b"glTF", 2, total_length))
    for kind, payload in rebuilt_chunks:
        result.extend(struct.pack("<I4s", len(payload), kind))
        result.extend(payload)
    path.write_bytes(result)

    print(json.dumps({
        "ok": True,
        "skin_factor": skin_factor,
        "hair_factor": hair_factor,
        "hair_gamma": hair_gamma,
        "grey_strands": grey_strands,
        "bake_hair_tint": bake_hair_tint,
        "hair_texture_bytes_before": len(source_bytes),
        "hair_texture_bytes_after": len(hair_png),
        "glb_bytes": len(result),
    }, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--profile", required=True, type=Path)
    parser.add_argument("--hair-gamma", type=float, default=0.28)
    parser.add_argument("--grey-strands", action="store_true")
    parser.add_argument("--bake-hair-tint", action="store_true")
    arguments = parser.parse_args()
    recolor(arguments.model, arguments.profile, arguments.hair_gamma, arguments.grey_strands, arguments.bake_hair_tint)
