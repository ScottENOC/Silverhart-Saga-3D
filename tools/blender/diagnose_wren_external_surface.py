#!/usr/bin/env python3
"""Generate geometry-only pelvic cross-sections for Wren collider review.

Diagnostic only: this does not classify anatomy or export a collider. Plane
intersections are computed directly from source triangles so open/non-manifold
skin meshes do not depend on trimesh's path assembly or optional spatial index.
"""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
import numpy as np
import trimesh


def load_body(path: Path):
    scene = trimesh.load(path, force="scene", process=False)
    for node in scene.graph.nodes_geometry:
        transform, geometry_name = scene.graph.get(node)
        if geometry_name == "Wren":
            mesh = scene.geometry[geometry_name].copy()
            mesh.apply_transform(transform)
            return mesh
    raise RuntimeError("Could not find the accepted Wren body mesh in GLB")


def intersect_x_plane(mesh, x_value, epsilon=1e-9):
    """Return independent 2D (Z,Y) line segments intersecting x=x_value."""
    triangles = mesh.vertices[mesh.faces]
    distances = triangles[:, :, 0] - x_value
    segments = []
    for tri, dist in zip(triangles, distances):
        # Ignore coplanar triangles: their area is not a section contour.
        if np.all(np.abs(dist) <= epsilon):
            continue
        points = []
        for a, b in ((0, 1), (1, 2), (2, 0)):
            da, db = dist[a], dist[b]
            if abs(da) <= epsilon:
                p = tri[a]
            elif abs(db) <= epsilon:
                p = tri[b]
            elif (da < 0.0) != (db < 0.0):
                t = da / (da - db)
                p = tri[a] + t * (tri[b] - tri[a])
            else:
                continue
            q = np.array([p[2], p[1]], dtype=float)
            if not any(np.linalg.norm(q - prior) <= epsilon * 10 for prior in points):
                points.append(q)
        if len(points) == 2 and np.linalg.norm(points[0] - points[1]) > epsilon:
            segments.append([points[0], points[1]])
    return np.asarray(segments, dtype=float).reshape((-1, 2, 2))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()
    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)
    mesh = load_body(Path(args.input))

    components = sorted(mesh.split(only_watertight=False),
                        key=lambda part: len(part.faces), reverse=True)
    rows = []
    for index, part in enumerate(components):
        rows.append({
            "index": index,
            "vertices": int(len(part.vertices)),
            "faces": int(len(part.faces)),
            "bounds": part.bounds.tolist(),
            "area_m2": float(part.area),
            "watertight": bool(part.is_watertight),
            "euler_number": int(part.euler_number),
        })

    offsets = [0.0, -0.01, 0.01, -0.02, 0.02]
    fig, axes = plt.subplots(1, len(offsets), figsize=(17, 7), sharey=True)
    section_counts = []
    for ax, x in zip(axes, offsets):
        segments = intersect_x_plane(mesh, x)
        section_counts.append({"x_m": x, "segment_count": int(len(segments))})
        if len(segments):
            ax.add_collection(LineCollection(segments, linewidths=0.65))
        ax.set_title(f"X = {x * 1000:.0f} mm ({len(segments)} segments)")
        ax.set_xlim(-0.14, 0.22)
        ax.set_ylim(0.68, 1.12)
        ax.set_xlabel("Anterior (+Z) / posterior (-Z), metres")
        ax.grid(True, alpha=0.2)
        ax.set_aspect("equal", adjustable="box")
    if not any(row["segment_count"] for row in section_counts):
        plt.close(fig)
        raise RuntimeError(
            "All pelvic cross-sections are empty; refusing to publish a blank diagnostic. "
            f"Mesh bounds: {mesh.bounds.tolist()}"
        )
    axes[0].set_ylabel("Height (Y), metres")
    fig.suptitle("Accepted Wren body: geometry-only pelvic cross-sections")
    fig.tight_layout()
    image_path = out / "wren-pelvic-cross-sections.png"
    fig.savefig(image_path, dpi=180)
    plt.close(fig)

    centres = mesh.triangles_center
    normals = mesh.face_normals
    pelvic = ((np.abs(centres[:, 0]) < 0.09) &
              (centres[:, 1] > 0.74) & (centres[:, 1] < 0.98) &
              (centres[:, 2] > 0.02))
    radial = centres - np.array([0.0, 0.90, 0.0])
    dots = np.einsum("ij,ij->i", normals[pelvic], radial[pelvic])
    report = {
        "diagnostic_only": True,
        "external_surface_verified": False,
        "internal_canal_exclusion_verified": False,
        "natural_openings_capped": False,
        "body_vertices": int(len(mesh.vertices)),
        "body_faces": int(len(mesh.faces)),
        "mesh_bounds": mesh.bounds.tolist(),
        "connected_component_count": len(components),
        "components": rows,
        "cross_sections": section_counts,
        "pelvic_region_definition": {
            "abs_x_less_than_m": 0.09,
            "y_range_m": [0.74, 0.98],
            "z_greater_than_m": 0.02,
            "note": "Coordinate crop for inspection only; not an anatomical label."
        },
        "pelvic_region_face_count": int(pelvic.sum()),
        "radial_normal_dot_percentiles": (
            np.percentile(dots, [0, 10, 25, 50, 75, 90, 100]).tolist()
            if len(dots) else []
        ),
        "radial_normal_test_warning": (
            "Not a classifier: concave external folds can also point inward "
            "relative to a global reference point."
        ),
        "cross_section_image": image_path.name,
        "conclusion": (
            "Human review of these sections is required. This diagnostic does "
            "not prove internal canal exclusion and must not enable cloth fitting."
        )
    }
    (out / "wren-external-surface-diagnostic.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("WREN_EXTERNAL_SURFACE_DIAGNOSTIC_READY",
          json.dumps({"components": len(components), "faces": len(mesh.faces),
                      "sections": section_counts, "image": str(image_path)}))


if __name__ == "__main__":
    main()
