"""Card-local reference fixture evaluator, not a project runtime adapter."""
from psaudit_pattern_numeric import vector, close, pairs, positive, binary

CHECKER_ID = 'concave-loss'
API_VERSION = 1


def check(d):
    if d.get("curve") != "concave":
        return "NOT_APPLICABLE"
    slopes = vector(d["slopes"]); intercepts = vector(d["intercepts"])
    list(pairs(slopes, intercepts))
    if any(a < b - 1e-9 for a, b in zip(slopes, slopes[1:])):
        raise ValueError("Nonincreasing segment slopes required")
    maximum = positive(d["phi_max"]); count = positive(d["count"])
    for power, loss in pairs(vector(d["power_w"]), vector(d["loss_mbps"])):
        lower = max(0, *(count * (maximum - b) - m * power for m, b in zip(slopes, intercepts)))
        if power < 0 or loss < lower - 1e-7 or loss > count * maximum + 1e-7:
            return False
    return True
