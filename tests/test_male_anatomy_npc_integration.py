"""Regression tests for deterministic male NPC anatomy integration."""
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools/ara/integrate_hollowmere_anatomy.py"
SPEC = importlib.util.spec_from_file_location("integrate_hollowmere_anatomy", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class MaleNpcIntegrationTests(unittest.TestCase):
    def test_male_npcs_get_stable_seed_and_aldric_gets_ten_percent_override(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            profiles = {
                "characters": [
                    {"id": "aldric", "name": "Aldric", "model": "aldric.glb",
                     "params": {"age": 0.8, "gender": 1}},
                    {"id": "npc_bram", "name": "Bram", "model": "bram.glb",
                     "params": {"age": 0.7, "gender": 1}},
                    {"id": "child_npc", "model": "child.glb",
                     "params": {"age": 0.2, "gender": 1}},
                ]
            }
            (directory / "profiles.json").write_text(json.dumps(profiles), encoding="utf-8")
            for name in ("aldric.glb", "bram.glb", "child.glb"):
                (directory / name).write_bytes(b"x" * 100_001)

            calls = []

            def fake_blender(script, *args):
                calls.append((script, args))
                args = list(args)
                output = Path(args[args.index("--output") + 1])
                source = Path(args[args.index("--input") + 1])
                output.write_bytes(source.read_bytes())

            with patch.object(sys, "argv", ["integrate_hollowmere_anatomy.py", "--directory", str(directory)]):
                with patch.object(MODULE, "run_blender", side_effect=fake_blender):
                    MODULE.main()

            self.assertEqual(len(calls), 2, "non-adult profile must not receive anatomy")
            aldric_args = list(calls[0][1])
            self.assertIn("--length-scale", aldric_args)
            self.assertEqual(aldric_args[aldric_args.index("--length-scale") + 1], "1.10")
            self.assertIn("--girth-scale", aldric_args)
            self.assertEqual(aldric_args[aldric_args.index("--girth-scale") + 1], "1.10")
            self.assertIn("--variation-strength", aldric_args)
            self.assertEqual(aldric_args[aldric_args.index("--variation-strength") + 1], "0")

            bram_args = list(calls[1][1])
            self.assertIn("--variation-seed", bram_args)
            self.assertEqual(bram_args[bram_args.index("--variation-seed") + 1], "npc_bram")
            self.assertEqual(bram_args[bram_args.index("--variation-strength") + 1], "1")


if __name__ == "__main__":
    unittest.main()
