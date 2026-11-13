import unittest
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/ci"))
import validate_legacy_character_rosters as validator


class LegacyRosterTests(unittest.TestCase):
    def test_source_rosters_are_complete_and_consistent(self):
        validator.main()


if __name__ == "__main__":
    unittest.main()
