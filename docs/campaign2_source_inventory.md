# Campaign 2 source inventory — world-port extraction pass 1

**Reference repository:** `ScottENOC/Hex-crpg`, branch `main`  
**Primary source:** `campaign2World.js`, `campaign2Content.js`, `campaign2Dialogue.js`, `worldMap.js`, `worldChunkStreaming.js`  
**Target branch:** `feature/full-world-port-foundation`  
**Fidelity target:** 99% behavioural, geographical and content parity. 3D presentation may differ where the gameplay result and spatial intent are preserved.

This is a source-derived inventory, not a claim that the content has already been migrated into Godot. It records concrete source facts and identifies the next extraction work.

## 1. Campaign identity and world scale

- The target is **Campaign 2**: the Hollowmere opening and its continuous local world.
- Do not confuse it with the separate older Campaign 3 map in `world_map_data.js` (400×400).
- Campaign 2's strategic map is 16×16. `campaign2World.js` defines `WORLD_HEX_SIZE = 130`, with the crossroads at local axial `(8,24)` mapped to strategic cell `(row 6, col 6)`.
- Strategic cells summarise local geography; they are not independent playable maps.
- The local world is continuous. The original browser streamer uses 24-hex chunks, hot radius 2, multiple living-party observers, and special preloading around stairs. Chunk boundaries are a rendering/performance concern, not gameplay borders.
- The current 3D prototype's 16-hex chunks and generic terrain outside the village are implementation scaffolding. They are not source-authored world data and must not silently replace it.

## 2. Hollowmere: verified source layout

The original source's `setupVillageScene()` paints an explicit 61×61 grass/forest-clump starting area (`q,r = -30..30`) and then lays out the following authored features.

| Feature | Source coordinate / extent | Notes |
|---|---:|---|
| Hollow Tankard | floor columns q=-5..5, r=-3..3 with per-column axial row shift; closed door (0,4) | Central opening location; party initially seated inside |
| General store | centre (0,18), half extents 4×3, door (0,15) | Counter at (0,17); Wick Hallow placed at (0,18) |
| Chapel | centre (-14,0), half extents 3×3, door (-11,0) | Contains `elder_locket`; church faction POI |
| Elder's house | centre (0,-12), half extents 3×2, door (0,-10) | Elder Marta placed at (0,-12) |
| Mira's house | centre (12,9), half extents 2×2, door (10,9) | East of village road |
| Oskar's house | centre (-6,9), half extents 2×2, door (-4,9) | West/south of store approach |
| Stream | initial straight span q=-20..28 at r=-25; continues east to q=220 and west to q=-90 | Variable-width/winding extensions; source paints road over the crossing |
| Village path ring | q=-8..8 and r=-6..6 | Spurs connect each named building |
| Crossroads/signpost | (8,24) | Four named/unnamed road directions |
| Hollowmere guild den | centre (-12,-8), half extents 2×2 | Separate small back-alley interior |
| Region-dressing spot | (8,21) | Prosperity-dependent beggar or peddler |

Important correction to any simplified diagrams: the general store is south of the tavern, the chapel west, Elder's house north, Mira's house east and Oskar's house west/south. The axial coordinates and door approaches above are the source of truth; preserve them in the 3D coordinate conversion.

### Opening population and event

- Party starts seated in the tavern at `(i,0)` by party index.
- Wren Talbot is added as a permanent companion for human starts; goblin/orc starts bypass the tavern opening.
- Named tavern/store roster is data-driven from `campaign2Content.js`; `campaign2World.js` places Garrick Holt at (-3,-2), Mira Ashbrook at (2,-2), Oskar Vinn at (3,-2), Wick Hallow at (0,18), and Ironbond soldiers outside at (0,6) pending their scripted entrance.
- Background patrons are placed along r=2.
- Elder Marta Wynfield is placed at (0,-12). The baron is a regional authority record, not a rendered local NPC.
- Rowan Fletcher is placed at (12,26), just beyond the signpost.
- The human opening schedules Wren's ambient introduction and the Ironbond shakedown. Goblin and orc starts instead spawn at their faction camps and do not trigger this scene.

The complete NPC specs, dialogue trees and scripted event branches remain in the original content files. This table is not a substitute for those records.

## 3. Road network and destination anchors

The crossroads is the shared local origin for road construction. The source's `paintRoad` walks valid adjacent hexes with deterministic bounded lateral drift. Treat the extracted trace as a reference for route order, broad direction, approximate distance, junctions and named waypoints. The 3D road curves may be smoothed or redesigned; individual source wiggle cells are not fidelity requirements.

| Route | Direction and length from crossroads | Authored destination |
|---|---|---|
| North | 4 × 130 hexes | Millbrook road endpoint at step 390 (q7,-366; house centre q1,-366, door q4,-366); Silverhart at road end |
| South | 130 + 40 hexes | Old Mac's Farmstead |
| East | 130 hexes | Reddale |
| East border road | 390 hexes | Goblin camp at ~195; Northwatch turn at 260; Ridgehold / orc stronghold at end |
| West | 260 hexes | Emberlode |
| Independent NE approach | Dwarf anchor at (908,-626) | Kragmoor |
| Independent southern approach | Elf anchor at (-252,934) | Sil'thandriel |

The extracted road polyline is a convenient source reference, not a required 3D trace. Preserve the same connected destinations, route ordering, meaningful junctions, approximate distances and relative directions. Smooth or redesign individual bends where that creates better 3D navigation.

The source also connects disconnected road components with `connectAllRoadNetworks()` before taking the world baseline snapshot. The final road graph's connectivity is part of simulation behaviour (including road-following NPCs and caravans).

## 4. Authored locations called by the Campaign 2 world bootstrap

The main bootstrap calls the following location builders. This is the initial world-content inventory, not an exhaustive list of every interior room, prop or NPC:

- Hollowmere guild den
- Old Mac's Farmstead
- Skarn-tooth goblin camp
- Player cottage plot
- Abandoned house
- Necromancer crypt
- Lich barrow
- Millbrook
- Dragon lair
- Lich chapterhouse
- Silverhart palace/capital
- Emberlode and its mine
- Reddale
- Vampire grave
- Druid grove
- Thieves' Cove caves
- Wild unicorn encounter/location
- Northwatch Fort
- Ridgehold Fort
- Orc stronghold
- Kragmoor / Deepholds dwarf kingdom and mine
- Sil'thandriel / Sylvan Court elven capital
- Side-quest content and connecting roads

The builder calls establish that these are part of the source-authored Campaign 2 bootstrap. Their full footprints, vertical layers, interiors, actors, object interactions and unlock conditions must be extracted from each builder and associated content before implementation is marked complete.

### Farmstead details already verified

Old Mac's Farmstead is not just a marker: it includes a carved house, fenced pasture, broken fence, blood-spatter trail, two sheep, Old Mac inside, and a wolf-den discovery deliberately placed out of ordinary pasture vision. The wolf encounter is triggered by dialogue/quest logic, not simply by standing on a map marker.

### Emberlode details already verified

Emberlode includes a foreman's hall, bunkhouse and mine entrance. The mine has ground level plus two underground layers (-1 and -2), stairs, a ledger, gold and gem ore nodes, and spiders on the deeper level. It has named foreman, miner and guild-contact actors. Access/trade consequences depend on the goblin-threat quest resolution.

### Reddale details already verified

Reddale contains a guardhouse, reeve's house and inn, with Captain, guard, reeve, innkeeper, guild contact and disciple hooks. The guard has a bribe interaction; the captain is explicitly incorruptible. The town also has a search-site waypoint for a missing-watch quest and evidence linked to the disciple.

## 5. Strategic geography acceptance facts

The 16×16 map is a real faction/terrain geography, not a decorative minimap. Source tests establish at least these constraints:

- Open ocean occupies the far-west edge.
- The north-east reserved 4×5 block contains a contiguous mountain range claimed by the dwarves (at least 15 mountain cells in that block).
- The mountain range borders orc territory; dwarves and greenskins are neighbours.
- The major river flows from the mountain range toward the western ocean.
- Human lands occupy the central/western inland region; the southern forest belt is reserved for elven territory.
- Hollowmere is strategic cell (6,6). One strategic cell represents 130 local hexes.
- Silverhart is four strategic cells north of Hollowmere, not six.

Use `worldMap.js` and its tests to establish the source's broad regional/faction pattern, coastline, river, mountain and forest belts. The 3D strategic map should communicate those major relationships; reproducing every incidental terrain cell is not required.

## 6. Source tests to turn into Godot acceptance tests

The original repository contains a large Playwright and unit-test suite. The following are especially relevant to full-world parity; migrate their assertions into GDScript tests or deterministic data-validation scripts rather than treating screenshots as sufficient:

| Source test | Required 3D coverage |
|---|---|
| `world-map-geography.spec.js` | Ocean, mountain block, faction ownership and river-to-coast relationship |
| `world-map-scale.spec.js` | Local-to-strategic scale, Hollowmere origin and Silverhart offset |
| `world-chunk-streaming.spec.js` | Multiple party observers, continuous chunks and connected upper-floor preloading |
| `wider-world.spec.js` | Crossroads, roads, missing-child wilderness quest, rewards and exploration |
| `millbrook-worldbuilding.spec.js` | Millbrook buildings, population, residents, upstairs accommodation and existing quest anchors |
| `settlement-content-density.spec.js` | Every added enterable building has authored content and a named resident |
| `emberlode-worldbuilding.spec.js` | Existing settlement anchors, named residents, mine ledger, buildings and population |
| `regions.spec.js` | Village → barony → kingdom stat inheritance and player-driven changes |
| `world-pulse.spec.js`, `world-pulse-camps-caravans.spec.js` | Time-based world events, camps, caravans and persistent simulation |
| `wilderness-living-world.spec.js` | Living wilderness population and encounter behaviour |
| `building-integrity-audit.spec.js`, `carve-polygon-room.spec.js` | Enterable building footprints, walls, doors and room topology |

These are representative, not the entire parity suite. A complete test inventory still needs to classify all Campaign 2 gameplay tests (quests, dialogue consequences, faction systems, companions, mounts, crafting, trade, combat, skills, NPC schedules, persistence and travel).

## 7. Data extraction and implementation rules

1. **Separate data from construction.** Extract stable source IDs, coordinates, terrain cells, road paths, structure footprints, floor layers, tile objects, NPC specs, dialogue nodes, quest definitions and effect definitions into explicit resources.
2. **Keep a source pointer.** Every migrated record should identify its originating source file and symbol/test where practical.
3. **Do not flatten dynamic logic into lossy snapshots.** Use deterministic generation for reproducible 3D chunks, but preserve the source's meaningful feature anchors, broad geography and route relationships rather than chasing parity for incidental road drift, forest clumps or minor stream bends.
4. **Do not use display names as IDs.** Create stable IDs while retaining source names as display strings.
5. **Persist world changes, not chunk nodes.** Chunk unload/reload must not reset doors, containers, NPC state, quest flags, resources or regional simulation.
6. **Keep vertical layers connected.** A stair/elevator/ladder can look different in 3D, but must preserve its destination, access rules and traversal outcome.
7. **Do not invent content to fill a gap.** Mark it Not yet ported until supported by source data.
8. **Maintain a deviation register.** Every 3D adaptation records the source behaviour, the 3D implementation and why the gameplay outcome remains equivalent.

## 8. NPC/dialogue inventory

The companion source index is [Campaign 2 NPC and dialogue content index](campaign2_npc_dialogue_index.md). It records the first-pass name, dialogue-ID, quest-ID and helper-function inventory from `campaign2Content.js` and `campaign2Dialogue.js`. Treat those as migration inputs, not as counts of active NPCs or a complete canonical quest list.

## 9. Next extraction sequence

1. Extract and validate the complete strategic 16×16 map and its marker/faction data.
2. Produce a machine-readable Hollowmere manifest (terrain, water, roads, buildings, objects, interiors, NPCs, schedules and quest anchors) and compare it against the existing 3D village.
3. Extract the source road waypoints, route connectivity and approximate distances, plus named builder anchors and functional footprints/interior layers. Individual road wiggles and incidental terrain cells are not required.
4. Extract all NPC/content/dialogue/quest records into stable-ID resources and map source tests to Godot tests.
5. Only then replace the current generic procedural terrain with source-backed regional terrain and begin streamed multi-chunk implementation.

**Status:** Source audit pass 1 complete. Strategic/local scale, Hollowmere anchors, route references, major destination builders and priority acceptance tests have been inspected. Millbrook now has a first source-described 3D house/NPC layout in the regional preview. Full structure-by-structure, NPC-by-NPC and quest-by-quest extraction remains outstanding. No full map or gameplay port is claimed complete by this document.
