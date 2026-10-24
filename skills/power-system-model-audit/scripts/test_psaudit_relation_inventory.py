"""Source-first ledger keeps unknown relations visible without claiming completeness."""
import copy
from pathlib import Path
import tempfile
import unittest

import psaudit_project as p
import psaudit_relation_inventory as inventory


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.project = Path(self.tmp.name)
        (self.project / 'model.m').write_text('objective\nnetwork\nbattery connection\n')
        (self.project / 'test.log').write_text('Synthetic review evidence only')
        source = {'path': 'model.m', 'sha256': p.sha(self.project / 'model.m'), 'meaning': 'Reviewed active source'}
        self.config = {'source_files': ['model.m']}
        self.document = {'schema_version': 1, 'reviewer': 'Protocol control', 'scope': 'Three source relations',
            'enumeration_complete': True, 'source_review': [source], 'relations': []}
        self.document['absent_kinds'] = {kind: {'reason': 'No such relation in declared synthetic source scope',
            'source_evidence': [{**source, 'first_line': 1, 'last_line': 3}]}
            for kind in inventory.KINDS - {'objective', 'equality', 'coupling'}}
        for identifier, kind in [('COST', 'objective'), ('KCL', 'equality'), ('GRID_BATTERY', 'coupling')]:
            self.document['relations'].append({'id': identifier, 'kind': kind, 'components': ['grid'],
                'required_scope': 'Every declared node and time',
                'source_evidence': [{**source, 'first_line': 1, 'last_line': 3}],
                'implementation': 'NOT_IMPLEMENTED', 'execution': 'NOT_EXECUTED',
                'coverage': 'NOT_ASSESSED', 'result': 'NOT_ASSESSED', 'reason': 'Checker pending'})

    def tearDown(self):
        self.tmp.cleanup()

    def review(self):
        return inventory.review(self.project, self.document, self.config)[0]

    def test_noncard_objective_and_coupling_remain_visible(self):
        summary = self.review()
        self.assertEqual(summary['total_relations'], 3)
        self.assertEqual(summary['uncovered'], ['COST', 'KCL', 'GRID_BATTERY'])
        self.assertEqual(summary['state'], 'PARTIAL')

    def test_cannot_claim_coverage_without_execution(self):
        self.document['relations'][0]['coverage'] = 'COMPLETE'
        with self.assertRaisesRegex(ValueError, 'Complete coverage'):
            self.review()

    def test_undeclared_source_review_and_incomplete_enumeration_prevent_complete_summary(self):
        self.document['source_review'] = []
        summary = self.review()
        self.assertFalse(summary['enumeration_reviewed_complete'])
        self.assertEqual(summary['missing_source_reviews'], ['model.m'])

    def test_stale_source_and_invalid_source_range_are_rejected(self):
        self.document['relations'][0]['source_evidence'][0]['last_line'] = 99
        with self.assertRaisesRegex(ValueError, 'range unavailable'):
            self.review()
        self.document['relations'][0]['source_evidence'][0]['last_line'] = 3
        (self.project / 'model.m').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'changed'):
            self.review()

    def test_checked_violation_counts_as_checked_not_model_correct(self):
        for row in self.document['relations']:
            row.update(implementation='IMPLEMENTED', execution='EXECUTED', coverage='COMPLETE', result='VIOLATION',
                       verification_evidence=[{'path': 'test.log', 'sha256': p.sha(self.project / 'test.log')}])
        summary = self.review()
        self.assertEqual(summary['state'], 'COMPLETE_FOR_DECLARED_SCOPE')
        self.assertEqual(summary['model_correctness'], 'NOT_ASSESSED')
        self.document['enumeration_complete'] = False
        self.assertEqual(self.review()['state'], 'PARTIAL')

    def test_exclusion_without_evidence_cannot_remove_relation(self):
        self.document['relations'][0]['result'] = 'NOT_APPLICABLE'
        with self.assertRaisesRegex(ValueError, 'Exclusion requires'):
            self.review()

    def test_duplicate_ids_are_rejected(self):
        self.document['relations'].append(copy.deepcopy(self.document['relations'][0]))
        with self.assertRaisesRegex(ValueError, 'unique'):
            self.review()

    def test_card_only_inventory_cannot_hide_unreviewed_relation_kinds(self):
        self.document['absent_kinds'] = {}
        summary = self.review()
        self.assertIn('boundary', summary['unreviewed_kinds'])
        self.assertFalse(summary['enumeration_reviewed_complete'])


if __name__ == '__main__':
    unittest.main()
