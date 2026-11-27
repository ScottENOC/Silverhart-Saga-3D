# Campaign 2 map gap audit — what is still missing

**Reference:** `ScottENOC/Hex-crpg` Campaign 2 source  
**Target:** `ScottENOC/Silverhart-Saga-3D`, `dev`  
**Scope:** Geography, terrain, routes, settlement/site footprints, buildings, entrances, interiors as spatial layouts, map-owned physical objects, and their rendering/traversability.

This document is deliberately a **map audit only**. It does not track whether an NPC has been authored, whether dialogue or a quest has been ported, whether an encounter behaves correctly, or whether a faction/simulation system is complete. Those belong in the campaign-content and mechanics records linked below.

## Related audits — do not duplicate their work

The following documents are the source of truth for the excluded work:

- [Campaign source-port status](CAMPAIGN_SOURCE_PORT_STATUS.md) — NPC identity/persistence, dialogue and quest port status, companion relationships and reactivity, schedules, banter and world agency.
- [Campaign 2 NPC and dialogue index](campaign2_npc_dialogue_index.md) — source display names, dialogue IDs and first-pass quest-ID inventory. This is an extraction index, not proof that each branch is migrated.
- [Chief Skarnub dialogue and trust port](skarnub_campaign_dialogue_port.md) — Skarn-tooth content, chief dialogue, favour choices and remaining campaign-runtime wiring.
- [Mechanics port register](MECHANICS_PORT_REGISTER.md) — shared mechanics and behavioural parity, including combat, movement, campaign simulation and other non-map systems.
- [Campaign 2 source inventory](campaign2_source_inventory.md) and [original 2D source audit](original_2d_campaign2_source_audit.md) — source-side inventories and extraction context.

**Boundary rule:** a map item may record the authored location/anchor for an NPC, creature, journal, quest object or encounter trigger. Its dialogue, quest effects, AI, spawning lifecycle and persistence are not map-audit items. If a map task depends on one of those systems, record only the spatial dependency here and link to the owning campaign audit.

## Audit rules

- Preserve meaningful authored geography, broad biome/terrain regions, navigable routes, settlement footprints, landmarks, building placement, entrances, floor layouts and gameplay-significant physical objects.
- Do not count random tree/rock placement, exact procedural road wiggles, or equivalent decorative substitutions as gaps when the same broad terrain or navigable route is represented.
- A macro-map marker, data record, or passing geometry test is not proof that a site is correctly rendered or traversable. Distinguish data present, rendered, connected, and playable spatially.
- Status labels describe missing spatial content only: **Missing**, **Partial**, **Ported**, or **Adapted**. Engine verification and visual QA are universal quality gates, not map-port backlog items.

## Executive finding

The 3D project has ported a substantial amount of the distinctive Campaign 2 world: its strategic geography, settlement footprints, named sites, fortifications, major routes and waterways, many source-authored interiors, and multi-level cave/dungeon structures.

The previous 4,732 / 16,566 comparison is **not a completion ratio**. The numerator counts a limited target-side JSON exterior-cell inventory; the denominator counts all source runtime terrain cells, including the broad base terrain pass. The target count also omits regional GDScript features. Dividing them produces a misleading 25%-style figure and must stop.

The revised unit of work is a meaningful spatial feature, not a terrain cell. Generic ground fill, terrain noise and decorative vegetation/rock distribution are systems. They are not thousands of unported source objects.

The actual remaining map-content work is concentrated in:
1. Kragmoor's distinctive surface mountain/settlement footprint, approach and entrance.
2. Exterior/interior entrance and return contracts for existing floor maps.
3. The remaining source-named Silverhart palace rooms/floors.
4. Reusable spatial prefabs for dynamic cottage/field construction where source features are not represented.
5. Semantic reconciliation of meaningful physical map objects (doors, stairs, journals, evidence, ore, siege objects and signs).

See [the feature-level port register](campaign2_feature_port_register.md) for the source-builder-by-source-builder reconciliation. Visual inspection, Godot execution and routine verification are not counted as outstanding map content.

## 1. Location-by-location map gaps

| Area | Status | Map work still required |
|---|---|---|
| **Kragmoor / Deepholds** | **Partial — highest priority** | Six floor maps, stair transitions and a deterministic relief profile exist. The distinctive surface mountain/settlement footprint, source landmarks, approach and entrance still need to be completed; underground floors do not substitute for the exterior kingdom. |
| **Silverhart** | **Partial** | The city layout is substantially represented: 40 buildings, 33 routes and 512 prop records cover the major districts, walls, gates and landmarks. Remaining map content is the source-named palace room/floor remainder and any missing entrance/return contracts; do not reopen the already registered city footprint as a generic verification task. |
| **Sil'thandriel / Sylvan Court** | **Ported** | Three-level tree/canopy/court maps, platforms, trunk/branches, rope bridge, archive/healer platforms and stair transitions are registered. No distinct missing major spatial feature is currently identified. |
| **Skarnak's Hold** | **Ported** | Warlord hut, seven surrounding huts, campfire, perimeter/gate terrain and road approach are represented at the source-derived anchor. No separate authored-geometry backlog is currently identified. |
| **Skarn-tooth Camp** | **Ported** | Source-authored chief's hut, five surrounding huts, campfire and road endpoint are represented. No known authored-geometry gap remains. |
| **Northwatch Fort** | **Ported** | Star fort, keep, gate, moat/waterway, siege engine, distant catapult, oil barrels, ladders and hearth are represented. No known missing named fort feature remains. |
| **Ridgehold Fort** | **Ported** | Fort walls, keep, downstream waterway and hearth are represented. No known missing named fort feature remains. |
| **Emberlode and Emberlode Mine** | **Partial** | Buildings, mine entrance/approaches, floor maps, stairs, ledger and ore-node anchors exist. Remaining map work is the exterior/interior and surface/mine entrance-return coordinate contract. |
| **Reddale** | **Partial** | Six building footprints/interior floor maps, roads and the eastern spider-ruin site exist. Remaining map work is the missing exterior/interior entrance-return contracts. |
| **Hollowmere** | **Partial** | Authored village, stream, bridge, roads, building footprints and floor maps exist. Remaining map work is missing entrance-return contracts and any unplaced source physical object such as the Elder Locket; its interaction belongs in campaign content. |
| **Millbrook** | **Partial** | House, road spur and floor map exist. Remaining map work is its exterior/interior entrance-return contract. |
| **Old Mac's Farmstead** | **Partial** | Farmhouse, pasture, fence/broken-fence clue, evidence anchors and interior floor exist. Remaining map work is the farmhouse entrance-return contract. Livestock appearance substitutions are not a map gap. |
| **Abandoned House and northern crypt/barrow chain** | **Partial** | Floor maps and spatial evidence anchors exist. Remaining map work is any missing entrance-return contract or source-authored passage coordinate, not new room generation. |
| **Lich Chapterhouse** | **Partial** | Single-floor stone footprint, entrance and fireplace placement exist. Remaining map work is its entrance-return contract. |
| **Thieves' Cove** | **Partial** | Three-level cave network, entrances, reciprocal stairs and evidence-object anchors exist. Remaining map work is any missing spatial entrance/return contract; the cave topology itself is represented. |
| **Vampire Grave** | **Ported** | Disturbed grave, carcass, fang and journal positions are represented. Investigation and encounter logic are tracked elsewhere. |
| **Old Mac's Wolf Den** | **Ported** | Source-derived anchor and cave-mouth/overhang/bone dressing exist. Wolf spawning and quest behaviour are out of scope here. |
| **Unicorn Vale** | **Ported** | Vale centre, eight patrol waypoints and hoofprint markers are represented. Live unicorn AI is out of scope. |
| **Ashveil's Dragon Lair** | **Ported** | Rocky outcrop and cave-den dressing exist. Dragon actor and encounter behaviour are out of scope. |
| **Emberwood Grove** | **Ported** | Clearing, foliage perimeter, spring rim and herb-patch features exist. Gathering and quest consequences are out of scope. |
| **Player cottage / field** | **Partial** | Plot marker/approach, field and fence geometry exist. Remaining map work is reusable spatial prefabs for source-authored cottage/upgrade variants and player-placed field objects where absent. The source does not author crop rows. |

## 2. Cross-cutting map gaps

1. **Kragmoor surface geography.** Complete the source-distinctive mountain/settlement silhouette, landmarks, approach and entrance. The existing floor maps and recent relief profile are not a substitute for the exterior site.
2. **Exterior/interior spatial transitions.** Complete the finite coordinate contract for existing interiors: exterior threshold, destination floor ID, interior door cell and return anchor. The map audit owns those spatial coordinates; campaign code owns lock state and interaction permissions.
3. **Meaningful physical-object placement.** Reconcile source map-owned objects such as journals, ledgers, evidence, altars, ore, stairs, doors, ladders, siege equipment and signs. Decorative prop counts are not a substitute for semantic coverage.
4. **Dynamic cottage/field construction.** Represent source-authored cottage/upgrade footprints and player-placed field objects where no equivalent reusable spatial prefab exists. The source defines no crop rows; zero crop rows is not a gap.
5. **Concrete route or water defects only.** A demonstrated missing bridge, ford, road connection, stream segment, gate aperture or chunk-owned feature join is a discrete task. Generic connectivity checks and visual review are not backlog items.

## 3. Source-builder cross-check — feature-level register

The source runtime extractor resolves the original builders and their terrain writes, but a builder's cell count is not a list of tasks. The source-to-target feature mapping and actual remaining work are recorded in [Campaign 2 feature-level map port register](campaign2_feature_port_register.md).

That register treats `setupVillageScene` as a base-terrain system; groups roads and water by meaningful route; and tracks settlements, forts, capitals, interiors, caves, landmarks, construction features and physical map objects as named spatial features. It explicitly excludes random decoration and generic terrain fill from the backlog.



## 4. Inventory counts and cautions

The existing source/target counts are diagnostic only:

- Source runtime: 16,566 unique terrain cells, of which 5,242 are touched only by the broad `setupVillageScene` base pass; named feature-builder footprints overlap.
- Target JSON-backed exterior inventory: 4,732 unique cells, excluding regional GDScript features and other map-owned systems.
- Target interior registry: 71 location records / 89 floors; source runtime reports 72 interior regions. These are different data models and not directly comparable.
- Source physical tile objects: 246 placements. Target JSON reports 520 prop records across 508 anchors, plus floor-local and feature-specific objects. Raw counts do not establish semantic parity.

**Do not divide 4,732 by 16,566 or publish the result as map completion.** The counts have different scope and represent different things. The feature-level register is the backlog source of truth; no overall percentage is published until all meaningful source spatial features have explicit matching rules.

## 5. Definition of done

A source spatial feature is considered ported when:
1. Its source purpose and meaningful footprint are identified.
2. The target has an equivalent spatial feature or a documented 3D adaptation.
3. Its map-owned physical components (where applicable) are represented.
4. Any known missing entrance, return point, stair, route or named connection is recorded as a concrete task.

Godot execution, visual inspection and routine validation remain important QA for every change, but they are not separate outstanding map-port tasks. NPC dialogue, quest branches, encounter AI, faction effects, schedules and campaign persistence remain in their owning campaign/mechanics audits.

## 6. Historical audit notes

Earlier audit snapshots recorded implementation checks and open verification items. Those notes are retained in Git history, but they are not current map-port tasks. The current source-to-target content backlog is defined exclusively by [the feature-level port register](campaign2_feature_port_register.md). In particular, old "verify in engine", "visual acceptance" and routine test-coverage entries are QA activities, not missing map content.

## 7. Revised priority order

1. **Kragmoor surface geography** — finish the actual exterior mountain/settlement silhouette, source landmarks, approach and entrance.
2. **Exterior/interior spatial contracts** — close the finite set of missing entrance, destination-floor and return-anchor definitions for existing locations.
3. **Silverhart interior remainder** — reconcile source-named palace rooms/floors against the existing 40-building, 33-route city implementation.
4. **Dynamic cottage/field spatial prefabs** — add only missing buildable structures and player-placed field-object variants.
5. **Meaningful physical-object crosswalk** — reconcile source doors, stairs, ladders, journals, ledgers, evidence, altars, ore, siege objects and signs.

A concrete missing road, stream, bridge, gate or chunk-join feature can be added when identified. Generic "verify connectivity", "inspect in engine" and procedural decoration are not backlog items.

## 8. Small-to-large execution approach

| Order | Task | Size | Why it is actual map work |
|---|---|---|---|
| 1 | Complete Kragmoor surface footprint, named landmarks, approach and entrance | L | Six underground floors exist; the distinctive surface kingdom footprint is still incomplete. |
| 2 | Finish missing entrance/return contracts for existing single-floor locations | M | The spatial coordinate contract is missing for a finite set of existing interiors; this does not require inventing new rooms. |
| 3 | Reconcile remaining Silverhart palace rooms/floors | M–L | The city footprint is substantially present; the remaining work is specific interior content, not rebuilding the city grid. |
| 4 | Add missing cottage/field construction prefabs | M | Only source-authored dynamic spatial variants not already represented are in scope. |
| 5 | Reconcile meaningful physical map objects | M | Compare semantic object types and placements, not raw prop counts or decorative clutter. |

Routine Godot verification and visual QA are not listed as tasks here. They apply to every implementation and do not change the amount of source content ported.

