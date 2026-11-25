# Campaign 2 map verification and scope decision — 25 November 2026

This is a map-only audit. NPC definitions, dialogue, quests, encounters, schedules, services, factions and combat behaviour are campaign-owned and are not ported by this workstream.

## Source fidelity rule: preserve authored layout, not random decoration

The migration distinguishes deliberately authored layout from procedural wilderness dressing:

- **Preserve and verify the layout-producing source logic:** settlement and town plans, building footprints, road/ring-road routes, walls, gates, bridges, defensive works, farm/field/fence layouts, authored clearings, landmarks, dungeon/ruin geometry, deliberate prop placements and gameplay/story-critical environmental features.
- **Preserve authored placement where it carries meaning:** entrances, clues, graves, quest props, named landmarks and other distinctive set dressing.
- **Do not require coordinate parity for random/procedural decoration:** randomly scattered trees, rocks, shrubs, grass, undergrowth and similar wilderness dressing need only retain the biome, broad woodland/open-ground character, density and gameplay readability. Silverhart may generate these differently using its own deterministic terrain-aware systems.
- **Do not count procedural decoration differences as migration gaps.** The source's broad random/base scene pass is not a cell-by-cell parity target. Audit it for landscape character and coverage, not identical individual placements.

When uncertain, classify a feature by its source-generation method and gameplay/story role before deciding whether exact geometry parity is required. A hand-authored grove, landmark rock formation or deliberate quest clue remains authored even if it resembles ordinary wilderness dressing.

## Silverhart: retain the authored city, defer procedural infill

The canonical Silverhart baseline currently contains:

- 40 source-authored building records
- 33 route/path records
- 513 prop records
- 38 named NPC placements (placement data only; NPC porting belongs to the campaign workstream)

Keep the palace and its interior buildings, stables, general-goods shop, clothier, magic shop, Corstane Manor, builder's house, four embassies, Ironbond office, Grand Cathedral, Commons Inn, Thieves' Guild and hidden vault, and the authored street/road/wall network. The existing residential houses remain part of the baseline record for now; the user has deferred the separate procedural capital-rebuild infill.

The original `silverhartCapitalRebuild.js` contains 40 candidate specifications, with source tests guaranteeing at least 15 successful placements. These are generated infill candidates, not a set of required story locations. The candidates include generic house/townhouse/tenement/workshop/warehouse/shop/inn archetypes and some civic-sounding placeholders (guildhall, watch headquarters, court, scribes' hall and translator office). They have no named NPC placements or dialogue/quest assignments in the rebuild specifications. They are therefore deferred rather than copied as if they were finished content. This removes no named NPC or dialogue from the current map baseline.

If the three existing outlying legacy houses are ever removed in a later city redesign, their three associated flavour residents are Osric Fenn, Greta Aldwyn and Tomlin Reed. They are not part of the deferred generated candidate set and are retained in the present baseline.

### City geometry to preserve and verify

- Palace curtain wall: source radius 23, seven watchtowers and two ladder crossings.
- Inner ring road: source radius 30 (`silverhart_outer_ring_road` in the current manifest).
- Middle ring road: source radius 45 (`silverhart_middle_ring_road`).
- Outer city wall: source radius 60, three-cell south gate and two gate watchtowers.
- Merchant and noble quarter street grids, diplomatic main road and all embassy/cathedral/Ironbond approaches.
- Thieves' Guild, hidden vault, Warrens row and outer approaches.

The current layout regression checks the 40 baseline buildings, 33 paths, city-wall cell count, gate cells, ring-road source corners, wall traversal/ladder movement costs, vault concealment and key palace/district interiors. The settlement builder also checks palace and Warrens chunk ownership. A further all-40-building chunk sweep is being added so every retained building must appear in its owning 24-hex chunk.

## Settlement and regional-site verification (step 2)

The canonical settlement catalogue contains eight definitions: Hollowmere, Silverhart, Millbrook, Emberlode, Reddale, Old Mac's Farmstead, Skarnak's Hold and Skarn-tooth Camp. Hollowmere's authored data is maintained in its own modular location files; the JSON inventory below does not include that separate presenter.

Existing regression coverage verifies:

- Hollowmere's authored buildings, paths, bridge, fields, fences, props, vegetation exclusions and opening-village presentation.
- Millbrook's source house footprint, door, path spur and interior.
- Emberlode's hall, bunkhouse, mine entrance and approaches.
- Reddale's six source buildings, three approaches and six interior maps.
- Old Mac's farmhouse, road spur, pasture/fences and chunk ownership.
- Skarn-tooth Camp's chief's hut, five surrounding huts and campfire.
- Skarnak's Hold's warlord hut, seven surrounding huts, perimeter/gate and approach.
- Northwatch and Ridgehold keep floor masks, doors, walls and hearths; Northwatch siege engine, catapult, oil barrels and wall ladders.
- Kragmoor's six source floors and Sil'thandriel's three canopy floors.
- Silverhart's baseline buildings, ring roads, district approaches, city walls and floor maps.

The registry currently has 71 multi-story/location definitions and 89 floor definitions. A new exhaustive floor-builder sweep is being added to require every registered floor to return a non-empty logical map.

A source-to-target door-anchor comparison now matches 67 of the 69 source interior regions that declare a door hex against target multi-story door objects and settlement building door records. The two unmatched anchors are `(268, -2)` in the Northwatch fort region and `(406, 35)` in the Ridgehold fort region. They may be outdoor fort access points rather than building doors, but they must be checked against the target wall gaps and approach routes before being marked intentional. Three of the 72 source regions have no source door anchor.

## Wilderness and physical-site verification (step 3)

Source-backed map presentation and floor-map tests cover:

- Vampire Grave: disturbed earth, sheep remains, punctures, fang and buried journal.
- Thieves' Cove, Vessel-Seeker's Crypt and Corvin Ashgrave Barrow: canonical entrances, chunk ownership, source doors and connected floor layouts.
- Ashveil's Dragon Lair: canonical outcrop anchor and surrounding rocky props.
- Emberwood Grove: clearing, spring rim and both herb patches.
- Unicorn Vale: all eight patrol waypoints and 24 hoofprint markers.
- Old Mac's Wolf Den: natural rock entrance and scattered bones.
- Abandoned House: two-cell worn-earth approach, source waypoint and doorway, journal and altar.
- Reddale's spider ruin: source-anchored collapsed-masonry dressing.
- Lich Chapterhouse: source east door and fireplace; a direct floor-builder regression is being added.

Map presentation deliberately does not spawn wolves, dragons, druids, undead, inquisitors, witch hunters or other encounter actors.

## Source terrain and geometry audit (step 5)

The source-runtime extractor and authored-hex audit completed successfully against pinned Hex-CRPG commit `4de96f16889d43cae91e03832c8eb1c1b4b00e42`. The audit checked seven named builder symbols (Emberlode, Farmstead, Goblin Camp, Millbrook, Orc Stronghold, Reddale and Silverhart Palace) and found none missing; it does not claim to have symbol-checked every builder in the runtime inventory.

Source runtime inventory:

- 16,566 terrain cells.
- 11,324 unique cells touched by explicit feature builders beyond the broad `setupVillageScene` base pass.
- 5,242 cells touched only by the base pass, with 326 overlaps.
- 246 physical object placements, 72 interior regions, nine multi-storey building definitions and 44 NPC/creature baseline placements.

Strategic-map parity is exact in the audit: 16×16 dimensions, all 12 named markers at their source positions, all 15 river waypoints matching, Hollowmere at the strategic origin, and zero unmarked terrain/faction mismatches.

Current target-side JSON inventory:

- 4,730 unique local exterior authored cells.
- 67 building records, 40 settlement path records and 522 prop records.
- 1,903 interior room-footprint cells summed across floors.

These totals are **not a source-to-target parity percentage**. The target JSON inventory excludes Hollowmere's modular presenter, regional GDScript terrain/features, some physical presenters and generated wilderness. Source builder cells include terrain, walls and other geometry not represented by the same target-side categories. A cell-by-cell source-builder-to-target comparison remains outstanding.

The source feature-builder inventory identifies the largest authored geometry owners as Silverhart Palace (2,584 cells), Dwarven Kingdom/Kragmoor (1,959), Northwatch (1,217), Ridgehold (937), local stream segments (902) and Sil'thandriel (702). Their target representations exist across settlement JSON, regional feature scripts, floor manifests and presentation scripts; the numeric counts alone cannot establish exact per-cell parity.

## Remaining gaps and follow-up work

1. **Visual review:** Headless tests validate geometry records, map cells, anchors and chunk ownership; they do not establish that every building, wall, road, interior or wilderness prop looks right in the Godot camera. Review scale, roof/material appearance, wall continuity and clutter in-engine.
   - The first automated 28-view capture (`campaign2-map-visual-review`, workflow run 45560807836) proves the preview scene can stream and render the selected views, but it is not visual sign-off: the Silverhart centre/ring captures show buildings, ribbons and wall features against a largely unrendered dark ground; the Kragmoor capture is effectively empty apart from a tiny marker. Rework the capture/ground presentation and inspect the actual in-game camera before accepting visual parity.
2. **Authored geometry parity:** Build a cell-by-cell comparison for layout-producing source builders (settlements, roads, walls, bridges, farms, authored clearings, landmarks and deliberate physical-site features) against the combined target JSON and GDScript providers. Exclude random/procedural tree, rock, shrub, grass and undergrowth placements from coordinate parity. Do not compare the 11,324 source feature-cell total directly with the 4,730 target JSON-only total.
3. **Wilderness character:** The broad source `setupVillageScene` pass touches 5,568 cells. Exact cell parity is intentionally not required for random trees, rocks and undergrowth. Review biome identity, woodland boundaries, density, clearings, sightlines and terrain-aware distribution instead. Elevation and hydrology remain separate geometry/terrain concerns and still require validation.
4. **Hydrology and elevation:** Existing tests check strategic river waypoints, local water/fort waterway continuity, deterministic elevation and sample chunk seams. An exhaustive seam/continuity sweep across all streamed chunks remains outstanding.
5. **Full runtime city traversal:** The stream uses 24-hex chunks and the tests exercise settlement chunks, palace/Warrens ownership and the regional/campaign stream contracts. A visual traversal from palace through all districts to the Warrens, including unload/reload while crossing chunk boundaries, remains an in-engine check.
6. **Exterior/interior transitions:** Source floor maps and door cells are registered and floor-tested. Full runtime door entry/exit wiring is still incomplete at several settlements and interiors; track each connection separately from the geometry itself.
7. **Presentation quality:** Several settlements still need visual scale/material review. Kragmoor and other multi-level interiors need more detailed dressing/lighting, but the source floor geometry and traversal data should be preserved.

The next map stages are: complete and validate the source-authored floor maps (stage 4); perform the source/target terrain and feature comparison and fill only genuine source-authored gaps (stage 5); then harden and visually verify chunk streaming, boundaries, determinism and runtime transitions (stage 6).
