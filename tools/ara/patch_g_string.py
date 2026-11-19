#!/usr/bin/env python3
"""Add a distinct, rig-compatible G-string variant to Ara's swimwear catalogue."""
from pathlib import Path
import sys

source = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("src/core/garments/swimwear.ts")
text = source.read_text(encoding="utf-8")

def replace_once(old, new, label):
    global text
    if new in text:
        return
    if text.count(old) != 1:
        raise SystemExit(f"Expected one {label} anchor; refusing to patch.")
    text = text.replace(old, new, 1)

replace_once(
    "const stringMat = (st: GarmentStyle): Material => mat('Bikini strings', null, { color: st.color, roughness: 0.35, metalness: st.pattern === 'foil' ? 0.6 : 0 });",
    "const stringMat = (st: GarmentStyle, name = 'Bikini strings'): Material => { const opacity = Math.max(0, Math.min(1, st.opacity ?? 1)); return mat(name, null, { color: st.color, roughness: 0.35, metalness: st.pattern === 'foil' ? 0.6 : 0, ...(opacity < 0.999 ? { alpha: 'blend' as const, opacity } : {}) }); };",
    "string material helper"
)
replace_once(
    "  return mat(name, tex, { roughness: foil ? 0.32 : 0.45, metalness: foil ? 0.7 : 0 });",
    "  const opacity = Math.max(0, Math.min(1, st.opacity ?? 1));\n  return mat(name, tex, { roughness: foil ? 0.32 : 0.45, metalness: foil ? 0.7 : 0, ...(opacity < 0.999 ? { alpha: 'blend' as const, opacity } : {}) });",
    "swimwear material opacity"
)
replace_once(
    "function bikiniBottom(g: GCtx, st: GarmentStyle): GPart[] {",
    "function bikiniBottom(g: GCtx, st: GarmentStyle, mode: 'g_string' | null = null): GPart[] {",
    "bikini bottom builder"
)
replace_once(
    "  const m = { ...swimMat(g, 'Bikini bottom', st), doubleSided: true };",
    "  const m = { ...swimMat(g, mode === 'g_string' ? 'G-string bottom' : 'Bikini bottom', st), doubleSided: true };",
    "bikini bottom material"
)
replace_once(
    "  const hwFront = (v: number) => cm(1.8) + cm(9.5) * v ** 1.25;",
    "  const hwFront = (v: number) => mode === 'g_string' ? cm(1.5) + cm(5.8) * v ** 1.25 : cm(1.8) + cm(9.5) * v ** 1.25;",
    "front panel width"
)
replace_once(
    "  const hwBack = (v: number) => cm(2) + cm(11) * v ** 0.7;",
    "  const hwBack = (v: number) => mode === 'g_string' ? cm(0.9) + cm(1.1) * v ** 0.7 : cm(2) + cm(11) * v ** 0.7;",
    "rear panel width"
)
start = text.index("function bikiniBottom(")
end = text.index("\nexport const SWIMWEAR", start)
bottom = text[start:end]
bottom = bottom.replace(
    "stringMat(st)",
    "stringMat(st, mode === 'g_string' ? 'G-string strings' : 'Bikini strings')"
)
text = text[:start] + bottom + text[end:]

entry = "  { id: 'g_string', label: 'G-string', slot: 'bottom', patterns: ['foil', 'solid', 'ankara', 'leopard'], color: '#3d4147', color2: '#22262b', build: (g, st) => bikiniBottom(g, st, 'g_string') },"
if entry not in text:
    lines = [line for line in text.splitlines() if "id: 'bikini_bottom'" in line]
    if len(lines) != 1:
        raise SystemExit("Expected one bikini_bottom catalogue entry; refusing to patch.")
    text = text.replace(lines[0], lines[0] + "\n" + entry, 1)

source.write_text(text, encoding="utf-8")
print("Added separate G-string garment: narrow front, minimal rear connector and retained hip strings.")
