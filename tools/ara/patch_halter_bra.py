#!/usr/bin/env python3
"""Replace Ara's halter-lace fabric panel with independent openwork cords.

Run after patch_layering.py against the pinned Ara swimwear.ts source.
"""
from pathlib import Path
import sys

source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("src/core/garments/swimwear.ts")
text = source.read_text(encoding="utf-8")
marker = "// Silverhart openwork halter lace v2"
if marker in text:
    print("Openwork halter lace already applied.")
    raise SystemExit(0)
if "id: 'halter_bra_lace'" not in text or "mode: 'lace' | 'fishnet' | null" not in text:
    raise SystemExit("Expected patch_layering halter catalogue and mode builder; refusing to patch.")

start_marker = "    } else {\n      // Lace retains the complete fitted cup shape"
end_marker = "\n    }\n  }\n  const skin = upperSkin(b);"
if text.count(start_marker) != 1 or text.count(end_marker) != 1:
    raise SystemExit("Expected exactly one layered halter cup branch; refusing to patch.")
start = text.index(start_marker)
end = text.index(end_marker, start) + len("\n    }")
replacement = """    } else if (mode === 'lace') {
      // Silverhart openwork halter lace v2: crossing cords follow the fitted
      // cup surface. No fabric panel is emitted and no body faces are hidden.
      const laceStrands: PolyMesh[] = [];
      for (const gr of cupMeshes) {
        const rows = gr.length, cols = gr[0]?.length ?? 0;
        for (let offset = -rows; offset < cols; offset += 4) {
          const diagonal: Vec3[] = [];
          for (let row = 0; row < rows; row++) {
            const col = row + offset;
            if (col >= 0 && col < cols) diagonal.push(gr[row][col]);
          }
          if (diagonal.length > 1) laceStrands.push(cord(diagonal, cm(0.16), false, 5));
        }
        for (let offset = 0; offset < rows + cols; offset += 4) {
          const diagonal: Vec3[] = [];
          for (let row = 0; row < rows; row++) {
            const col = offset - row;
            if (col >= 0 && col < cols) diagonal.push(gr[row][col]);
          }
          if (diagonal.length > 1) laceStrands.push(cord(diagonal, cm(0.16), false, 5));
        }
      }
      const openwork = merge(laceStrands);
      if (openwork) parts.push({
        mesh: openwork,
        material: mat('Halter lace bra cups', null, { color: st.color2, roughness: 0.62 }),
      });
      parts.push({
        mesh: merge(cupMeshes.map((gr) => cord(
          gridOutline(gr).map((p) => v3.madd(p, OUTWARD.front, cm(0.08))), cm(0.12), true, 5
        )))!,
        material: { ...stringMat(st), name: 'Halter lace bra piping' },
      });
    } else {
      // The original triangle bikini remains a solid, separately named garment.
      parts.push({ mesh: merge(cupMeshes.map((gr) => gridMesh(gr, 0.12)))!, material: { ...m, doubleSided: true }, hides });
      parts.push({ mesh: merge(cupMeshes.map((gr) => cord(gridOutline(gr).map((p) => v3.madd(p, OUTWARD.front, cm(0.06))), cm(0.1), true, 5)))!, material: { ...stringMat(st), name: 'Bikini top piping' } });
    }"""
text = text[:start] + replacement + text[end:]
source.write_text(text, encoding="utf-8")
print("Replaced halter lace fabric panel with independent openwork cord geometry.")
