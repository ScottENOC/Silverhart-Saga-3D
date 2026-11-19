#!/usr/bin/env python3
"""Build distinct lace and fishnet halters with broad, continuous back/shoulder panels."""
from pathlib import Path
import sys
import textwrap

source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("src/core/garments/swimwear.ts")
text = source.read_text(encoding="utf-8")
marker = "// Silverhart full-panel halter v3"
if marker in text:
    print("Full-panel halter construction already applied.")
    raise SystemExit(0)
if "id: 'halter_bra_lace'" not in text or "mode: 'lace' | 'fishnet' | null" not in text:
    raise SystemExit("Expected patch_layering halter catalogue and mode builder; refusing to patch.")

old_import = "import { clamp, hplane, isTrunk, mat, points, type GarmentDef, type GarmentStyle, type GCtx, type GPart } from './kit';"
new_import = "import { clamp, hplane, isTrunk, isUpper, mat, points, shellPart, type GarmentDef, type GarmentStyle, type GCtx, type GPart } from './kit';"
if text.count(old_import) != 1:
    raise SystemExit("Expected one swimwear toolkit import; refusing to patch.")
text = text.replace(old_import, new_import, 1)

# Replace the previous lace lattice with Ara's distinct corded guipure texture.
start_marker = "    } else if (mode === 'lace') {"
end_marker = "\n    }\n  }\n  const skin = upperSkin(b);"
if text.count(start_marker) != 1 or text.count(end_marker) != 1:
    raise SystemExit("Expected exactly one halter lace branch; refusing to patch.")
start = text.index(start_marker)
end = text.index(end_marker, start) + len("\n    }")
replacement = """    } else if (mode === 'lace') {
      const laceMaterial = swimMat(g, 'Halter lace bra cups', { ...st, pattern: 'lace' });
      parts.push({
        mesh: merge(cupMeshes.map((gr) => gridMesh(gr, 0.12)))!,
        material: { ...laceMaterial, doubleSided: true },
      });
      parts.push({
        mesh: merge(cupMeshes.map((gr) => cord(
          gridOutline(gr).map((p) => v3.madd(p, OUTWARD.front, cm(0.08))), cm(0.12), true, 5
        )))!,
        material: { ...stringMat(st), name: 'Halter lace bra piping' },
      });
    } else {
      parts.push({ mesh: merge(cupMeshes.map((gr) => gridMesh(gr, 0.12)))!, material: { ...m, doubleSided: true }, hides });
      parts.push({ mesh: merge(cupMeshes.map((gr) => cord(gridOutline(gr).map((p) => v3.madd(p, OUTWARD.front, cm(0.06))), cm(0.1), true, 5)))!, material: { ...stringMat(st), name: 'Bikini top piping' } });
    }"""
text = text[:start] + replacement + text[end:]

# Keep the original string construction for the triangle bikini only. The two
# halter variants instead use broad fitted panels cut from Ara's tank-top shell.
block_start = text.index("  const skin = upperSkin(b);", start)
block_end_anchor = "  parts.push({ mesh: halter, material: stringMat(st), skinAt: trunkLookup(b, halter) });"
if text.count(block_end_anchor) != 1:
    raise SystemExit("Expected one original halter cord assembly; refusing to patch.")
block_end = text.index(block_end_anchor, block_start) + len(block_end_anchor)
original = text[block_start:block_end]
panel = """  if (!mode) {
""" + textwrap.indent(original, "  ") + """
  } else {
    const sx = b.L.shoulderX;
    const panelName = mode === 'lace' ? 'Halter lace bra straps' : 'Halter fishnet bra straps';
    const panelPattern = mode === 'lace' ? 'lace' : 'fishnet_coarse';
    const panelMaterial = {
      ...swimMat(g, panelName, { ...st, pattern: panelPattern }),
      name: panelName,
      doubleSided: true,
    };
    // Tank-top-derived back band, broad shoulder straps and rear-neck panel.
    // These are continuous openwork surfaces, not single cords or front fabric.
    const panels = shellPart(g, {
      covers: (v) => isUpper(v) && v.tt >= 0.52 && (
        (v.tt < 0.74 && Math.abs(v.tth) > 1.62) ||
        Math.abs(v.ax - 0.6 * sx) < 0.2 * sx ||
        (v.region === REGION.neck && v.tt >= 0.74 && Math.abs(v.tth) > 1.6)
      ),
      offset: cm(0.62), tile: 0.2, relax: 4,
    }, panelMaterial, false);
    parts.push(...panels);
  }"""
text = text[:block_start] + panel + text[block_end:]

signature = "function bikiniTop(g: GCtx, st: GarmentStyle, mode: 'lace' | 'fishnet' | null = null): GPart[] {"
if text.count(signature) != 1:
    raise SystemExit("Expected one bikiniTop signature; refusing to patch.")
text = text.replace(signature, signature + "\n  // " + marker, 1)

source.write_text(text, encoding="utf-8")
print("Built distinct lace cups and broad fishnet/lace panels over the back, shoulders and rear neck.")
