# ADR 0002: One authored settlement definition contract

- Status: accepted for incremental migration
- Date: 2026-11-21
- Scope: authored settlement data, presentation, logical placement and streaming
- Does not change: campaign axial coordinates, NPC identity/appearance ownership, simulation authority, authored feature positions

## Context

The project currently has two settlement-definition shapes with different consumers:

1. Hollowmere is composed from domain-owned GDScript resources. `presentation.gd` assembles palette, ground, building/route/bridge/agriculture/prop feature data, creature placements and vegetation inputs. Other Hollowmere modules own terrain and interior rules.
2. Campaign 2 streamed settlements are loaded from `campaign2_settlement_layouts.json`. Its records carry building footprints, paths and NPC data and are consumed by `Campaign2SettlementBuilder`.

Both routes use shared building construction, but their data contracts and orchestration paths are not yet unified. The generic `WorldSettlementPresenter` is not itself a universal settlement registry: it currently expects the richer Hollowmere presentation shape. The chunk builder is not a second world-definition authority; it is a chunk membership/presentation adapter.

A third source, `authored_settlement_terrain.json`, currently registers terrain definitions only. It must not become a competing settlement catalogue.

## Decision

Adopt one versioned settlement envelope, independent of storage format and presentation lifecycle. A settlement is authored once; JSON or GDScript modules are serialization/authoring choices, not different runtime models.

Canonical envelope (schema version 1):

```gdscript
{
  "schema_version": 1,
  "id": "stable_settlement_id",
  "name": "Display name",
  "source": "source file / source builder provenance",
  "coordinate_system": "campaign2_local_axial_qr",
  "origin": {"q": 0, "r": 0},
  "bounds": {"min_q": -96, "max_q": 96, "min_r": -96, "max_r": 96},
  "terrain": {},

  "layout": {
    "buildings": [],
    "paths": [],
    "bridges": [],
    "fields": [],
    "props": []
  },

  "placements": {
    "characters": [],
    "creatures": []
  },

  "presentation": {
    "hex_radius": 2.0,
    "ground": {},
    "palette": {},
    "vegetation": {}
  },

  "interiors": []
}
```

The envelope is deliberately domain-oriented:

- `terrain` describes local logical terrain rules and authored terrain precedence. The regional/world terrain system remains responsible for regional rules.
- `layout` describes stable authored world features and their local axial anchors. Feature records retain stable IDs and source provenance where available.
- `placements` describes *where* actors start, using character/profile IDs and axial positions. It does not define character identity, appearance, class progression, equipment, dialogue or schedules. Those remain owned by character/campaign data.
- `presentation` supplies optional visual settings and deterministic ecology inputs. It does not own logical navigation, occupancy, doors, quest state or persistence.
- `interiors` references authored interior definitions; interior gameplay state remains registered through the existing logical building/interior systems.

Fields that do not apply to a settlement may be empty or omitted where the validator explicitly permits it. A missing optional visual layer must not make a valid logical settlement unusable. Required identity, coordinate frame, origin and schema version may never be inferred from the settlement name or a scene script.

## Runtime responsibilities

There is one definition provider/registry and one validated in-memory contract.

- The provider loads the settlement catalogue, validates stable IDs, coordinate frame, bounds, references and duplicate IDs, then returns canonical definitions.
- Feature factories consume canonical feature records. They do not load settlement files or branch on settlement IDs.
- A shared settlement composition service selects feature presenters from the definition. It does not invent or mutate authored content.
- A streaming presenter asks the provider for features intersecting its chunk and creates/disposes presentation nodes. Chunk boundaries are lifecycle/performance boundaries only.
- The campaign root selects the active world and simulation. It does not construct settlement features.
- Terrain, building/interior registration, NPC schedules, quests, occupancy and saves remain authoritative outside disposable presentation nodes.

The full-settlement preview and streamed campaign must call the same feature factories with the same canonical feature records. They may differ in *when* and *which subset* they present, never in how a building, road or bridge is defined. `WorldSettlementFeatureComposer` is the shared feature-construction path for both full-location and streamed settlement presentation. Point-anchored features have one owning chunk, while multi-chunk axial routes are split into chunk-local presentation fragments. These fragments are disposable and retain the authored route identity as their prefix; they do not become new logical roads.

The Campaign 2 regional preview now presents Hollowmere through the canonical chunk builder rather than instantiating the full-location presenter. Its regional terrain cells provide the ground surface; the builder composes authored buildings, routes, bridges, agriculture and props, generates deterministic authored vegetation only for candidate cells owned by the current chunk, and spawns authored creature actors in their owning chunks. Vegetation sampling remains aligned to the same zero-anchored axial lattice as the former location-wide generator, so changing chunk boundaries does not change candidate positions. The preview's `WorldSimulation` outlives disposable chunk nodes. When a creature actor is recreated, the builder resolves its stable animal ID and restores its current simulation hex; a moved animal is therefore not respawned at its original authored location. The opening campaign `WorldRoot` still uses the full-location `WorldSettlementPresenter` and its animal registration path; migrating that gameplay scene to the chunk lifecycle remains a separate integration step, so the regional preview is not yet proof that all campaign runtime presentation is streamed.

## Migration sequence

1. Add the canonical schema and validator without changing current runtime behaviour.
2. Add read-only adapters for the existing Hollowmere GDScript modules and Campaign 2 JSON layout. Both adapters must produce equivalent canonical envelope sections and preserve every authored coordinate.
3. Add parity tests against the existing source records: stable IDs, building footprints/doors, road endpoints, NPC placement references, terrain bounds, vegetation parameters and interior references.
4. Move consumers to the canonical provider: terrain queries, full-settlement presentation, chunk presentation and logical registration. Consumers must stop loading source files independently.
5. Move Campaign 2 NPC identity/appearance/equipment out of layout records through the separate character-data migration. Do not duplicate that migration here; settlement placements retain only character IDs and positions.
6. Once all consumers use the provider, remove legacy format adapters and the terrain-only settlement catalogue. Keep domain-specific authoring modules where they provide useful ownership boundaries, but they must compose into the one canonical envelope.
7. Consolidate full-settlement and streamed presentation on the same composition service. The shared `WorldSettlementFeatureComposer` dispatches canonical buildings, routes, bridges, agricultural features and prop assemblies to the existing shared factories. `Campaign2SettlementBuilder` now owns Hollowmere's authored vegetation and creature presentation per chunk in the regional preview; simulation state remains outside disposable actor nodes. Migrate the opening campaign `WorldRoot` from the full-location presenter to this same chunk lifecycle before declaring the gameplay world fully streamed.

## Invariants and acceptance criteria

- A settlement ID is globally unique within the campaign catalogue.
- All authored local axial coordinates use an explicitly declared coordinate frame and one explicit origin transform.
- The same source definition produces the same canonical record regardless of whether it was authored in JSON or GDScript.
- No feature factory, global terrain adapter, campaign root or streamer contains settlement-ID-specific construction branches.
- No second authoritative settlement catalogue survives after migration.
- Full preview and chunk streaming render the same authored building/road/bridge/prop definitions.
- Moving a feature across a chunk boundary changes only which chunk presents it, not its identity, position, logical state or appearance.
- Unloading presentation never removes simulation state or authored data.
- Character identity, appearance, progression and equipment are not owned by settlement layout.
- Adding a settlement requires authored data and, where needed, a reusable feature definition—not a new settlement-specific runtime script.
- Existing Hollowmere and Millbrook positions, building geometry metadata, path endpoints, entrances, interiors, quest hooks and gameplay remain unchanged.

## Explicit non-goals

- No new settlement or bulk NPC content.
- No coordinate rebasing or strategic-map redesign.
- No replacement of the current terrain/streaming systems in one step.
- No visual redesign of Hollowmere.
- No merging this work to `dev` as part of the migration.
