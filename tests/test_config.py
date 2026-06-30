"""Validate config.yaml against config.schema.yaml; assert every mode is reachable."""
import unittest
from pathlib import Path

import jsonschema
import yaml

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "config.yaml"
SCHEMA = ROOT / "config.schema.yaml"
ALL_MODES = ["5utr_pred", "3utr_pred"]


class ConfigSchema(unittest.TestCase):
    def setUp(self):
        self.cfg = yaml.safe_load(CONFIG.read_text())
        self.schema = yaml.safe_load(SCHEMA.read_text())

    def test_default_config_validates(self):
        jsonschema.validate(self.cfg, self.schema)

    def test_each_mode_validates(self):
        for mode in ALL_MODES:
            cfg = dict(self.cfg)
            cfg["common_parameters"] = dict(cfg["common_parameters"], mode=mode)
            with self.subTest(mode=mode):
                jsonschema.validate(cfg, self.schema)

    def test_invalid_mode_rejected(self):
        cfg = dict(self.cfg)
        cfg["common_parameters"] = dict(cfg["common_parameters"], mode="bogus")
        with self.assertRaises(jsonschema.ValidationError):
            jsonschema.validate(cfg, self.schema)

    def test_per_rule_resources_present(self):
        rules = self.cfg["masked_parameters"]["resources"]
        for r in ("predict_utr", "concatenate"):
            self.assertIn(r, rules, f"missing resources block: {r}")

    def test_all_checkpoints_present(self):
        ckpts = self.cfg["masked_parameters"]["checkpoints"]
        for ck in ("utr5_pred", "utr3_pred"):
            self.assertIn(ck, ckpts, f"missing checkpoint: {ck}")


if __name__ == "__main__":
    unittest.main()
