"""Meaningful local regressions for retrieval, revision and freshness behavior."""
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch
from contextlib import redirect_stdout, redirect_stderr
import io

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
        spec = k.read(target / "project-checks.json")
        spec["pattern_id"] = name
        k.write(target / "project-checks.json", spec)
        record["project_checks_sha256"] = k.digest(target / "project-checks.json")
        k.write(target / "record.json", record)
        return target

    def test_all_pattern_fixtures(self):
        for folder in k.folders():
            record = k.load_pattern(folder)
            self.assertTrue(all(x["passed"] for x in k.test_pattern(folder, record)), folder.name)

    def test_search_reads_only_metadata_without_loading_or_testing_cards(self):
        original = k.read
        def metadata_only(path):
            self.assertIn(Path(path).name, {'record.json', 'discovery.json'})
            return original(path)
        with patch.object(k, 'read', side_effect=metadata_only), \
                patch.object(k, 'load_pattern', side_effect=AssertionError('Card body loaded')), \
                patch.object(k, 'test_pattern', side_effect=AssertionError('Fixture executed')):
            rows = k.search_records('储能', self.context, 1)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['tests_state'], 'NOT_RUN')
        self.assertEqual(rows[0]['use'], 'CANDIDATE_METADATA_ONLY')
        self.assertEqual(rows[0]['freshness'], 'NOT_CHECKED')

    def test_search_can_discover_damaged_card_without_misreporting_verification(self):
        (self.folder / 'card.md').unlink()
        (self.folder / 'checker.py').unlink()
        self.assertEqual(k.search_records('storage-energy', {}, 1)[0]['id'], 'storage-energy')
        with self.assertRaises((ValueError, OSError)):
            k.inspect_pattern(self.folder, self.roots, self.context)

    def test_index_rebuild_does_not_load_unrelated_checker_implementations(self):
        with patch.object(k, 'load_pattern', side_effect=AssertionError('Unneeded full card load')):
            k.build_index()
        self.assertIn('储能', (k.SKILL / 'references/pattern-index.md').read_text(encoding='utf-8'))

    def test_search_cli_does_not_report_vacuous_test_success(self):
        output = io.StringIO()
        with redirect_stdout(output):
            self.assertEqual(k.main(['search', 'storage-energy', '--limit', '1']), 0)
        result = json.loads(output.getvalue())
        self.assertEqual(result['state'], 'METADATA_ONLY')
        self.assertNotIn('all_local_tests_passed', result)

    def test_nodal_synonyms_find_same_card_without_executing_checkers(self):
        for query in ('KCL', '节点负荷', '节点净注入', '基尔霍夫电流定律', 'ＢＵＳ power balance'):
            rows = k.search_records(query, {}, 1)
            self.assertEqual(rows[0]['id'], 'dc-nodal-power-balance', query)
            self.assertTrue(rows[0]['matched_terms'])

    def test_family_relation_and_scope_filters_are_independent(self):
        rows = k.search_records('', {}, families=['dcopf'], relations=['nodal_balance'])
        self.assertEqual([x['id'] for x in rows], ['dc-nodal-power-balance'])
        self.assertEqual(k.search_records('储能', {}, scope_filter='match'), [])
        self.assertNotIn('storage-energy', [x['id'] for x in k.search_records('storage-energy', {'energy_state': 'T'}, scope_filter='compatible')])
        self.assertEqual(k.search_records('storage-energy', {'energy_state': 'T'}, scope_filter='any')[0]['applicability']['state'], 'MISMATCH')

    def test_english_abbreviations_do_not_match_inside_unrelated_words(self):
        self.assertEqual(k.search_records('mucus', {}), [])
        self.assertFalse(k.contains('scuc', 'uc'))

    def test_search_metadata_edit_does_not_change_mathematical_record(self):
        before = k.digest(self.folder / 'record.json')
        path = self.folder / 'discovery.json'; meta = k.read(path)
        meta['aliases'].append('synthetic unique alias'); k.write(path, meta)
        self.assertEqual(k.search_records('synthetic unique alias', {}, 1)[0]['id'], 'storage-energy')
        self.assertEqual(before, k.digest(self.folder / 'record.json'))
        self.assertTrue(k.inspect_pattern(self.folder, self.roots, self.context)['tests_passed'])

    def test_verify_requires_explicit_selection(self):
        with redirect_stderr(io.StringIO()):
            self.assertEqual(k.main(['verify']), 2)

    def test_verify_executes_only_selected_card(self):
        output = io.StringIO()
        with patch.object(k, 'test_pattern', wraps=k.test_pattern) as spy, redirect_stdout(output):
            code = k.main(['verify', '--pattern', 'storage-energy', '--context', 'energy_state=T+1',
                           '--context', 'self_discharge=none', '--source', 'demo=' + str(self.source)])
        self.assertEqual(code, 0)
        self.assertEqual([Path(x.args[0]).name for x in spy.call_args_list], ['storage-energy'])
        self.assertTrue(json.loads(output.getvalue())['all_local_tests_passed'])

    def test_incompatible_or_incomplete_scope_does_not_execute_fixtures(self):
        with patch.object(k, 'test_pattern', side_effect=AssertionError('Unneeded execution')), \
                patch.object(k, 'load_pattern', side_effect=AssertionError('Unneeded card body load')):
            for context in ({}, {'energy_state': 'T', 'self_discharge': 'none'}):
                row = k.inspect_pattern(self.folder, self.roots, context)
                self.assertEqual(row['tests_state'], 'SKIPPED_SCOPE_OR_REUSE')
                self.assertFalse(row['tests_passed'])
                self.assertNotEqual(row['use'], 'CONDITIONAL_REFERENCE')

    def test_explicit_full_validation_still_executes_with_missing_context(self):
        row = k.inspect_pattern(self.folder, {}, {}, force_tests=True)
        self.assertEqual(len(row['tests']), 5)
        self.assertTrue(row['tests_passed'])
        self.assertEqual(row['use'], 'REVIEW_REQUIRED')

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
        previous_version = self.record["version"]
        c = self.candidate("storage-energy", previous_version + 1)
        k.register(c, self.roots, expected)
        archive = k.SKILL / "references/learning-history/storage-energy" / ("v%d-" % previous_version + expected[:12])
        self.assertEqual((archive / "record.json").read_bytes(), before)
        self.assertEqual(k.read(self.folder / "record.json")["version"], previous_version + 1)

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
