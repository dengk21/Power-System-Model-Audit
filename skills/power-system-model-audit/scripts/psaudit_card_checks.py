#!/usr/bin/env python3
"""Plan card-triggered checks, then scaffold them in the source project.

Agent-authored structural evidence, contexts and mappings drive selection.
No source parser, equation compiler, solver, or automatic environment install.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

import psaudit_knowledge as knowledge
import psaudit_learning_policy as policy
import psaudit_project as project_tools

SKILL = Path(__file__).resolve().parents[1]


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'))


def project_reference(project, review):
    """Bind an Agent-reviewed independent reference in this project, not old provenance."""
    if not review:
        return []
    if (review.get('independent_basis') is not True
            or any(not isinstance(review.get(x), str) or not review[x].strip() for x in ('basis', 'reviewer'))
            or not isinstance(review.get('evidence'), list) or not review['evidence']):
        raise ValueError('Project reference requires substantive independent review and source evidence')
    rows = []
    for item in review['evidence']:
        path = policy.contained(project, item['path'])
        first, last = item['first_line'], item['last_line']
        if (item.get('kind') != 'specification' or item.get('role') != 'independent_reference'
                or not isinstance(item.get('meaning'), str) or not item['meaning'].strip()
                or type(first) is not int or type(last) is not int or first < 1 or last < first
                or not path.is_file() or knowledge.digest(path) != item['sha256']):
            raise ValueError('Independent project reference evidence changed or incomplete')
        lines = path.read_text(encoding='utf-8').splitlines()
        if last > len(lines) or not ''.join(lines[first-1:last]).strip():
            raise ValueError('Independent project reference line range unavailable')
        rows.append({'path': item['path'], 'sha256': item['sha256']})
    return rows


def plan_checks(project, skill, assessment, roots=None, fixture_cache=None):
    project, _ = project_tools.location(project)
    skill = Path(skill).resolve()
    roots = {'skill': skill, **(roots or {})}
    if Path(roots['skill']).resolve() != skill:
        raise ValueError('The skill source mapping must match the selected Skill')
    recognition = policy.classify(assessment, project)
    known = set(recognition['known_components'])
    from psaudit_fixture_cache import FixtureCache
    fixture_cache = fixture_cache if fixture_cache is not None else FixtureCache()
    entries = []; library_issues = []; unmatched = []; reference_files = []
    for component in assessment['components']:
        identifier = component['id']
        if not re.fullmatch(r'[a-z][a-z0-9-]{0,47}', identifier):
            raise ValueError('Use stable lowercase component IDs')
        found = False
        for folder in sorted((skill / 'references/patterns').iterdir()):
            if not folder.is_dir():
                continue
            try:
                contract = knowledge.read(folder / 'project-checks.json')
                if component['family'] not in contract.get('families', []):
                    continue
                record = knowledge.read(folder / 'record.json')
                if record['project_checks_sha256'] != knowledge.digest(folder / 'project-checks.json'):
                    raise ValueError('Project-check contract changed; review before planning')
                context = {**component.get('context', {}),
                           **component.get('card_context', {}).get(record['id'], {})}
                bindings = component.get('check_bindings', {}).get(record['id'], {})
                if not isinstance(bindings, dict):
                    raise ValueError('Check bindings must describe canonical input mappings')
                scope = knowledge.applicability(record, context)
                row = (knowledge.inspect_pattern(folder, roots, context, fixture_cache=fixture_cache)
                       if identifier in known and scope['state'] == 'MATCH' else
                       {'freshness': {'state': 'NOT_CHECKED'}, 'tests_passed': False,
                        'applicability': scope, 'use': 'REVIEW_REQUIRED'})
                review = component.get('reference_review', {}).get(record['id'])
                local_reference = []
                if (review and row['freshness']['state'] == 'SOURCE_UNAVAILABLE'
                        and record['reuse'] == 'CONDITIONAL' and row['tests_passed']
                        and row['applicability']['state'] == 'MATCH' and identifier in known):
                    local_reference = project_reference(project, review)
                    reference_files.extend(local_reference)
            except (OSError, ValueError, KeyError, TypeError) as error:
                library_issues.append({'component': identifier, 'pattern': folder.name, 'detail': str(error)})
                continue
            found = True
            missing = [name for name in contract['inputs']
                       if not isinstance(bindings.get(name), str) or not bindings[name].strip()]
            if identifier not in known:
                state = 'STRUCTURE_REVIEW_REQUIRED'
            elif row['applicability']['state'] == 'MISMATCH':
                state = 'NOT_APPLICABLE'
            elif row['applicability']['state'] == 'NEEDS_CONTEXT':
                state = 'NEEDS_CONTEXT'
            elif row['use'] != 'CONDITIONAL_REFERENCE' and not local_reference:
                state = 'REFERENCE_REVIEW_REQUIRED'
            else:
                state = 'NEEDS_BINDINGS' if missing else 'MATCH'
            key = record['id'] + ':' + identifier
            function = 'pscheck_' + record['id'][:32].replace('-', '_') + '_' + hashlib.sha256(key.encode()).hexdigest()[:10]
            prefix = 'references/patterns/' + record['id'] + '/'
            files = [prefix + name for name in knowledge.pattern_files(record)]
            files += ['scripts/' + x for x in record.get('checker_dependencies', {})]
            entries.append({'component': identifier, 'pattern_id': record['id'],
                'pattern_version': record['version'], 'record_sha256': knowledge.digest(folder / 'record.json'),
                'state': state, 'context': context, 'bindings': bindings, 'missing_bindings': missing,
                'contract': contract, 'function': function, 'skill_files': sorted(set(files)),
                'reference_use': 'PROJECT_REVIEWED_REFERENCE' if local_reference else row['use'],
                'project_reference_review': review if local_reference else None,
                'source_freshness': row['freshness']['state']})
        if not found or not any(x['component'] == identifier and x['state'] == 'MATCH' for x in entries):
            unmatched.append(identifier)
    components = [x['id'] for x in assessment['components']]
    relations = [{'component': row['component'], 'pattern_id': row['pattern_id'],
                  'relation': relation, 'selection_state': row['state'],
                  'implementation': 'NOT_ASSESSED', 'execution': 'NOT_ASSESSED',
                  'numerical_coverage': 'NOT_ASSESSED'}
                 for row in entries for relation in row['contract']['relations']]
    return {'schema_version': 1, 'state': 'PLANNED_NOT_IMPLEMENTED',
        'assessment': assessment, 'source_roots': {k: str(Path(v).resolve()) for k, v in roots.items()},
        'source_dependencies': recognition['dependencies'] + reference_files, 'entries': entries,
        'uncovered_components': components, 'components_without_ready_match': unmatched,
        'relation_tasks': relations, 'library_issues': library_issues,
        'structural_issues': recognition['issues'],
        'coverage_note': 'No numerical coverage established at planning. MATCH means selection ready, not implemented, executed or verified. Inventory uncatalogued and coupling relations independently in the project.'}


def assert_current_plan(project, skill, plan, fixture_cache=None):
    current = plan_checks(project, skill, plan['assessment'], plan['source_roots'], fixture_cache)
    if canonical(current) != canonical(plan):
        raise ValueError('Card plan changed; review source evidence, selected card dependencies and context')
    return current


def scaffold(project, skill, plan, fixture_cache=None):
    project, adapter = project_tools.location(project)
    plan = assert_current_plan(project, skill, plan, fixture_cache)
    config = project_tools.read(adapter / 'project.json')
    selected = [x for x in plan['entries'] if x['state'] in {'MATCH', 'NEEDS_BINDINGS'}]
    if not selected:
        raise ValueError('No conditionally applicable cards; resolve evidence/context/reference issues first')
    writes = []
    calls = []
    for row in selected:
        folder = project_tools.contained(adapter, 'checks/' + row['function'])
        task = canonical(row) + '\n'
        task_file = project_tools.contained(adapter, 'checks/' + row['function'] + '/task.json')
        if task_file.exists() and task_file.read_text(encoding='utf-8') != task:
            raise ValueError('Existing checker task changed; review and maintain it in place: ' + row['function'])
        function_file = project_tools.contained(adapter, 'checks/' + row['function'] + '/' + row['function'] + '.m')
        if function_file.exists() and not task_file.exists():
            raise ValueError('Unmanaged checker file; preserve it: ' + str(function_file))
        source = (f'function items = {row["function"]}(data)\n'
                  f'% Project-owned specialization of {row["pattern_id"]} v{row["pattern_version"]}.\n'
                  '% Agent maps actual variables, independently rebuilds all declared relations,\n'
                  '% tests normal/violation/equivalent/inapplicable/missing data, and integrates check_all.\n'
                  "error('psaudit:CheckNotImplemented','Complete the reviewed card specialization and tests first.');\nend\n")
        writes.append((task_file, task, False))
        writes.append((function_file, source, True))
        calls.append(f"part = {row['function']}(mapped.{row['function']}); items = [items part]; %#ok<AGROW>")
    dispatcher = ('function items = check_all(mapped)\n'
                  '% Project-local relation assembly; run psaudit_check_relations on returned items.\n'
                  "here=fileparts(mfilename('fullpath')); oldPath=path; guard=onCleanup(@()path(oldPath));\n"
                  "addpath(genpath(fullfile(here,'checks')));\nitems=struct([]);\n" + '\n'.join(calls) +
                  "\nif ~isempty(items), assert(numel(unique({items.id}))==numel(items),'Duplicate project relation IDs'); end\nend\n")
    dispatch_file = project_tools.contained(adapter, 'check_all.m')
    if dispatch_file.exists() and dispatch_file.read_text(encoding='utf-8') != dispatcher:
        raise ValueError('Existing check_all differs; integrate additional checks manually without overwriting edits')
    plan_file = project_tools.contained(adapter, 'checks-plan.json')
    if plan_file.exists() and canonical(project_tools.read(plan_file)) != canonical(plan):
        raise ValueError('Existing project plan differs; review and version the change in place')
    # Preflight all conflicts before writing; never replace implemented checkers.
    for path, content, preserve in writes:
        path.parent.mkdir(parents=True, exist_ok=True)
        if not path.exists():
            path.write_text(content, encoding='utf-8')
    if not dispatch_file.exists():
        dispatch_file.write_text(dispatcher, encoding='utf-8')
    project_tools.write(plan_file, plan)
    config['card_plan'] = 'checks-plan.json'
    from psaudit_relation_inventory import blank
    config.setdefault('relation_inventory', 'relations.json')
    inventory_file = project_tools.contained(adapter, config['relation_inventory'])
    if not inventory_file.exists():
        project_tools.write(inventory_file, blank())
    config['skill_files'] = sorted(set(config.get('skill_files', [])) |
        {name for row in selected for name in row['skill_files']} |
        {'scripts/psaudit_check_relations.m'})
    config['source_files'] = sorted(set(config.get('source_files', [])) |
        {x['path'] for x in plan['source_dependencies']})
    project_tools.write(adapter / 'project.json', config)
    return {'state': 'SCAFFOLDED_NOT_IMPLEMENTED', 'project_checkers': len(selected),
        'pending_bindings': sum(bool(x['missing_bindings']) for x in selected),
        'uncovered_components': plan['uncovered_components'],
        'next': 'Agent implements project checkers, integrates check_all, tests them independently, then freezes the adapter.'}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('plan', 'scaffold'))
    parser.add_argument('--project', required=True)
    parser.add_argument('--skill-root', default=str(SKILL))
    parser.add_argument('--assessment'); parser.add_argument('--plan'); parser.add_argument('--output')
    parser.add_argument('--source', action='append', default=[])
    parser.add_argument('--cache-dir', help='Optional project-local fixture cache outside Skill/adapter')
    args = parser.parse_args(argv)
    try:
        from psaudit_fixture_cache import FixtureCache
        cache = FixtureCache(args.cache_dir) if args.cache_dir else None
        if cache is not None and cache.directory.is_relative_to(Path(args.skill_root).resolve()):
            raise ValueError('Fixture caches belong outside the selected Skill')
        if args.command == 'plan':
            if not args.assessment or not args.output:
                raise ValueError('plan requires --assessment and a new --output directory')
            roots = {}
            for item in args.source:
                name, separator, value = item.partition('=')
                if not separator or not name or not value:
                    raise ValueError('Source mappings use name=path')
                roots[name] = Path(value).resolve()
            result = plan_checks(args.project, args.skill_root, project_tools.read(args.assessment), roots, cache)
            out = Path(args.output).resolve()
            if out.is_relative_to(Path(args.skill_root).resolve()) or not out.is_relative_to(Path(args.project).resolve()):
                raise ValueError('Planning output belongs inside the model project, outside the Skill')
            out.mkdir(parents=True, exist_ok=False)
            project_tools.write(out / 'checks-plan.json', result)
            print(json.dumps({'state': result['state'], 'candidates': len(result['entries']),
                'matches': sum(x['state'] == 'MATCH' for x in result['entries']),
                'output': str(out), 'uncovered_components': result['uncovered_components']}, ensure_ascii=False))
        else:
            if not args.plan:
                raise ValueError('scaffold requires --plan')
            result = scaffold(args.project, args.skill_root, project_tools.read(args.plan), cache)
            print(json.dumps(result, ensure_ascii=False))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print('ERROR: ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
