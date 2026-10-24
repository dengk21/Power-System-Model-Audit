"""Load reviewed card-local fixture checkers; no global domain registry.

Only the fixed checker.py of a hash-bound card is executed. JSON is data.
This loader is not a sandbox. Project runtime checkers live in the project.
"""
import hashlib
from pathlib import Path


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def validate_binding(folder, record):
    folder = Path(folder).resolve()
    spec = record.get('checker_spec', {})
    if spec != {'id': record['checker'], 'file': 'checker.py', 'api_version': 1}:
        raise ValueError('Unsupported or mismatched checker descriptor')
    path = folder / 'checker.py'
    if path.is_symlink() or not path.is_file() or digest(path) != record.get('checker_sha256'):
        raise ValueError('Card checker changed or missing; review only its dependents')
    dependencies = record.get('checker_dependencies')
    expected = {'psaudit_pattern_checks.py', 'psaudit_pattern_numeric.py'}
    if not isinstance(dependencies, dict) or set(dependencies) != expected:
        raise ValueError('Declare loader and shared numeric dependencies')
    for name, value in dependencies.items():
        if value != digest(Path(__file__).with_name(name)):
            raise ValueError('Shared checker dependency changed: ' + name)
    return path


def load_checker(folder, record):
    path = validate_binding(folder, record)
    # Compile exact bound bytes rather than using a possibly stale .pyc.
    namespace = {'__file__': str(path), '__name__': 'psaudit_card_fixture'}
    exec(compile(path.read_bytes(), str(path), 'exec'), namespace)
    if namespace.get('CHECKER_ID') != record['checker'] or namespace.get('API_VERSION') != 1:
        raise ValueError('Checker code does not match its declared ID/API')
    function = namespace.get('check')
    if not callable(function):
        raise ValueError('Card checker must implement check(data)')
    return function


def evaluate(function, data):
    try:
        value = function(data)
        if isinstance(value, str) and value in ('PASS', 'VIOLATION', 'NOT_APPLICABLE', 'DATA_INSUFFICIENT'):
            return value
        if type(value) is not bool:
            raise RuntimeError('Invalid checker return type')
        return 'PASS' if value else 'VIOLATION'
    except (KeyError, ValueError, TypeError, IndexError, OverflowError, ZeroDivisionError):
        return 'DATA_INSUFFICIENT'
