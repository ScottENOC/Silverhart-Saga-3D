#!/usr/bin/env python3
"""Apply the project-local halter-lace garment extension to the pinned Ara source."""
from pathlib import Path
import sys

source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("src/core/garments/swimwear.ts")
text = source.read_text(encoding="utf-8")

if "id: 'halter_bra_lace'" in text:
    print("Halter lace garment already present; no change needed.")
    raise SystemExit(0)

signature = "function bikiniTop(g: GCtx, st: GarmentStyle): GPart[] {"
if text.count(signature) != 1:
    raise SystemExit("Expected exactly one pinned Ara bikiniTop signature; refusing to patch.")
text = text.replace(signature, "function bikiniTop(g: GCtx, st: GarmentStyle, lace = false): GPart[] {", 1)
text = text.replace(
    "  const m = swimMat(g, 'Bikini top', st);",
    "  const m = swimMat(g, 'Bikini top', st);\n  const strapMaterial = lace ? mat('Bikini strings', null, { color: '#3b2529', roughness: 0.72 }) : stringMat(st);",
    1,
)

old = """  if (cupMeshes.length) {
    parts.push({ mesh: merge(cupMeshes.map((gr) => gridMesh(gr, 0.12)))!, material: { ...m, doubleSided: true }, hides });
    // Piping along the cups' edges, on the fabric.
    parts.push({ mesh: merge(cupMeshes.map((gr) => cord(gridOutline(gr).map((p) => v3.madd(p, OUTWARD.front, cm(0.06))), cm(0.1), true, 5)))!, material: stringMat(st) });
  }"""
new = """  if (cupMeshes.length) {
    if (lace) {
      // Openwork lace: two crossing families of cords follow each curved cup.
      const laceStrands: PolyMesh[] = [];
      for (const gr of cupMeshes) {
        const rows = gr.length, cols = gr[0]?.length ?? 0;
        for (let k = -rows; k < cols; k += 4) {
          const down: Vec3[] = [], up: Vec3[] = [];
          for (let i = 0; i < rows; i++) {
            const j = i + k;
            if (j >= 0 && j < cols) down.push(gr[i][j]);
            const mirror = cols - 1 - j;
            if (mirror >= 0 && mirror < cols) up.push(gr[i][mirror]);
          }
          if (down.length > 1) laceStrands.push(cord(down, cm(0.30), false, 6));
          if (up.length > 1) laceStrands.push(cord(up, cm(0.30), false, 6));
        }
        laceStrands.push(cord(gridOutline(gr).map((p) => v3.madd(p, OUTWARD.front, cm(0.10))), cm(0.22), true, 6));
      }
      const openwork = merge(laceStrands);
      if (openwork) parts.push({ mesh: openwork, material: mat('Halter lace', null, { color: '#3b2529', roughness: 0.72 }) });
    } else {
      parts.push({ mesh: merge(cupMeshes.map((gr) => gridMesh(gr, 0.12)))!, material: { ...m, doubleSided: true }, hides });
      // Piping along the cups' edges, on the fabric.
      parts.push({ mesh: merge(cupMeshes.map((gr) => cord(gridOutline(gr).map((p) => v3.madd(p, OUTWARD.front, cm(0.06))), cm(0.1), true, 5)))!, material: strapMaterial });
    }
  }"""
if text.count(old) != 1:
    raise SystemExit("Expected exactly one pinned Ara bikiniTop cup-mesh block; refusing to patch.")
text = text.replace(old, new, 1)
# The shared back band, sternum bridge and halter straps use the same dark lace finish.
start = text.index("function bikiniTop")
end = text.index("function bikiniBottom", start)
text = text[:start] + text[start:end].replace("material: stringMat(st)", "material: strapMaterial") + text[end:]

entry = "  { id: 'bikini_top', label: 'Bikini top (triangle)', slot: 'top', patterns: ['foil', 'solid', 'ankara', 'leopard'], color: '#c9963a', color2: '#fff1c4', build: bikiniTop },\n"
if text.count(entry) != 1:
    raise SystemExit("Expected exactly one pinned Ara bikini_top catalog entry; refusing to patch.")
text = text.replace(entry, entry + "  { id: 'halter_bra_lace', label: 'Halter bra (open lace)', slot: 'top', patterns: ['solid'], color: '#3b2529', color2: '#d6b5a5', build: (g, st) => bikiniTop(g, st, true) },\n", 1)

source.write_text(text, encoding="utf-8")
print("Added halter_bra_lace with visible openwork cups and matching dark halter/band.")
