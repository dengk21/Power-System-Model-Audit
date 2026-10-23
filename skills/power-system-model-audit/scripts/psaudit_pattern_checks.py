"""Small independent numerical checks for pattern fixtures, never a solver.

These check the declared local relations only. They do not parse arbitrary
source, establish physical assumptions or certify a whole optimization model.
"""
import math


def vector(value):
    if not isinstance(value, list):
        value = [value]
    if not value or any(isinstance(x, bool) or not isinstance(x, (int, float))
                        or not math.isfinite(x) for x in value):
        raise ValueError("Expected nonempty finite numerical array")
    return value


def close(a, b):
    return abs(a - b) <= 1e-7 + 1e-9 * max(abs(a), abs(b))


def pairs(*arrays):
    if len({len(x) for x in arrays}) != 1:
        raise ValueError("Shape mismatch")
    return zip(*arrays)


def positive(x):
    x = vector(x)[0]
    if x <= 0:
        raise ValueError("Positive parameter required")
    return x


def binary(values):
    return all(close(x, 0) or close(x, 1) for x in values)


def storage(d):
    if d.get("self_discharge_model") != "none":
        return "NOT_APPLICABLE"
    ef = {"kWh": 1, "MWh": 1000}[d["energy_unit"]]
    pf = {"kW": 1, "MW": 1000}[d["power_unit"]]
    energy = [x * ef for x in vector(d["energy"])]
    charge = vector(d["charge"]); discharge = vector(d["discharge"])
    eta_c = positive(d["eta_c"]); eta_d = positive(d["eta_d"])
    dt = positive(d["dt_h"])
    if eta_c > 1 or eta_d > 1 or len(energy) != len(charge) + 1:
        raise ValueError("Efficiency or T+1 energy shape invalid")
    valid = all(x >= 0 for x in charge + discharge + energy)
    for e0, e1, pc, pd in pairs(energy[:-1], energy[1:], charge, discharge):
        valid &= close(e1, e0 + dt * pf * (eta_c * pc - pd / eta_d))
    if "capacity" in d:
        valid &= all(e <= positive(d["capacity"]) * ef + 1e-7 for e in energy)
    return valid


def balance(d):
    if d.get("lossless") is not True:
        return "NOT_APPLICABLE"
    return close(sum(vector(d["generation"])), sum(vector(d["demand"])))


def commitment(d):
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


def mobile_flow(d):
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


def travel_operation(d):
    if d["resource"] != "MESS":
        return "NOT_APPLICABLE"
    dt = positive(d["dt_h"]); pmax = positive(d["pmax"])
    for travel, charge, discharge in pairs(vector(d["travel_h"]), vector(d["charge"]), vector(d["discharge"])):
        if min(travel, charge, discharge) < 0 or travel + dt * (charge + discharge) / pmax > dt + 1e-7:
            return False
    return True


def endpoint_gating(d):
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


def repair(d):
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


def concave_loss(d):
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


CHECKERS = {"storage-energy": storage, "ed-balance": balance, "uc-duration": commitment,
            "mobile-flow": mobile_flow, "travel-operation": travel_operation,
            "endpoint-gating": endpoint_gating, "repair-progress": repair,
            "concave-loss": concave_loss}


def evaluate(checker, data):
    try:
        value = CHECKERS[checker](data)
        if isinstance(value, str):
            return value
        return "PASS" if value else "VIOLATION"
    except (KeyError, ValueError, TypeError, IndexError, OverflowError, ZeroDivisionError):
        return "DATA_INSUFFICIENT"
