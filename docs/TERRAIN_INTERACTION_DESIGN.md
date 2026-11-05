# Terrain interaction design

## Goals and authority

The terrain is a continuous 3D height field. The hex grid remains the authority for discrete gameplay decisions: occupancy, movement steps, construction footprints and map-scale interaction. The rendered mesh and its collision surface are derived from the same height samples; they must never become independent terrain representations.

This avoids two competing worlds: a visually continuous landscape with characters moving on a flat invisible board, or a landscape made of visibly disconnected hex prisms.

## Geometry and collision

- Build the visual triangle mesh from cell centres and globally shared corner samples.
- Build the terrain collision shape from that exact committed mesh using Mesh.create_trimesh_shape() on a StaticBody3D. Do not independently approximate the collision surface.
- Keep grid-edge overlays non-colliding.
- Rebuild visual mesh and collision together after terrain edits. For large maps, replace whole-map rebuilds with chunked updates; adjacent chunks must share boundary samples.
- Use static concave collision for the landscape. Characters, movable objects and physics props use their own simple collision shapes.

The current renderer now creates this matching static collision mesh. It is a foundation for physics queries, not yet a complete navigation or interaction implementation.

## Character grounding and movement

1. Resolve the destination hex using the logical grid.
2. Check occupancy, walkability and movement rules before moving.
3. Query the terrain surface at the destination (raycast down against the terrain collision layer, or sample the same height field if the caller already has a reliable map-space coordinate).
4. Place the character's ground-contact point at the hit height, then apply the character's animation/root offset.
5. Keep the logical axial coordinate as the saved position. Reconstruct world position from the grid coordinate and current terrain surface when loading.

Do not use a global y=0 plane for picking or character placement once the renderer is integrated. Mouse/touch picking should raycast against the terrain collision surface, then convert the hit XZ position to axial coordinates. Reject hits outside the authored map.

## Edge profiles and slope access

Cell-centre grade is useful as a broad movement-cost signal but is insufficient for sharp ridges, ledges and escarpments. The next movement refinement should classify the shared edge between adjacent hexes:

- Sample the two shared edge endpoints and both cell centres.
- Compare the highest/lowest points along the crossing profile, not just centre-to-centre elevation.
- Distinguish a traversable slope, a climbable face and a non-traversable cliff.
- A narrow ledge must not become traversable merely because the two cell centres happen to be at similar heights.
- A climb skill can permit a face crossing, but should not erase the physical height profile or allow movement through an overhang.

Keep these classifications in TerrainElevationRules; the renderer should not decide gameplay access. Add tests for a sharp ridge shared by otherwise level cells, a one-sided ledge, a gentle ramp and a climbable face before tuning thresholds.

## Line of sight and cover

Use a 3D ray between attack origin and target sample points:

- The source point is character eye/weapon height, not ground level.
- The target point is a defined target-body sample (initially torso centre; later multiple samples for partial cover).
- Terrain collision blocks the ray when it intersects before the target.
- Walls, buildings, trees and large props use separate blocker collision layers so the combat query can distinguish terrain occlusion from cover.
- Cover should be a separate result from hard obstruction. A low wall may provide cover without making every target behind it completely invisible.
- For large creatures or multi-cell targets, test several target samples and define the required visible fraction.

The first implementation should be deterministic and single-ray. Multi-sample partial cover can follow once basic ranged combat exists.

## Falls and vertical traversal

Do not infer fall damage from the movement multiplier. A fall occurs when a character loses support or is forced over an edge, not when they walk up a steep but climbable slope.

When falling is implemented:
- detect unsupported movement or a forced displacement over an edge;
- calculate vertical drop from the departure support surface to the landing surface;
- resolve collision/landing before applying fall effects;
- keep the fall event separate from ordinary movement TP costs.

## Build order

1. Matching render/collision mesh (implemented in the prototype renderer).
2. Terrain ray picking and surface-aware character grounding.
3. Edge-profile slope classification and regression tests.
4. Terrain occlusion for line of sight.
5. Cover layers and partial-cover sampling.
6. Falls, water flow and earthworks as separate systems.

## Current limitations

The collision body currently supports physics queries against the prototype surface, but the game does not yet use it for mouse picking, character grounding, LOS, cover or falls. The prototype remains isolated from Hollow Tankard.
