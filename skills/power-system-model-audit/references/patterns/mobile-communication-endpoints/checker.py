"""Card-local reference fixture evaluator, not a project runtime adapter."""
from psaudit_pattern_numeric import vector, close, pairs, positive, binary

CHECKER_ID = 'endpoint-gating'
API_VERSION = 1


def check(d):
    if d["resource"] not in ("MESS", "CREW") or d["enabled"] is False:
        return "NOT_APPLICABLE"
    if d["enabled"] is not True:
        raise ValueError("Explicit communication switch required")
    current = vector(d["coverage_t"]); next_c = vector(d["coverage_next"])
    if len(current) != len(next_c) or not binary(current + next_c):
        raise ValueError("Coverage must be binary and shape matched")
    outgoing = [0.] * len(current); incoming = [0.] * len(current)
    if len(d["arcs"]) != len(vector(d["flow"])):
        raise ValueError("Arc shape mismatch")
    for (a, b), v in zip(d["arcs"], vector(d["flow"])):
        if any(not isinstance(i, int) or isinstance(i, bool) or i < 0 or i >= len(current) for i in (a, b)):
            raise ValueError("Invalid endpoints")
        if not 0 <= v <= 1:
            return False
        if a != b:
            outgoing[a] += v; incoming[b] += v
    return all(o <= c + 1e-7 and i <= c + 1e-7 and i <= c1 + 1e-7
               for o, i, c, c1 in zip(outgoing, incoming, current, next_c))
