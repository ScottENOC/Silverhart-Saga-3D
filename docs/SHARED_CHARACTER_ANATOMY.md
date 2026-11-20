# Shared Ara Character Anatomy Contract

## Purpose

Every human actor is instantiated from exactly one of the two canonical Ara runtime
body assets:

- Female: `art/characters/ara_runtime/ara_person_body_anatomy.glb`
- Male: `art/characters/ara_runtime/ara_person_male_body.glb`

Character identity, body parameters, appearance, hair, tattoos and equipment are
modifications applied to that base. Settlement data controls placement and behaviour,
not body construction.

All downstream systems must address anatomy through a shared semantic interface.
They must not hard-code imported GLB node paths or infer body locations from whole-body
bounding boxes.

## Representation layers

These are intentionally distinct because a bone, a surface point and a body region
are not interchangeable.

| Layer | Representation | Primary consumers |
|---|---|---|
| Rig landmark | Animated joint transform with a semantic ID | Animation, IK, bone attachments |
| Surface anchor | Authored point and orientation on the deformed skin | Jewellery, precise attachment, garment guides |
| Surface region | Labelled/deformable set of body surface samples or triangles | Garment fitting, coverage, compression |
| Spatial volume | Deformation-aware 3D region with bounds/shape | Combat hit regions, collision, targeting |

## Runtime contract

`CharacterAnatomy` is the shared query interface. It exposes character-root-local
transforms so consumers do not need to know the skeleton's parent transform.

- `has_landmark(id)`
- `get_landmark_transform(id)`
- `get_landmark_position(id)`
- `available_landmarks()`
- `has_surface_anchor(id)`
- `get_surface_anchor_transform(id)`
- `available_surface_anchors()`

Rig landmark origins are joint positions. They must not be treated as skin surface
positions. Surface anchors are explicit attachment points and must not be mistaken for
full surface regions.

## Initial implementation scope

The first implementation resolves common Ara rig landmarks and the existing named
surface sockets. Missing optional bones or sockets are reported as unavailable; the
runtime must not silently invent a location from a body bounding box.

The current Ara anatomy exports contain only a small set of explicit surface sockets
(ear, nose, necklace and anatomy-specific points). They do not yet contain the general
surface-region data required for robust clothing fit or combat volumes.

## Required next layer: surface regions

Author a common region vocabulary for both body bases, including at least:

- head, neck, chest, abdomen, waist, pelvis
- left/right shoulder, upper arm, elbow, forearm, wrist, hand
- left/right thigh, knee, calf, ankle, foot
- base-specific chest/breast and external anatomy regions where applicable

Regions must be derived from the evaluated/deformed body surface, not static world-space
height fractions. The data representation must preserve correspondence through Ara body
morphs and runtime modifications. A region query should provide surface samples with
position, normal and stable region identity, and should support closest-point/projection
queries for fitting.

## Required spatial volumes

Volumes should be generated or updated from the same semantic landmarks and surface
regions. They must follow animation and body modifications. The first combat set should
include head, torso, pelvis, left/right arms and left/right legs, with more detailed
regions added where gameplay needs them.

## Validation requirements

- Both canonical Ara bodies load and expose the same required semantic rig landmark IDs.
- Differences in optional anatomy-specific anchors are explicit and do not break the common
  interface.
- Landmark transforms move with animation.
- Surface anchors remain attached to their intended skin surface.
- Body morphs update surface regions and volumes; no stale pre-morph bounds.
- Extreme body presets (including Reyna and Dagna) are checked before garment fitting is
  re-enabled against this contract.
- Missing landmarks/regions fail validation rather than falling back to arbitrary
  percentages of the body bounds.

## Current implementation boundary

The first runtime layer implements rig landmarks and resolves existing surface anchors.
Surface-region segmentation, deformation-aware sampling and spatial volumes remain
explicit follow-on work; they are not claimed to be implemented by this layer.

## Surface-region proof of concept

`CharacterSurfaceRegions` is the first runtime implementation of broad surface regions.
It derives per-vertex region influence from the canonical Ara skin's existing bone weights,
then evaluates each selected vertex using the mesh's active relative blend-shape deltas,
the current `Skeleton3D` bone poses and the `Skin` inverse-bind transforms.

The first shared vocabulary is deliberately broad:

- head, neck, chest, abdomen and pelvis
- left/right shoulder, upper arm, forearm, hand, thigh, calf and foot

A region query returns character-root-local positions, normals, influence weights and
stable source vertex identifiers. It also supports nearest-sample lookup. These samples
are evaluated when queried; they are not cached in rest-pose world coordinates.

### Important limits

This is a proof of concept for rig-driven broad regions. Skin weights are useful for
limbs and large torso divisions, but they do not encode every anatomical boundary.
They cannot, by themselves, reliably separate breast tissue from the chest, underbust
from abdomen, or buttocks from pelvis. Those require explicit authorable surface labels
or region masks, which must be added without repurposing the existing skin-colour vertex
attribute.

The current query is CPU-evaluated and intended for validation and low-frequency fitting
queries, not yet as a per-frame full-mesh operation. A later pass should add caching and
a purpose-built sparse sample set after correctness and performance have been measured.

### Validation

`tests/test_character_surface_regions.gd` loads both canonical GLBs and checks that
the common broad regions return finite surface positions and normals, then verifies
that chest samples respond to a body morph and upper-arm samples respond to a changed
joint pose. The Godot CI run is the acceptance gate; no garment-fitting consumer should
depend on this proof of concept until the test passes.