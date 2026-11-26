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


## 7. Source builder coverage cross-check

The original `campaign2World.js` contains the following named world-builder families. This list is a checklist of source owners, not a requirement to reproduce their exact rendering implementation.

| Source builder / family | Target evidence | Gap status |
|---|---|---|
| `setupVillageScene`, `paintRoad`, `paintPath`, `paintStreamSegment` | Hollowmere data, strategic/local road data, regional hydrology and terrain stream | **Verify** route connectivity, bridge/water traversal, and that source-authored named approaches all resolve |
| `buildFarmstead` | Old Mac's farmhouse, pasture/fences/evidence and interior | **Partial** wolf encounter and full farm gameplay |
| `buildGoblinCamp` / `buildGoblinNPC` | Skarn-tooth structures and camp terrain | **Partial** named actors, faction and encounter behaviour |
| `buildOrcStronghold` / `buildOrcNPC` | Skarnak's Hold structures, clearing, wall/gate and approach | **Partial** moved-site verification, named actors, trader/troll, trust quest |
| `buildDwarvenKingdom`, `revealSunkenDeepPassage` | Kragmoor six-floor location registry and gated floor state | **Partial** exterior presentation, named population, mining/services, travel and quest interaction |
| `buildElvenCapital` | Sil'thandriel three-level location registry and terrain | **Partial** population, services and faction/quest behaviour |
| `buildLichChapterhouse` | Chapterhouse floor map | **Partial** actors, faction content, encounter and entry/exit |
| `buildSideQuestContent` | Mirabel's spider ruin and several named quest sites | **Partial** spider actor support and complete side-quest interactions |
| `buildPlayerCottagePlot`, `buildPlayerCottage`, `upgradePlayerCottage` | Plot marker/approach and dwelling-state foundations | **Partial** full construction, upgrade, entry and persistence loop |
| `buyPlayerField`, `placeFieldFence`, `buyFieldLamb`, `plantAppleTree` | Field/fence geometry and farmstead state foundations | **Partial / Verify** crop rows, seasonal growth, livestock purchase, harvest and save/load |
| `buildAbandonedHouse`, `renovateAbandonedHouse`, `isAbandonedHouseCleared` | House exterior/interior, journal and altar positions | **Partial** clearing/renovation state, dormant skeletons, journal/altar and quest chain |
| `buildNecromancerCrypt`, `buildLichBarrow` | Crypt and barrow floors/corridors | **Partial** encounters, journals, faction/quest progression and entry/exit |
| `buildMillbrook` | House, road and two NPCs | **Partial** entry/exit and services |
| `buildDragonLair`, `revealDragonLairArea` | Lair terrain and dressing | **Partial** dragon actor, reveal/encounter logic and rewards |
| `buildSilverhartPalace`, `fortifySilverhartManor` | Extensive city/settlement records and selected palace floor stacks | **Partial** remaining rooms, wall traversal, gated access, services and kingdom interactions |
| `buildThievesCoveCaves`, `searchSecretPassage`, `revealSingleTunnelEntrance`, `revealTunnelEntrances`, `openTunnelJunction` | Four-level cave registry and entrance/site records | **Partial** secret passage discovery, tunnel reveal/junction state, guild actors and quest interactions |
| `buildVampireGrave` | Grave evidence and journal object | **Partial** vampire encounter, investigation and journal interaction |
| `buildDruidGrove` | Grove terrain, spring and herb visuals | **Partial** gathering and grove inhabitants/trial consequences |
| `spawnWildUnicorn` | Vale, hoofprints and patrol waypoints | **Partial** live unicorn, patrol AI and discovery |
| `buildEmberlode` | Settlement and mine floors | **Partial** actor spawning, mining, services and quest consequences |
| `buildReddale` | Six buildings/interiors, twelve NPC placements and ruin site | **Partial** services, bribes, evidence, spider actor and espionage consequences |
| `buildNorthwatchFort`, `buildRidgeholdFort` | Fort geometry, keeps, waterway and selected props | **Partial** complete defender/siege actors, schedules and battle flows |
| `buildHollowmereGuildDen` | Guild Den floor map | **Partial** guild contact, recruitment/services and entry/exit |

### Source runtime inventory counts to retain as denominators

- Source runtime scene: 16,566 unique terrain cells; 11,324 cells touched by named feature builders after deduplication; 246 physical tile-object placements; 72 interior regions; 9 multi-storey building definitions; 8 unicorn patrol waypoints.
- Target JSON-backed exterior inventory: 4,732 unique cells, plus regional GDScript features that are not included in that number; 1,543 walkable cells across the registered floor maps in the existing geometry audit.
- The target multi-story location registry contains 70 location records (many are single-floor), while the source runtime inventory reports 72 interior regions. The counts are not directly equivalent: some source interiors are represented by settlement-layout metadata, some target records are 3D adaptations, and registration does not imply runtime entry/exit. Resolve this with a location-by-location interior mapping rather than comparing totals.
- The target settlement-layout registry contains seven definitions on `dev`: Millbrook, Emberlode, Reddale, Old Mac's Farmstead, Silverhart, Skarn-tooth Camp and Skarnak's Hold. Hollowmere uses its separate location presenter; Kragmoor and Emberlode Mine use the multi-story registry.

The named-builder table and the location table above are the current actionable gap register. The next refinement is to attach exact source IDs and target file/test references to each NPC, quest, dialogue branch and physical interaction, not to inflate decorative geometry counts.
