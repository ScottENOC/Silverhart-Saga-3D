"""Sculpt adult female external anatomy directly into the existing Ara skin mesh.

The mons, labial folds, clitoral structures, vestibule and external openings
are surface deformations of the original skin mesh. Its material, UVs, vertex
groups and rig remain in place; no genital object is attached. This is an
anatomy sculpt pass requiring multi-angle visual review before acceptance.
On clothed exports, lower garments are fitted around the deformed body surface.

Ara GLB axes after Blender import: Z up, character facing -Y.
"""
import argparse
import os
import sys
import math

import bpy
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

# Shared material-aware fit policy; kept outside Blender so it can be unit-tested.
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "ara")))
from garment_fit import (
    FIT_PROFILES, profile_for_material, estimate_correction_strain, classify_strain,)