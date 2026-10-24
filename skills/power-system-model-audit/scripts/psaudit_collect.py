"""Capture an explicit project test run and derive a reviewable acceptance envelope.

No solver discovery or implicit execution. Runtime observations are emitted by
project tests, not inferred from mapping prose. Mathematical review stays human.
"""
from datetime import datetime, timezone
import math
import os
from pathlib import Path
import platform
import signal
import subprocess
import sys
import time

import psaudit_project as p


def snapshot(project, adapter, skill, config, runner):
    rows = []
    roots = {'project': project, 'adapter': adapter, 'skill': skill}
    names = [('project', x) for x in config.get('source_files', [])]
    names += [('skill', x) for x in config.get('skill_files', [])]
    names += [('project', x) for x in config.get('test_files', [])]
    names.append(('project', runner))
    names += [('adapter', x.relative_to(adapter).as_posix()) for x in sorted(adapter.rglob('*'))
              if x.is_file() and x.relative_to(adapter).parts[0] != 'history'
              and x.name != 'bindings.json' and '__pycache__' not in x.parts]
    for root, name in sorted(set(names)):
        file = p.contained(roots[root], name)
        if not file.is_file():
            raise ValueError('Missing declared run dependency: ' + name)
        if root == 'project' and name in config.get('source_files', []) and file.is_relative_to(adapter.parent):
            raise ValueError('Model source cannot be an audit artifact')
        rows.append({'root': root, 'path': name, 'sha256': p.sha(file)})
    return rows


def runtime_checks(facts, plan, evidence):
    if (not isinstance(facts, dict) or facts.get('schema_version') != 1
            or not isinstance(facts.get('checks'), list) or not facts['checks']):
        raise ValueError('Runtime facts require schema_version=1 and checks')
    checks = facts['checks']
    names = [x['function'] for x in checks]
    if len(names) != len(set(names)):
        raise ValueError('Duplicate runtime check functions')
    selected = {x['function']: x for x in (plan or {}).get('entries', []) if x['state'] == 'MATCH'}
    if plan is not None and set(names) != set(selected):
        raise ValueError('Runtime facts must cover exactly the selected card checkers')
    result = []
    from psaudit_project_acceptance import CATEGORIES
    for check in checks:
        inputs = check.get('inputs', {})
        if not isinstance(inputs, dict):
            raise ValueError('Runtime inputs must be observations by canonical name')
        if plan is not None and set(inputs) != set(selected[check['function']]['contract']['inputs']):
            raise ValueError('Runtime inputs do not match the selected card')
        for observation in inputs.values():
            shape = observation.get('shape')
            if (not isinstance(shape, list) or not shape or any(type(x) is not int or x < 1 for x in shape)
                    or any(not isinstance(observation.get(k), str) or not observation[k].strip()
                           for k in ('unit', 'index_review'))):
                raise ValueError('Emit observed shape and reviewed unit/index interpretation from tests')
        relations = check.get('relations', [])
        roles = [x['card_relation'] for x in relations]
        if len(roles) != len(set(roles)):
            raise ValueError('Duplicate runtime card relations')
        if plan is not None and set(roles) != set(selected[check['function']]['contract']['relations']):
            raise ValueError('Runtime relations do not match selected card roles')
        for relation in relations:
            ids = relation.get('project_relation_ids')
            if (not isinstance(ids, list) or not ids or len(ids) != len(set(ids))
                    or any(not isinstance(x, str) or not x.strip() for x in ids)
                    or relation.get('status') not in {'PASS', 'VIOLATION', 'DATA_INSUFFICIENT', 'NOT_APPLICABLE'}):
                raise ValueError('Emit actual relation IDs and observed status')
        controls = check.get('controls', [])
        if not CATEGORIES <= {x['category'] for x in controls}:
            raise ValueError('Runtime controls omit required test categories')
        for control in controls:
            # Do not accept an authored passed=true in place of observed outcomes.
            if (not isinstance(control.get('actual'), str) or not control['actual'].strip()
                    or not isinstance(control.get('expected'), str) or not control['expected'].strip()
                    or control['actual'] != control['expected']):
                raise ValueError('Runtime control failed or lacks actual/expected outcome')
        result.append({'function': check['function'],
            'inputs': {k: {**v, 'evidence': evidence} for k, v in inputs.items()},
            'relations': [{**x, 'evidence': evidence} for x in relations],
            'controls': [{**x, 'passed': True, 'evidence': evidence} for x in controls]})
    return result


def collect(project, skill, runner, output, command, timeout=60):
    project, adapter = p.location(project)
    skill = Path(skill).resolve()
    if not command or not all(isinstance(x, str) and x for x in command):
        raise ValueError('Provide an explicit --run command; nothing executes by default')
    if not isinstance(timeout, (int, float)) or not math.isfinite(timeout) or timeout <= 0:
        raise ValueError('Provide a finite positive test timeout')
    if not runner or not output:
        raise ValueError('collect requires --runner and a new --output directory')
    out = p.contained(project, output)
    if out.is_relative_to(adapter) or out.is_relative_to(skill) or skill.is_relative_to(out):
        raise ValueError('Run artifacts belong outside adapter and Skill sources')
    config = p.read(adapter / 'project.json')
    inventory = p.read(p.contained(adapter, config['relation_inventory']))
    for key in ('reviewer', 'scope'):
        if not isinstance(inventory.get(key), str) or not inventory[key].strip():
            raise ValueError('Record reviewer and scope once in relations.json before collection')
    if not config.get('source_files'):
        raise ValueError('Declare model source_files before collection')
    before = snapshot(project, adapter, skill, config, runner)
    plan = p.read(p.contained(adapter, config['card_plan'])) if config.get('card_plan') else None
    if plan is not None:
        from psaudit_card_checks import assert_current_plan
        assert_current_plan(project, skill, plan)
    out.mkdir(parents=True, exist_ok=False)
    facts_file = out / 'facts.json'
    env = dict(os.environ, PSAUDIT_FACTS_PATH=str(facts_file), PYTHONDONTWRITEBYTECODE='1')
    started = datetime.now(timezone.utc).isoformat()
    tick = time.monotonic()
    execution = {'schema_version': 1, 'command': command, 'cwd': str(project),
        'started_at': started, 'timeout_seconds': timeout,
        'host': {'platform': platform.platform(), 'python': sys.version},
        'state': 'FAILED', 'exit_code': None, 'files_before': before,
        'scope': 'Observed subprocess execution; does not prove mathematics, runner invocation or undeclared dependency completeness.'}
    execution['collector_files'] = [{'name': Path(x).name, 'sha256': p.sha(x)}
                                    for x in (__file__, p.__file__)]
    error = None
    try:
        with (out / 'stdout.log').open('wb') as stdout, (out / 'stderr.log').open('wb') as stderr:
            kwargs = {'creationflags': subprocess.CREATE_NO_WINDOW} if os.name == 'nt' else {'start_new_session': True}
            proc = subprocess.Popen(command, cwd=project, env=env, stdout=stdout, stderr=stderr, **kwargs)
            try:
                execution['exit_code'] = proc.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                if os.name == 'nt':
                    subprocess.run(['taskkill', '/PID', str(proc.pid), '/T', '/F'],
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
                else:
                    os.killpg(proc.pid, signal.SIGKILL)
                proc.kill() if proc.poll() is None else None
                proc.wait()
                execution['state'] = 'TIMED_OUT'
                raise ValueError('Test command timed out')
        if execution['exit_code'] != 0:
            raise ValueError('Test command failed; inspect captured stderr/stdout')
        after = snapshot(project, adapter, skill, config, runner)
        execution['files_after'] = after
        if before != after:
            raise ValueError('Declared source/test/adapter changed during execution; run again after review')
        facts_ref = {'root': 'project', 'path': facts_file.relative_to(project).as_posix(), 'sha256': p.sha(facts_file)}
        checks = runtime_checks(p.read(facts_file), plan, facts_ref)
        execution['state'] = 'COLLECTED_NOT_REVIEWED'
    except (OSError, ValueError, KeyError, TypeError) as exc:
        error = str(exc)
        execution['error'] = error
    execution['elapsed_seconds'] = time.monotonic() - tick
    p.write(out / 'execution.json', execution)
    if error:
        return {'state': execution['state'], 'output': str(out), 'error': error}
    files = before[:]
    for name in ('facts.json', 'stdout.log', 'stderr.log', 'execution.json'):
        file = out / name
        files.append({'root': 'project', 'path': file.relative_to(project).as_posix(), 'sha256': p.sha(file)})
    report = {'schema_version': 1, 'collection_version': 1,
        'reviewer': inventory['reviewer'], 'scope': inventory['scope'], 'files': files,
        'runner': next(x for x in files if x['root'] == 'project' and x['path'] == runner),
        'execution_evidence': files[-1], 'checks': checks,
        'review_state': 'PENDING_SEMANTIC_REVIEW'}
    p.write(out / 'acceptance.json', report)
    return {'state': execution['state'], 'output': str(out),
            'test_evidence': (out / 'acceptance.json').relative_to(project).as_posix(),
            'next': 'Review observations, mapping assertions and independent mathematics, then freeze using this test_evidence.'}


def validate_collection(project, adapter, skill, report):
    roots = {'project': project, 'adapter': adapter, 'skill': skill}
    rows = report.get('files', [])
    if not rows:
        raise ValueError('Collected evidence lacks bound files')
    for row in rows:
        file = p.contained(roots[row['root']], row['path'])
        if not file.is_file() or p.sha(file) != row['sha256']:
            raise ValueError('Collected execution dependency changed: ' + row['path'])
    evidence = report['execution_evidence']
    if evidence not in rows or report['runner'] not in rows:
        raise ValueError('Collected runner/execution must be bound')
    execution = p.read(p.contained(roots[evidence['root']], evidence['path']))
    if execution.get('state') != 'COLLECTED_NOT_REVIEWED' or execution.get('exit_code') != 0:
        raise ValueError('Collected execution did not complete successfully')
    if execution.get('files_before') != execution.get('files_after'):
        raise ValueError('Execution source snapshots differ')
    return rows
