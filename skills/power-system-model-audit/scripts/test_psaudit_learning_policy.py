"""Regression checks for automatic learning decisions and local persistence."""
import contextlib
import copy
import io
import json
from pathlib import Path
import tempfile
import unittest

import psaudit_learning_policy as p
import psaudit_knowledge as k


class LearningPolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source = self.root / "model"; self.source.mkdir()
        self.code = self.source / "model.py"
        self.code.write_text("dispatch = decision()\nbalance(dispatch, demand)\nbounds(dispatch, capacity)\n")
        self.pref = self.root / "local/preferences.json"
        self.assessment = {"schema_version": 1, "coverage_complete": True,
                           "unresolved_structure": False, "novel_components": [],
                           "components": [{"id": "dispatch", "family": "ed", "evidence": [
                               {"role": role, "kind": "active_code", "path": "model.py",
                                "first_line": n, "last_line": n, "sha256": p.digest(self.code),
                                "meaning": role}
                               for n, role in enumerate(["dispatch_decisions", "supply_demand_relation", "operating_limits"], 1)]}]}

    def tearDown(self):
        self.temp.cleanup()

    def plan(self, assessment=None, decision=None):
        return p.automatic_plan(assessment or self.assessment, self.source, self.pref, decision)

    def unknown(self):
        value = copy.deepcopy(self.assessment)
        value["components"][0]["family"] = "novel-resource-physics"
        return value

    def test_classic_automatically_learns_without_preference_write(self):
        plan = self.plan()
        self.assertEqual((plan["classification"], plan["action"]), ("CLASSIC", "AUTO_LEARN"))
        p.require_automatic_permission(plan)
        self.assertFalse(self.pref.exists())

    def test_family_name_alone_is_insufficient(self):
        self.assessment["components"][0]["evidence"] = []
        plan = self.plan()
        self.assertEqual((plan["classification"], plan["action"]), ("UNCERTAIN", "ASK_USER"))

    def test_every_required_structural_role_is_needed(self):
        self.assessment["components"][0]["evidence"].pop()
        self.assertEqual(self.plan()["action"], "ASK_USER")

    def test_unknown_model_asks_three_choices(self):
        plan = self.plan(self.unknown())
        self.assertEqual((plan["classification"], plan["action"]), ("NONCLASSIC", "ASK_USER"))
        self.assertEqual(len(plan["options"]), 3)
        self.assertFalse(self.pref.exists())

    def test_classic_plus_innovation_is_hybrid(self):
        self.assessment["novel_components"] = ["custom dispatch-communication coupling"]
        plan = self.plan()
        self.assertEqual((plan["classification"], plan["action"]), ("HYBRID", "ASK_USER"))

    def test_classic_and_unknown_components_are_hybrid(self):
        extra = self.unknown()["components"][0]; extra["id"] = "novel"
        self.assessment["components"].append(extra)
        self.assertEqual(self.plan()["classification"], "HYBRID")

    def test_incomplete_coverage_requires_choice(self):
        self.assessment["coverage_complete"] = False
        self.assertEqual(self.plan()["action"], "ASK_USER")

    def test_unresolved_structure_requires_choice(self):
        self.assessment["unresolved_structure"] = True
        self.assertEqual(self.plan()["action"], "ASK_USER")

    def test_novelty_must_be_explicit(self):
        del self.assessment["novel_components"]
        self.assertEqual(self.plan()["classification"], "UNCERTAIN")

    def test_once_does_not_enable_future_learning(self):
        plan = self.plan(self.unknown(), "learn-once")
        p.require_automatic_permission(plan)
        self.assertFalse(self.pref.exists())
        self.assertEqual(self.plan(self.unknown())["action"], "ASK_USER")

    def test_always_persists_and_reset_invalidates_old_plan(self):
        plan = self.plan(self.unknown(), "always")
        p.require_automatic_permission(plan)
        self.assertEqual(self.plan(self.unknown())["action"], "AUTO_LEARN")
        p.preferences(self.pref, "ask")
        self.assertEqual(self.plan(self.unknown())["action"], "ASK_USER")
        with self.assertRaises(ValueError):
            p.require_automatic_permission(plan)

    def test_skip_is_local_even_for_classic(self):
        self.assertEqual(self.plan(decision="skip")["action"], "SKIP")
        self.assertFalse(self.pref.exists())
        self.assertEqual(self.plan()["action"], "AUTO_LEARN")

    def test_never_only_applies_to_nonclassic(self):
        p.preferences(self.pref, "never")
        self.assertEqual(self.plan(self.unknown())["action"], "SKIP")
        self.assertEqual(self.plan()["action"], "AUTO_LEARN")

    def test_corrupt_preference_never_silently_enables_learning(self):
        self.pref.parent.mkdir()
        self.pref.write_text('{"schema_version":1,"nonclassic_learning":"typo"}')
        with self.assertRaises(ValueError):
            self.plan()

    def test_changed_code_invalidates_classic_and_unknown_plans(self):
        plans = [self.plan(), self.plan(self.unknown(), "learn-once")]
        self.code.write_text("changed\n")
        self.assertEqual(self.plan()["action"], "ASK_USER")
        for plan in plans:
            with self.assertRaises(ValueError):
                p.require_automatic_permission(plan)

    def test_escape_and_invalid_range_cannot_identify_classic(self):
        self.assessment["components"][0]["evidence"][0]["path"] = "../outside.py"
        self.assertEqual(self.plan()["action"], "ASK_USER")
        self.assessment["components"][0]["evidence"][0]["path"] = "model.py"
        self.assessment["components"][0]["evidence"][0]["last_line"] = 999
        self.assertEqual(self.plan()["action"], "ASK_USER")

    def test_no_active_code_cannot_identify_classic(self):
        for item in self.assessment["components"][0]["evidence"]:
            item["kind"] = "specification"
        self.assertEqual(self.plan()["action"], "ASK_USER")

    def test_automatic_mutations_reject_unanswered_plan(self):
        plan_path = self.root / "plan.json"
        plan_path.write_text(json.dumps(self.plan(self.unknown())))
        out = self.root / "capture"
        for args in [["learn", "--source-root", str(self.source), "--project", "demo", "--output", str(out)],
                     ["register", "--candidate", str(self.root / "candidate")]]:
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(k.main(args + ["--automatic", "--policy-plan", str(plan_path)]), 2)
        self.assertFalse(out.exists())

    def test_cli_classic_plan_and_capture_without_user_learning_prompt(self):
        assessment_path = self.root / "assessment.json"
        assessment_path.write_text(json.dumps(self.assessment))
        output = self.root / "policy"
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(k.main(["auto-plan", "--assessment", str(assessment_path), "--source-root", str(self.source),
                                    "--preferences", str(self.pref), "--output", str(output)]), 0)
            capture = self.root / "capture"
            self.assertEqual(k.main(["learn", "--source-root", str(self.source), "--project", "demo", "--output", str(capture),
                                    "--automatic", "--policy-plan", str(output / "learning-policy.json")]), 0)
        self.assertTrue((capture / "learning-session.json").exists())
        self.assertFalse(self.pref.exists())

    def test_automatic_learning_rejects_different_model_root(self):
        plan_path = self.root / "plan.json"; plan_path.write_text(json.dumps(self.plan()))
        out = self.root / "capture"
        with contextlib.redirect_stderr(io.StringIO()):
            status = k.main(["learn", "--source-root", str(self.root), "--project", "other", "--output", str(out),
                             "--automatic", "--policy-plan", str(plan_path)])
        self.assertEqual(status, 2)
        self.assertFalse(out.exists())


if __name__ == "__main__":
    unittest.main()
