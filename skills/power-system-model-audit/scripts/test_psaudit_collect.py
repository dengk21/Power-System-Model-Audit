"""Local tool regressions for compact onboarding and observed execution, no solver."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

import psaudit_collect as c
import psaudit_project as p
from psaudit_project_acceptance import CATEGORIES


class CollectionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.project = Path(self.tmp.name) / '项目'; self.project.mkdir()
        p.initialize(self.project)
        self.adapter = self.project / p.ADAPTER
        self.skill = p.SKILL
        (self.project / 'model.m').write_text('original model')
        self.config = p.read(self.adapter / 'project.json')
        self.config.update(source_files=['model.m'], skill_files=['scripts/psaudit_observe.m'])
        p.write(self.adapter / 'project.json', self.config)
        self.inventory = p.read(self.adapter / 'relations.json')
        self.inventory.update(reviewer='test reviewer', scope='local execution only')
        p.write(self.adapter / 'relations.json', self.inventory)
        self.facts = {'schema_version': 1, 'checks': [{
            'function': 'check_energy',
            'inputs': {'energy': {'shape': [1, 3], 'unit': 'MWh', 'index_review': 'device A; states 0,1,2'}},
            'relations': [{'card_relation': 'energy', 'project_relation_ids': ['E'], 'status': 'VIOLATION'}],
            'controls': [{'category': x, 'expected': 'VIOLATION' if x == 'violation' else 'PASS',
                          'actual': 'VIOLATION' if x == 'violation' else 'PASS'}
                         for x in sorted(CATEGORIES)]}]}
        self.runner = self.project / 'test_runner.py'

    def tearDown(self):
        self.tmp.cleanup()

    def script(self, extra=''):
        self.runner.write_text("import json,os\nfrom pathlib import Path\nprint('test executed')\n" + extra +
            '\nPath(os.environ["PSAUDIT_FACTS_PATH"]).write_text(' + repr(json.dumps(self.facts)) + ",encoding='utf-8')\n",
            encoding='utf-8')

    def run_capture(self, **kwargs):
        return c.collect(self.project, self.skill, 'test_runner.py', 'PowerSystemModelAudit/runs/run1',
                         [sys.executable, '-B', 'test_runner.py'], **kwargs)

    def test_numeric_default_has_one_review_document(self):
        self.assertTrue((self.adapter / 'review.md').exists())
        self.assertTrue((self.adapter / 'run_audit.m').exists())
        self.assertFalse((self.adapter / 'mapping.md').exists())
        self.assertFalse((self.adapter / 'math-spec.md').exists())

    def test_static_review_promotes_without_rewriting_review(self):
        other = Path(self.tmp.name) / 'static'; other.mkdir()
        p.initialize(other, 'review')
        adapter = other / p.ADAPTER
        self.assertFalse((adapter / 'run_audit.m').exists())
        (adapter / 'review.md').write_text('review already completed')
        (adapter / 'run_audit.m').write_text('existing user implementation')
        p.enable_numeric(other)
        self.assertEqual((adapter / 'review.md').read_text(), 'review already completed')
        self.assertEqual((adapter / 'run_audit.m').read_text(), 'existing user implementation')

    def test_real_run_derives_envelope_and_preserves_violation(self):
        self.script()
        result = self.run_capture()
        self.assertEqual(result['state'], 'COLLECTED_NOT_REVIEWED')
        report = p.read(self.project / result['test_evidence'])
        self.assertEqual(report['reviewer'], self.inventory['reviewer'])
        self.assertEqual(report['checks'][0]['relations'][0]['status'], 'VIOLATION')
        self.assertTrue(all(x['passed'] for x in report['checks'][0]['controls']))
        self.assertTrue(c.validate_collection(self.project, self.adapter, self.skill, report))
        execution = p.read(self.project / report['execution_evidence']['path'])
        self.assertEqual(execution['exit_code'], 0)
        self.assertGreater(execution['elapsed_seconds'], 0)

    def test_failed_command_does_not_create_acceptance(self):
        self.script('raise SystemExit(7)')
        self.assertEqual(self.run_capture()['state'], 'FAILED')
        out = self.project / 'PowerSystemModelAudit/runs/run1'
        self.assertFalse((out / 'acceptance.json').exists())
        self.assertEqual(p.read(out / 'execution.json')['exit_code'], 7)

    def test_missing_facts_does_not_create_acceptance(self):
        self.runner.write_text("print('no facts')")
        self.assertEqual(self.run_capture()['state'], 'FAILED')

    def test_malformed_or_empty_runtime_cannot_claim_collection(self):
        for value in ([], {}, {'schema_version': 1, 'checks': []}):
            with self.subTest(value=value), self.assertRaises(ValueError):
                c.runtime_checks(value, None, {})

    def test_changed_source_during_run_is_rejected(self):
        self.script("Path('model.m').write_text('mutated')")
        self.assertEqual(self.run_capture()['state'], 'FAILED')

    def test_failed_control_is_rejected_even_if_passed_is_true(self):
        control = self.facts['checks'][0]['controls'][0]
        control.update(actual='WRONG', passed=True)
        self.script()
        self.assertEqual(self.run_capture()['state'], 'FAILED')

    def test_zero_exit_is_not_sufficient(self):
        self.facts['checks'][0]['inputs']['energy']['shape'] = [0]
        self.script()
        self.assertEqual(self.run_capture()['state'], 'FAILED')

    def test_timeout_is_preserved_as_failure(self):
        self.script('import time\ntime.sleep(10)')
        result = self.run_capture(timeout=0.1)
        self.assertEqual(result['state'], 'TIMED_OUT')

    def test_output_collision_preserves_previous_evidence(self):
        self.script(); result = self.run_capture()
        evidence = self.project / result['test_evidence']; original = evidence.read_bytes()
        with self.assertRaises(FileExistsError): self.run_capture()
        self.assertEqual(evidence.read_bytes(), original)

    def test_evidence_drift_is_rejected(self):
        self.script(); result = self.run_capture()
        report = p.read(self.project / result['test_evidence'])
        (self.project / 'model.m').write_text('later version')
        with self.assertRaises(ValueError):
            c.validate_collection(self.project, self.adapter, self.skill, report)

    def test_collection_requires_explicit_execution_and_safe_output(self):
        self.script()
        with self.assertRaises(ValueError): c.collect(self.project, self.skill, 'test_runner.py', 'run', [], 1)
        with self.assertRaises(ValueError): c.collect(self.project, self.skill, 'test_runner.py', '../run', ['echo'], 1)
        with self.assertRaises(ValueError):
            c.collect(self.project, self.skill, 'test_runner.py', (p.ADAPTER / 'run').as_posix(), ['echo'], 1)

    def test_card_runtime_must_match_plan(self):
        plan = {'entries': [{'state': 'MATCH', 'function': 'different', 'contract': {}}]}
        with self.assertRaises(ValueError): c.runtime_checks(self.facts, plan, {})

    def test_card_runtime_requires_every_relation(self):
        plan = {'entries': [{'state': 'MATCH', 'function': 'check_energy',
                            'contract': {'inputs': {'energy': {}}, 'relations': ['energy', 'boundary']}}]}
        with self.assertRaises(ValueError): c.runtime_checks(self.facts, plan, {})

    def test_compact_document_is_accepted_and_run_dependencies_are_bound(self):
        (self.adapter / 'run_audit.m').write_text('function r=run_audit(p,s,o)\nr=struct;\nend')
        (self.adapter / 'review.md').write_text('independently reviewed specification and mapping')
        # Partial source review is allowed; do not invent complete model coverage.
        self.inventory['relations'] = [{'id': 'E', 'kind': 'equality', 'components': ['storage'],
            'source_evidence': [{'path': 'model.m', 'sha256': p.sha(self.project / 'model.m'),
                                 'first_line': 1, 'last_line': 1, 'meaning': 'reviewed relation'}],
            'required_scope': 'device A and state boundaries', 'implementation': 'IMPLEMENTED',
            'execution': 'NOT_EXECUTED', 'coverage': 'NOT_ASSESSED', 'result': 'NOT_ASSESSED',
            'reason': 'no full-model numerical coverage claimed', 'card_links': []}]
        p.write(self.adapter / 'relations.json', self.inventory)
        self.script(); result = self.run_capture()
        frozen = p.freeze(self.project, self.skill, result['test_evidence'], 'reviewed observed local tests')
        self.assertEqual(frozen['relation_coverage']['state'], 'PARTIAL')
        self.assertEqual(p.status(self.project, self.skill)['state'], 'FRESH')
        self.runner.write_text('changed test')
        self.assertEqual(p.status(self.project, self.skill)['state'], 'STALE')


if __name__ == '__main__':
    unittest.main()
