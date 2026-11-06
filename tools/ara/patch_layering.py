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
    ("export interface GarmentStyle {\\n  pattern: Pattern;\\n  color: string;\\n  color2: string;\\n}",
     "export interface GarmentStyle {\\n  pattern: Pattern;\\n  color: string;\\n  color2: string;\\n  opacity?: number;\\n}"),
    ("  const rough = st.pattern === 'leather' ? 0.55 : st.pattern === 'techwear' ? 0.6 : 0.88;\\n  return mat(name, tex, { roughness: rough, ...o });",
     "  const rough = st.pattern === 'leather' ? 0.55 : st.pattern === 'techwear' ? 0.6 : 0.88;\\n  const opacity = Math.max(0, Math.min(1, st.opacity ?? 1));\\n  return mat(name, tex, { roughness: rough, ...(opacity < 0.999 ? { alpha: 'blend' as const, opacity } : {}), ...o });")
])
edit("src/core/params.ts", [
    ("garmentStyles: Record<string, { pattern?: string; color?: string; color2?: string }>;",
     "garmentStyles: Record<string, { pattern?: string; color?: string; color2?: string; opacity?: number }>;"),
    ("...(typeof o.color2 === 'string' && /^#[0-9a-fA-F]{6}$/.test(o.color2) ? { color2: o.color2 } : {}),\\n      };",
     "...(typeof o.color2 === 'string' && /^#[0-9a-fA-F]{6}$/.test(o.color2) ? { color2: o.color2 } : {}),\\n        ...(typeof o.opacity === 'number' && Number.isFinite(o.opacity) ? { opacity: Math.max(0, Math.min(1, o.opacity)) } : {}),\\n      };")
])
edit("src/core/garments/index.ts", [
    ("return { pattern, color: o.color ?? def.color, color2: o.color2 ?? def.color2 };",
     "return { pattern, color: o.color ?? def.color, color2: o.color2 ?? def.color2, ...(o.opacity !== undefined ? { opacity: o.opacity } : {}) };")
])
edit("src/core/garments/textures.ts", [
    ("const c = cordv > 0.3 ? mul(cordC, 0.85 + 0.2 * cordv) : net ? mul(A, 0.86) : lining;\\n        return { c, h: cordv * 1.4 + (net ? 0.25 : 0) };\\n      }, false, 3.5);",
     "const c = cordv > 0.3 ? mul(cordC, 0.85 + 0.2 * cordv) : net ? mul(A, 0.86) : lining;\\n        return { c, a: cordv > 0.3 || net ? 1 : 0, h: cordv * 1.4 + (net ? 0.25 : 0) };\\n      }, true, 3.5);")
])

# Add a selectable halter-style lace bra to Ara's top catalogue. It is an
# underTop item, with separate cup and narrow neck/halter panels.
edit("src/core/garments/catalog.ts", [
    ("  // ---------------- Bottoms\\n", """  {
    id: 'halter_bra_lace', label: 'Halter lace bra', slot: 'top', patterns: ['lace'], color: '#29242d', color2: '#987b91',
    build: (g, st) => {
      const material = cloth(g, 'Halter lace bra', st);
      const cups = shellPart(g, {
        covers: (v) => isUpper(v) && v.tt >= 0.46 && v.tt <= 0.77 && Math.abs(v.tth) < 1.05,
        offset: cm(0.72), tile: 0.12, relax: 4,
      }, material, false);
      const halter = shellPart(g, {
        covers: (v) => (v.region === REGION.neck && v.t < 0.34 && Math.abs(v.theta) < 0.72) ||
          (v.region === REGION.torso && v.tt > 0.73 && Math.abs(v.ax) < cm(2.8)),
        offset: cm(0.82), tile: 0.10, relax: 3,
      }, material, false);
      return [...cups, ...halter];
    },
  },

  // ---------------- Bottoms\\n""")
])

print("Ara underTop, lace halter bra and briefs layering patch applied.")
