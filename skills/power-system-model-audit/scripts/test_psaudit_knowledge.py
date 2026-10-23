"""Meaningful local regressions for retrieval, revision and freshness behavior."""
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

import psaudit_knowledge as k


class KnowledgeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.old_skill, self.old_patterns = k.SKILL, k.PATTERNS
        k.SKILL = self.root / "skill"
        k.PATTERNS = k.SKILL / "references/patterns"
        shutil.copytree(self.old_patterns, k.PATTERNS)
        self.folder = k.PATTERNS / "storage-energy"
        self.source = self.root / "source"; self.source.mkdir()
        (self.source / "model.m").write_text("energy conservation\n")
        self.record = k.read(self.folder / "record.json")
        self.record["sources"] = [{"project": "demo", "path": "model.m",
            "sha256": k.digest(self.source / "model.m"), "role": "ACTIVE_IMPLEMENTATION"}]
        k.write(self.folder / "record.json", self.record)
        self.roots = {"demo": self.source}
        self.context = {"energy_state": "T+1", "self_discharge": "none"}

    def tearDown(self):
        k.SKILL, k.PATTERNS = self.old_skill, self.old_patterns
        self.temp.cleanup()

    def candidate(self, name="new-energy", version=1):
        target = self.root / "candidate"
        shutil.copytree(self.folder, target)
        record = k.read(target / "record.json")
        record.update(id=name, version=version, revision_note="Rechecked changed source against energy conservation and all boundary fixtures.")
        k.write(target / "record.json", record)
        return target

    def test_all_pattern_fixtures(self):
        for folder in k.folders():
            record = k.load_pattern(folder)
            self.assertTrue(all(x["passed"] for x in k.test_pattern(folder, record)), folder.name)

    def test_matching_scope_and_source_are_conditional_not_error(self):
        result = k.inspect_pattern(self.folder, self.roots, self.context)
        self.assertEqual(result["use"], "CONDITIONAL_REFERENCE")
        self.assertFalse(result["automatically_confirms_model_error"])

    def test_changed_dependency_is_stale(self):
        (self.source / "model.m").write_text("changed time coefficient\n")
        result = k.inspect_pattern(self.folder, self.roots, self.context)
        self.assertEqual(result["freshness"]["state"], "STALE")
        self.assertEqual(result["use"], "DO_NOT_USE")

    def test_deleted_dependency_is_stale(self):
        (self.source / "model.m").unlink()
        self.assertEqual(k.source_status(self.record, self.roots)["state"], "STALE")

    def test_unavailable_source_cannot_claim_freshness(self):
        result = k.inspect_pattern(self.folder, {}, self.context)
        self.assertEqual(result["freshness"]["state"], "SOURCE_UNAVAILABLE")
        self.assertEqual(result["use"], "REVIEW_REQUIRED")

    def test_unprovided_scope_is_not_assumed(self):
        result = k.inspect_pattern(self.folder, self.roots, {})
        self.assertEqual(result["applicability"]["state"], "NEEDS_CONTEXT")
        self.assertEqual(result["use"], "REVIEW_REQUIRED")

    def test_incompatible_scope_excludes_pattern(self):
        result = k.inspect_pattern(self.folder, self.roots, {"energy_state": "T", "self_discharge": "none"})
        self.assertEqual(result["use"], "DO_NOT_USE")

    def test_code_only_candidate_is_not_promoted(self):
        self.record["reuse"] = "CANDIDATE"
        k.write(self.folder / "record.json", self.record)
        self.assertEqual(k.inspect_pattern(self.folder, self.roots, self.context)["use"], "CANDIDATE_ONLY")

    def test_new_unimplemented_pattern_can_be_saved_as_untested_candidate(self):
        c = self.candidate()
        record = k.read(c / "record.json")
        record.update(reuse="CANDIDATE", validation="UNTESTED", checker=None, checker_sha256=None)
        record["review"]["independent_basis"] = False
        k.write(c / "cases.json", [])
        record["cases_sha256"] = k.digest(c / "cases.json")
        k.write(c / "record.json", record)
        k.register(c, {})
        result = k.inspect_pattern(k.PATTERNS / "new-energy", {}, self.context)
        self.assertEqual(result["use"], "CANDIDATE_ONLY")
        self.assertFalse(result["tests_passed"])
        self.assertEqual(result["validation"], "UNTESTED")

    def test_independent_basis_required_for_reuse(self):
        self.record["review"]["independent_basis"] = False
        k.write(self.folder / "record.json", self.record)
        with self.assertRaises(ValueError):
            k.load_pattern(self.folder)

    def test_fixture_tamper_is_detected(self):
        path = self.folder / "cases.json"
        path.write_text(path.read_text(encoding='utf-8') + " ", encoding="utf-8")
        with self.assertRaises(ValueError):
            k.test_pattern(self.folder, self.record)

    def test_formula_card_edit_requires_review(self):
        path = self.folder / "card.md"
        path.write_text(path.read_text(encoding='utf-8') + "\nChanged efficiency direction.\n", encoding="utf-8")
        with self.assertRaises(ValueError):
            k.load_pattern(self.folder)

    def test_unknown_checker_is_rejected(self):
        self.record["checker"] = "arbitrary-shell-command"
        k.write(self.folder / "record.json", self.record)
        with self.assertRaises(ValueError):
            k.load_pattern(self.folder)

    def test_traversal_source_is_rejected(self):
        self.record["sources"][0]["path"] = "../outside"
        k.write(self.folder / "record.json", self.record)
        with self.assertRaises(ValueError):
            k.load_pattern(self.folder)

    def test_registration_adds_retrievable_pattern(self):
        c = self.candidate()
        k.register(c, self.roots)
        self.assertTrue((k.PATTERNS / "new-energy/card.md").is_file())
        self.assertIn("new-energy", (k.SKILL / "references/pattern-index.md").read_text(encoding='utf-8'))

    def test_revision_retains_previous_record_and_sources(self):
        before = (self.folder / "record.json").read_bytes()
        expected = k.digest(self.folder / "record.json")
        c = self.candidate("storage-energy", 2)
        k.register(c, self.roots, expected)
        archive = k.SKILL / "references/learning-history/storage-energy" / ("v1-" + expected[:12])
        self.assertEqual((archive / "record.json").read_bytes(), before)
        self.assertEqual(k.read(self.folder / "record.json")["version"], 2)

    def test_conflicting_revision_does_not_overwrite(self):
        before = (self.folder / "record.json").read_bytes()
        with self.assertRaises(ValueError):
            k.register(self.candidate("storage-energy", 2), self.roots, "0" * 64)
        self.assertEqual((self.folder / "record.json").read_bytes(), before)

    def test_stale_candidate_cannot_become_conditional(self):
        c = self.candidate()
        (self.source / "model.m").write_text("updated coefficient")
        with self.assertRaises(ValueError):
            k.register(c, self.roots)
        self.assertFalse((k.PATTERNS / "new-energy").exists())

    def test_learning_capture_is_not_misreported_as_extraction(self):
        output = self.root / "capture"; output.mkdir()
        k.prepare_learning(self.source, "demo", output)
        session = k.read(output / "learning-session.json")
        self.assertEqual(session["state"], "CAPTURED_NOT_EXTRACTED")
        self.assertEqual(session["files"][0]["sha256"], k.digest(self.source / "model.m"))

    def test_existing_output_is_preserved(self):
        with self.assertRaises(ValueError):
            k.new_output(self.source)


class MirrorTests(unittest.TestCase):
    def test_sync_refuses_local_edits_before_any_copy(self):
        script = Path(__file__).resolve().parents[3] / "tools/sync_workspace_skill.py"
        if not script.is_file():
            self.skipTest("Mirror integration check requires the canonical Git repository tools")
        spec = importlib.util.spec_from_file_location("sync_workspace_skill", script)
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); source = root / "source"; mirror = root / "mirror"
            source.mkdir(); (source / "a.txt").write_text("original")
            module.sync_tree(source, mirror)
            (mirror / "a.txt").write_text("local edit")
            (source / "b.txt").write_text("new source")
            with self.assertRaises(ValueError):
                module.sync_tree(source, mirror)
            self.assertFalse((mirror / "b.txt").exists())
            self.assertEqual((mirror / "a.txt").read_text(encoding='utf-8'), "local edit")


if __name__ == "__main__":
    unittest.main()
