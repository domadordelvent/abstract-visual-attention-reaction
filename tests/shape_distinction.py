"""Compare complete contours under arbitrary rotation/reflection (stdlib only)."""
from pathlib import Path
import cmath
import json
import math

source = (Path(__file__).resolve().parents[1] / 'abstract_shapes.gd').read_text()
raw = source.split('const OUTLINES := [', 1)[1].split('\n]', 1)[0]
polygons = json.loads('[' + raw.rstrip().rstrip(',') + ']')


def sample(points, count=128):
    vertices = [complex(*point) for point in points]
    lengths = [abs(vertices[(i+1) % len(vertices)]-v) for i, v in enumerate(vertices)]
    perimeter = sum(lengths)
    result = []
    edge = 0
    distance = 0.0
    for index in range(count):
        location = perimeter * index / count
        while location > distance + lengths[edge]:
            distance += lengths[edge]
            edge += 1
        fraction = (location-distance) / lengths[edge]
        result.append(vertices[edge]*(1-fraction)+vertices[(edge+1) % len(vertices)]*fraction)
    center = sum(result)/count
    result = [point-center for point in result]
    scale = math.sqrt(sum(abs(point)**2 for point in result)/count)
    return [point/scale for point in result]


def difference(a, b):
    # Optimal continuous rotation from complex correlation; try both traversal
    # directions, reflection, and all boundary offsets. Normalize size/position.
    count = len(a)
    best = 2.0
    for reflected in [b, [point.conjugate() for point in b]]:
        for candidate in [reflected, list(reversed(reflected))]:
            conjugates = [point.conjugate() for point in candidate]
            for shift in range(count):
                correlation = sum(a[i]*conjugates[(i+shift) % count] for i in range(count))/count
                best = min(best, max(0.0, 2.0-2.0*abs(correlation)))
    return math.sqrt(best)


assert len(polygons) == 12
samples = [sample(points) for points in polygons]
# Control cases prove the comparison detects arbitrary rotated/reflected copies.
assert difference(samples[0], [point*cmath.exp(1.234j) for point in samples[0]]) < 1e-6
assert difference(samples[0], [point.conjugate()*cmath.exp(.713j) for point in samples[0]]) < 1e-6
nearest = (float('inf'), None)
for i in range(12):
    for j in range(i+1, 12):
        error = difference(samples[i], samples[j])
        nearest = min(nearest, (error, (i+1, j+1)))
        assert error > .12, f'Contours {i+1}/{j+1} too similar after rotation/reflection: {error:.3f}'
print(f'PASS: 66 contour pairs differ under arbitrary rotation/reflection; minimum normalized boundary RMS {nearest[0]:.3f} (shapes {nearest[1]}). Two copy-detection controls passed.')
