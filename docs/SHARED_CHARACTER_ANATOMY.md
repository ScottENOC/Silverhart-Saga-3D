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

## Surface regions: implementation and next requirements

The first broad region layer is implemented by `CharacterSurfaceRegions` and validated against Godot's skinned-mesh bake for both canonical bodies. The next work is to extend the vocabulary with authored fine regions, not to replace the working broad rig-weight layer.

The complete region vocabulary should include:

- head, neck, chest, abdomen, waist, pelvis
- left/right shoulder, upper arm, elbow, forearm, wrist, hand
- left/right thigh, knee, calf, ankle, foot
- base-specific chest/breast and external anatomy regions where applicable

Regions must be derived from the evaluated/deformed body surface, not static world-space
height fractions. The data representation must preserve correspondence through Ara body
morphs and runtime modifications. A region query should provide surface samples with
position, normal and stable region identity, and should support closest-point/projection
queries for fitting.

### Authored fine-mask resource contract

Fine labels are stored separately from the GLB's vertex colours and skin weights in `CharacterSurfaceRegionMask` resources. A resource targets exactly one body asset, relative mesh-node path and mesh surface. It stores one `PackedFloat32Array` per semantic region, with one weight in the inclusive 0–1 range for every source vertex.

The resource records the source vertex count, surface name and a SHA-256 signature over the imported rest-pose vertex data, index data and surface name. Runtime loading rejects a mask if the body asset, mesh path, surface index/name, vertex count or signature differs. This is deliberately strict: a changed GLB export must trigger mask re-authoring rather than applying old labels to a new vertex order.

The initial fine vocabulary is `breast_left`, `breast_right`, `underbust`, `waist`, `hip_left`, `hip_right`, `buttock_left`, `buttock_right` and `groin`. A body may supply only the regions that make sense for that base. `CharacterSurfaceRegions` accepts an optional array of validated mask resources and exposes their weights through the same deformation-aware sample API as broad regions.

Runtime discovery is handled by `CharacterSurfaceRegionMaskLibrary`: when an Ara actor first requests surface regions, it scans `res://data/characters/anatomy_masks/` and loads only resources whose `body_asset_path` exactly matches the actor's loaded GLB. This keeps fine masks lazy and body-specific; unrelated actors do not load them.

The contract test uses a deliberately synthetic one-vertex mask on each canonical body to verify loading, source-vertex identity, deformation-aware querying and rejection of stale metadata. These are plumbing tests only: **no production fine anatomy masks have been authored yet**, and the synthetic test mask must not be used for garment fitting. Actual labels still need to be painted/authored against the canonical meshes, visually inspected, and checked against Reyna and Dagna.

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

The shared runtime now implements rig landmarks, existing surface anchors and a validated broad surface-region query layer. Fine anatomical masks, authored surface anchors beyond the existing sockets, and spatial volumes remain follow-on work.

## Surface-region proof of concept

`CharacterSurfaceRegions` is the first runtime implementation of broad surface regions.
It derives per-vertex region influence from the canonical Ara skin's existing bone weights,
then evaluates each selected vertex using the mesh's active blend shapes (both Godot
normalised and relative modes), the current `Skeleton3D` bone poses and the `Skin`
inverse-bind transforms.

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

### Current body-morph asymmetry

The imported female runtime body currently exposes 34 facial blend shapes but no body
shape blend shapes. Its existing runtime body-parameter path therefore falls back to
stature scaling; muscle, weight, breast and leg parameters do not currently deform that
female mesh. The male runtime body exposes six body shape blend shapes in addition to
the facial shapes. The surface query supports the available morphs on either asset, but
it cannot create missing female morph targets. This is a separate body-customisation
gap that should be addressed before claiming equivalent male/female body-shape controls.

### Validation

`tests/test_character_surface_regions.gd` loads both canonical GLBs and checks that
the common broad regions return finite surface positions and normals, then verifies
that chest samples respond to a body morph and that upper-arm samples respond to a
changed joint pose. The test explicitly binds each imported MeshInstance3D to its
Skeleton3D (important because Godot 4.6 changed the default skeleton path), checks
that a valid SkinReference is registered, and compares multiple evaluated positions
and normals against MeshInstance3D.bake_mesh_from_current_skeleton_pose() output.
The bake API ignores blend shapes, so this engine comparison is performed with morph
weights reset and a changed joint pose. The Godot CI run is the acceptance gate; no
garment-fitting consumer should depend on this proof of concept until that comparison
passes for both canonical bodies.

### Next step: fine anatomical surface masks

The broad rig-weight regions are now validated as a deformation evaluator. Do not stretch
those broad labels into fine anatomy by simply adding more bone aliases. The next layer
needs authored, per-body semantic masks (for example left/right breast, underbust, waist,
hip, buttock and groin regions) with stable mesh/surface/vertex correspondence. Masks
must remain separate from the existing female skin-colour vertex channel and must be
evaluated through the same morph-and-skin deformation path.

`tests/audit_ara_fine_surface_geometry.gd` records the current chest, abdomen and pelvis
sample bounds, centroids and normal directions for both canonical bodies. This is a
geometry-orientation audit to inform mask authoring, not an automatic anatomical
classifier and not evidence that the fine masks already exist. Extreme body presets
such as Reyna and Dagna still need to be validated after the masks and the missing female
body morph support are addressed.
