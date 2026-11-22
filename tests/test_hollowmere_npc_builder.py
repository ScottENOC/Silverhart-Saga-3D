#!/usr/bin/env python3
"""Fast unit tests for the Hollowmere Ara cast selection and metadata output."""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "ara"))
import build_hollowmere_npcs as builder


class HollowmereNpcBuilderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = json.loads(
            (ROOT / "data" / "characters" / "hollowmere_npcs.json").read_text()
        )

    def test_only_village_residents_and_player_avatar_are_selected(self):
        selected = builder.select_village_cast(self.source)
        ids = [profile["id"] for profile in selected["characters"]]
        self.assertEqual(len(ids), 14)
        self.assertIn("player_avatar", ids)
        self.assertNotIn("wren_talbot", ids)
        self.assertEqual(
            sum(1 for profile in self.source["characters"] if profile.get("role") == "companion"),
            8,
        )

    def test_current_source_placements_do_not_require_legacy_hex_field(self):
        selected = builder.select_village_cast(self.source)
        for profile in selected["characters"]:
            self.assertNotIn("hex", profile)
            output = builder.output_profile_record(
                profile,
                "medium",
                f'{profile["id"]}.glb',
                profile["params"],
            )
            self.assertNotIn("hex", output)
            self.assertEqual(output["id"], profile["id"])

    def test_legacy_hex_is_preserved_when_present(self):
        profile = {
            "id": "legacy_npc",
            "game_id": "legacy_npc",
            "name": "Legacy NPC",
            "role": "villager",
            "hex": {"q": 2, "r": 3},
            "params": {},
        }
        output = builder.output_profile_record(profile, "low", "legacy_npc.glb", {})
        self.assertEqual(output["hex"], {"q": 2, "r": 3})

    def test_wrong_cast_size_is_rejected(self):
        broken = dict(self.source)
        broken["characters"] = [
            profile for profile in self.source["characters"]
            if profile["id"] != "garrick_holt"
        ]
        with self.assertRaises(ValueError):
            builder.select_village_cast(broken)


if __name__ == "__main__":
    unittest.main()
