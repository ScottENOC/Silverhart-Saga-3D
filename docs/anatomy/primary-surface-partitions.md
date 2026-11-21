# Primary surface partitions

## Two different kinds of anatomy data

The project has two intentionally different representations:

- `CharacterSurfaceRegionPartition` is the **primary ownership map**. Each source vertex has exactly one region index. It must cover the entire target surface, and each declared primary region must be one connected component.
- `CharacterSurfaceRegionMask` is a set of **secondary feature channels**. Its independent weights may overlap. Breast tissue, sternum, pectoral features, clavicle landmarks and garment-relevant landmarks belong here when they are descriptive features rather than mutually exclusive skin ownership.

Do not turn every anatomical feature into a primary region. Doing so would force legitimate overlaps into artificial holes or splits.

## Partition invariants

A completed partition is valid only when:

1. Its mesh node path, surface name, vertex count and topology signature match the exact source surface.
2. The assignment array has exactly one integer per source vertex.
3. Every integer refers to one declared primary region. There is no unassigned sentinel and no second assignment slot.
4. Every declared region owns at least one vertex.
5. Each primary region is connected in the source triangle adjacency graph.
6. The source is a valid indexed triangle surface.

Because a vertex stores one integer rather than a list of region weights, primary overlap is impossible by construction. Because connected components are checked against triangle adjacency, accidental islands are rejected. Coverage is checked before connectivity, so a gap cannot be mistaken for a valid boundary.

## Boundaries

A boundary is authored once between adjacent primary regions, not as two independent outlines. The shared boundary can be represented by the transition between their labels on the triangle mesh. Any renderer or garment tool should derive both sides from that same transition.

A triangle can touch two or three primary labels at a legitimate junction. Do not force those junctions into duplicate masks. Secondary feature channels can cross the primary boundary without changing ownership.

## Authoring sequence for Wren

1. Review the native Wren `Skin_Anatomy` surface and agree on a manageable primary torso partition taxonomy.
2. Trace boundaries on the actual surface and assign the primary labels.
3. Run the partition validator and inspect coloured front, side and rear renders plus boundary-junction diagnostics.
4. Correct any disconnected islands, missing coverage or anatomically implausible adjacency.
5. Only then author secondary breast/sternum/underbust feature channels and bra guide curves.

The current Wren ellipsoid proposal is a spatial hypothesis only. It is not a primary partition, it is not production anatomy data, and it must not be promoted automatically. No Wren primary partition or bra garment should be generated from those ellipsoid guesses.

## Validation implementation

`scripts/characters/character_surface_region_partition.gd` contains the reusable exact-surface contract and topology checks. `tools/review/test_character_surface_region_partition.gd` exercises complete coverage, missing assignments, disconnected regions, duplicate IDs, assignment cardinality and empty regions in CI.
