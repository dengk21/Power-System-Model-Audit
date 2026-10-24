"""Card-local reference fixture evaluator, not a project runtime adapter."""
from psaudit_pattern_numeric import vector, close, pairs, positive, binary

CHECKER_ID = 'repair-progress'
API_VERSION = 1


def check(d):
    if d["faulted"] is False:
        return "NOT_APPLICABLE"
    R = positive(d["repair_h"]); dt = positive(d["dt_h"]); hmax = positive(d["max_progress"])
    if not close(R / dt, round(R / dt)) or hmax < R:
        raise ValueError("Discrete threshold must align with the declared time step")
    h = vector(d["progress"]); u = vector(d["available"]); c = vector(d["coverage_before"])
    if not binary(u + c):
        return False
    if not close(h[0], 0) or not close(u[0], 0):
        return False
    previous = 0
    for amount, available, coverage in pairs(h, u, c):
        if (amount < -1e-7 or amount > hmax + 1e-7
                or R * available > amount + 1e-7
                or amount > R - dt + (hmax - R + dt) * available + 1e-7
                or available < previous - 1e-7 or available - previous > coverage + 1e-7):
            return False
        previous = available
    return True
