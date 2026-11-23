"""Regression tests for deterministic, bell-curve male NPC anatomy sizing."""

import importlib.util
import statistics
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "ara" / "generate_tavern_npc_profiles.py"
SPEC = importlib.util.spec_from_file_location("generate_tavern_npc_profiles", MODULE_PATH)
GENERATOR = importlib.util.module_from_spec(SPEC)
assert SPEC is not None and SPEC.loader is not None
SPEC.loader.exec_module(GENERATOR)


class MaleAnatomyDistributionTests(unittest.TestCase):
    def test_draw_is_deterministic_and_clipped_to_two_standard_deviations(self):
        first = GENERATOR.sample_male_anatomy_size(123456)
        second = GENERATOR.sample_male_anatomy_size(123456)
        self.assertEqual(first, second)
        self.assertGreaterEqual(first["length_cm"], 13.12 - 2.0 * 1.66)
        self.assertLessEqual(first["length_cm"], 13.12 + 2.0 * 1.66)
        self.assertGreaterEqual(first["circumference_cm"], 11.66 - 2.0 * 1.10)
        self.assertLessEqual(first["circumference_cm"], 11.66 + 2.0 * 1.10)

    def test_many_draws_form_a_population_distribution_around_the_measured_means(self):
        draws = [GENERATOR.sample_male_anatomy_size(seed) for seed in range(5000)]
        lengths = sorted(draw["length_cm"] for draw in draws)
        circumferences = sorted(draw["circumference_cm"] for draw in draws)
        p5 = int(0.05 * (len(draws) - 1))
        p95 = int(0.95 * (len(draws) - 1))

        self.assertAlmostEqual(statistics.fmean(lengths), 13.12, delta=0.08)
        self.assertAlmostEqual(statistics.fmean(circumferences), 11.66, delta=0.05)
        self.assertAlmostEqual(lengths[p5], 10.39, delta=0.08)
        self.assertAlmostEqual(lengths[p95], 15.85, delta=0.08)
        self.assertAlmostEqual(circumferences[p5], 9.81, delta=0.08)
        self.assertAlmostEqual(circumferences[p95], 13.47, delta=0.08)

    def test_generated_profiles_store_sizes_for_males_only(self):
        with tempfile.TemporaryDirectory() as directory:
            ara_root = Path(directory)
            catalogue = ara_root / "src" / "core" / "garments"
            catalogue.mkdir(parents=True)
            (catalogue / "test_catalogue.ts").write_text(
                "id: 'long_tunic'\\nid: 'trousers'\\n", encoding="utf-8"
            )
            manifest = GENERATOR.generate(40, 20261120, ara_root)

        male = [entry for entry in manifest["characters"] if int(entry["params"]["gender"]) == 1]
        female = [entry for entry in manifest["characters"] if int(entry["params"]["gender"]) == 0]
        self.assertTrue(male)
        self.assertTrue(female)
        self.assertTrue(all(isinstance(entry.get("anatomy_size"), dict) for entry in male))
        self.assertTrue(all("anatomy_size" not in entry for entry in female))
        self.assertEqual(manifest["male_anatomy_distribution"]["clip_sd"], 2.0)


if __name__ == "__main__":
    unittest.main()
