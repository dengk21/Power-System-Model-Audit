"""Independent node/time balance fixtures; no model loading or solver."""
from psaudit_pattern_numeric import vector, close

CHECKER_ID = 'dc-nodal-balance'
API_VERSION = 1


def matrix(value):
    if not isinstance(value, list) or not value:
        raise ValueError('Nonempty matrix required')
    rows = [vector(x) for x in value]
    if any(len(x) != len(rows[0]) for x in rows):
        raise ValueError('Rectangular matrix required')
    return rows


def check(data):
    if data.get('network') != 'lossless_dc':
        return 'NOT_APPLICABLE'
    if data['power_unit'] != 'MW':
        raise ValueError('Explicit common MW unit required')
    generation = matrix(data['generation_by_node'])
    demand = matrix(data['demand_by_node'])
    incidence = matrix(data['incidence'])
    flow = matrix(data['branch_flow'])
    n, t = len(generation), len(generation[0])
    if (len(demand) != n or len(demand[0]) != t or len(incidence[0]) != n
            or len(flow) != len(incidence) or len(flow[0]) != t):
        raise ValueError('Node/branch/time shape mismatch')
    for row in incidence:
        if row.count(1) != 1 or row.count(-1) != 1 or any(x not in (-1, 0, 1) for x in row):
            raise ValueError('Each branch requires one origin and one destination')
    return all(close(generation[i][j] - demand[i][j],
                     sum(incidence[l][i] * flow[l][j] for l in range(len(flow))))
               for i in range(n) for j in range(t))
