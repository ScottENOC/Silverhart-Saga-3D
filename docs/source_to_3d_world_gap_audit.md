# Source-to-3D world gap audit — pass 1

**Compared:** original `Hex-crpg/main` Campaign 2 source against current `Silverhart-Saga-3D/dev` world data.  
**Purpose:** identify what must change before the 3D project can claim a faithful multi-chunk world.  
**Rule:** source-authored content wins. Existing 3D content is retained only where it matches the source or is explicitly recorded as a deliberate 3D adaptation.

## 1. Critical scale gap: current village bounds cannot hold the opening region

The original source roads extend far beyond the current 3D village blockout:

- Hollowmere crossroads: (8,24).
- Millbrook is captured at north-road iteration 390.
- Silverhart is at north-road iteration 520.
- Old Mac's Farmstead is at the south-road endpoint, iteration 170.
- Reddale is at east-road iteration 130.
- Emberlode is at west-road iteration 260.
- The east border road continues to iteration 390, with the goblin camp at 195 and Northwatch turn at 260.

The current `HollowmereVillageData.MAP_RADIUS` is 96 and its farmstead is at (12,54). This is a local prototype bound, not the full source opening region. The original north/south/east/west road network spans several hundred local hexes. The 3D world must therefore stream chunks over a shared global axial coordinate space; it must not stretch the village blockout or create separate disconnected maps.

### Deterministic waypoint calculation

The source `paintRoad` algorithm was ported into a reference calculation using the same primary steps, `sin(i * 0.37)` wiggle gate, `sin(i * 1.7)` lateral direction and ±2 lateral drift bound. This trace is useful for broad directions, waypoint order and approximate distances, but individual wiggle cells are not required in the 3D world.

| Feature | Source-derived local axial coordinate |
|---|---:|
| Crossroads | (8,24) |
| Abandoned house waypoint | (8,-176) |
| Millbrook waypoint | (7,-366) |
| Silverhart north-road endpoint | (8,-496) |
| Old Mac south-road endpoint | (6,194) |
| Old Mac farmhouse centre (road endpoint q - 6) | (0,194) |
| Reddale east-road endpoint | (138,24) |
| Skarn-tooth goblin camp waypoint | (203,23) |
| Northwatch turn waypoint | (268,22) |
| Ridgehold / orc stronghold east-road endpoint | (398,23) |
| Emberlode centre (west endpoint q - 4) | (-256,22) |
| Kragmoor anchor | (908,-626) |
| Sil'thandriel anchor | (-252,934) |

These coordinates are source-derived reference anchors. Millbrook's road endpoint is q7/r-366, while its settlement/house centre is q1/r-366 and its door is q4/r-366. Use route waypoints and approximate distances to validate relative geography; do not make the exact generated polyline a canonical 3D requirement.

## 2. Hollowmere footprint discrepancies

The existing 3D village data currently approximates several original building footprints. The centres generally match, but the half-extents are not all source-exact.

| Building | Original Campaign 2 source | Current 3D data | Audit |
|---|---|---|---|
| General store | centre (0,18), halfW=4, halfH=3 | half_q=3, half_r=2 | **Mismatch** |
| Chapel | centre (-14,0), halfW=3, halfH=3 | half_q=2, half_r=3 | **Mismatch** |
| Elder's house | centre (0,-12), halfW=3, halfH=2 | half_q=2, half_r=2 | **Mismatch** |
| Mira's house | centre (12,9), halfW=2, halfH=2 | half_q=2, half_r=2 | Centre/extents match; door and axial row-shift must still be checked |
| Oskar's house | centre (-6,9), halfW=2, halfH=2 | half_q=2, half_r=2 | Centre/extents match; door and axial row-shift must still be checked |
| Hollow Tankard | row-shifted floor q=-5..5, r=-3..3; wall adjacency ring; door (0,4) | Existing 3D tavern blockout | Compare exact walkable floor, wall ring, entrance and internal furniture |

The source uses both `carveBuilding` and `carveFlatRoom`; their row-shift and wall-ring rules help identify room function and access. The 3D adaptation may use a different footprint and mesh construction, provided entrances, usable rooms, important objects and gameplay access remain equivalent.

## 3. Farmstead content discrepancy

Original `buildFarmstead()` creates:

- One farmhouse at the south-road endpoint offset by q=-6.
- A fenced pasture west of the farmhouse, with a deliberately broken fence section.
- A blood-spatter trail fading toward a wolf den outside ordinary pasture vision.
- Two sheep.
- Old Mac inside the farmhouse.
- A world-map farmstead marker.

The current 3D village data places the farmhouse at (12,54) and includes a barn at (22,51), with a farmyard route. The farmhouse position does not match the source-derived centre (0,194), and the barn is not part of the inspected original `buildFarmstead()` implementation. Treat the current barn as an unverified addition: do not silently preserve it as original content. It can remain only if a separate source location or a clearly documented 3D adaptation justifies it.

## 4. Stream and terrain discrepancies

Original local stream generation:

- Initial straight span q=-20..28 at r=-25.
- Eastward extension in three chained segments to q=220, with deterministic lateral drift and changing width.
- Westward extension from q=-21 to q=-90.
- Road painting later overwrites the crossing cells to form the bridge deck.

Current `HollowmereVillageData` models a short interpolated stream from q=-30..30 and bounds the local map to radius 96. The stream should preserve the source's broad direction, continuity and relationship to the village/bridge, but its precise bend and width may be redesigned in 3D. The bridge must remain a usable crossing and connect the village road network.

Original forest is deterministic 4×4 clump-based placement over the starting region, not unrestricted per-cell random trees. Recreate the source's clump/hash rules or extract the resulting terrain and foliage seed data.

## 5. Strategic map parity

The current 3D strategic map follows the source's 16×16 regional structure and first-pass location anchors. Validate the broad faction territories, coastline, river course, mountain range, forest belt and relative placement of landmarks against `worldMap.js`; a cell-by-cell copy of incidental terrain is not part of the target.

## 6. Immediate corrective work order

1. Build a source-side deterministic extraction harness for Campaign 2 that emits JSON for the actual post-bootstrap state: terrain overrides, tile objects, road graph, building regions/floors, NPC specs/positions, world-map grid and markers.
2. Run it on a fresh human Campaign 2 start and on goblin/orc starts where the source has distinct world setup.
3. Compare that export with current 3D resources and produce a machine-readable mismatch report.
4. Reconcile meaningful Hollowmere building/stream/farmstead placement against the source. Redesign local 3D footprints where useful, but correct major relative-position mismatches such as the farmstead being too close to the village.
5. Implement a global axial world data provider and chunk streamer that reads authored source data first. Procedural wilderness may fill only explicitly un-authored cells and must be deterministic.
6. Add tests for source waypoint anchors, route connectivity, major regional biomes, building access/functional rooms, NPC anchors and chunk-boundary persistence.

## 7. Current conclusion

The existing 3D project has a good playable Hollowmere foundation and a strategic-map skeleton, but the world data is still a compact prototype approximation. It is not yet the original Campaign 2 world at full scale. The most important next deliverable is the source-side JSON extraction and automated diff; that will turn the 99% target into measurable parity rather than visual guesswork.
