"""Small shared numeric primitives for independent card fixtures; no solver."""
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
