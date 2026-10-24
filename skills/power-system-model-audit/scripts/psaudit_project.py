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


def initialize(project, profile='numeric'):
    if profile not in {'review', 'numeric', 'legacy'}:
        raise ValueError('Unknown project profile')
    project, adapter = location(project)
    if adapter.exists():
        raise ValueError('Project adapter already exists; review and maintain it in place')
    adapter.mkdir(parents=True)
    names = (('run_audit.m', 'math-spec.md', 'mapping.md') if profile == 'legacy'
             else ('review.md',) + (('run_audit.m',) if profile == 'numeric' else ()))
    for name in names:
        (adapter / name).write_bytes((SKILL / 'assets/project-adapter' / name).read_bytes())
    from psaudit_relation_inventory import blank
    write(adapter / 'relations.json', blank())
    config = {'schema_version': 1, 'backend': 'matlab', 'profile': profile,
        'entrypoint': 'run_audit.m', 'source_files': [], 'skill_files': [], 'relation_inventory': 'relations.json'}
    if profile != 'legacy':
        config['review_document'] = 'review.md'
    write(adapter / 'project.json', config)
    return {'state': 'UNPREPARED', 'adapter': str(adapter),
        'next': 'Review relations once in relations.json and assumptions/mapping in review.md; implement numerical checks only when requested.'}


def dependencies(project, adapter, skill, config, evidence, fixture_cache=None):
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
    documents = ([config['review_document']] if config.get('review_document') else ['math-spec.md', 'mapping.md'])
    for name in documents:
        if 'PSAUDIT_UNPREPARED' in contained(adapter, name).read_text(encoding='utf-8'):
            raise ValueError('Complete independent specification and project mapping first')
    plan = None
    if config.get('card_plan'):
        from psaudit_card_checks import assert_current_plan
        plan = read(contained(adapter, config['card_plan']))
        assert_current_plan(project, skill, plan, fixture_cache)
        if any(x['state'] == 'NEEDS_BINDINGS' for x in plan['entries']):
            raise ValueError('Complete canonical input mappings before freezing card-derived checks')
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
    for name in config.get('test_files', []):
        add('project', project, name)
    evidence_path = contained(project, evidence)
    if evidence_path.is_relative_to(adapter):
        raise ValueError('Keep test evidence outside the adapter source directory')
    add('project', project, evidence)
    report = None
    if evidence_path.suffix == '.json':
        report = read(evidence_path)
    if isinstance(report, dict) and report.get('collection_version') == 1:
        from psaudit_collect import validate_collection
        for item in validate_collection(project, adapter, skill, report):
            if item not in rows:
                rows.append(item)
    for file in sorted(adapter.rglob('*')):
        relative = file.relative_to(adapter)
        if relative.parts[0] == 'history' or file.name == 'bindings.json' or '__pycache__' in relative.parts:
            continue
        if file.is_symlink():
            raise ValueError('Adapter dependencies must not be symbolic links')
        if file.is_file():
            if file.suffix == '.m' and 'psaudit:CheckNotImplemented' in file.read_text(encoding='utf-8'):
                raise ValueError('Project-specific checker is still an unimplemented scaffold')
            add('adapter', adapter, relative.as_posix())
    if plan is not None:
        from psaudit_project_acceptance import validate
        accepted = validate(project, adapter, skill, config, plan, evidence)
        for item in accepted:
            if item not in rows:
                rows.append(item)
    elif config.get('relation_inventory'):
        from psaudit_relation_inventory import review
        _, extra = review(project, read(contained(adapter, config['relation_inventory'])), config)
        rows.extend(item for item in extra if item not in rows)
    return rows


def enable_numeric(project):
    project, adapter = location(project)
    config = read(adapter / 'project.json')
    if config.get('profile') != 'review':
        raise ValueError('enable-numeric applies to a compact review project only')
    entry = contained(adapter, config['entrypoint'])
    if not entry.exists():
        entry.write_bytes((SKILL / 'assets/project-adapter/run_audit.m').read_bytes())
    config['profile'] = 'numeric'
    write(adapter / 'project.json', config)
    return {'state': 'UNPREPARED', 'adapter': str(adapter),
            'next': 'Implement the numerical entrypoint and tests; existing review and relations are preserved.'}


def freeze(project, skill, evidence, note, expected=None, fixture_cache=None):
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
    rows = dependencies(project, adapter, skill, read(adapter / 'project.json'), evidence, fixture_cache)
    config = read(adapter / 'project.json')
    inventory_summary = {'state': 'NOT_ASSESSED'}
    if config.get('relation_inventory'):
        from psaudit_relation_inventory import review
        plan = read(contained(adapter, config['card_plan'])) if config.get('card_plan') else None
        inventory_summary, _ = review(project, read(contained(adapter, config['relation_inventory'])), config, plan)
    record = {'schema_version': 1, 'version': old['version'] + 1 if old else 1,
        'state': 'BOUND_NOT_PROOF', 'review_note': note, 'test_evidence': evidence,
        'created_at': datetime.now(timezone.utc).isoformat(), 'files': rows,
        'checker_acceptance': 'REVIEWED_EVIDENCE_BOUND' if config.get('card_plan') else 'NOT_ASSESSED',
        'relation_coverage': inventory_summary,
        'scope': 'Declared dependencies and reviewed evidence only; does not attest execution, prove model correctness or discover undeclared relations.'}
    if old:
        history = adapter / 'history' / ('v%d-%s.json' % (old['version'], expected[:12]))
        history.parent.mkdir(exist_ok=True)
        if history.exists():
            raise ValueError('Revision history already exists')
        history.write_bytes(current.read_bytes())
    write(current, record)
    return {'state': 'BOUND_NOT_PROOF', 'version': record['version'], 'files': len(rows),
            'checker_acceptance': record['checker_acceptance'], 'relation_coverage': inventory_summary}


def status(project, skill, fixture_cache=None):
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
    if (adapter / 'project.json').is_file():
        config = read(adapter / 'project.json')
        if config.get('card_plan'):
            from psaudit_card_checks import assert_current_plan
            try:
                assert_current_plan(project, skill, read(contained(adapter, config['card_plan'])), fixture_cache)
            except (OSError, ValueError, KeyError, TypeError):
                changes.append('card_plan:SOURCE_REFERENCE_OR_SELECTION_CHANGED')
    return {'state': 'STALE' if changes else 'FRESH', 'version': record['version'],
        'changed': changes, 'model_correctness': 'NOT_ASSESSED',
        'checker_acceptance': 'STALE' if changes else record.get('checker_acceptance', 'NOT_ASSESSED'),
        'relation_coverage': {'state': 'STALE'} if changes else record.get('relation_coverage', {'state': 'NOT_ASSESSED'})}


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('command', choices=('init', 'enable-numeric', 'status', 'freeze', 'collect'))
    p.add_argument('--project', required=True)
    p.add_argument('--skill-root', default=str(SKILL))
    p.add_argument('--test-evidence'); p.add_argument('--review-note')
    p.add_argument('--expected-bindings-sha')
    p.add_argument('--cache-dir', help='Optional fixture cache; status writes no cache unless explicitly selected')
    p.add_argument('--profile', choices=('review', 'numeric', 'legacy'), default='numeric')
    p.add_argument('--runner', help='Project-relative test entrypoint, included in the run snapshot')
    p.add_argument('--output', help='New project-relative evidence directory outside adapter')
    p.add_argument('--timeout', type=float, default=60)
    p.add_argument('--run', nargs=argparse.REMAINDER, help='Explicit test command; must be the last option')
    args = p.parse_args(argv)
    try:
        from psaudit_fixture_cache import FixtureCache
        cache = FixtureCache(args.cache_dir) if args.cache_dir else None
        if cache is not None and cache.directory.is_relative_to(Path(args.skill_root).resolve()):
            raise ValueError('Fixture caches belong outside the selected Skill')
        if args.command == 'init':
            result = initialize(args.project, args.profile)
        elif args.command == 'enable-numeric':
            result = enable_numeric(args.project)
        elif args.command == 'collect':
            from psaudit_collect import collect
            result = collect(args.project, args.skill_root, args.runner, args.output, args.run, args.timeout)
        elif args.command == 'status':
            result = status(args.project, args.skill_root, cache)
        else:
            if not args.test_evidence or not args.review_note:
                raise ValueError('freeze requires --test-evidence and --review-note')
            result = freeze(args.project, args.skill_root, args.test_evidence,
                            args.review_note, args.expected_bindings_sha, cache)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 2 if result['state'] in {'STALE', 'FAILED', 'TIMED_OUT'} else 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print('ERROR: ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
