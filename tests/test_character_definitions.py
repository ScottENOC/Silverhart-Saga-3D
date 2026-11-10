import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from character_definitions import ara_export_params, load_item_catalog, validate_character_definitions


class CharacterDefinitionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((ROOT / "data/characters/hollowmere_npcs.json").read_text(encoding="utf-8"))
        cls.items = load_item_catalog()

    def test_all_characters_have_consistent_inventory_and_equipment(self):
        validate_character_definitions(self.manifest, self.items)

    def test_ara_params_are_derived_from_equipped_items(self):
        wren = next(c for c in self.manifest["characters"] if c["id"] == "wren_talbot")
        params = ara_export_params(wren, self.items)
        self.assertEqual(params["top"], "fatigue_shirt")
        self.assertEqual(params["underTop"], "bra")
        self.assertEqual(params["underBottom"], "bikini_bottom")
        self.assertEqual(params["bottom"], "fatigue_pants")
        self.assertEqual(params["shoes"], "combat_boots")
        self.assertEqual(params["weapon"], "none")

    def test_un_equipped_inventory_does_not_change_ara_export(self):
        wren = next(c for c in self.manifest["characters"] if c["id"] == "wren_talbot")
        copied = json.loads(json.dumps(wren))
        copied["inventory"].append("dagger")
        self.assertEqual(ara_export_params(copied, self.items), ara_export_params(wren, self.items))


if __name__ == "__main__":
    unittest.main()
