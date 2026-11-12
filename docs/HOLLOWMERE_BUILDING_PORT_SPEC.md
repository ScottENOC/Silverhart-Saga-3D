# Hollowmere building and interior port specification

**Status:** source audit / proposed implementation  
**Base:** `dev` at the time this document was prepared  
**Reference project:** `ScottENOC/Hex-crpg` (Campaign 2 / Hollowmere)  
**Scope:** Hollowmere building architecture and content preservation. This is not yet an implementation plan for every Campaign 2 settlement.

## 1. Porting principle

The original 2D game is the content authority. Preserve its authored map positions, named residents, dialogue IDs, quest hooks, doors, furniture/props, workplaces, household assignments and time-based behaviour. Where the 3D game needs a different presentation, preserve the gameplay semantics rather than mechanically copying the 2D implementation.

**Important architectural correction:** the original Hollowmere does not use a separate scene transition for each ordinary building. `campaign2World.js` carves floors and wall rings into the same axial world map, places a door tile at the threshold, and registers interior regions for indoor lighting. Doors are world objects which can open/close, lock, and be attacked. The tavern also has a layered upper floor. The 3D port should preserve this continuous-world experience where practical. A separate interior scene is acceptable only as an implementation detail if it preserves seamless entry/exit, world state, NPC identity and location.

## 2. Current 3D baseline (dev)

Relevant files:
- `scripts/world/world_root.gd`
- `scripts/world/hollowmere_village.gd`
- `scripts/world/hollowmere_village_data.gd`
- `scripts/world/hollow_tankard.gd`
- `data/characters/hollowmere_npcs.json`
- `docs/HOLLOWMERE_VILLAGE.md`
- `docs/HOLLOW_TANKARD_BLOCKOUT.md`

Current state:
- `WorldRoot` creates a `HollowmereVillage` presentation node and a separate `HollowTankard` node.
- The village renderer creates the exterior buildings, roads, stream, bridge, fields, pasture and barn.
- `HollowmereVillageData.BUILDINGS` describes seven non-tavern exterior footprints: general store, chapel, elder's house, Mira's house, Oskar's house, Old Mac's farmhouse and barn.
- The exterior cottage builder creates a visible door opening and door slab, but there is no shared door interaction or interior entry system.
- The tavern has its own rendered room, furniture, logical movement blocking and roof cutaway (V). Its entrance is currently a permanently open doorway with a decorative door leaf, not a stateful door.
- The tavern blockout document explicitly lists door interaction/locking, physical collision, save/load and several narrative elements as unfinished.
- The village's logical data and tavern's local simulation are separate systems at present. The port should converge them on one authoritative world/building model rather than creating another parallel map.

### Character manifest discrepancy to verify

The current `data/characters/hollowmere_npcs.json` contains 14 records when counted, including the player avatar. The existing `tests/test_hollowmere_village.gd` asserts 13 records, and the village documentation also says 13 adult profiles. Resolve this count/definition mismatch before relying on the test as a completeness check. The NPC records include Wren, Garrick, Mira, Oskar, Wick, the three Ironbond soldiers, Yvette, Hendra, Bram Fenwick, Elder Marta, Rowan, and the player avatar.

## 3. Original 2D content inventory

### A. Core village interiors authored in `setupVillageScene()`

The original map registers these interior regions:

| Original location / ID | Axial centre | Door / threshold | Existing content and gameplay significance |
|---|---:|---:|---|
| Hollow Tankard | (0, 0) | (0, 4) | Opening encounter location; fireplace, two tables and benches; door begins locked for the scripted Ironbond entrance; tavern keeper Garrick, Wren, Mira, Oskar, soldiers and background patrons. |
| Unlabelled small building (`storeRegion`) | (14, 0) | (10, 0) | A carved, empty interior in the original setup. Do not silently discard it or assume it is the general store: it is distinct from the explicitly named general store at (0,18). Confirm its intended identity from the map/art/history before assigning content. |
| Chapel | (-14, 0) | (-11, 0) | Contains the `elder_locket` quest item for “A Missing Locket”; registered as the Church faction/music point of interest. |
| Elder's house | (0, -12) | (0, -10) | Home of Elder Marta Wynfield; the elder NPC is spawned inside. |
| General store | (0, 18) | (0, 15) | Wick Hallow; counter/table at (0,17); shopkeeper dialogue and trading/supplies context. |
| Mira's house | (12, 9) | (10, 9) | Mira's residence; her night/home schedule targets this door/home. |
| Oskar's house | (-6, 9) | (-4, 9) | Oskar's residence; his home schedule targets this house. |

The tavern's furniture and hearth are individually represented as tile objects. The other core interiors are much less furnished in the original source: their primary value is their location, named occupant, quest item or social-system registration. Do not invent elaborate bespoke furniture as a prerequisite to making them enterable.

### B. Other authored Hollowmere buildings

| Location | Axial centre / placement | Source behaviour | Port notes |
|---|---:|---|---|
| Hollowmere guild den | (-12, -8) | A deliberately small, concealed thieves' guild room; optional guild contact is spawned inside. | Missing from the current 3D building list. Add as a discoverable/appropriate-access interior, not an obvious public shop. |
| Old Mac's farmhouse | Derived from southern road endpoint; 3D anchor currently (12,54) | House interior, door spur, fenced pasture, broken fence, blood trail, sheep and Old Mac. Wolf-den clue leads away from the farm. | Current 3D has farmhouse and barn exterior. Original `buildFarmstead()` builds a farmhouse and fenced pasture; it does not define the current 3D barn as an enterable interior. Preserve the wolf evidence/quest trail and sheep interaction. |
| Tankard lodging floor | Same footprint as tavern, floor 1 | Separate floor layer, stair up/down, six bed placements (excluding the stair cell), adjacent tables; residence capacity 8. | Current 3D tavern has no upstairs floor. Port this as a genuine second level, not as a second building. |

### C. Generated housing and work economy

`hollowmereSocialFabric.js` expands the village beyond the hand-authored core:

- Target dwelling registry: 20 residences.
- Existing registry entries: Elder's house, Mira's house, Oskar's house and Tankard lodgings.
- Up to 16 additional generated cottages/tenements are carved with a floor, wall ring, door, fireplace and household capacity.
- Tests expect 18–20 registered residences, at least 14 built physical residences, and housing capacity sufficient for the 80-person population.
- Households have surnames, spouse links, parent/child links and friend networks. Generated residents are assigned a home hex and a social-visit destination.
- Adult residents are assigned workplaces; dependants are not assigned jobs.
- Daily schedule targets include home, work and visiting a friend's home. The NPC routine scheduler moves residents between those nodes while respecting a live-entity cap.

Workplace registry includes:

| Workplace | Type | Capacity | Physical form in source |
|---|---|---:|---|
| Hollow Tankard | Tavern | 8 | Existing tavern |
| General store | Shop | 5 | Existing general store |
| Chapel | Chapel | 3 | Existing chapel |
| Market green | Market | 10 | Outdoor/common-space work point |
| Smithy | Smithy | 5 | Generated workshop with anvil |
| Bakery | Bakery | 4 | Generated workshop with table/work prop |
| Weaver | Weaver | 5 | Generated workshop with crate/work prop |
| Carpenter | Carpenter | 5 | Generated workshop with crate/work prop |
| Riverside landing | Fishing | 8 | Outdoor work location |
| North fields | Farm | 18 | Outdoor work location |
| South fields | Farm | 18 | Outdoor work location |
| Woodlot | Forestry | 10 | Outdoor work location |
| Builders' yard | Labour | 10 | Outdoor work location |

The source tests require at least nine workplaces and sufficient capacity for the adult population. The full registry above contains 13 entries. The 3D port should not turn all outdoor workplaces into enclosed buildings; preserve their outdoor character and give only the four craft workshops enclosed interiors.

## 4. Original door and interior semantics to preserve

The original `campaign2World.js` provides:
- Shared axial map coordinates for exterior and interior floor cells.
- Floor regions surrounded by actual hex-adjacency wall rings.
- Door tile objects with open/closed state.
- Locked doors that block movement and line of sight.
- Door toggling; locked doors refuse ordinary entry.
- Lock/unlock from the inside.
- Doors can be attacked; default durability is 20 HP; a destroyed door becomes permanently open and cannot be locked.
- Per-region indoor lighting multipliers.
- Multi-story building floors stored as separate floor maps, so upper floors can occupy the same axial footprint without overwriting the ground floor.
- Door/room footprint reconciliation to prevent paths or adjacent buildings from punching holes in walls.

The 3D version should translate these semantics into a shared building/door model:
- Stable building ID, floor ID, door ID and axial threshold.
- Open/closed/locked/broken state owned by simulation, not mesh visibility.
- Door state controls movement, collision and line of sight consistently.
- Roof and wall cutaway is presentation-only and must never alter logical walkability or door state.
- Floor transitions preserve character identity, party state, NPC state, time, quest state and save data.
- Furniture/props have explicit logical footprints separate from their meshes.
- Every building footprint and entrance is checked against road/path connectivity and neighbouring structures.

## 5. NPC and quest/content mapping

Preserve existing game IDs and dialogue IDs; do not create duplicate NPC instances when changing floors or loading interiors.

Key authored occupants and content:
- Garrick Holt — tavern keeper; rest/room interaction and Ironbond shakedown.
- Wren Talbot — companion; opening scene and companion dialogue.
- Mira Ashbrook and Oskar Vinn — tavern patrons with their own houses and home schedules.
- Dray Coltayne, Tomlin Brask and Hask Greel — Ironbond soldiers in the opening tavern event.
- Yvette Marlow and Hendra Wells — background patrons with local/Ironbond dialogue; Hendra is tied to the missing-child thread.
- Wick Hallow — general store keeper.
- Elder Marta Wynfield — Elder's house; chapel locket quest.
- Rowan Fletcher — wandering hunter near the crossroads; hunting/vendor/news role.
- Old Mac — farmhouse occupant; sheep, damaged fence, blood trail and wolf encounter chain.
- Optional Hollowmere guild contact — hidden guild den.
- Generated residents — household/workplace/friendship/routine simulation, not individually authored quest-givers by default.

Quest/interactable preservation checklist:
- Ironbond shakedown: tavern entrance/door choreography, dialogue branches, combat/non-combat outcomes and aftermath.
- “A Missing Locket”: `elder_locket` located in the chapel.
- Missing child: Hendra Wells and Tam Wells; village dialogue and wilderness trail/encounter.
- Farmstead/wolves: Old Mac, sheep, broken fence, blood evidence, wolf den and encounter.
- Guild den: hidden thieves' guild contact and associated access/discovery.
- Shop interactions: Wick's supplies/trade dialogue.
- Hunter interactions: Rowan's hunting/trading/news role.
- Ambient chatter and social schedule changes based on time, security and shakedown outcome.

This list is a preservation checklist, not a claim that all of these are already implemented in 3D.

## 6. Proposed 3D architecture

Create a data-driven building layer shared by village presentation and world simulation.

Suggested components (names are provisional):
- `BuildingDefinition`: stable ID, type, axial centre/footprint, exterior profile, floors, entrances, access policy, occupant/workplace IDs and content tags.
- `BuildingRuntime`: persistent per-save state (doors, damage, discovered/locked status, furniture state, floor occupancy).
- `BuildingExterior3D`: meshes/materials/roof cutaway and exterior collision.
- `BuildingInterior3D`: floor/wall/furniture presentation and indoor lighting.
- `BuildingDoor`: interaction target and simulation-owned door state.
- `BuildingRegistry`: lookup from axial cell/door/floor to building definition and runtime state.
- `BuildingTransitionService`: seamless movement between exterior/interior/floors, retaining the same character/simulation instances.

Prefer a continuous shared world map and camera/cutaway model if performance and the existing chunk architecture allow it. If interiors are streamed as separate scene content, they must behave as a continuous world: preserve the world-space threshold, return position, simulation clock and all live state. Do not duplicate NPCs or maintain separate incompatible map coordinates.

Do not hardcode each building in the tavern script. Do not create one bespoke interaction script per building. Building-specific content should be data/resources attached to reusable definitions.

## 7. Delivery order

### Phase 0 — resolve source and coordinate audit
1. Confirm the unlabelled 2D building at (14,0) and the hidden guild den's intended placement/access.
2. Reconcile the 3D map's building footprints, doors and roads against the 2D source; document intentional layout changes.
3. Fix/clarify the 13-versus-14 character manifest/test count.
4. Decide how the original 2D 80-person social simulation maps to 3D actors and background/off-screen simulation.

### Phase 1 — reusable building and door framework
1. Define building/floor/door data and stable IDs.
2. Add interaction prompts and open/close/lock/break semantics.
3. Make movement, collision and line-of-sight use the same door state.
4. Add roof/wall cutaway groups that are presentation-only.
5. Add save/load persistence for building state.
6. Add tests for entrance reachability, wall-ring integrity, door states, collision/LOS agreement and entry/exit position preservation.

### Phase 2 — migrate the Hollow Tankard
1. Register the tavern as a building definition.
2. Preserve its current dimensions, bar, fireplace, tables, benches, opening layout and V roof toggle.
3. Replace the decorative always-open entrance with the shared door system.
4. Add the upstairs lodging floor, stair interaction, beds and tables.
5. Preserve the opening encounter and all existing NPC IDs/party state.

### Phase 3 — first non-tavern interior
Implement the General Store at (0,18) first:
- Wick Hallow at the source threshold/interior position.
- Counter at the source's counter location.
- Shelving and modest stockroom dressing as presentation additions.
- Existing shop/trade/supplies interactions.
- Exterior door, interior walkability and return path.
This validates the framework on a building that is not the tavern without inventing a large new content system.

### Phase 4 — authored Hollowmere locations
Recommended order:
1. Elder's house and Chapel (quest-critical; verify locket location and Elder content).
2. Mira's and Oskar's houses (residential schedule/ownership test).
3. Unlabelled building at (14,0), after its identity is confirmed.
4. Hidden guild den.
5. Old Mac's farmhouse and farmyard; preserve animal/evidence/quest interactions.
6. Four craft workshops (smithy, bakery, weaver, carpenter).

### Phase 5 — generated settlement and simulation
1. Port the 20-residence registry and household assignment rules.
2. Port the 13 workplace roles, keeping farms/fishing/forestry/builders yard outdoors.
3. Port the 80-person population as persistent lightweight simulation records, not necessarily 80 fully rendered actors at once.
4. Materialise nearby residents as Ara actors; schedule off-screen residents without requiring live 3D nodes.
5. Ensure residents can enter/leave homes and workplaces without teleporting or duplicating.

## 8. Acceptance criteria

- Every source-authored Hollowmere building that is intended to be enterable can be entered and exited.
- Each door has correct state, movement blocking, collision and line-of-sight behaviour.
- No building's wall ring is broken by roads, paths, neighbouring buildings or props.
- Interior and exterior thresholds connect to the same logical axial world and preserve player position on exit.
- Roof/wall cutaway never changes collision or simulation state.
- Tavern upstairs is a real floor with stairs and lodging contents.
- NPC IDs, dialogue IDs, quests, shop functions, household identities and schedules survive transitions and save/load.
- The Chapel still contains the locket quest item; Old Mac's farm still supports the sheep/fence/blood-trail/wolf sequence.
- Generated residents remain simulated without requiring every resident to be rendered.
- Tests cover all building definitions, doors, floors, paths and source-content references.

## 9. Source files reviewed

Original 2D:
- `campaign2World.js` — building carving, Hollowmere layout, farmstead, guild den, doors, floors and world setup.
- `campaign2Content.js` — authored NPC profiles and dialogue IDs.
- `campaign2Dialogue.js` — opening encounter and NPC dialogue/quest interactions.
- `hollowmereSocialFabric.js` — generated residences, workshops, workplaces, households, relationships and schedule integration.
- `tests/hollowmere-social-fabric.spec.js`, `tests/mira-house-relocation.spec.js`, `tests/building-integrity-audit.spec.js` — source expectations and known geometry integrity concerns.

3D:
- `scripts/world/world_root.gd`
- `scripts/world/hollowmere_village.gd`
- `scripts/world/hollowmere_village_data.gd`
- `scripts/world/hollow_tankard.gd`
- `data/characters/hollowmere_npcs.json`
- `tests/test_hollowmere_village.gd`
- `docs/HOLLOWMERE_VILLAGE.md`
- `docs/HOLLOW_TANKARD_BLOCKOUT.md`