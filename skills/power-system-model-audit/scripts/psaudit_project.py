#!/usr/bin/env python3
"""Create and version project-owned adapters; never execute a model or solver.

The Agent writes the actual adapter and independently reviews its mathematics.
These bindings track declared dependencies, not semantic correctness.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import sys

SKILL = Path(__file__).resolve().parents[1]
ADAPTER = Path('PowerSystemModelAudit/adapter')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8'))


def write(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def contained(root, relative):
    p = Path(relative)
    if not relative or p.is_absolute() or '..' in p.parts or '\\' in relative or ':' in relative:
        raise ValueError('Use a contained relative path with forward slashes')
    target = (root / p).resolve()
    if not target.is_relative_to(root.resolve()):
        raise ValueError('Dependency escapes its declared root')
    return target


def location(project):
    project = Path(project).resolve()
    if not project.is_dir():
        raise ValueError('Project directory unavailable')
    if project == SKILL or project.is_relative_to(SKILL):
        raise ValueError('Adapter project must be separate from the Skill tree')
    adapter = contained(project, ADAPTER.as_posix())
    if adapter == SKILL or adapter.is_relative_to(SKILL) or SKILL.is_relative_to(adapter):
        raise ValueError('Adapter output must be separate from the Skill tree')
    return project, adapter


def initialize(project):
    project, adapter = location(project)
    if adapter.exists():
        raise ValueError('Project adapter already exists; review and maintain it in place')
    adapter.mkdir(parents=True)
    for name in ('run_audit.m', 'math-spec.md', 'mapping.md'):
        (adapter / name).write_bytes((SKILL / 'assets/project-adapter' / name).read_bytes())
    write(adapter / 'project.json', {'schema_version': 1, 'backend': 'matlab',
        'entrypoint': 'run_audit.m', 'source_files': [], 'skill_files': []})
    return {'state': 'UNPREPARED', 'adapter': str(adapter),
        'next': 'Agent reviews sources, implements adapter/spec/mapping and tests; then freezes bindings.'}


def dependencies(project, adapter, skill, config, evidence):
    if config.get('schema_version') != 1 or config.get('backend') != 'matlab':
        raise ValueError('Unsupported project config')
    for key in ('source_files', 'skill_files'):
        values = config.get(key)
        if not isinstance(values, list) or not values or any(not isinstance(x, str) for x in values) or len(values) != len(set(values)):
            raise ValueError('Declare nonempty, unique ' + key)
    entry = contained(adapter, config['entrypoint'])
    if entry.suffix != '.m' or not entry.is_file():
        raise ValueError('Missing MATLAB entrypoint')
    if 'psaudit:AdapterNotImplemented' in entry.read_text(encoding='utf-8'):
        raise ValueError('Adapter scaffold has not been implemented')
    for name in ('math-spec.md', 'mapping.md'):
        if 'PSAUDIT_UNPREPARED' in (adapter / name).read_text(encoding='utf-8'):
            raise ValueError('Complete independent specification and project mapping first')
    rows = []
    def add(root_name, root, name):
        path = contained(root, name)
        if not path.is_file():
            raise ValueError('Dependency missing: ' + name)
        rows.append({'root': root_name, 'path': name, 'sha256': sha(path)})
    for name in config['source_files']:
        path = contained(project, name)
        if path.is_relative_to((project / 'PowerSystemModelAudit').resolve()):
            raise ValueError('Model source cannot be an audit artifact')
        add('project', project, name)
    for name in config['skill_files']:
        add('skill', skill, name)
    evidence_path = contained(project, evidence)
    if evidence_path.is_relative_to(adapter):
        raise ValueError('Keep test evidence outside the adapter source directory')
    add('project', project, evidence)
    for file in sorted(adapter.rglob('*')):
        relative = file.relative_to(adapter)
        if relative.parts[0] == 'history' or file.name == 'bindings.json' or '__pycache__' in relative.parts:
            continue
        if file.is_symlink():
            raise ValueError('Adapter dependencies must not be symbolic links')
        if file.is_file():
            add('adapter', adapter, relative.as_posix())
    return rows


def freeze(project, skill, evidence, note, expected=None):
    project, adapter = location(project)
    skill = Path(skill).resolve()
    if not note.strip():
        raise ValueError('Record substantive review and test scope')
    current = adapter / 'bindings.json'
    old = read(current) if current.exists() else None
    if old and (not expected or sha(current) != expected):
        raise ValueError('Revision requires exact --expected-bindings-sha; do not silently re-sign')
    if not old and expected:
        raise ValueError('No previous bindings to revise')
    rows = dependencies(project, adapter, skill, read(adapter / 'project.json'), evidence)
    record = {'schema_version': 1, 'version': old['version'] + 1 if old else 1,
        'state': 'BOUND_NOT_PROOF', 'review_note': note, 'test_evidence': evidence,
        'created_at': datetime.now(timezone.utc).isoformat(), 'files': rows,
        'scope': 'Declared dependencies only; does not prove model correctness or discover undeclared dependencies.'}
    if old:
        history = adapter / 'history' / ('v%d-%s.json' % (old['version'], expected[:12]))
        history.parent.mkdir(exist_ok=True)
        if history.exists():
            raise ValueError('Revision history already exists')
        history.write_bytes(current.read_bytes())
    write(current, record)
    return {'state': 'BOUND_NOT_PROOF', 'version': record['version'], 'files': len(rows)}


def status(project, skill):
    project, adapter = location(project)
    if not (adapter / 'bindings.json').is_file():
        return {'state': 'UNPREPARED', 'changed': [], 'model_correctness': 'NOT_ASSESSED'}
    record = read(adapter / 'bindings.json')
    roots = {'project': project, 'adapter': adapter, 'skill': Path(skill).resolve()}
    changes = []
    for item in record['files']:
        path = contained(roots[item['root']], item['path'])
        if not path.is_file() or sha(path) != item['sha256']:
            changes.append(item['root'] + ':' + item['path'])
    bound = {x['path'] for x in record['files'] if x['root'] == 'adapter'}
    for file in adapter.rglob('*'):
        relative = file.relative_to(adapter)
        if relative.parts[0] == 'history' or file.name == 'bindings.json' or '__pycache__' in relative.parts:
            continue
        if file.is_file() and relative.as_posix() not in bound:
            changes.append('adapter:NEW:' + relative.as_posix())
    return {'state': 'STALE' if changes else 'FRESH', 'version': record['version'],
        'changed': changes, 'model_correctness': 'NOT_ASSESSED'}


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('command', choices=('init', 'status', 'freeze'))
    p.add_argument('--project', required=True)
    p.add_argument('--skill-root', default=str(SKILL))
    p.add_argument('--test-evidence'); p.add_argument('--review-note')
    p.add_argument('--expected-bindings-sha')
    args = p.parse_args(argv)
    try:
        if args.command == 'init':
            result = initialize(args.project)
        elif args.command == 'status':
            result = status(args.project, args.skill_root)
        else:
            if not args.test_evidence or not args.review_note:
                raise ValueError('freeze requires --test-evidence and --review-note')
            result = freeze(args.project, args.skill_root, args.test_evidence,
                            args.review_note, args.expected_bindings_sha)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 2 if result['state'] == 'STALE' else 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print('ERROR: ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
