"""Scoped checker evolution and card-to-project specialization controls."""
import copy
import json
from pathlib import Path
import shutil
import tempfile
import sys
import unittest
from unittest.mock import patch

import psaudit_knowledge as k
import psaudit_card_checks as c
import psaudit_project as p
import psaudit_pattern_checks as fixture_loader

REAL_SKILL = Path(__file__).resolve().parents[1]


class CardChecksTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.project = self.root / 'model'; self.project.mkdir()
        self.skill = self.root / 'skill'
        shutil.copytree(REAL_SKILL, self.skill, ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
        self.code = self.project / 'model.m'
        self.code.write_text('dispatch\nnetwork equations\nnetwork limits\n', encoding='utf-8')
        self.patterns = self.skill / 'references/patterns'
        for folder in self.patterns.iterdir():
            record = k.read(folder / 'record.json')
            record['sources'] = [{'project': 'demo', 'path': 'model.m', 'sha256': k.digest(self.code), 'role': 'SYNTHETIC_TEST_SOURCE'}]
            k.write(folder / 'record.json', record)
        self.assessment = {'schema_version': 1, 'coverage_complete': True,
            'unresolved_structure': False, 'novel_components': [], 'components': [
                {'id': 'grid', 'family': 'dcopf',
                 'context': {'network': 'lossless', 'quantity': 'active_power'},
                 'card_context': {'dc-nodal-power-balance': {'network': 'lossless_dc'}},
                 'check_bindings': {
                     'ed-power-balance': {'generation': 'mapped generator MW by time', 'demand': 'raw load MW by time'},
                     'dc-nodal-power-balance': {'generation_by_node': 'independent bus/device mapping',
                         'demand_by_node': 'original node load matrix', 'branch_flow': 'actual branch flow', 'incidence': 'original endpoints'}},
                 'evidence': [{'role': role, 'kind': 'active_code', 'path': 'model.m',
                    'first_line': i, 'last_line': i, 'sha256': k.digest(self.code), 'meaning': role}
                    for i, role in enumerate(['dispatch_decisions', 'active_network_relation', 'network_limits'], 1)]}]}
        p.initialize(self.project)
        self.adapter = self.project / p.ADAPTER

    def tearDown(self):
        self.temp.cleanup()

    def plan(self):
        return c.plan_checks(self.project, self.skill, self.assessment, {'demo': self.project})

    def acceptance_fixture(self):
        """Synthetic envelope controls only; never presented as MATLAB verification."""
        plan = self.plan(); c.scaffold(self.project, self.skill, plan)
        for name in ('run_audit.m', 'review.md'):
            (self.adapter / name).write_text('Synthetic acceptance protocol control')
        for file in (self.adapter / 'checks').glob('*/*.m'):
            file.write_text('% Synthetic envelope protocol control')
        artifact = self.project / 'PowerSystemModelAudit/tests.log'
        artifact.write_text('Synthetic envelope artifact; no execution claimed')
        runner = self.project / 'test_adapter.m'; runner.write_text('% synthetic runner binding')
        roots = {'project': self.project, 'adapter': self.adapter, 'skill': self.skill}
        def ref(root, name):
            return {'root': root, 'path': name, 'sha256': p.sha(roots[root] / name)}
        config = p.read(self.adapter / 'project.json')
        source = {'path': 'model.m', 'sha256': p.sha(self.code), 'meaning': 'Synthetic source review'}
        verification = {'path': 'PowerSystemModelAudit/tests.log', 'sha256': p.sha(artifact)}
        inventory = {'schema_version': 1, 'reviewer': 'Synthetic envelope control',
                     'scope': 'Declared synthetic ledger only', 'enumeration_complete': True,
                     'source_review': [source], 'relations': []}
        for row in plan['entries']:
            if row['state'] != 'MATCH': continue
            for role in row['contract']['relations']:
                inventory['relations'].append({'id': 'SYNTHETIC_' + role, 'kind': 'equality',
                    'components': [row['component']], 'required_scope': 'Synthetic full declared indices',
                    'source_evidence': [{**source, 'first_line': 1, 'last_line': 1}],
                    'card_links': [{'component': row['component'], 'pattern_id': row['pattern_id'], 'relation': role}],
                    'implementation': 'IMPLEMENTED', 'execution': 'EXECUTED', 'coverage': 'COMPLETE',
                    'result': 'PASS', 'verification_evidence': [verification]})
        p.write(self.adapter / 'relations.json', inventory)
        files = [ref(root, name) for root, names in [('project', config['source_files']),
                 ('skill', config['skill_files'])] for name in names]
        files += [ref('adapter', x.relative_to(self.adapter).as_posix())
                  for x in self.adapter.rglob('*') if x.is_file()]
        evidence = ref('project', 'PowerSystemModelAudit/tests.log')
        checks = []
        for row in plan['entries']:
            if row['state'] != 'MATCH': continue
            checks.append({'function': row['function'],
                'inputs': {x: {'shape': [2, 2], 'unit': 'synthetic',
                    'index_review': 'Synthetic envelope only', 'evidence': evidence}
                    for x in row['contract']['inputs']},
                'relations': [{'card_relation': x, 'project_relation_ids': ['SYNTHETIC_' + x],
                    'evidence': evidence} for x in row['contract']['relations']],
                'controls': [{'category': x, 'passed': True, 'evidence': evidence} for x in
                    ('normal', 'violation', 'equivalent', 'inapplicable', 'missing_data', 'boundary')]})
        report = {'schema_version': 1, 'reviewer': 'Synthetic protocol test',
            'scope': 'Envelope only; not a runtime or mathematics claim', 'files': files,
            'runner': ref('project', 'test_adapter.m'), 'execution_evidence': evidence, 'checks': checks}
        path = 'PowerSystemModelAudit/acceptance.json'
        p.write(self.project / path, report)
        return path, report

    def test_planning_does_not_claim_numerical_coverage(self):
        plan = self.plan()
        self.assertEqual(plan['uncovered_components'], ['grid'])
        self.assertEqual(plan['components_without_ready_match'], [])
        self.assertTrue(all(x['numerical_coverage'] == 'NOT_ASSESSED' for x in plan['relation_tasks']))

    def test_collected_card_envelope_freezes_compact_project(self):
        from psaudit_collect import collect
        _, report = self.acceptance_fixture()
        checks = copy.deepcopy(report['checks'])
        for check in checks:
            for relation in check['relations']:
                relation['status'] = 'PASS'
            for control in check['controls']:
                control.update(actual='PASS', expected='PASS')
        runner = self.project / 'emit_facts.py'
        runner.write_text('import os\nfrom pathlib import Path\n'
            'Path(os.environ["PSAUDIT_FACTS_PATH"]).write_text(' +
            repr(json.dumps({'schema_version': 1, 'checks': checks})) + ",encoding='utf-8')\n", encoding='utf-8')
        result = collect(self.project, self.skill, 'emit_facts.py', 'PowerSystemModelAudit/runs/collected',
                         [sys.executable, '-B', 'emit_facts.py'])
        self.assertEqual(result['state'], 'COLLECTED_NOT_REVIEWED')
        frozen = p.freeze(self.project, self.skill, result['test_evidence'], 'Synthetic tool protocol regression only')
        self.assertEqual(frozen['checker_acceptance'], 'REVIEWED_EVIDENCE_BOUND')
        self.assertEqual(p.status(self.project, self.skill)['state'], 'FRESH')

    def test_repeated_card_across_components_executes_fixture_only_once(self):
        second = copy.deepcopy(self.assessment['components'][0]); second['id'] = 'grid-second'
        self.assessment['components'].append(second)
        with patch.object(k, 'test_pattern', wraps=k.test_pattern) as spy:
            plan = self.plan()
        self.assertEqual(sum(x['state'] == 'MATCH' for x in plan['entries']), 4)
        self.assertEqual(spy.call_count, 2)

    def test_fixture_cache_does_not_change_frozen_plan_content(self):
        from psaudit_fixture_cache import FixtureCache
        cache = FixtureCache(self.root / 'cache')
        first = c.plan_checks(self.project, self.skill, self.assessment, {'demo': self.project}, cache)
        second = c.plan_checks(self.project, self.skill, self.assessment, {'demo': self.project}, cache)
        self.assertEqual(c.canonical(first), c.canonical(second))

    def test_uncatalogued_objective_stays_in_inventory_denominator(self):
        path, report = self.acceptance_fixture()
        inventory = p.read(self.adapter / 'relations.json')
        relation = copy.deepcopy(inventory['relations'][0])
        relation.update(id='PROJECT_OBJECTIVE', kind='objective', card_links=[],
                        implementation='NOT_IMPLEMENTED', execution='NOT_EXECUTED', coverage='NOT_ASSESSED',
                        result='NOT_ASSESSED', verification_evidence=[], reason='Independent cost reconstruction pending')
        inventory['relations'].append(relation)
        p.write(self.adapter / 'relations.json', inventory)
        for item in report['files']:
            if item['root'] == 'adapter' and item['path'] == 'relations.json':
                item['sha256'] = p.sha(self.adapter / 'relations.json')
        p.write(self.project / path, report)
        result = p.freeze(self.project, self.skill, path, 'Partial coverage; objective pending')
        self.assertEqual(result['relation_coverage']['state'], 'PARTIAL')
        self.assertEqual(result['relation_coverage']['uncovered'], ['PROJECT_OBJECTIVE'])

    def test_inapplicable_candidates_do_not_hide_unmatched_components(self):
        self.assessment['components'][0]['context']['network'] = 'lossy'
        self.assessment['components'][0]['card_context'] = {}
        self.assertEqual(self.plan()['components_without_ready_match'], ['grid'])

    def test_card_freeze_rejects_arbitrary_log_even_with_completed_files(self):
        self.acceptance_fixture()
        with self.assertRaises(ValueError):
            p.freeze(self.project, self.skill, 'PowerSystemModelAudit/tests.log', 'protocol control')

    def test_acceptance_rejects_stale_tested_code(self):
        path, _ = self.acceptance_fixture()
        (self.adapter / 'check_all.m').write_text('changed after test')
        with self.assertRaisesRegex(ValueError, 'stale'):
            p.freeze(self.project, self.skill, path, 'protocol control')

    def test_acceptance_rejects_missing_relation_input_or_negative_control(self):
        path, report = self.acceptance_fixture()
        for target in ('relations', 'inputs', 'controls'):
            changed = copy.deepcopy(report)
            changed['checks'][0][target] = {} if target == 'inputs' else []
            p.write(self.project / path, changed)
            with self.assertRaises(ValueError):
                p.freeze(self.project, self.skill, path, 'protocol control')

    def test_frozen_acceptance_tracks_runner_and_artifact_changes(self):
        path, _ = self.acceptance_fixture()
        result = p.freeze(self.project, self.skill, path, 'protocol control only')
        self.assertEqual(result['checker_acceptance'], 'REVIEWED_EVIDENCE_BOUND')
        (self.project / 'test_adapter.m').write_text('changed runner')
        self.assertEqual(p.status(self.project, self.skill)['checker_acceptance'], 'STALE')

    def test_acceptance_rejects_unobserved_shape_or_missing_snapshot(self):
        path, report = self.acceptance_fixture()
        changed = copy.deepcopy(report)
        next(iter(changed['checks'][0]['inputs'].values()))['shape'] = []
        p.write(self.project / path, changed)
        with self.assertRaisesRegex(ValueError, 'observed shape'):
            p.freeze(self.project, self.skill, path, 'protocol control')
        changed = copy.deepcopy(report)
        changed['files'] = [x for x in changed['files'] if x['path'] != 'check_all.m']
        p.write(self.project / path, changed)
        with self.assertRaisesRegex(ValueError, 'snapshot omits'):
            p.freeze(self.project, self.skill, path, 'protocol control')

    def test_card_matches_produce_only_project_local_specializations(self):
        plan = self.plan()
        self.assertEqual({x['pattern_id'] for x in plan['entries'] if x['state'] == 'MATCH'},
                         {'ed-power-balance', 'dc-nodal-power-balance'})
        before = {str(x.relative_to(self.skill)): k.digest(x) for x in self.skill.rglob('*') if x.is_file()}
        result = c.scaffold(self.project, self.skill, plan)
        self.assertEqual(result['project_checkers'], 2)
        self.assertEqual(len(list((self.adapter / 'checks').glob('*/*.m'))), 2)
        self.assertEqual(before, {str(x.relative_to(self.skill)): k.digest(x) for x in self.skill.rglob('*') if x.is_file()})
        self.assertTrue((self.adapter / 'check_all.m').is_file())

    def test_adding_unrelated_card_does_not_change_the_plan(self):
        original = self.plan()
        folder = self.patterns / 'extra-storage'; shutil.copytree(self.patterns / 'storage-energy', folder)
        record = k.read(folder / 'record.json'); record['id'] = 'extra-storage'
        spec = k.read(folder / 'project-checks.json'); spec['pattern_id'] = record['id']
        k.write(folder / 'project-checks.json', spec)
        record['project_checks_sha256'] = k.digest(folder / 'project-checks.json'); k.write(folder / 'record.json', record)
        self.assertEqual(c.canonical(original), c.canonical(self.plan()))

    def test_changing_unrelated_checker_does_not_invalidate_other_cards(self):
        before = self.plan()
        target = self.patterns / 'storage-energy/checker.py'
        target.write_bytes(target.read_bytes() + b'\n# unrelated edit\n')
        self.assertEqual(c.canonical(before), c.canonical(self.plan()))
        with self.assertRaises(ValueError): k.load_pattern(target.parent)
        other = self.patterns / 'ed-power-balance'
        self.assertTrue(all(x['passed'] for x in k.test_pattern(other, k.load_pattern(other))))

    def test_changed_selected_checker_cannot_reuse_old_plan(self):
        before = self.plan()
        target = self.patterns / 'ed-power-balance/checker.py'
        target.write_bytes(target.read_bytes() + b'\n# changed\n')
        with self.assertRaises(ValueError): c.scaffold(self.project, self.skill, before)
        self.assertFalse((self.adapter / 'checks-plan.json').exists())

    def test_wrong_scope_and_missing_context_are_not_instantiated(self):
        self.assessment['components'][0]['context']['network'] = 'lossy'
        self.assessment['components'][0]['card_context']['dc-nodal-power-balance']['network'] = 'lossy'
        plan = self.plan()
        self.assertTrue(all(x['state'] == 'NOT_APPLICABLE' for x in plan['entries']))
        with self.assertRaises(ValueError): c.scaffold(self.project, self.skill, plan)
        self.assessment['components'][0]['context'] = {}
        self.assessment['components'][0]['card_context'] = {}
        self.assertTrue(all(x['state'] == 'NEEDS_CONTEXT' for x in self.plan()['entries']))

    def test_planning_excludes_wrong_scope_before_opening_card_bodies(self):
        self.assessment['components'][0]['context']['network'] = 'lossy'
        self.assessment['components'][0]['card_context'] = {}
        with patch.object(k, 'load_pattern', side_effect=AssertionError('Unneeded card load')), \
                patch.object(k, 'test_pattern', side_effect=AssertionError('Unneeded fixture run')):
            plan = self.plan()
        self.assertTrue(all(x['state'] == 'NOT_APPLICABLE' for x in plan['entries']))

    def test_missing_variable_mappings_stay_pending(self):
        self.assessment['components'][0]['check_bindings'] = {}
        plan = self.plan()
        self.assertTrue(all(x['state'] == 'NEEDS_BINDINGS' for x in plan['entries']))
        result = c.scaffold(self.project, self.skill, plan)
        self.assertEqual(result['pending_bindings'], 2)
        self.assertEqual(result['state'], 'SCAFFOLDED_NOT_IMPLEMENTED')

    def test_missing_original_reference_requires_review(self):
        plan = c.plan_checks(self.project, self.skill, self.assessment)
        self.assertTrue(all(x['state'] == 'REFERENCE_REVIEW_REQUIRED' for x in plan['entries']))

    def test_current_independent_reference_can_support_local_check_without_old_project(self):
        spec = self.project / 'reference.md'
        spec.write_text('Independent physical definition: supply equals consumption within the declared lossless boundary.\n', encoding='utf-8')
        review = {'independent_basis': True, 'basis': 'Independently reviewed lossless conservation for this project',
            'reviewer': 'Synthetic reference-review control', 'evidence': [{'kind': 'specification',
                'role': 'independent_reference', 'path': 'reference.md', 'first_line': 1, 'last_line': 1,
                'sha256': k.digest(spec), 'meaning': 'Source-bound independent definition'}]}
        self.assessment['components'][0]['reference_review'] = {'ed-power-balance': review}
        plan = c.plan_checks(self.project, self.skill, self.assessment)
        selected = next(x for x in plan['entries'] if x['pattern_id'] == 'ed-power-balance')
        self.assertEqual(selected['state'], 'MATCH')
        self.assertEqual(selected['reference_use'], 'PROJECT_REVIEWED_REFERENCE')
        self.assertEqual(selected['source_freshness'], 'SOURCE_UNAVAILABLE')
        c.scaffold(self.project, self.skill, plan)
        self.assertIn('reference.md', p.read(self.adapter / 'project.json')['source_files'])
        spec.write_text('changed definition')
        with self.assertRaises(ValueError): c.assert_current_plan(self.project, self.skill, plan)

    def test_local_reference_does_not_override_known_stale_source(self):
        record_path = self.patterns / 'ed-power-balance/record.json'
        record = k.read(record_path); record['sources'][0]['sha256'] = '0' * 64; k.write(record_path, record)
        self.assessment['components'][0]['reference_review'] = {'ed-power-balance': {'independent_basis': True}}
        row = next(x for x in self.plan()['entries'] if x['pattern_id'] == 'ed-power-balance')
        self.assertEqual(row['state'], 'REFERENCE_REVIEW_REQUIRED')

    def test_family_keyword_without_active_evidence_is_not_enough(self):
        self.assessment['components'][0]['evidence'] = []
        plan = self.plan()
        self.assertIn('grid', plan['uncovered_components'])
        self.assertTrue(all(x['state'] == 'STRUCTURE_REVIEW_REQUIRED' for x in plan['entries']))

    def test_source_change_requires_replanning(self):
        plan = self.plan(); self.code.write_text('changed model', encoding='utf-8')
        with self.assertRaises(ValueError): c.scaffold(self.project, self.skill, plan)

    def test_scaffolding_preserves_implemented_project_code(self):
        plan = self.plan(); c.scaffold(self.project, self.skill, plan)
        file = next((self.adapter / 'checks').glob('*/*.m'))
        file.write_text('% project-specific implementation', encoding='utf-8')
        c.scaffold(self.project, self.skill, plan)
        self.assertEqual(file.read_text(), '% project-specific implementation')

    def test_scaffold_conflict_is_rejected_before_any_write(self):
        plan = self.plan(); (self.adapter / 'check_all.m').write_text('user code')
        with self.assertRaises(ValueError): c.scaffold(self.project, self.skill, plan)
        self.assertFalse((self.adapter / 'checks').exists())

    def test_generated_dependencies_exclude_unselected_cards(self):
        c.scaffold(self.project, self.skill, self.plan())
        config = p.read(self.adapter / 'project.json')
        self.assertIn('references/patterns/ed-power-balance/checker.py', config['skill_files'])
        self.assertFalse(any('storage-energy' in x for x in config['skill_files']))

    def test_freeze_rejects_unimplemented_specialized_checker(self):
        c.scaffold(self.project, self.skill, self.plan())
        (self.adapter / 'run_audit.m').write_text('function r=run_audit(p,s,o)\nr=struct;\nend')
        (self.adapter / 'review.md').write_text('Independent nodal balance definitions and reviewed mappings')
        evidence = self.project / 'PowerSystemModelAudit/tests.log'; evidence.write_text('synthetic test artifact')
        with self.assertRaisesRegex(ValueError, 'unimplemented scaffold'):
            p.freeze(self.project, self.skill, 'PowerSystemModelAudit/tests.log', 'protocol control only')

    def test_nodal_fixture_detects_wrong_load_location_despite_equal_total(self):
        folder = self.patterns / 'dc-nodal-power-balance'
        record = k.load_pattern(folder); cases = k.read(folder / 'cases.json')
        wrong = next(x for x in cases if x['category'] == 'violation')
        data = wrong['data']
        self.assertEqual(sum(row[0] for row in data['generation_by_node']), sum(row[0] for row in data['demand_by_node']))
        results = k.test_pattern(folder, record)
        self.assertEqual(next(x['actual'] for x in results if x['category'] == 'violation'), 'VIOLATION')

    def test_project_contract_edit_requires_review(self):
        folder = self.patterns / 'ed-power-balance'
        spec = k.read(folder / 'project-checks.json'); spec['inputs'] = {}
        k.write(folder / 'project-checks.json', spec)
        with self.assertRaises(ValueError): k.load_pattern(folder)

    def test_shared_numeric_change_invalidates_its_actual_dependents(self):
        original = fixture_loader.__file__
        try:
            fixture_loader.__file__ = str(self.skill / 'scripts/psaudit_pattern_checks.py')
            helper = self.skill / 'scripts/psaudit_pattern_numeric.py'
            helper.write_bytes(helper.read_bytes() + b'\n# shared helper changed\n')
            for name in ('storage-energy', 'ed-power-balance'):
                with self.assertRaises(ValueError): k.load_pattern(self.patterns / name)
        finally:
            fixture_loader.__file__ = original

    def test_frozen_project_ignores_unrelated_checker_but_detects_selected_change(self):
        path, _ = self.acceptance_fixture()
        p.freeze(self.project, self.skill, path, 'Protocol control; no model-correctness claim')
        self.assertEqual(p.status(self.project, self.skill)['state'], 'FRESH')
        other = self.patterns / 'storage-energy/checker.py'; other.write_bytes(other.read_bytes() + b'\n# unrelated\n')
        self.assertEqual(p.status(self.project, self.skill)['state'], 'FRESH')
        selected = self.patterns / 'ed-power-balance/checker.py'; selected.write_bytes(selected.read_bytes() + b'\n# selected\n')
        self.assertEqual(p.status(self.project, self.skill)['state'], 'STALE')


if __name__ == '__main__':
    unittest.main()
