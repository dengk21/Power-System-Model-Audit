"""Project ownership, dependency drift and revision preservation controls."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

import psaudit_project as p


class ProjectTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.project = self.root / 'model'; self.project.mkdir()
        self.skill = self.root / 'skill'; self.skill.mkdir()
        (self.skill / 'check.m').write_text('independent checker')
        (self.project / 'model.m').write_text('model source')
        (self.project / 'parameters.m').write_text('parameters')
        p.initialize(self.project)
        self.adapter = self.project / p.ADAPTER
        (self.project / 'PowerSystemModelAudit/tests').mkdir()
        self.evidence = 'PowerSystemModelAudit/tests/check.log'
        (self.project / self.evidence).write_text('local controls passed; no full solve')

    def tearDown(self):
        self.temp.cleanup()

    def implement(self):
        (self.adapter / 'run_audit.m').write_text('function r=run_audit(p,s,o)\nr=struct;\nend\n')
        (self.adapter / 'math-spec.md').write_text('independently reviewed relationship')
        (self.adapter / 'mapping.md').write_text('reviewed variable mapping')
        p.write(self.adapter / 'project.json', {'schema_version': 1, 'backend': 'matlab',
            'entrypoint': 'run_audit.m', 'source_files': ['model.m', 'parameters.m'],
            'skill_files': ['check.m']})

    def freeze(self, expected=None):
        return p.freeze(self.project, self.skill, self.evidence, 'reviewed local normal and negative controls', expected)

    def test_scaffold_is_not_an_audit(self):
        self.assertEqual(p.status(self.project, self.skill)['state'], 'UNPREPARED')
        self.assertIn('AdapterNotImplemented', (self.adapter / 'run_audit.m').read_text())
        with self.assertRaises(ValueError): self.freeze()

    def test_reinitialization_preserves_project_edits(self):
        self.implement()
        before = p.sha(self.adapter / 'run_audit.m')
        with self.assertRaises(ValueError): p.initialize(self.project)
        self.assertEqual(before, p.sha(self.adapter / 'run_audit.m'))

    def test_skill_is_not_a_project_output(self):
        with self.assertRaises(ValueError): p.initialize(p.SKILL)

    def test_project_can_contain_a_skill_checkout_without_writing_into_it(self):
        old = p.SKILL
        try:
            p.SKILL = self.project / 'vendor/skill'
            project, adapter = p.location(self.project)
            self.assertEqual(adapter, self.adapter)
            self.assertFalse(adapter.is_relative_to(p.SKILL))
        finally:
            p.SKILL = old

    def test_matching_bindings_are_not_model_correctness(self):
        self.implement(); self.freeze()
        result = p.status(self.project, self.skill)
        self.assertEqual(result['state'], 'FRESH')
        self.assertEqual(result['model_correctness'], 'NOT_ASSESSED')

    def test_source_and_parameter_drift(self):
        self.implement(); self.freeze()
        for name in ('model.m', 'parameters.m'):
            original = (self.project / name).read_text()
            (self.project / name).write_text('changed')
            self.assertEqual(p.status(self.project, self.skill)['state'], 'STALE')
            (self.project / name).write_text(original)

    def test_core_tool_and_evidence_drift(self):
        self.implement(); self.freeze()
        (self.skill / 'check.m').write_text('changed formula')
        (self.project / self.evidence).write_text('failed rerun')
        changes = p.status(self.project, self.skill)['changed']
        self.assertIn('skill:check.m', changes)
        self.assertIn('project:' + self.evidence, changes)

    def test_adapter_added_changed_or_missing(self):
        self.implement(); self.freeze()
        (self.adapter / 'helper.m').write_text('new dependency')
        (self.adapter / 'mapping.md').unlink()
        changes = p.status(self.project, self.skill)['changed']
        self.assertIn('adapter:NEW:helper.m', changes)
        self.assertIn('adapter:mapping.md', changes)

    def test_revision_requires_exact_previous_sha_and_preserves_bytes(self):
        self.implement(); self.freeze()
        original = (self.adapter / 'bindings.json').read_bytes()
        (self.project / 'model.m').write_text('new formulation')
        with self.assertRaises(ValueError): self.freeze()
        with self.assertRaises(ValueError): self.freeze('0' * 64)
        result = self.freeze(p.sha(self.adapter / 'bindings.json'))
        self.assertEqual(result['version'], 2)
        self.assertEqual(next((self.adapter / 'history').glob('*.json')).read_bytes(), original)
        self.assertEqual(p.status(self.project, self.skill)['state'], 'FRESH')

    def test_missing_source_cannot_be_frozen(self):
        self.implement(); (self.project / 'parameters.m').unlink()
        with self.assertRaises(ValueError): self.freeze()

    def test_dependency_escape_is_rejected(self):
        with self.assertRaises(ValueError): p.contained(self.project, '../outside')
        with self.assertRaises(ValueError): p.contained(self.project, 'C:/outside')

    def test_audit_artifact_cannot_replace_model_source(self):
        self.implement()
        config = p.read(self.adapter / 'project.json')
        config['source_files'] = [self.evidence]
        p.write(self.adapter / 'project.json', config)
        with self.assertRaises(ValueError): self.freeze()

    def test_managed_retirement_refuses_independent_edits(self):
        repo = Path(__file__).resolve().parents[3]
        tool = repo / 'tools/sync_workspace_skill.py'
        if not tool.exists(): self.skipTest('Repository-only sync test')
        spec = importlib.util.spec_from_file_location('project_sync_test', tool)
        sync = importlib.util.module_from_spec(spec); spec.loader.exec_module(sync)
        source = self.root / 'source'; source.mkdir()
        mirror = self.root / 'mirror'
        (source / 'old.m').write_text('adapter')
        sync.sync_tree(source, mirror)
        (source / 'old.m').unlink()
        with self.assertRaises(ValueError): sync.sync_tree(source, mirror)
        (mirror / 'old.m').write_text('independent edit')
        with self.assertRaises(ValueError): sync.sync_tree(source, mirror, retire_managed=True)
        self.assertEqual((mirror / 'old.m').read_text(), 'independent edit')
        (mirror / 'old.m').write_text('adapter')
        dry = sync.sync_tree(source, mirror, dry_run=True, retire_managed=True)
        self.assertEqual(dry['retired'], ['old.m'])
        self.assertTrue((mirror / 'old.m').exists())
        sync.sync_tree(source, mirror, retire_managed=True)
        self.assertFalse((mirror / 'old.m').exists())


if __name__ == '__main__':
    unittest.main()
