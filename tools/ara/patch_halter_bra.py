#!/usr/bin/env python3
"""Build distinct lace and fishnet halters with broad, continuous back/shoulder panels."""
from pathlib import Path
import sys
import textwrap

source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("src/core/garments/swimwear.ts")
text = source.read_text(encoding="utf-8")
marker = "// Silverhart full-panel halter v4"
if marker in text:
    print("Full-panel halter construction already applied.")
    raise SystemExit(0)

signature = "function bikiniTop(g: GCtx, st: GarmentStyle, mode: 'lace' | 'fishnet' | null = null): GPart[] {"
if text.count(signature) != 1:
    raise SystemExit("Expected the mode-aware bikiniTop from patch_layering; refusing to patch.")

old_import = "import { clamp, hplane, isTrunk, mat, points, type GarmentDef, type GarmentStyle, type GCtx, type GPart } from './kit';"
new_import = "import { clamp, hplane, isTrunk, isUpper, mat, points, shellPart, type GarmentDef, type GarmentStyle, type GCtx, type GPart } from './kit';"
if old_import in text:
    text = text.replace(old_import, new_import, 1)
elif new_import not in text:
    raise SystemExit("Expected one swimwear toolkit import; refusing to patch.")

# patch_layering already builds lace cups with Ara's lace texture and fishnet cups
# as open strands. Do not try to replace that branch a second time. Replace only
# the shared narrow-cord halter assembly for the two halter variants.
block_start_anchor = "  const skin = upperSkin(b);"
block_end_anchor = "  parts.push({ mesh: halter, material: mode === 'lace' ?"
if text.count(block_start_anchor) != 1 or text.count(block_end_anchor) != 1:
    raise SystemExit("Expected the original shared halter-cord assembly; refusing to patch.")
block_start = text.index(block_start_anchor)
block_end = text.index("\n", text.index("skinAt: trunkLookup(b, halter) });", text.index(block_end_anchor))) + 1
original = text[block_start:block_end]
panel = """  if (!mode) {
""" + textwrap.indent(original, "  ") + """  } else {
    const sx = b.L.shoulderX;
    const panelName = mode === 'lace' ? 'Halter lace bra straps' : 'Halter fishnet bra straps';
    const panelPattern = mode === 'lace' ? 'lace' : 'fishnet_coarse';
    const panelMaterial = {
      ...swimMat(g, panelName, { ...st, pattern: panelPattern }),
      name: panelName,
      doubleSided: true,
    };
    // Continuous tank-top-derived fabric: broad back band, shoulder/halter
    // straps and rear-neck panel. No single-cord neck or back straps remain.
    const panels = shellPart(g, {
      covers: (v) => isUpper(v) && (
        // Keep only a slim lower-back anchor band; the halter is not a
        // conventional bra with a horizontal strap across the back.
        (v.tt >= 0.54 && v.tt < 0.60) ||
        // Two broad shoulder ribbons rise from the cups and converge into
        // one continuous panel at the nape, behind the neck.
        (v.tt >= 0.60 && v.tt < 0.86 &&
          (Math.abs(v.ax - 0.6 * sx) < 0.16 * sx ||
           Math.abs(v.ax + 0.6 * sx) < 0.16 * sx ||
           Math.abs(v.ax) < 0.20 * sx)) ||
        (v.tt >= 0.76 && v.region === REGION.neck)
      ),
      // Finer sampling and extra relaxation close small holes at the shoulder
      // transitions without changing the cup mesh or body.
      offset: cm(0.62), tile: 0.12, relax: 8,
    }, panelMaterial, false);
    parts.push(...panels);
  }
"""
text = text[:block_start] + panel + text[block_end:]
text = text.replace(signature, signature + "\n  // " + marker, 1)
source.write_text(text, encoding="utf-8")
print("Built lace/fishnet cups with broad continuous patterned back, shoulder and neck panels.")
