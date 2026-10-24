"""Card-local reference fixture evaluator, not a project runtime adapter."""
from psaudit_pattern_numeric import vector, close, pairs, positive, binary

CHECKER_ID = 'ed-balance'
API_VERSION = 1


def check(d):
    if d.get("lossless") is not True:
        return "NOT_APPLICABLE"
    return close(sum(vector(d["generation"])), sum(vector(d["demand"])))
