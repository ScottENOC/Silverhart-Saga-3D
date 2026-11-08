#!/usr/bin/env python3
"""Patch the pinned Ara checkout with Silverhart's medieval hand-prop set.

The patch is intentionally applied to the temporary CI checkout, not vendored
into the game. It extends Ara's existing grip-frame weapon generator so every
prop uses the same WeaponR origin and coordinate convention as Ara's sword.
"""
from __future__ import annotations

import argparse
from pathlib import Path


WEAPON_CASES = r"""
    case 'axe':
      return [
        { mesh: cylinder([0, -0.48, 0], [0, 0.34, 0], 0.014, 12), material: LEATHER },
        { mesh: merge([
            box([0, 0.34, 0], [0.105, 0.105, 0.022]),
            box([0.045, 0.34, 0], [0.055, 0.125, 0.018]),
          ])!, material: STEEL },
        { mesh: cylinder([0, -0.46, 0], [0, -0.20, 0], 0.018, 12), material: LEATHER },
      ];
    case 'spear':
      return [
        { mesh: cylinder([0, -0.58, 0], [0, 0.62, 0], 0.012, 12), material: LEATHER },
        { mesh: blade(0.48, 0.91, 0.043, 0.006), material: STEEL },
        { mesh: cylinder([0, 0.43, 0], [0, 0.51, 0], 0.018, 10), material: BRASS },
      ];
    case 'bow': {
      const points: Vec3[] = [
        [0, -0.57, 0], [0, -0.39, 0.075], [0, -0.18, 0.135],
        [0, 0.18, 0.135], [0, 0.39, 0.075], [0, 0.57, 0],
      ];
      const stave = merge(points.slice(0, -1).map((p, i) =>
        cylinder(p, points[i + 1], 0.010, 8)
      ))!;
      const string = cylinder([0, -0.57, -0.018], [0, 0.57, -0.018], 0.0022, 6);
      const grip = cylinder([0, -0.075, 0.01], [0, 0.075, 0.01], 0.019, 10);
      return [
        { mesh: stave, material: LEATHER },
        { mesh: merge([string, grip])!, material: BRASS },
      ];
    }
    case 'mace': {
      const spikes = [
        cylinder([0, 0.39, 0], [0.075, 0.39, 0], 0.010, 8),
        cylinder([0, 0.39, 0], [-0.075, 0.39, 0], 0.010, 8),
        cylinder([0, 0.39, 0], [0, 0.39, 0.075], 0.010, 8),
        cylinder([0, 0.39, 0], [0, 0.39, -0.075], 0.010, 8),
        cylinder([0, 0.39, 0], [0, 0.465, 0], 0.010, 8),
        cylinder([0, 0.39, 0], [0, 0.315, 0], 0.010, 8),
      ];
      return [
        { mesh: cylinder([0, -0.46, 0], [0, 0.34, 0], 0.014, 12), material: LEATHER },
        { mesh: merge([box([0, 0.39, 0], [0.055, 0.055, 0.055], 0, 2), ...spikes])!, material: STEEL },
      ];
    }
    case 'club':
      return [
        { mesh: cylinder([0, -0.46, 0], [0, 0.28, 0], 0.024, 12), material: LEATHER },
        { mesh: cylinder([0, 0.20, 0], [0, 0.43, 0], 0.052, 12), material: LEATHER },
      ];
"""


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"Expected exactly one {label} patch point, found {count}")
    return source.replace(old, new, 1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("ara_root", type=Path)
    root = parser.parse_args().ara_root
    weapons_path = root / "src/core/props/weapons.ts"
    export_path = root / "src/export/index.ts"
    weapons = weapons_path.read_text()
    weapons = replace_once(
        weapons,
        "export const WEAPONS = ['none', 'rifle', 'pistol', 'sword', 'knife'] as const;",
        "export const WEAPONS = ['none', 'rifle', 'pistol', 'sword', 'knife', 'axe', 'spear', 'bow', 'mace', 'club'] as const;",
        "weapon id list",
    )
    weapons = replace_once(
        weapons,
        "  none: 'None', rifle: 'Assault rifle', pistol: 'Pistol', sword: 'Sword', knife: 'Combat knife',",
        "  none: 'None', rifle: 'Assault rifle', pistol: 'Pistol', sword: 'Sword', knife: 'Combat knife',\n"
        "  axe: 'Battle axe', spear: 'Spear', bow: 'Longbow', mace: 'Mace', club: 'Wooden club',",
        "weapon labels",
    )
    weapons = replace_once(
        weapons,
        "    case 'knife':\n",
        WEAPON_CASES + "    case 'knife':\n",
        "weapon geometry switch",
    )
    weapons_path.write_text(weapons)

    export_source = export_path.read_text()
    export_source = replace_once(
        export_source,
        "    weaponFile: 'held',",
        "    weaponFile: ch.weapon ? 'separate' : 'held',",
        "separate weapon export default",
    )
    export_path.write_text(export_source)
    print("Ara Silverhart patch applied: axe, spear, bow, mace, club and separate grip-origin props")


if __name__ == "__main__":
    main()
