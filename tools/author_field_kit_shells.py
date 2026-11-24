#!/usr/bin/env python3
"""Write the original exterior shells for the Sprint 12 Godot props."""
from pathlib import Path

OUTPUT = Path(__file__).resolve().parents[1] / "client/assets/props"


def outline(width, height, corner):
    x, y = width / 2, height / 2
    return [
        (-x + corner, -y), (x - corner, -y), (x, -y + corner),
        (x, y - corner), (x - corner, y), (-x + corner, y),
        (-x, y - corner), (-x, -y + corner),
    ]


def shell(name, rings, bow):
    """Connect four chamfered outlines around the existing visual origin."""
    vertices = []
    for width, height, corner, depth in rings:
        for x, y in outline(width, height, corner):
            curve = bow * (1 - (x / (rings[1][0] / 2)) ** 2)
            vertices.append((x, y, depth - curve))
    lines = [f"# {name} | original Sprint 12 game exterior", f"o {name}", "s off"]
    lines.extend("v %.6f %.6f %.6f" % point for point in vertices)
    width, height = rings[1][:2]
    texcoords = [(x / width + 0.5, y / height + 0.5) for x, y, _ in vertices]
    faces = [[(i, i) for i in range(8, 0, -1)]]
    for ring in range(3):
        for i in range(8):
            a = 1 + ring * 8 + i
            b = 1 + ring * 8 + (i + 1) % 8
            uv = len(texcoords) + 1
            u0, u1 = i / 8, (i + 1) / 8
            v0, v1 = ring / 3, (ring + 1) / 3
            texcoords.extend([(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
            faces.append([(a, uv), (b, uv + 1), (b + 8, uv + 2), (a + 8, uv + 3)])
    faces.append([(i, i) for i in range(25, 33)])
    lines.extend("vt %.6f %.6f" % uv for uv in texcoords)
    lines.extend("f " + " ".join(f"{point}/{uv}" for point, uv in face) for face in faces)
    (OUTPUT / f"{name}.obj").write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    shell("field_kit_claymore_shell", [
        (0.432, 0.155, 0.026, -0.053),
        (0.474, 0.190, 0.035, -0.031),
        (0.474, 0.190, 0.035, 0.058),
        (0.432, 0.155, 0.026, 0.070),
    ], bow=0.018)
    shell("field_kit_shield_shell", [
        (2.12, 0.82, 0.070, -0.082),
        (2.18, 0.88, 0.086, -0.057),
        (2.18, 0.88, 0.086, 0.057),
        (2.12, 0.82, 0.070, 0.082),
    ], bow=0)
