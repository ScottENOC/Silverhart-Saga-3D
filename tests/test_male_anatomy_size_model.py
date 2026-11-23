"""Pure-Python regression tests for the Blender male-anatomy size resolver.

The Blender script imports bpy, so these tests AST-extract only the literal
size constants and pure calculation functions. They run in ordinary CPython.
"""
import ast
import math
import os
import random
import unittest
from pathlib import Path


def load_size_model():
    override = os.environ.get("MALE_ANATOMY_SCRIPT")
    source = Path(override) if override else Path(__file__).resolve().parents[1] / "tools/blender/add_male_anatomy.py"
    tree = ast.parse(source.read_text(encoding="utf-8"), filename=str(source))
    wanted_assignments = {"PHALLUS", "MALE_TRANSITION", "SIZE"}
    wanted_functions = {"_catmull", "resolve_penis_size"}
    nodes = []
    for node in tree.body:
        if isinstance(node, ast.Assign):
            names = {target.id for target in node.targets if isinstance(target, ast.Name)}
            if names & wanted_assignments:
                nodes.append(node)
        elif isinstance(node, ast.FunctionDef) and node.name in wanted_functions:
            nodes.append(node)
    found = set()
    for node in nodes:
        if isinstance(node, ast.Assign):
            found.update(target.id for target in node.targets if isinstance(target, ast.Name))
        elif isinstance(node, ast.FunctionDef):
            found.add(node.name)
    missing = (wanted_assignments | wanted_functions) - found
    if missing:
        raise AssertionError(f"Missing size model definitions: {sorted(missing)}")
    namespace = {"math": math, "random": random, "SystemExit": SystemExit}
    exec(compile(ast.Module(body=nodes, type_ignores=[]), str(source), "exec"), namespace)
    return namespace


MODEL = load_size_model()


class MaleAnatomySizeTests(unittest.TestCase):
    def setUp(self):
        MODEL["MALE_TRANSITION"]["erect_length_scale"] = 1.0
        MODEL["MALE_TRANSITION"]["erect_girth_scale"] = 1.0

    def test_default_is_published_population_mean(self):
        result = MODEL["resolve_penis_size"](1.0, 1.0, None, 1.0, 1.676)
        self.assertAlmostEqual(result["length_cm"], 13.12, places=2)
        self.assertAlmostEqual(result["circumference_cm"], 11.66, places=2)

    def test_height_scales_both_measurements_proportionally(self):
        reference = MODEL["resolve_penis_size"](1.0, 1.0, None, 1.0, 1.676)
        taller = MODEL["resolve_penis_size"](1.0, 1.0, None, 1.0, 1.844)
        self.assertAlmostEqual(taller["length_cm"] / reference["length_cm"], 1.1, places=5)
        self.assertAlmostEqual(taller["circumference_cm"] / reference["circumference_cm"], 1.1, places=5)

    def test_seed_is_stable_and_different_characters_vary(self):
        first = MODEL["resolve_penis_size"](1.0, 1.0, "npc_aldred", 1.0, 1.676)
        again = MODEL["resolve_penis_size"](1.0, 1.0, "npc_aldred", 1.0, 1.676)
        other = MODEL["resolve_penis_size"](1.0, 1.0, "npc_bram", 1.0, 1.676)
        self.assertEqual(first, again)
        self.assertNotEqual((first["length_cm"], first["circumference_cm"]),
                            (other["length_cm"], other["circumference_cm"]))

    def test_variation_is_clipped_to_two_standard_deviations(self):
        for seed in range(250):
            result = MODEL["resolve_penis_size"](1.0, 1.0, str(seed), 1.0, 1.676)
            self.assertLessEqual(abs(result["z_length"]), 2.0)
            self.assertLessEqual(abs(result["z_girth"]), 2.0)
            self.assertGreaterEqual(result["length_cm"], 13.12 - 2 * 1.66)
            self.assertLessEqual(result["length_cm"], 13.12 + 2 * 1.66)
            self.assertGreaterEqual(result["circumference_cm"], 11.66 - 2 * 1.10)
            self.assertLessEqual(result["circumference_cm"], 11.66 + 2 * 1.10)

    def test_length_and_girth_customisation_are_independent(self):
        mean = MODEL["resolve_penis_size"](1.0, 1.0, None, 1.0, 1.676)
        longer = MODEL["resolve_penis_size"](1.1, 1.0, None, 1.0, 1.676)
        thicker = MODEL["resolve_penis_size"](1.0, 1.1, None, 1.0, 1.676)
        self.assertAlmostEqual(longer["length_cm"], mean["length_cm"] * 1.1, places=2)
        self.assertAlmostEqual(longer["circumference_cm"], mean["circumference_cm"], places=2)
        self.assertAlmostEqual(thicker["length_cm"], mean["length_cm"], places=2)
        self.assertAlmostEqual(thicker["circumference_cm"], mean["circumference_cm"] * 1.1, places=2)

    def test_custom_values_outside_realistic_bounds_are_rejected(self):
        with self.assertRaises(SystemExit):
            MODEL["resolve_penis_size"](1.5, 1.0, None, 1.0, 1.676)
        with self.assertRaises(SystemExit):
            MODEL["resolve_penis_size"](1.0, 1.5, None, 1.0, 1.676)


if __name__ == "__main__":
    unittest.main()
