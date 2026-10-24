"""Review a project-owned source-first relation ledger; no equation parser."""
import argparse
from collections import Counter
import json
import re
import sys

import psaudit_project as p

KINDS = {'objective', 'equality', 'inequality', 'domain', 'boundary', 'coupling', 'other'}


def blank():
    return {'schema_version': 1, 'reviewer': '', 'scope': '', 'enumeration_complete': False,
            'source_review': [], 'absent_kinds': {}, 'relations': []}


def review(project, document, config, plan=None):
    if document.get('schema_version') != 1 or type(document.get('enumeration_complete')) is not bool:
        raise ValueError('Invalid relation inventory schema/completeness declaration')
    if any(not isinstance(document.get(k), str) or not document[k].strip() for k in ('reviewer', 'scope')):
        raise ValueError('Review source relations independently before freezing the inventory')
    dependencies = []

    def source(item, lines=False):
        file = p.contained(project, item['path'])
        if file.is_relative_to(project / p.ADAPTER) or not file.is_file() or p.sha(file) != item['sha256']:
            raise ValueError('Inventory source evidence missing, changed or derived from adapter')
        if not isinstance(item.get('meaning'), str) or not item['meaning'].strip():
            raise ValueError('Explain the substantive source review')
        if lines:
            first, last = item['first_line'], item['last_line']
            if type(first) is not int or type(last) is not int or first < 1 or last < first:
                raise ValueError('Invalid inventory source line range')
            text = file.read_text(encoding='utf-8').splitlines()
            if last > len(text) or not ''.join(text[first-1:last]).strip():
                raise ValueError('Inventory source line range unavailable')
        ref = {'root': 'project', 'path': item['path'], 'sha256': item['sha256']}
        if ref not in dependencies:
            dependencies.append(ref)

    reviewed = set()
    for item in document.get('source_review', []):
        source(item)
        if item['path'] in reviewed:
            raise ValueError('Duplicate source review')
        reviewed.add(item['path'])
    missing_sources = sorted(set(config['source_files']) - reviewed)
    rows = document.get('relations')
    if not isinstance(rows, list) or not rows:
        raise ValueError('Inventory must enumerate source relations, not only matched cards')
    ids = [x['id'] for x in rows]
    if len(ids) != len(set(ids)) or any(not re.fullmatch(r'[A-Za-z][A-Za-z0-9_.:-]{0,127}', x) for x in ids):
        raise ValueError('Use unique stable project relation IDs')
    tasks = {(x['component'], x['pattern_id'], role) for x in (plan or {}).get('entries', [])
             if x['state'] == 'MATCH' for role in x['contract']['relations']}
    links = set(); components = set(); gaps = []; excluded = []; checked = []
    for row in rows:
        if row.get('kind') not in KINDS or not row.get('components') or not row.get('source_evidence'):
            raise ValueError('Every relation needs kind, components and source evidence')
        if not isinstance(row.get('required_scope'), str) or not row['required_scope'].strip():
            raise ValueError('Declare independent index/domain coverage, not the checker loop range')
        components.update(row['components'])
        for evidence in row['source_evidence']:
            source(evidence, lines=True)
        for link in row.get('card_links', []):
            key = (link['component'], link['pattern_id'], link['relation'])
            if key not in tasks or link['component'] not in row['components']:
                raise ValueError('Inventory card link is not a selected component relation')
            links.add(key)
        implementation = row.get('implementation')
        execution = row.get('execution')
        coverage = row.get('coverage')
        result = row.get('result')
        if (implementation not in {'NOT_IMPLEMENTED', 'IMPLEMENTED'}
                or execution not in {'NOT_EXECUTED', 'EXECUTED'}
                or coverage not in {'NOT_ASSESSED', 'PARTIAL', 'COMPLETE'}
                or result not in {'NOT_ASSESSED', 'PASS', 'VIOLATION', 'DATA_INSUFFICIENT', 'NOT_APPLICABLE'}):
            raise ValueError('Separate implementation/execution/coverage/result states')
        if execution == 'EXECUTED' and implementation != 'IMPLEMENTED':
            raise ValueError('Unimplemented relation cannot claim execution')
        if result in {'PASS', 'VIOLATION'} and execution != 'EXECUTED':
            raise ValueError('Unchecked relation cannot claim pass or violation')
        if result == 'NOT_APPLICABLE':
            if not row.get('reason') or not row.get('verification_evidence'):
                raise ValueError('Exclusion requires reason and independent evidence')
            excluded.append(row['id'])
        elif coverage == 'COMPLETE':
            if (execution != 'EXECUTED' or result not in {'PASS', 'VIOLATION'}
                    or not row.get('verification_evidence')):
                raise ValueError('Complete coverage requires execution and numeric/semantic evidence')
            checked.append(row['id'])
        else:
            if not row.get('reason'):
                raise ValueError('Uncovered relation needs an explicit reason')
            gaps.append(row['id'])
        for evidence in row.get('verification_evidence', []):
            file = p.contained(project, evidence['path'])
            if not file.is_file() or p.sha(file) != evidence['sha256']:
                raise ValueError('Inventory verification evidence changed or missing')
            if file.is_relative_to(project / p.ADAPTER) or file.name == 'bindings.json':
                raise ValueError('Keep execution evidence outside adapter sources')
            ref = {'root': 'project', 'path': evidence['path'], 'sha256': evidence['sha256']}
            if ref not in dependencies:
                dependencies.append(ref)
    missing_components = sorted({x['id'] for x in (plan or {}).get('assessment', {}).get('components', [])} - components)
    missing_roles = sorted(tasks - links)
    kinds = {row['kind'] for row in rows}
    absence = document.get('absent_kinds', {})
    if not isinstance(absence, dict) or set(absence) - KINDS or set(absence) & kinds:
        raise ValueError('Invalid or contradictory absent relation kinds')
    for item in absence.values():
        if not item.get('reason') or not item.get('source_evidence'):
            raise ValueError('Absent relation kind requires independent source review')
        for evidence in item['source_evidence']:
            source(evidence, lines=True)
    unreviewed_kinds = sorted(KINDS - kinds - set(absence))
    enumeration = document['enumeration_complete'] and not missing_sources and not missing_components and not unreviewed_kinds
    summary = {'state': 'COMPLETE_FOR_DECLARED_SCOPE' if enumeration and not gaps and not missing_roles else 'PARTIAL',
               'enumeration_reviewed_complete': enumeration, 'total_relations': len(rows),
               'by_kind': dict(Counter(x['kind'] for x in rows)), 'checked': checked,
               'excluded': excluded, 'uncovered': gaps, 'missing_source_reviews': missing_sources,
               'missing_components': missing_components, 'unlinked_card_roles': missing_roles,
               'unreviewed_kinds': unreviewed_kinds,
               'model_correctness': 'NOT_ASSESSED', 'scope': document['scope']}
    return summary, dependencies


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', required=True)
    args = parser.parse_args()
    try:
        project, adapter = p.location(args.project)
        config = p.read(adapter / 'project.json')
        plan = p.read(p.contained(adapter, config['card_plan'])) if config.get('card_plan') else None
        summary, _ = review(project, p.read(p.contained(adapter, config['relation_inventory'])), config, plan)
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print('ERROR: ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
