"""Check freshness/completeness of project-reviewed checker acceptance evidence.

This is an evidence envelope, not a model/checker API or execution attestation.
Project tests own formulas, mapping assertions, coupling and runtime formats.
"""
import psaudit_project as p

CATEGORIES = {'normal', 'violation', 'equivalent', 'inapplicable', 'missing_data', 'boundary'}


def validate(project, adapter, skill, config, plan, evidence):
    report = p.read(p.contained(project, evidence))
    if not isinstance(report, dict) or report.get('schema_version') != 1:
        raise ValueError('Card checker freeze requires a project acceptance JSON, not an arbitrary log')
    for key in ('reviewer', 'scope'):
        if not isinstance(report.get(key), str) or not report[key].strip():
            raise ValueError('Acceptance requires substantive ' + key)
    roots = {'project': project, 'adapter': adapter, 'skill': skill}
    bound = set()
    dependencies = []

    def reference(row):
        root = row.get('root')
        if root not in roots:
            raise ValueError('Unknown acceptance evidence root')
        file = p.contained(roots[root], row['path'])
        if not file.is_file() or p.sha(file) != row['sha256']:
            raise ValueError('Acceptance evidence missing or stale: ' + row['path'])
        if file == p.contained(project, evidence) or file.name == 'bindings.json':
            raise ValueError('Acceptance cannot refer to itself or bindings as test evidence')
        bound.add((root, row['path']))
        item = {'root': root, 'path': row['path'], 'sha256': row['sha256']}
        if item not in dependencies:
            dependencies.append(item)
        return file

    for row in report.get('files', []):
        reference(row)
    # Bind the code tested, not just its log; adapter config/dispatch/checkers included.
    required = {('project', x) for x in config['source_files']}
    required |= {('skill', x) for x in config['skill_files']}
    for file in adapter.rglob('*'):
        relative = file.relative_to(adapter)
        if (file.is_file() and relative.parts[0] != 'history'
                and file.name != 'bindings.json' and '__pycache__' not in relative.parts):
            required.add(('adapter', relative.as_posix()))
    if required - bound:
        raise ValueError('Acceptance snapshot omits declared source, selected Skill or adapter files')
    reference(report['runner'])
    reference(report['execution_evidence'])
    if not config.get('relation_inventory'):
        raise ValueError('Card project requires a source-first relation inventory')
    from psaudit_relation_inventory import review
    inventory = p.read(p.contained(adapter, config['relation_inventory']))
    _, inventory_deps = review(project, inventory, config, plan)
    dependencies.extend(x for x in inventory_deps if x not in dependencies)
    indexed = {x['id']: x for x in inventory['relations']}
    selected = {x['function']: x for x in plan['entries'] if x['state'] == 'MATCH'}
    if not selected:
        raise ValueError('No ready card selections to accept; unresolved coverage remains unassessed')
    checks = report.get('checks', [])
    names = [x['function'] for x in checks]
    if len(names) != len(set(names)) or set(names) != set(selected):
        raise ValueError('Acceptance must cover exactly the selected project checkers')
    for check in checks:
        task = selected[check['function']]
        inputs = check.get('inputs', {})
        if set(inputs) != set(task['contract']['inputs']):
            raise ValueError('Acceptance missing actual canonical input observations')
        for observation in inputs.values():
            shape = observation.get('shape')
            if (not isinstance(shape, list) or not shape
                    or any(type(x) is not int or x < 1 for x in shape)
                    or any(not isinstance(observation.get(k), str) or not observation[k].strip()
                           for k in ('unit', 'index_review'))):
                raise ValueError('Record observed shape, unit and physical/time index review')
            reference(observation['evidence'])
        relations = check.get('relations', [])
        roles = [x['card_relation'] for x in relations]
        if len(roles) != len(set(roles)) or set(roles) != set(task['contract']['relations']):
            raise ValueError('Acceptance must account for every selected card relation')
        for relation in relations:
            ids = relation.get('project_relation_ids')
            if (not isinstance(ids, list) or not ids or len(ids) != len(set(ids))
                    or any(not isinstance(x, str) or not x.strip() for x in ids)):
                raise ValueError('Bind card roles to actual executed project relation IDs')
            reference(relation['evidence'])
            for identifier in ids:
                item = indexed.get(identifier)
                key = {'component': task['component'], 'pattern_id': task['pattern_id'],
                       'relation': relation['card_relation']}
                if (item is None or key not in item.get('card_links', [])
                        or item.get('execution') != 'EXECUTED' or item.get('result') == 'NOT_APPLICABLE'):
                    raise ValueError('Accepted project relation missing/excluded from executed inventory')
        controls = check.get('controls', [])
        if not CATEGORIES <= {x['category'] for x in controls}:
            raise ValueError('Acceptance requires normal/violation/equivalent/inapplicable/missing_data/boundary controls')
        for control in controls:
            if control.get('passed') is not True:
                raise ValueError('Project checker control did not pass its expected outcome')
            reference(control['evidence'])
    return dependencies
