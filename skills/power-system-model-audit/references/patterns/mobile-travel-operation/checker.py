"""Card-local reference fixture evaluator, not a project runtime adapter."""
from psaudit_pattern_numeric import vector, close, pairs, positive, binary

CHECKER_ID = 'travel-operation'
API_VERSION = 1


def check(d):
    if d["resource"] != "MESS":
        return "NOT_APPLICABLE"
    dt = positive(d["dt_h"]); pmax = positive(d["pmax"])
    for travel, charge, discharge in pairs(vector(d["travel_h"]), vector(d["charge"]), vector(d["discharge"])):
        if min(travel, charge, discharge) < 0 or travel + dt * (charge + discharge) / pmax > dt + 1e-7:
            return False
    return True
