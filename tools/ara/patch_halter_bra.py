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
if text.count(old_import) != 1: raise SystemExit("Expected one swimwear toolkit import.")
text = text.replace(old_import, new_import, 1)

start_marker = "    } else if (mode === 'lace') {"
end_marker = "\\n    }\\n  }\\n  const skin = upperSkin(b);"
if text.count(start_marker) != 1 or text.count(end_marker) != 1:
    raise SystemExit("Expected exactly one halter lace branch.")
start = text.index(start_marker)
end = text.index(end_marker, start) + len("\\n    }")
replacement = """    } else if (mode === 'lace') {
      const laceMaterial = swimMat(g, 'Halter lace bra cups', { ...st, pattern: 'lace' });
      parts.push({ mesh: merge(cupMeshes.map((gr) => gridMesh(gr, 0.12)))!,
        material: { ...laceMaterial, doubleSided: true } });
      parts.push({ mesh: merge(cupMeshes.map((gr) => cord(
        gridOutline(gr).map((p) => v3.madd(p, OUTWARD.front, cm(0.08))), cm(0.12), true, 5
      )))!, material: { ...stringMat(st), name: 'Halter lace bra piping' } });
    } else {
      parts.push({ mesh: merge(cupMeshes.map((gr) => gridMesh(gr, 0.12)))!, material: { ...m, doubleSided: true }, hides });
      parts.push({ mesh: merge(cupMeshes.map((gr) => cord(gridOutline(gr).map((p) => v3.madd(p, OUTWARD.front, cm(0.06))), cm(0.1), true, 5)))!, material: { ...stringMat(st), name: 'Bikini top piping' } });
    }"""
text = text.slice(0,start) + replacement + text.slice(end)

const blockStart = text.indexOf("  const skin = upperSkin(b);", start)
const blockEndAnchor = "  parts.push({ mesh: halter, material: stringMat(st), skinAt: trunkLookup(b, halter) });"
if (text.split(blockEndAnchor).length !== 2) throw new Error("Expected original halter cord assembly.");
const blockEnd = text.indexOf(blockEndAnchor, blockStart) + blockEndAnchor.length;
const original = text.slice(blockStart,blockEnd);
const panel = `  if (!mode) {
` + textwrap.indent(original, "  ") + `
  } else {
    const sx = b.L.shoulderX;
    const panelName = mode === 'lace' ? 'Halter lace bra straps' : 'Halter fishnet bra straps';
    const panelPattern = mode === 'lace' ? 'lace' : 'fishnet_coarse';
    const panelMaterial = { ...swimMat(g, panelName, { ...st, pattern: panelPattern }), name: panelName, doubleSided: true };
    // Tank-top-derived back band, broad shoulder straps and rear-neck panel.
    const panels = shellPart(g, {
      covers: (v) => isUpper(v) && v.tt >= 0.52 && (
        (v.tt < 0.74 && Math.abs(v.tth) > 1.62) ||
        Math.abs(v.ax - 0.6 * sx) < 0.2 * sx ||
        (v.region === REGION.neck && v.tt >= 0.74 && Math.abs(v.tth) > 1.6)
      ),
      offset: cm(0.62), tile: 0.2, relax: 4,
    }, panelMaterial, false);
    parts.push(...panels);
  }`;
text = text.slice(0,blockStart) + panel + text.slice(blockEnd);
const sig="function bikiniTop(g: GCtx, st: GarmentStyle, mode: 'lace' | 'fishnet' | null = null): GPart[] {";
if(text.split(sig).length!==2)throw new Error("Expected bikiniTop signature once");
text=text.replace(sig,sig+"\\n  // "+marker);
source.write_text(text, encoding="utf-8");
print("Built distinct lace cups and broad fishnet/lace panels over the back, shoulders and rear neck.");
