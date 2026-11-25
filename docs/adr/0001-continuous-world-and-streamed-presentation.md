# ADR: Continuous world, modular authored data, streamed presentation

**Status:** Accepted  
**Date:** 2026-11-20  
**Applies to:** Silverhart Saga 3D, all campaign regions and settlements

## Decision

Silverhart Saga is one continuous logical world. It is not a collection of settlement-sized worlds stitched together at runtime.

The project will use:

1. **One authoritative world-coordinate system** for geography, navigation, ownership, feature placement and simulation.
2. **Modular authored data** organised by world, region and settlement domains.
3. **Shared runtime systems** that load, validate, resolve, simulate and render those definitions.
4. **Chunk-based presentation streaming** as a performance mechanism only.

A chunk is not a level, a simulation boundary, a coordinate origin, or an owner of persistent world state. Loading and unloading chunks must not change the logical world.

## Coordinate and geography authority

- The world coordinate frame and its grid/metric conversion rules are global authorities. Existing canonical axial/world conversion utilities remain the authority; feature data must not invent competing conversions.
- Regional geography is authored in that world frame, or in a documented regional frame with an explicit, validated transform to the world frame. A regional transform is data, not an implicit offset hidden in a scene script.
- Terrain, elevation, hydrology, major landforms, regional roads, biome distribution and political/geographic boundaries belong to world or regional data.
- Settlement data references its position and region in the world. Its local coordinates are allowed as an authoring convenience only when an explicit transform maps them into the canonical world frame.
- Settlement definitions add local detail: buildings, entrances, local paths, landmarks, fields, local placements and settlement-specific overrides. They do not redefine the surrounding terrain, river course, regional road network or world origin.
- Features crossing region, settlement or chunk boundaries must be represented and resolved continuously. No boundary may truncate a river, road, forest, trail or other world feature.

## Data ownership and layout

The intended organisation is domain-oriented, not one giant file per settlement and not one giant global manifest.

```text
data/
  world/
    world_definition
    coordinate_system
    regions/
      <region_id>/
        region_definition
        geography
        elevation
        hydrology
        roads
        biomes
  settlements/
    <settlement_id>/
      settlement_definition
      buildings
      local_roads_and_paths
      agriculture
      landmarks_and_props
      authored_placements
  runtime/
    # Persistent campaign state is stored separately from authored definitions.
```

The exact resource format and file granularity should follow Godot's existing loading, validation and editing needs. Do not create a file for every trivial object merely to satisfy this layout. Split data by coherent ownership and change lifecycle.

Every authored record should have a stable ID. Cross-file references must be validated. Where source content is migrated, retain source provenance. A settlement's identity and world position are distinct from the data files that describe its individual features.

## Shared runtime responsibilities

- A world data provider loads manifests, resolves region/settlement references, applies authored-feature precedence and answers world-coordinate queries.
- Shared feature factories turn validated definitions into disposable presentation nodes. Factories must not contain settlement-ID branches or mutate campaign simulation as a rendering side effect.
- Logical systems own navigation, occupancy, building identity, doors, ownership, schedules, quests and persistent state.
- Procedural systems fill only unspecified space. Authored geography and named features take precedence over procedural terrain and placement.
- Deterministic generation is based on stable world coordinates, stable IDs and explicit seeds/versioning, not on chunk load order.

## Streaming contract

- Streaming queries the continuous world using world-space bounds/coordinates.
- Chunk origins are derived from the global coordinate system. They do not reset feature coordinates or random seeds.
- Features spanning chunks must be clipped, partitioned or represented through shared feature identity so adjacent chunks render without gaps or duplication.
- A streamed presentation object may be destroyed and recreated. Its authoritative logical state must survive independently.
- Chunk unload/reload order must not affect navigation, simulation, save data, ownership or deterministic placement.
- Neighbouring chunks must agree at their shared edges for terrain, elevation, roads, water, vegetation rules and other continuous features.

## Authored definitions versus runtime state

Authored data describes the initial/design state: for example, a shop's location, footprint, entrance and visual archetype.

Runtime state describes what has happened: for example, its owner, inventory, open/closed state, damage or destruction. Runtime state is keyed by stable world/entity IDs and persisted separately. A presentation reload must reconstruct the current state from the authored definition plus saved/runtime state; it must not reset the world to the authored starting condition.

## Migration rules

1. Preserve existing authoritative world coordinates and geography. Do not move or locally re-origin content merely to make a settlement scene convenient.
2. Audit current manifests, transforms, terrain providers and streamers before introducing new abstractions. Reuse existing authorities where sound; consolidate only when duplicate responsibilities are demonstrated.
3. Migrate settlement content by coherent data domains (buildings, paths, agriculture, props, placements), with shared validation and factories.
4. Keep settlement scripts as thin composition/orchestration adapters during migration; do not replace one god file with a different god file or a circular collection of data scripts.
5. Move regional biome and geography rules to regional/world ownership. Settlement-specific ecological exceptions may be explicit local overrides, not the authority for the region.
6. Keep the logical movement/navigation graph independent of visual route meshes.
7. Do not merge or remove existing streamers until their actual call sites, state ownership and coverage are mapped and equivalence tests exist.
8. Add cross-boundary and unload/reload tests before expanding the world substantially.

## Required acceptance tests

- A world coordinate resolves to the same geography and logical location regardless of which chunk is loaded.
- A settlement's authored local detail resolves to the same world coordinates through its explicit transform.
- Roads, rivers, terrain and other continuous features remain connected across chunk and region boundaries.
- Procedural generation is stable across different chunk load orders and reloads.
- Authored features take precedence over procedural placement.
- Unloading/reloading presentation does not reset simulation state or saved changes.
- Adding a settlement requires data and reusable systems, not edits to another settlement's script or a shared factory.
- Two adjacent regions agree on their shared boundary without duplicated or missing geometry.

## Consequences

This decision deliberately separates *how the world is authored* from *how much of it is currently rendered*. It supports a much larger map while preserving one coherent geography and simulation. It also means future settlement migration must first identify the relevant regional/world authority rather than treating each existing village script as a self-contained source of truth.
