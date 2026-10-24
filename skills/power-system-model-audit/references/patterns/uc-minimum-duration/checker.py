"""Card-local reference fixture evaluator, not a project runtime adapter."""
from psaudit_pattern_numeric import vector, close, pairs, positive, binary

CHECKER_ID = 'uc-duration'
API_VERSION = 1


def check(d):
    if d.get("model_type") != "UC":
        return "NOT_APPLICABLE"
    u = vector(d["state"])
    if not binary(u):
        return False
    u = [int(round(x)) for x in u]
    on = d["minimum_on"]; off = d["minimum_off"]
    if any(not isinstance(x, int) or isinstance(x, bool) or x < 1 or x > len(u)
           for x in [on, off]):
        raise ValueError("Integer duration within fixture horizon required")
    periodic = d["periodic"]
    if not isinstance(periodic, bool):
        raise ValueError("Explicit boundary mode required")
    if not periodic and d.get("boundary_policy") != "truncate":
        raise ValueError("This checker only supports declared truncate boundaries")
    initial = u[-1] if periodic else d["initial_state"]
    if initial not in (0, 1):
        raise ValueError("Binary initial state required")
    for t, current in enumerate(u):
        previous = u[t - 1] if t else initial
        if current == previous:
            continue
        duration = on if current else off
        for offset in range(duration):
            at = t + offset
            if not periodic and at >= len(u):
                break
            if u[at % len(u)] != current:
                return False
    return True
