"""Unit tests for shared garment fit policy (no Blender required)."""
import unittest
import sys
from pathlib import Path

# Make repository-root namespace packages importable when run as a script.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.ara.garment_fit import (
    FIT_PROFILES, classify_strain, estimate_correction_strain, evaluate_fit,
    construction_for_material, profile_for_material, profile_name_for_material,
)


class GarmentFitPolicyTests(unittest.TestCase):
    def test_materials_resolve_to_distinct_behaviours(self):
        self.assertEqual(profile_name_for_material("Halter lace bra cups"), "open_mesh")
        self.assertEqual(profile_name_for_material("Standard Bra"), "structured_bra")
        self.assertEqual(profile_name_for_material("Leather Armour"), "rigid")
        self.assertEqual(profile_name_for_material("Fatigue Shirt"), "stretch_fabric")
        self.assertEqual(profile_name_for_material("Backless Slit Dress"), "loose_drape")

    def test_profile_values_are_independent_copies(self):
        profile = profile_for_material("Fishnet briefs")
        profile["clearance_m"] = 99
        self.assertNotEqual(FIT_PROFILES["open_mesh"]["clearance_m"], 99)

    def test_fit_flags_penetration_and_overstretch(self):
        profile = profile_for_material("Standard Briefs")
        result = evaluate_fit(signed_distance_m=-0.001, strain=0.30, profile=profile)
        self.assertTrue(result["penetrating"])
        self.assertTrue(result["needs_clearance"])
        self.assertTrue(result["overstretched"])

    def test_fabric_and_garment_construction_are_independent_axes(self):
        profile = profile_for_material("Fishnet Halter Bra")
        self.assertEqual(profile["name"], "open_mesh")
        self.assertEqual(profile["construction"], "structured_support")
        self.assertEqual(profile["coverage_mode"], "edge_constrained")
        self.assertEqual(profile["texture_response"], "preserve_openings")
        self.assertEqual(profile["support_mode"], "distributed_tension")
        self.assertIn("neck_strap", profile["constrained_features"])
        self.assertEqual(construction_for_material("Lace briefs"), "flexible_panel")
        self.assertEqual(construction_for_material("Standard Bra"), "structured_support")

    def test_all_profiles_have_finite_material_limits(self):
        for profile in FIT_PROFILES.values():
            self.assertGreater(profile["max_strain"], 0)
            self.assertLessEqual(profile["compression_limit"], 0.15)

    def test_differential_clearance_correction_estimates_strain(self):
        result = estimate_correction_strain(
            [(0, 1), (1, 2)],
            {0: (0.0, 0.0, 0.0), 1: (1.0, 0.0, 0.0), 2: (2.0, 0.0, 0.0)},
            {0: (0.0, 0.0, 0.0), 1: (0.1, 0.0, 0.0), 2: (0.1, 0.0, 0.0)},
        )
        self.assertEqual(result["sampled_edges"], 2)
        self.assertAlmostEqual(result["max_estimated_strain"], 0.1)

    def test_strain_classification_separates_comfort_from_failure(self):
        profile = profile_for_material("Standard Bra")
        comfort = classify_strain(0.07, profile)
        hard = classify_strain(0.13, profile)
        self.assertTrue(comfort["above_comfort_strain"])
        self.assertFalse(comfort["overstretched"])
        self.assertTrue(hard["overstretched"])


if __name__ == "__main__":
    unittest.main()
