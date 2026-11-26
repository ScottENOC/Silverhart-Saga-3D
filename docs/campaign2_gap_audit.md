# Campaign 2 gap audit — what is still missing

**Reference:** `ScottENOC/Hex-crpg` main, pinned source geometry baseline `4de96f16889d43cae91e03832c8eb1c1b4b00e42`  
**Target:** `ScottENOC/Silverhart-Saga-3D`, `dev`  
**Purpose:** Record omissions and incomplete behaviour, not celebrate existing port coverage.

## Audit rules

- Treat Campaign 2 in `campaign2World.js`, `worldMap.js`, `campaign2Content.js`, `campaign2Dialogue.js` and their supporting systems as the reference.
- Preserve meaningful authored geography, settlements, routes, landmarks, buildings, entrances, interiors, props that communicate gameplay, NPCs, encounters and interactions.
- Do **not** count random tree/rock placement, exact procedural road wiggles, or equivalent decorative substitutions as gaps when the same broad terrain or navigable route is represented.
- A macro-map marker, data record, or passing geometry test is not proof that the location is playable. Distinguish data present, rendered, traversable, interacted with, and behaviourally complete.
- Status labels: **Missing** = no target implementation evidenced; **Partial** = some layers exist but named work remains; **Verify** = target code exists but source-to-target runtime parity has not been established; **Adapted** = intentionally different 3D implementation whose gameplay result still needs acceptance.

## Executive finding

The world has a substantial authored-map foundation, but it is not yet a complete Campaign 2 port. The remaining work is concentrated in (1) Kragmoor and several other location-specific actors/interactions, (2) entry/exit and gameplay wiring for authored interiors, (3) Silverhart's remaining city/palace/Thieves' Guild gameplay, (4) NPC schedules and living-world simulation parity, and (5) a source-ID-level quest/dialogue/companion crosswalk.

The current geometry audit is not a coverage percentage. It reports 4,732 unique JSON-backed exterior cells and 1,543 walkable interior cells, while explicitly excluding regional GDScript features and some site systems. The source runtime extractor reports 16,566 unique terrain cells, including 11,324 cells touched by named feature builders after deduplication. These figures have different scopes and must **not** be divided to claim a percentage. They do, however, show why a complete owner-by-owner source/target register is still needed.

## 1. Location and world-content gaps

| Area | Status | What is still missing or needs acceptance |
|---|---|---|
| Kragmoor / Deepholds | **Partial — highest priority** | The exterior presentation is visibly inadequate in the reviewed capture (near-featureless pale surface). The six floor maps and stair/save-state framework exist, but named dwarf NPCs and creatures, actor behaviour, dialogue, trader/runesmith/foreman/mining/journal interactions, and campaign travel routing remain. CI has also reported missing actor IDs: `dwarf_king`, `hall_guard_01`, `hall_guard_02`, `deepholds_trader`, `deepholds_runesmith`, `deepholds_foreman`. Verify whether the source's 1,959-cell builder footprint has been represented meaningfully in 3D, rather than assuming generic floors equal the full kingdom. |
| Silverhart | **Partial** | Exterior records are extensive (40 buildings, 33 routes, 512 props, 38 named NPC placements), and several major floor stacks exist. Remaining work: verify the full outer city wall, three-cell gate and watchtowers are rendered/traversable; finish remaining palace rooms/floors; wire building entry/exit; implement doors and reputation gates; NPC interactions and schedules; Thieves' Guild quest state and hidden-vault interactions; kingdom/faction interactions. |
| Sil'thandriel / Sylvan Court | **Partial** | Three-level tree/canopy floor maps and traversal structures exist. Population/NPCs, services, faction interactions and final traversal/visual acceptance remain. |
| Skarnak's Hold | **Partial** | The moved site needs its perimeter, gate and approach revalidated at the new location. Guards, Kesh the trader, troll, faction relations and trust quest are still campaign-owned work. |
| Skarn-tooth Camp | **Partial** | Exterior structures are present; chief/guards, dialogue, faction and quest behaviour remain. |
| Northwatch Fort | **Partial** | Fort/keep/gate/waterway and siege props are represented. Siege actors, assault wave behaviour, defender routines and complete encounter flow need runtime acceptance. |
| Ridgehold Fort | **Partial** | Fort and keep are represented. Defender population, routines, faction/quest interaction and complete traversal/visual acceptance remain. |
| Emberlode and Emberlode Mine | **Partial** | Buildings, interiors, floors, stairs, ore and spider spawn coordinates exist. Exterior entry/exit, live creature spawning, mining/ore interactions, ledger use, trade and quest consequences remain. |
| Reddale | **Partial** | Buildings, six interiors, roads, NPC placements and the spider-ruin site exist. Spider actor/asset support, entry/exit, merchant services, evidence reading, bribes, dialogue and espionage quest consequences remain. |
| Hollowmere | **Partial** | Authored village and floor maps exist. Interior entry/exit, Elder Locket placement, guild contact, recruitment/services, remaining opening events and persistence parity remain; cottage construction interaction remains campaign-owned. |
| Millbrook | **Partial** | House, road, NPCs and floor map exist. Entry/exit and resident services/interactions remain. |
| Old Mac's Farmstead | **Partial** | Exterior, farmhouse interior and key evidence exist. Entry/exit, Reyna's dialogue/recruitment/persistent character integration, and the wolf-den encounter trigger/spawn/persistence remain. Sheep-to-cow substitution is an accepted visual/gameplay adaptation, not a gap. |
| Abandoned House and northern crypt/barrow chain | **Partial** | Floor maps and physical evidence are represented. Dormant skeleton activation, journal/altar interactions, disciple/phylactery quest chain, encounter behaviour and runtime entry/exit remain. |
| Lich Chapterhouse | **Partial** | Floor, entrance and fireplace are present. Lich faction content, inquisitor/witch-hunter encounter behaviour and runtime entry/exit remain. |
| Thieves' Cove | **Partial** | Three-level cave network, stairs and evidence markers exist. Guild residents, services, quest content and runtime traversal/interaction wiring remain. |
| Vampire Grave | **Partial** | Disturbed grave, carcass, fang and journal are physicalized. Vampire actor/encounter, journal reading, investigation, quest state and interaction wiring remain. |
| Old Mac's Wolf Den | **Partial** | Cave-mouth dressing and anchor exist. Trigger, live wolf spawning, combat and quest persistence remain. |
| Unicorn Vale | **Partial** | Vale, patrol waypoints and hoofprints exist. Live unicorn actor, patrol AI and discovery behaviour remain. |
| Ashveil's Dragon Lair | **Partial** | Lair ground/dressing exists. Dragon actor, encounter and reward/quest behaviour remain. |
| Emberwood Grove | **Partial** | Terrain, spring and herb-patch visuals exist. Inhabitants, gathering and Fenn/grove quest consequences remain. |
| Player cottage / field | **Partial** | Plot and approach are represented. Construction, upgrades, field purchase/fencing, livestock, planting/harvest and persistence need a complete playable flow. |

## 2. Cross-cutting map and presentation gaps

1. **Kragmoor exterior and settlement presentation:** resolve the near-blank capture; compare source landmarks, entrance, approach, mountain silhouette and settlement scale. Do not treat a correct floor-map data structure as a visually complete mountain kingdom.
2. **Interior transitions:** many source-authored floor maps are registered, but most exterior-to-interior entry/exit wiring remains. Build a single audited transition register (entrance hex, destination floor, return hex, door/lock state, vertical stairs).
3. **Source physical objects:** the source runtime baseline records 246 physical tile-object placements. Target JSON inventory currently reports 520 prop records across 508 anchors, but this does not prove object-by-object semantic coverage. Cross-reference gameplay objects (journals, ledgers, evidence, altars, ore, stairs, doors, ladders, siege equipment, signs) and ignore replaceable decoration.
4. **Fields and crops:** the current JSON inventory reports 63 field cells, 22 fence cells and **zero crop rows**. Verify whether source crop/planting behaviour is represented elsewhere; if not, crop rows, seasonal growth, harvesting and farm-state persistence are missing.
5. **Road and water usability:** source route traces are represented, but test connected travel between all meaningful destinations, road-following NPC/caravan behaviour, bridge/ford traversal and stream/water barriers. Exact source road wiggles are explicitly not required.
6. **Strategic-to-local travel:** verify that every strategic destination resolves to its local site, and that the moved Skarnak's Hold strategic marker, local anchor, approach road and travel graph agree.

## 3. Simulation-system gaps

These are source system families, not merely map decoration. The target has partial systems in several areas; the missing work is behavioural parity and explicit acceptance tests.

| Source system family | Status | Gap to close |
|---|---|---|
| Continuous world streaming (`worldChunkStreaming.js`) | **Verify / Adapted** | Source uses 24-hex chunks, hot radius 2, multiple party observers and vertical stair preloading. Target uses a 3D streamed/chunked architecture, but its chunk size and observer semantics differ. Confirm multi-party/companion observers, active-vs-abstract simulation, stair preloading, save/load and chunk-boundary continuity. |
| NPC routines and event schedules (`npcRoutineScheduler.js`, `eventDrivenNpcSchedules.js`) | **Verify** | Source has a heap-based event scheduler, visible/abstract travel, promotion/demotion and persistent scheduler state. Target needs a source-ID-level audit of schedule data, daily routines, transitions, visible movement, abstract movement and persistence. Do not count static NPC placement as schedule parity. |
| Regions and settlements (`regions.js`, `settlementScale.js`) | **Verify** | Compare hierarchical region security/prosperity, settlement tiers/population targets, parent-child effects, local services and how world events change these values. |
| World pulse / autonomous events (`worldPulse.js`) | **Partial / Verify** | Source includes bandit-camp seeding, caravan spawn/despawn/ambush/raids, guard alert and rumours. Confirm equivalent target events, persistence, deterministic scheduling and consequences; implement missing event types. |
| Wilderness living world (`wildernessLivingWorld.js`) | **Verify** | Compare wildlife/encounter populations, respawn/cleanup, wilderness activity, travel-distance rules and persistence. A terrain biome alone is not a living wilderness. |
| Resources (`resources.js`) | **Partial** | A target wilderness resource system exists. Audit every source node/action: ore, fruit, timber, stone, herbs, fishing, corpses/food, well-fed state and donation to regions; verify depletion/regrowth, inventory effects, skill checks and save/load. |
| Quests and scripted encounters | **Partial** | Target has companion quest data/runtime and some campaign quest state. Build a source quest-ID/action/consequence matrix for main arc, side quests, espionage, missing child, farm wolves, Reddale watch, border assault, goblin succession, Emberlode escort, druid trial, crypt/lich/vampire and location-specific investigations. |
| Companion world agency and reactivity | **Partial / Verify** | Target has companion relationship/quest-chain foundations. Cross-check recruitment alternatives, companion departures, major-quest reactivity, companion self-decisions, world placement and persistent relationship/arc state against source. |
| NPC progression and authored builds | **Partial** | Validate all named NPC class levels, skill picks, equipment, progression modes, death/recruitment and restoration. CI has reported missing class-level profiles for `lady_miriel_corstane`, `master_builder_hallis` and `petra_ashfield`; resolve by tracing their source definitions rather than inventing levels. |
| Factions, reputation and diplomacy | **Verify** | Compare faction standing/trust, bribes, guard hostility, settlement security, faction ownership and consequence propagation across quests and regions. |
| Time, seasons and persistence | **Verify** | Compare world clock hooks, scheduled transitions, seasonal resource rarity, long-running event state and save/load. Ensure time progression continues correctly across unloaded chunks. |

## 4. Named NPC, dialogue and quest audit still required

The existing dialogue index is a mechanical first pass: 114 `name` literals, 69 explicit `dialogueId` values, 56 named helper functions and 49 literal quest-ID-like values. These are not complete canonical totals and do not establish that a character or branch is implemented.

The outstanding audit is a row-by-row mapping with at least:

- source character/quest/dialogue ID and source file;
- source spawn/starting location and schedule;
- target character profile, class levels, appearance/equipment and placement;
- dialogue entry point and all choices;
- state/relationship/faction/quest effects;
- combat/encounter or service effects;
- target implementation file and automated test;
- status: missing, partial, implemented, adapted, or intentionally excluded.

Priority named groups: Hollowmere opening cast and Ironbond shakedown; Silverhart court/embassies/Thieves' Guild; Kragmoor dwarf leadership and staff; Sil'thandriel population; border-fort defenders and siege actors; Reddale and Emberlode residents; Old Mac/Reyna/Fenn/Nessa; named companions and their recruitment/quest arcs.

## 5. Priority order to finish the port

### P0 — unblock coherent campaign play
1. Fix Skarnak's Hold relocation and all tests; verify the site visually and confirm strategic/local/road coordinates.
2. Make Kragmoor's exterior recognisable and complete its named NPC/creature roster, interactions and campaign travel.
3. Wire the common exterior/interior transition service and complete the most-used locations first: Hollowmere, Millbrook, Silverhart, Emberlode, Reddale, Old Mac's Farmstead.
4. Close the main campaign path and opening/major encounter consequences end-to-end.

### P1 — complete the authored world
5. Finish Silverhart's remaining palace/city/Thieves' Guild traversal and interactions.
6. Finish Sil'thandriel, forts, camps, dungeon chains and site-specific encounters.
7. Complete the NPC schedule, region, world-pulse, wilderness and resource parity matrices.
8. Finish named NPC profile/class/equipment and dialogue/quest crosswalks.

### P2 — depth and polish
9. Complete player cottage/farming and long-term settlement progression.
10. Improve lighting, materials, elevation, prop density and visual identity after functional acceptance.
11. Add optional ambient NPC barks/banter and decorative dressing only after gameplay gaps are closed.

## 6. Definition of done for this audit

A gap is closed only when its source behaviour/content is identified, the target implementation is linked, the intended adaptation is recorded, and a relevant test or explicit visual/runtime acceptance exists. The next audit revision should include a machine-readable CSV/JSON row for every source POI, named NPC, quest/dialogue ID, object interaction and source system feature. No overall completion percentage should be published until the denominator and target matching rules are agreed.
