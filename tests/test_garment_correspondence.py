"""Unit tests for garment-to-body landmark correspondence."""
import unittest

from tools.ara.garment_correspondence import (
    build_landmark_weights, transfer_landmark_deltas, validate_landmark_set,
)


class GarmentCorrespondenceTests(unittest.TestCase):
    def test_exact_anchor_gets_one_hot_weight(self):
        result = build_landmark_weights(
            [(0.0, 0.0, 0.0)],
            {"left_shoulder": (0.0, 0.0, 0.0), "right_shoulder": (1.0, 0.0, 0.0)},
        )
        self.assertEqual(result, [{"left_shoulder": 1.0}])

    def test_weights_are_normalised_and_local(self):
        result = build_landmark_weights(
            [(0.25, 0.0, 0.0)],
            {"left": (0.0, 0.0, 0.0), "right": (1.0, 0.0, 0.0), "far": (4.0, 0.0, 0.0)},
            neighbours=2,
        )[0]
        self.assertAlmostEqual(sum(result.values()), 1.0)
        self.assertNotIn("far", result)

    def test_panel_region_prevents_cross_body_correspondence(self):
        landmarks = {
            "sternum": (0.0, 0.0, 0.0),
            "left_underbust": (-0.1, 0.0, 0.0),
            "left_hip": (0.0, 0.0, -0.01),
        }
        result = build_landmark_weights(
            [(0.0, 0.0, 0.0)], landmarks, neighbours=3, region="chest",
        )[0]
        self.assertIn("sternum", result)
        self.assertNotIn("left_hip", result)

    def test_unknown_or_empty_panel_region_fails_closed(self):
        with self.assertRaises(ValueError):
            build_landmark_weights([(0.0, 0.0, 0.0)], {"left_hip": (0.0, 0.0, 0.0)}, region="chest")
        with self.assertRaises(ValueError):
            build_landmark_weights([(0.0, 0.0, 0.0)], {"left_hip": (0.0, 0.0, 0.0)}, region="abdomen")

    def test_landmark_motion_transfers_to_garment_point(self):
        result = transfer_landmark_deltas(
            {"left": 0.75, "right": 0.25},
            {"left": (0.0, 0.0, 0.2), "right": (0.0, 0.0, 0.0)},
        )
        self.assertAlmostEqual(result[2], 0.15)

    def test_distant_anchor_set_fails_instead_of_guessing(self):
        with self.assertRaises(ValueError):
            build_landmark_weights(
                [(10.0, 0.0, 0.0)], {"waist": (0.0, 0.0, 0.0)}, max_distance=0.5,
            )

    def test_required_landmarks_are_checked(self):
        with self.assertRaises(ValueError):
            validate_landmark_set({"sternum": (0.0, 0.0, 0.0)}, ["sternum", "neck_base"])


if __name__ == "__main__":
    unittest.main()
