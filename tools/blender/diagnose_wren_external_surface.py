#!/usr/bin/env python3
"""Generate geometry-only pelvic cross-sections for Wren collider review.

This is deliberately diagnostic, not an anatomical classifier. It never edits
or exports a collision mesh and never claims that internal canal surfaces have
been excluded.
"""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
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

    # GLB coordinates are X lateral, Y vertical, +Z anterior.
    # Plot section traces of the body mesh only; no skin render or garment.
    offsets = [0.0, -0.01, 0.01, -0.02, 0.02]
    fig, axes = plt.subplots(1, len(offsets), figsize=(15, 7), sharey=True)
    for ax, x in zip(axes, offsets):
        section = mesh.section(plane_origin=[x, 0.0, 0.0],
                               plane_normal=[1.0, 0.0, 0.0])
        if section is not None:
            for line in section.discrete:
                points = np.asarray(line)
                ax.plot(points[:, 2], points[:, 1], linewidth=0.65)
        ax.set_title(f"X = {x * 1000:.0f} mm")
        ax.set_xlim(-0.14, 0.22)
        ax.set_ylim(0.68, 1.12)
        ax.set_xlabel("Anterior (+Z) / posterior (-Z), metres")
        ax.grid(True, alpha=0.2)
    axes[0].set_ylabel("Height (Y), metres")
    fig.suptitle("Accepted Wren body: geometry-only pelvic cross-sections")
    fig.tight_layout()
    image_path = out / "wren-pelvic-cross-sections.png"
    fig.savefig(image_path, dpi=180)
    plt.close(fig)

    # Candidate inward-facing normal statistics are informational only. A
    # radial normal test is not a valid general external-surface classifier.
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
        "connected_component_count": len(components),
        "components": rows,
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
          json.dumps({"components": len(components),
                      "faces": len(mesh.faces),
                      "image": str(image_path)}))


if __name__ == "__main__":
    main()
