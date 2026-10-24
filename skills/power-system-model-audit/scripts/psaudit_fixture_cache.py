"""Content-bound fixture memoization, never project result/applicability caching."""
import hashlib
import json
import os
from pathlib import Path
import platform
import sys
import tempfile


def encode(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False)


def sha(value):
    return hashlib.sha256(value).hexdigest()


class FixtureCache:
    def __init__(self, directory=None, refresh=False):
        self.directory = Path(directory).resolve() if directory else None
        skill = Path(__file__).resolve().parents[1]
        if self.directory and self.directory.is_relative_to(skill):
            raise ValueError('Fixture caches belong outside the Skill')
        if self.directory and any(x.name == 'adapter' and x.parent.name == 'PowerSystemModelAudit'
                                  for x in (self.directory, *self.directory.parents)):
            raise ValueError('Fixture caches belong outside adapter source bindings')
        self.refresh = refresh
        self.memory = {}

    def key(self, folder, record, engine):
        folder = Path(folder); engine = Path(engine)
        files = {name: sha((folder / name).read_bytes()) for name in
                 ('record.json', 'card.md', 'cases.json', 'checker.py', 'project-checks.json')}
        files.update({'shared:' + name: sha((engine.parent / name).read_bytes())
                      for name in record['checker_dependencies']})
        files['engine'] = sha(engine.read_bytes())
        files['cache_engine'] = sha(Path(__file__).read_bytes())
        return sha(encode({'schema_version': 1, 'files': files,
                           'runtime': [sys.version, sys.implementation.name, platform.system(),
                                       platform.release(), platform.machine()]}).encode())

    def valid(self, results, folder):
        cases = json.loads((Path(folder) / 'cases.json').read_text(encoding='utf-8'))
        if not isinstance(results, list) or len(results) != len(cases) or not results:
            return False
        for row, case in zip(results, cases):
            if (not isinstance(row, dict) or set(row) != {'id', 'category', 'expected', 'actual', 'passed'}
                    or any(row.get(k) != case[k] for k in ('id', 'category', 'expected'))
                    or not isinstance(row.get('actual'), str)
                    or row['actual'] not in {'PASS', 'VIOLATION', 'NOT_APPLICABLE', 'DATA_INSUFFICIENT'}
                    or type(row.get('passed')) is not bool or row['passed'] != (row['actual'] == row['expected'])):
                return False
        return True

    def run(self, folder, record, runner, engine):
        if record['validation'] == 'UNTESTED':
            return runner(), False
        key = self.key(folder, record, engine)
        stored = None if self.refresh else self.memory.get(key)
        target = self.directory / (key + '.json') if self.directory else None
        if stored is None and target and target.is_file() and not self.refresh:
            try:
                stored = json.loads(target.read_text(encoding='utf-8'))
            except (OSError, ValueError):
                stored = None
        if isinstance(stored, dict):
            rows = stored.get('results')
            if (stored.get('schema_version') == 1 and stored.get('key') == key and self.valid(rows, folder)
                    and stored.get('results_sha256') == sha(encode(rows).encode())):
                self.memory[key] = stored
                return json.loads(encode(rows)), True
        results = runner()
        if not self.valid(results, folder):
            raise ValueError('Fixture result does not match current independent cases')
        stored = {'schema_version': 1, 'key': key, 'results': results,
                  'results_sha256': sha(encode(results).encode())}
        self.memory[key] = json.loads(encode(stored))
        if target:
            self.directory.mkdir(parents=True, exist_ok=True)
            temporary = None
            try:
                with tempfile.NamedTemporaryFile('w', encoding='utf-8', dir=self.directory,
                                                  prefix='.psaudit-cache-', delete=False) as stream:
                    temporary = Path(stream.name)
                    stream.write(encode(stored) + '\n')
                os.replace(temporary, target)
            finally:
                if temporary and temporary.exists():
                    temporary.unlink()
        return results, False
