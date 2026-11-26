import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class AmbassadorRuntimeWiringTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = json.loads((ROOT / "data/world/campaign2_settlement_layouts.json").read_text())
        cls.tavern = (ROOT / "scripts/world/hollow_tankard.gd").read_text()

    def test_brokk_and_toren_are_authored_silverhart_npcs(self):
        silverhart = next(item for item in self.layout["settlements"] if item["id"] == "silverhart")
        npcs = {item["id"]: item for item in silverhart.get("npcs", [])}
        expected = {
            "ambassador_brokk_stonehammer": "dwarven_ambassador",
            "ambassador_toren_aldwyn": "corvane_ambassador",
        }
        for character_id, dialogue_id in expected.items():
            with self.subTest(character=character_id):
                self.assertIn(character_id, npcs)
                self.assertEqual(npcs[character_id]["dialogue_id"], dialogue_id)

    def test_ambassador_services_are_registered_and_routed(self):
        self.assertIn('DWARVEN_AMBASSADOR_CONTENT_SCRIPT = preload("res://scripts/simulation/dwarven_ambassador_content.gd")', self.tavern)
        self.assertIn('CORVANE_AMBASSADOR_CONTENT_SCRIPT = preload("res://scripts/simulation/corvane_ambassador_content.gd")', self.tavern)
        self.assertIn("DWARVEN_AMBASSADOR_CONTENT_SCRIPT.register_definition(simulation.campaign_journal)", self.tavern)
        self.assertIn("CORVANE_AMBASSADOR_CONTENT_SCRIPT.register_definition(simulation.campaign_journal)", self.tavern)
        self.assertIn('if dialogue_id == "dwarven_ambassador":', self.tavern)
        self.assertIn('if dialogue_id == "corvane_ambassador":', self.tavern)
        self.assertIn('if choice_id.begins_with("brokk_"):', self.tavern)
        self.assertIn('if choice_id.begins_with("toren_"):', self.tavern)


if __name__ == "__main__":
    unittest.main()
