"""Card-local reference fixture evaluator, not a project runtime adapter."""
from psaudit_pattern_numeric import vector, close, pairs, positive, binary

CHECKER_ID = 'storage-energy'
API_VERSION = 1


def check(d):
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
