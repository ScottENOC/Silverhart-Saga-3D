#!/usr/bin/env python3
"""Apply small, audited clothing-material extensions to the pinned Ara checkout.

Adds per-garment opacity and makes the existing lace pattern an alpha-cutout
open weave. The body is deliberately NOT hidden under either non-opaque fabric.
"""
from pathlib import Path
import sys

root = Path(sys.argv[1])

def replace_once(relative, old, new):
    path = root / relative
    source = path.read_text()
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"{relative}: expected one patch anchor, found {count}")
    path.write_text(source.replace(old, new, 1))
    print("Patched", relative)

replace_once(
    "src/core/garments/kit.ts",
    "export interface GarmentStyle {\n  pattern: Pattern;\n  color: string;\n  color2: string;\n}",
    "export interface GarmentStyle {\n  pattern: Pattern;\n  color: string;\n  color2: string;\n  /** 0..1 opacity; below 1 uses alpha blending and leaves the body visible underneath. */\n  opacity?: number;\n}",
)

replace_once(
    "src/core/garments/kit.ts",
    "  const rough = st.pattern === 'leather' ? 0.55 : st.pattern === 'techwear' ? 0.6 : 0.88;\n  return mat(name, tex, { roughness: rough, ...o });",
    "  const rough = st.pattern === 'leather' ? 0.55 : st.pattern === 'techwear' ? 0.6 : 0.88;\n  const opacity = Math.max(0, Math.min(1, st.opacity ?? 1));\n  return mat(name, tex, { roughness: rough, ...(opacity < 0.999 ? { alpha: 'blend' as const, opacity } : {}), ...o });",
)

replace_once(
    "src/core/params.ts",
    "  garmentStyles: Record<string, { pattern?: string; color?: string; color2?: string }>;",
    "  garmentStyles: Record<string, { pattern?: string; color?: string; color2?: string; opacity?: number }>;",
)

replace_once(
    "src/core/params.ts",
    "        ...(typeof o.color2 === 'string' && /^#[0-9a-fA-F]{6}$/.test(o.color2) ? { color2: o.color2 } : {}),\n      };",
    "        ...(typeof o.color2 === 'string' && /^#[0-9a-fA-F]{6}$/.test(o.color2) ? { color2: o.color2 } : {}),\n        ...(typeof o.opacity === 'number' && Number.isFinite(o.opacity) ? { opacity: Math.max(0, Math.min(1, o.opacity)) } : {}),\n      };",
)

replace_once(
    "src/core/garments/index.ts",
    "  return { pattern, color: o.color ?? def.color, color2: o.color2 ?? def.color2 };",
    "  return { pattern, color: o.color ?? def.color, color2: o.color2 ?? def.color2, ...(o.opacity !== undefined ? { opacity: o.opacity } : {}) };",
)

replace_once(
    "src/core/garments/textures.ts",
    "        const c = cordv > 0.3 ? mul(cordC, 0.85 + 0.2 * cordv) : net ? mul(A, 0.86) : lining;\n        return { c, h: cordv * 1.4 + (net ? 0.25 : 0) };\n      }, false, 3.5);",
    "        const c = cordv > 0.3 ? mul(cordC, 0.85 + 0.2 * cordv) : net ? mul(A, 0.86) : lining;\n        // Keep the raised cord and fine net; transparent gaps expose the body beneath.\n        return { c, a: cordv > 0.3 || net ? 1 : 0, h: cordv * 1.4 + (net ? 0.25 : 0) };\n      }, true, 3.5);",
)

print("Ara clothing extensions applied.")
