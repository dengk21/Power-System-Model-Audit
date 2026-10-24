"""Fixture reuse must never inherit project freshness, scope or numerical validity."""
import copy
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

import psaudit_knowledge as k
from psaudit_fixture_cache import FixtureCache


class CacheTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.folder = self.root / 'storage-energy'
        shutil.copytree(k.PATTERNS / 'storage-energy', self.folder)
        self.source = self.root / 'model.m'; self.source.write_text('Synthetic active source')
        record = k.read(self.folder / 'record.json')
        record['sources'] = [{'project': 'demo', 'path': 'model.m', 'sha256': k.digest(self.source), 'role': 'TEST_SOURCE'}]
        k.write(self.folder / 'record.json', record)
        self.roots = {'demo': self.root}
        self.context = {'energy_state': 'T+1', 'self_discharge': 'none'}
        self.directory = self.root / 'cache'
        self.cache = FixtureCache(self.directory)

    def tearDown(self):
        self.tmp.cleanup()

    def inspect(self, cache=None, context=None):
        return k.inspect_pattern(self.folder, self.roots, self.context if context is None else context,
                                 fixture_cache=cache if cache is not None else self.cache)

    def test_persistent_hit_skips_execution_but_still_checks_source(self):
        self.assertEqual(self.inspect()['tests_state'], 'EXECUTED')
        with patch.object(k, 'test_pattern', side_effect=AssertionError('Repeated fixture execution')):
            result = self.inspect(FixtureCache(self.directory))
            self.assertEqual(result['tests_state'], 'CACHED')
            self.assertEqual(result['use'], 'CONDITIONAL_REFERENCE')
            self.source.write_text('Changed model source')
            stale = self.inspect()
        self.assertEqual(stale['freshness']['state'], 'STALE')
        self.assertEqual(stale['use'], 'DO_NOT_USE')

    def test_scope_change_cannot_inherit_cached_reference_qualification(self):
        self.inspect()
        with patch.object(self.cache, 'run', side_effect=AssertionError('Cache used outside scope')):
            result = self.inspect(context={})
        self.assertEqual(result['tests_state'], 'SKIPPED_SCOPE_OR_REUSE')
        self.assertEqual(result['use'], 'REVIEW_REQUIRED')

    def test_unreviewed_checker_change_fails_before_cache_lookup(self):
        self.inspect()
        file = self.folder / 'checker.py'; file.write_bytes(file.read_bytes() + b'\n# changed\n')
        with self.assertRaises(ValueError):
            self.inspect()

    def test_reviewed_checker_revision_invalidates_fixture_result(self):
        self.inspect()
        file = self.folder / 'checker.py'; file.write_bytes(file.read_bytes() + b'\n# reviewed change\n')
        record = k.read(self.folder / 'record.json'); record['version'] += 1
        record['checker_sha256'] = k.digest(file); k.write(self.folder / 'record.json', record)
        self.assertEqual(self.inspect()['tests_state'], 'EXECUTED')

    def test_changed_fixture_cannot_be_hidden_by_hit(self):
        self.inspect()
        file = self.folder / 'cases.json'; file.write_bytes(file.read_bytes() + b' ')
        with self.assertRaises(ValueError):
            self.inspect()

    def test_engine_and_shared_dependency_bytes_are_in_cache_key(self):
        engine = self.root / 'engine.py'; engine.write_bytes(Path(k.__file__).read_bytes())
        record = k.load_pattern(self.folder)
        for name in record['checker_dependencies']:
            shutil.copyfile(Path(k.__file__).with_name(name), self.root / name)
        first = self.cache.key(self.folder, record, engine)
        engine.write_bytes(engine.read_bytes() + b'\n# engine change\n')
        second = self.cache.key(self.folder, record, engine)
        self.assertNotEqual(first, second)
        helper = self.root / 'psaudit_pattern_numeric.py'; helper.write_bytes(helper.read_bytes() + b'\n# helper change\n')
        self.assertNotEqual(second, self.cache.key(self.folder, record, engine))

    def test_corrupt_cache_falls_back_to_execution(self):
        self.inspect()
        target = next(self.directory.glob('*.json'))
        stored = k.read(target); stored['results'][0]['actual'] = {'bad': 'type'}; k.write(target, stored)
        self.assertEqual(self.inspect(FixtureCache(self.directory))['tests_state'], 'EXECUTED')

    def test_refresh_and_explicit_validation_bypass_cache(self):
        self.inspect()
        self.assertEqual(self.inspect(FixtureCache(self.directory, refresh=True))['tests_state'], 'EXECUTED')
        result = k.inspect_pattern(self.folder, {}, {}, force_tests=True, fixture_cache=self.cache)
        self.assertEqual(result['tests_state'], 'EXECUTED')

    def test_discovery_alias_changes_do_not_invalidate_math_fixture_cache(self):
        self.inspect()
        file = self.folder / 'discovery.json'; meta = k.read(file)
        meta['aliases'].append('Another search name'); k.write(file, meta)
        self.assertEqual(self.inspect()['tests_state'], 'CACHED')

    def test_cached_failure_is_not_upgraded_to_success(self):
        record = k.load_pattern(self.folder)
        rows = copy.deepcopy(k.test_pattern(self.folder, record))
        rows[0].update(actual='VIOLATION', passed=False)
        cached = FixtureCache()
        cached.run(self.folder, record, lambda: rows, k.__file__)
        result, hit = cached.run(self.folder, record, lambda: self.fail('Repeated failure execution'), k.__file__)
        self.assertTrue(hit)
        self.assertFalse(result[0]['passed'])


if __name__ == '__main__':
    unittest.main()
