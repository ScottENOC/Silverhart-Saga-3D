"""Patch the pinned Ara source with explicit under-garment layers for Silverhart.

Adds an underTop garment slot and ensures briefs are generated beneath all outer
bottoms. The patch is strict: if Ara changes its source contract, the build fails.
"""
from pathlib import Path

ROOT = Path("/tmp/ara-3d-gen")


def edit(path, replacements):
    file = ROOT / path
    source = file.read_text()
    for old, new in replacements:
        if old not in source:
            raise SystemExit(f"Ara source contract changed in {path}; missing: {old[:100]!r}")
        source = source.replace(old, new, 1)
    file.write_text(source)


edit("src/core/params.ts", [
    ("  top: string;\n  /** Procedural jacket", "  top: string;\n  /** Optional base layer worn beneath the main top (e.g. a bra). */\n  underTop: string;\n  /** Optional lower underwear layer (e.g. briefs or string bikini bottom). */\n  underBottom: string;\n  /** Procedural jacket"),
    ("  top: 'none',\n  jacket: 'none',", "  top: 'none',\n  underTop: 'none',\n  underBottom: 'none',\n  jacket: 'none',"),
    ("'outfit', 'top', 'jacket', 'bottom', 'shoes'", "'outfit', 'top', 'underTop', 'underBottom', 'jacket', 'bottom', 'shoes'"),
])

edit("src/core/garments/index.ts", [
    ("import type { FittedOutfit } from './kit';", "import { briefsUnder, type FittedOutfit } from './kit';"),
    ("export interface Dressing {\n  top?: string;", "export interface Dressing {\n  top?: string;\n  underTop?: string;\n  underBottom?: string;"),
    ("  let top = pieces && topId !== 'none' && garmentById.has(topId) ? topId : undefined;", "  let top = pieces && topId !== 'none' && garmentById.has(topId) ? topId : undefined;\n  const underTop = pieces && p.underTop !== 'none' && garmentById.get(p.underTop)?.slot === 'top' ? p.underTop : undefined;\n  const underBottom = pieces && p.underBottom !== 'none' && garmentById.get(p.underBottom)?.slot === 'bottom' ? p.underBottom : undefined;"),
    ("    top,\n    jacket,", "    top,\n    underTop,\n    underBottom,\n    jacket,"),
    ("[d.top, d.jacket, d.bottom, ...d.accessories]", "[d.underBottom, d.bottom, d.underTop, d.top, d.jacket, ...d.accessories]"),
    ("if (!d.top && !d.jacket && !d.bottom && !d.accessories.length && !d.footwear)", "if (!d.top && !d.underTop && !d.underBottom && !d.jacket && !d.bottom && !d.accessories.length && !d.footwear)"),
    ("layered: { top: !!d.top, bottom: !!d.bottom && d.bottom !== 'briefs' },\n    underwear: d.underwear,", "layered: { top: !!d.top || !!d.underTop, bottom: (!!d.bottom && d.bottom !== 'briefs') || !!d.underBottom },\n    // Briefs are added once below, independently of the selected outer bottoms.\n    underwear: false,"),
    ("if (id === d.bottom || id === d.top || id === d.jacket) {", "if (id === d.underBottom || id === d.bottom || id === d.underTop || id === d.top || id === d.jacket) {"),
    ("for (const id of [d.bottom, d.top, d.jacket, ...d.accessories]) dress(id);", "for (const id of [d.underBottom, d.bottom, d.underTop, d.top, d.jacket, ...d.accessories]) dress(id);\n  if (d.underwear && !d.underBottom && d.bottom && d.bottom !== 'briefs') parts.push(...briefsUnder({ ...g, underwear: true }));"),
])

edit("src/core/garments/catalog.ts", [
    ("  // ---------------- Tops\n", """  // ---------------- Tops
  {
    id: 'bra', label: 'Sports bra (under layer)', slot: 'top', patterns: ['solid'], color: '#34343a', color2: '#111114',
    build: (g, st) => shellPart(g, {
      // Close-fitting front and side chest band; thinner than the outer shirt.
      covers: (v) => isTrunk(v) && v.tt > 0.52 && v.tt < 0.79 && Math.abs(v.tth) < 1.62,
      offset: cm(0.48), tile: 0.2, relax: 3,
    }, cloth(g, 'Bra', st)),
  },
"""),
])


# Extend Ara's existing lace texture into a true open-weave alpha-cutout fabric.
edit("src/core/garments/kit.ts", [
    ("export interface GarmentStyle {\n  pattern: Pattern;\n  color: string;\n  color2: string;\n}",
     "export interface GarmentStyle {\n  pattern: Pattern;\n  color: string;\n  color2: string;\n  opacity?: number;\n}"),
    ("  const rough = st.pattern === 'leather' ? 0.55 : st.pattern === 'techwear' ? 0.6 : 0.88;\n  return mat(name, tex, { roughness: rough, ...o });",
     "  const rough = st.pattern === 'leather' ? 0.55 : st.pattern === 'techwear' ? 0.6 : 0.88;\n  const opacity = Math.max(0, Math.min(1, st.opacity ?? 1));\n  return mat(name, tex, { roughness: rough, ...(opacity < 0.999 ? { alpha: 'blend' as const, opacity } : {}), ...o });")
])
edit("src/core/params.ts", [
    ("garmentStyles: Record<string, { pattern?: string; color?: string; color2?: string }>;",
     "garmentStyles: Record<string, { pattern?: string; color?: string; color2?: string; opacity?: number }>;"),
    ("...(typeof o.color2 === 'string' && /^#[0-9a-fA-F]{6}$/.test(o.color2) ? { color2: o.color2 } : {}),\n      };",
     "...(typeof o.color2 === 'string' && /^#[0-9a-fA-F]{6}$/.test(o.color2) ? { color2: o.color2 } : {}),\n        ...(typeof o.opacity === 'number' && Number.isFinite(o.opacity) ? { opacity: Math.max(0, Math.min(1, o.opacity)) } : {}),\n      };")
])
edit("src/core/garments/index.ts", [
    ("return { pattern, color: o.color ?? def.color, color2: o.color2 ?? def.color2 };",
     "return { pattern, color: o.color ?? def.color, color2: o.color2 ?? def.color2, ...(o.opacity !== undefined ? { opacity: o.opacity } : {}) };")
])
edit("src/core/garments/textures.ts", [
    ("const c = cordv > 0.3 ? mul(cordC, 0.85 + 0.2 * cordv) : net ? mul(A, 0.86) : lining;\n        return { c, h: cordv * 1.4 + (net ? 0.25 : 0) };\n      }, false, 3.5);",
     "const c = cordv > 0.3 ? mul(cordC, 0.85 + 0.2 * cordv) : net ? mul(A, 0.86) : lining;\n        return { c, a: cordv > 0.3 || net ? 1 : 0, h: cordv * 1.4 + (net ? 0.25 : 0) };\n      }, true, 3.5);")
])

# Tell outer garment builders when a separate under-top exists. This lets
# shirts sit farther out only when an underlayer is equipped.
edit("src/core/garments/kit.ts", [
    ("layered: { top: boolean; bottom: boolean };",
     "layered: { top: boolean; bottom: boolean; underTop: boolean };")
])
edit("src/core/garments/index.ts", [
    ("layered: { top: !!d.top || !!d.underTop, bottom: (!!d.bottom && d.bottom !== 'briefs') || !!d.underBottom },",
     "layered: { top: !!d.top || !!d.underTop, bottom: (!!d.bottom && d.bottom !== 'briefs') || !!d.underBottom, underTop: !!d.underTop },")
])
edit("src/core/garments/catalog.ts", [
    ("offset: cm(0.5), tile: 0.2, relax: 4,",
     "offset: (v) => cm(0.5) + (g.layered.underTop ? cm(0.7) : 0), tile: 0.2, relax: 4,"),
    ("offset: cm(1.0), tile: 0.3, relax: 3,",
     "offset: (v) => cm(1.0) + (g.layered.underTop ? cm(0.7) : 0), tile: 0.3, relax: 3,")
])

# Build the lace halter from Ara's own fitted bikini-cup geometry. This preserves
# its anatomically fitted lower cup, continuous back band and neck straps; only
# the cup surface changes from solid fabric to openwork cords.
edit("src/core/garments/swimwear.ts", [
    ("function bikiniTop(g: GCtx, st: GarmentStyle): GPart[] {",
     "function bikiniTop(g: GCtx, st: GarmentStyle, lace = false): GPart[] {"),
    ("  const m = swimMat(g, 'Bikini top', st);",
     "  const m = swimMat(g, lace ? 'Halter lace' : 'Bikini top', st);"),
    ("""  if (cupMeshes.length) {
    parts.push({ mesh: merge(cupMeshes.map((gr) => gridMesh(gr, 0.12)))!, material: { ...m, doubleSided: true }, hides });
    // Piping along the cups' edges, on the fabric.
    parts.push({ mesh: merge(cupMeshes.map((gr) => cord(gridOutline(gr).map((p) => v3.madd(p, OUTWARD.front, cm(0.06))), cm(0.1), true, 5)))!, material: stringMat(st) });
  }""",
     """  if (cupMeshes.length) {
    if (lace) {
      // Actual openwork geometry: a fine diamond lattice spans the complete cup,
      // including the lower half. There is no opaque panel behind the strands.
      const strands: PolyMesh[] = [];
      for (const gr of cupMeshes) {
        for (let row = 0; row < gr.length; row += 3)
          strands.push(cord(gr[row], cm(0.16), false, 5));
        const cols = gr[0]?.length ?? 0;
        for (let col = 0; col < cols; col += 3)
          strands.push(cord(gr.map((r) => r[col]), cm(0.16), false, 5));
        for (let start = -gr.length; start < cols; start += 5) {
          const diagonal: Vec3[] = [];
          for (let row = 0; row < gr.length; row++) {
            const col = row + start;
            if (col >= 0 && col < cols) diagonal.push(gr[row][col]);
          }
          if (diagonal.length > 2) strands.push(cord(diagonal, cm(0.13), false, 5));
        }
        strands.push(cord(gridOutline(gr).map((p) => v3.madd(p, OUTWARD.front, cm(0.06))), cm(0.13), true, 5));
      }
      parts.push({ mesh: merge(strands)!, material: { ...stringMat(st), name: 'Halter lace openwork' } });
    } else {
      parts.push({ mesh: merge(cupMeshes.map((gr) => gridMesh(gr, 0.12)))!, material: { ...m, doubleSided: true }, hides });
      // Piping along the cups' edges, on the fabric.
      parts.push({ mesh: merge(cupMeshes.map((gr) => cord(gridOutline(gr).map((p) => v3.madd(p, OUTWARD.front, cm(0.06))), cm(0.1), true, 5)))!, material: stringMat(st) });
    }
  }"""),
    ("  { id: 'bikini_top', label: 'Bikini top (triangle)', slot: 'top', patterns: ['foil', 'solid', 'ankara', 'leopard'], color: '#c9963a', color2: '#fff1c4', build: bikiniTop },",
     "  { id: 'bikini_top', label: 'Bikini top (triangle)', slot: 'top', patterns: ['foil', 'solid', 'ankara', 'leopard'], color: '#c9963a', color2: '#fff1c4', build: bikiniTop },\n  { id: 'halter_bra_lace', label: 'Halter lace bra', slot: 'top', patterns: ['solid'], color: '#29242d', color2: '#987b91', build: (g, st) => bikiniTop(g, st, true) },")
])

# Add a backless dress whose skirt deliberately leaves a narrow opening at one side.
# The skirt arc is 300 degrees, leaving a 60-degree side slit rather than a front gap.
edit("src/core/garments/catalog.ts", [
    ("  // ---------------- Bottoms\n", """  {
    id: 'backless_slit_dress', label: 'Backless dress (side slit)', slot: 'top',
    patterns: ['solid', 'lace', 'ankara'], color: '#34243d', color2: '#b58b9b',
    build: (g, st) => {
      const b = g.body;
      const m = cloth(g, 'Backless slit dress', st);
      const bodice = shellPart(g, {
        // Front bodice only: the back remains open. The neckline and shoulders
        // are retained so the dress reads as a supported garment, not a tunic.
        covers: (v, p) => isUpper(v) && v.tt >= 0.22 && v.tt <= 0.84 && p[2] >= b.L.torsoZ,
        offset: cm(0.9), tile: 0.22, relax: 4,
      }, m, false);
      const knee = b.joint('lowerleg01.L____head')[1];
      const top = torsoY(b, 0.22);
      const hem = b.L.hipY - (b.L.hipY - knee) * 0.78;
      const panel = skirt(b, top, hem, cm(1.5), 0.045,
        [Math.PI / 2 + 0.22, Math.PI * 2 + Math.PI / 2 - 0.22], 40);
      return [
        ...bodice,
        ...(panel ? [{ mesh: panel, material: { ...m, doubleSided: true }, smooth: true }] : []),
      ];
    },
  },

  // ---------------- Bottoms\n""")
])

print("Ara underTop, full-cup openwork halter, backless side-slit dress and briefs layering patch applied.")
