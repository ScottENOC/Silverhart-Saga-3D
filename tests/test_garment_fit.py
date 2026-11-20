"""Unit tests for shared garment fit policy (no Blender required)."""
import unittest
import sys
from pathlib import Path

# Make repository-root namespace packages importable when run as a script.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.ara.garment_fit import (
    FIT_PROFILES, evaluate_fit, profile_for_material, profile_name_for_material,
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

    def test_intentional_open_mesh_is_not_a_different_coverage_mode(self):
        profile = profile_for_material("Fishnet Halter Bra")
        self.assertEqual(profile["coverage_mode"], "pattern_preserving")
        self.assertEqual(profile["texture_response"], "preserve_openings")

    def test_all_profiles_have_finite_material_limits(self):
        for profile in FIT_PROFILES.values():
            self.assertGreater(profile["max_strain"], 0)
            self.assertLessEqual(profile["compression_limit"], 0.15)


if __name__ == "__main__":
    unittest.main()
