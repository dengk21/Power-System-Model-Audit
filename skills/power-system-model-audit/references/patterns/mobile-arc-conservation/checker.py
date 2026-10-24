"""Card-local reference fixture evaluator, not a project runtime adapter."""
from psaudit_pattern_numeric import vector, close, pairs, positive, binary

CHECKER_ID = 'mobile-flow'
API_VERSION = 1


def check(d):
    if d.get("representation") != "unique-endpoint-arcs":
        return "NOT_APPLICABLE"
    x = d["positions"]; y = d["flows"]; arcs = d["arcs"]
    if len(x) < 2 or len(y) != len(x) - 1:
        raise ValueError("T states and T-1 movements required")
    n = len(vector(x[0])); normalized = []
    for arc in arcs:
        if (not isinstance(arc, list) or len(arc) != 2
                or any(not isinstance(i, int) or isinstance(i, bool) or i < 0 or i >= n for i in arc)):
            raise ValueError("Invalid zero-based arc endpoints")
        normalized.append(tuple(arc))
    if len(set(normalized)) != len(normalized):
        raise ValueError("Unique endpoint arcs required by this representation")
    for row in x:
        row = vector(row)
        if len(row) != n:
            raise ValueError("Position shape mismatch")
        if not binary(row) or not close(sum(row), 1):
            return False
    for t, row in enumerate(y):
        row = vector(row)
        if len(row) != len(arcs):
            raise ValueError("Arc shape mismatch")
        if any(v < 0 or v > 1 for v in row):
            return False
        for i in range(n):
            outgoing = sum(v for (a, b), v in zip(normalized, row) if a == i)
            incoming = sum(v for (a, b), v in zip(normalized, row) if b == i)
            if not close(outgoing, x[t][i]) or not close(incoming, x[t + 1][i]):
                return False
    return True
