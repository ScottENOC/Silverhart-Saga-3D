# World interior / exterior reconciliation audit

**Audit date:** 2026-11-28  
**Audited branch:** `dev` at `02312c9119857f4f4491e1dc4cc0d795c621ba2d`  
**Scope:** Campaign 2 authored building exteriors, multi-story floor definitions, interior presentation data, and non-building transitions.  
**Purpose:** Establish which interiors can be integrated into their intended exterior locations, what is missing, and which transitions are justified.

## Executive finding

The project has a substantial amount of source-authored interior *layout data*, but it is not accurate to say that every exterior has a fully designed 3D interior ready to move into place.

The repository currently contains:

- **71** entries in `campaign2_multistory_locations.json`, describing **89** floor definitions and **32** stair/floor transitions.
- **67** building/site records in `campaign2_settlement_layouts.json` across Millbrook, Emberlode, Reddale, Old Mac's Farmstead, Silverhart, Skarn-tooth Camp and Skarnak's Hold.
- A separate Hollowmere building definition with **7** exterior records, plus the separately authored Hollow Tankard and a hidden guild-den location.
- A fully authored, bespoke 3D interior shell and furnishing layout for **the Hollow Tankard**.
- Many other interiors represented as logical axial room/corridor/floor plans and tile-object records. Those are valuable source content, but are not equivalent to finished bespoke 3D room kits with walls, ceilings, stairs, furniture, collision and door meshes.
- Several exterior settlements/buildings with no interior definition at all.

**Good news:** for many ordinary buildings, the authored interior room dimensions and centres agree with the exterior footprint data. This suggests a common integration system is feasible. We should not have to redesign every building.

**Important caveat:** matching axial half-widths is a promising data-level fit, not proof that the rendered 3D shell, wall thickness, door opening, floor elevation, roof and usable walkable area all fit. A metric-space and in-engine validation pass is still required.

## 1. Current data inventory

### 1.1 Multi-story location definitions

The 71 location records group as follows:

| Group | Location records | Notes |
|---|---:|---|
| Hollowmere | 8 | Chapel, general store, elder's house, an unlabelled store, tavern, Mira's house, Oskar's house and hidden guild den |
| Emberlode | 3 | Foreman's hall, bunkhouse and three-level mine |
| Old Mac's Farmhouse | 1 | Single-room floor plan |
| Reddale | 6 | Guardhouse, reeve's house, inn, guildhouse, manor and smithy |
| Millbrook | 1 | House |
| Silverhart and its districts | 43 | Palace, shops, houses, embassies, warrens, hidden guild/vault, tunnel junctions and other district locations |
| Kragmoor | 1 | Six-level Deepholds |
| Sil'thandriel | 1 | Three-level canopy/court location |
| Thieves' Cove | 1 | Cave, lower levels and wilderness tunnel junction |
| Corvin Ashgrave Barrow | 1 | Connected cave/dungeon rooms |
| Vessel-Seeker's Crypt | 1 | Connected cave/dungeon rooms |
| Lich Chapterhouse | 1 | Single-level stone location |
| Abandoned House | 1 | Single-room house |
| Northwatch Keep | 1 | Keep interior definition |
| Ridgehold Keep | 1 | Keep interior definition |

The location registry has **89 floor definitions** in total. Nine locations have more than one floor:

- Kragmoor: floors 0, -1, -2, -3, -4 and -5.
- Emberlode Mine: floors 0, -1 and -2.
- Sil'thandriel: floors 0, 1 and 2.
- Silverhart Palace: floors 0 and 1.
- Silverhart Palace Barracks: floors 0 and 1.
- Silverhart Palace Wizard's Tower: floors 0, 1 and 2.
- Thieves' Cove: floors 0, -1, -2 and -9.
- Silverhart Palace Tunnel Junction: floors 0 and -9.
- Silverhart City Tunnel Junction: floors 0 and -9.

The 32 recorded floor transitions are concentrated in the multi-level cave/mine/canopy/building locations. The two Silverhart tunnel-junction stubs have floor -9 definitions but no ordinary stair transition in the location data; their inter-node travel is handled by the separate tunnel network.

### 1.2 Exterior building definitions

The canonical settlement layout file contains 67 records:

| Settlement | Records | Audit notes |
|---|---:|---|
| Millbrook | 1 | House |
| Emberlode | 3 | Foreman's hall, bunkhouse, mine entrance |
| Reddale | 6 | All six have corresponding single-floor room definitions |
| Old Mac's Farmstead | 1 | Farmhouse; barn is in the separate Hollowmere definition |
| Silverhart | 40 | Many corresponding floor-plan entries; some records are not yet linked by stable IDs |
| Skarn-tooth Camp | 7 | Exterior huts/campfire only; no interior records |
| Skarnak's Hold | 9 | Exterior huts/campfire only; no interior records |

Hollowmere's separate `data/settlements/hollowmere/buildings.gd` contains the general store, chapel, elder's house, Mira's house, Oskar's house, Old Mac's farmhouse and barn. The Hollow Tankard has its own authored structure/layout files. The hidden Hollowmere guild den exists in the multi-story location registry but is not in that seven-building exterior list.

The two greenskin settlement records use zero axial half-width/half-height placeholders for their hut footprints. Those values are not usable interior-fit dimensions. Only the chiefs' hut and warlord hut currently have explicit metric exterior dimensions. Do not infer interior room sizes from the zero placeholders.

### 1.3 What is actually 3D-authored?

**Bespoke 3D interior:** The Hollow Tankard. Its structure, upper storey, roof, taproom, partitions, beds and furniture are authored in dedicated files and assembled by the shared interior presenter. Its logical blocking/door/floor registration is authored separately and interpreted by the shared registrar.

**Logical floor-plan data:** Most other entries. The multi-story location registry records room centres and half-widths/heights, corridors, floor terrain, doors, stairs, props, actors and creatures. The runtime can build floor maps and present a location, but this is not proof that each location already has a finished bespoke 3D shell and furnishing set matched to its exterior mesh.

**Exterior-only:** Skarn-tooth Camp and Skarnak's Hold currently have building/site exterior records but no corresponding interior floor-plan records. The Old Mac barn is an exterior structure without a matching enterable barn interior. Several Hollowmere social-fabric residences/workplaces are described in the source design but are not all individually represented as finished 3D interiors.

## 2. Fit and coordinate findings

### 2.1 Strong evidence of compatible authored dimensions

A substantial subset of ordinary buildings has a direct or near-direct pairing between the interior room dimensions and exterior footprint:

- Emberlode foreman's hall and bunkhouse: room half-size 3×2 matches exterior half-size 3×2.
- Reddale guardhouse, reeve's house, inn, Ironbond guildhouse, Baron's manor and smithy: room half-size 3×2 matches exterior half-size 3×2.
- Millbrook house: room half-size 3×3 matches exterior half-size 3×3.
- Old Mac's farmhouse: room half-size 3×2 matches exterior half-size 3×2.
- Silverhart palace grand hall: room half-size 7×5 matches the grand-hall footprint; the queen's private chamber is a smaller room within the same authored palace location.
- Silverhart barracks: both floors use a 4×4 room matching the exterior footprint.
- Silverhart wizard's tower: all three floors use 3×3 rooms matching the exterior footprint.
- Many Silverhart shops, cottages, warrens shacks and embassies have room half-sizes matching their corresponding exterior records.

This is the strongest evidence that we can perform a data-driven placement/integration pass. The source centres also agree for most of these pairs.

### 2.2 Mismatches and unresolved pairings

These must be resolved before bulk generation:

1. **Stable-ID gaps.** Several locations appear to correspond to exterior buildings by position and naming convention, but the IDs differ (for example, numbered Silverhart cottages versus word-numbered floor-plan IDs, and the Reddale guildhouse). Coordinate proximity is useful for auditing, but must not become runtime identity. Add explicit `building_id` references.
2. **Silverhart Corvane Embassy:** floor-plan anchor is (16, -463), while the exterior building centre is (16, -462). This one-hex discrepancy needs source review; do not silently offset it.
3. **Silverhart Builder's House:** floor-plan anchor is (38, -492), while exterior centre is (38, -491). The floor definition currently has no room entries despite the exterior record. Confirm whether this is an intentional entrance/shape difference or missing room data.
4. **Silverhart Corstane Manor:** a location exists at the exterior centre but its floor currently has no room entries. It is not ready to instantiate as a walkable interior.
5. **Silverhart Palace:** the main floor contains both the grand hall and queen's private chambers. The private chamber is a separate authored room inside the palace footprint; do not mistake it for an exterior building requiring its own door.
6. **Silverhart Thieves' Guild and Vault:** the guild and vault are represented as two rooms connected within one location/floor plan, with a concealed door. This is a good continuous-world arrangement; preserve it as one connected building/interior rather than creating a separate teleport destination.
7. **Hollowmere unlabelled store at (14,0):** a logical room exists, but the current Hollowmere exterior building list does not include a matching building. The existing general store is at (0,18); do not conflate the two.
8. **Hollowmere Guild Den:** a logical interior exists at (-12,-8), but it is not in the current seven-record exterior building list. It needs a deliberate hidden entrance/exterior treatment, not a guessed ordinary house mesh.
9. **Northwatch Keep and Ridgehold Keep:** floor-location definitions exist, but the current canonical settlement building catalogue does not pair them with exterior building records.
10. **Skarn-tooth Camp and Skarnak's Hold:** exterior hut records exist but no interior plans. These are not fit failures; they are missing interior design/data.
11. **Old Mac's Barn:** the exterior exists, but the source/3D interior inventory does not define an enterable barn. Keep it exterior-only unless gameplay requires entry.
12. **Outlying Silverhart residences:** the source layout contains both named outlying house records and numbered outlying house records. Their locations need stable-ID reconciliation before deciding whether they are duplicates, aliases or distinct houses.

The full centre/footprint comparison must be validated against the source map and actual rendered geometry. A one-hex discrepancy is a hard flag, not an invitation to guess.

## 3. Transition policy recommendations

Use three categories, not one blanket rule.

### A. Ordinary buildings — convert to physical continuous-world interiors

**Recommendation: no teleport doors.**

Applies to:
- Hollowmere houses, shops, chapel, tavern, hidden guild den and farmhouse.
- Millbrook house.
- Emberlode foreman's hall and bunkhouse.
- All Reddale buildings.
- Silverhart houses, shops, embassies, palace rooms, barracks, wizard's tower, stables, manor and guild.
- Northwatch/Ridgehold keeps once their exterior definitions are paired.
- Greenskin huts once actual interior definitions are authored.

The exterior threshold, door leaf, interior floor, wall opening and interior room must occupy one coherent world coordinate system. Opening a door changes the authoritative door state; the character physically walks through it. A roof/wall cutaway or interior visibility optimisation is presentation-only.

For multi-storey ordinary buildings, use real stairs/landings and vertically aligned floor geometry. It is acceptable to stream or hide floor presentation for performance, but the stair traversal must preserve the character's physical position and not become a disguised teleport door.

### B. Caves, mines and deep dungeons — retain floor streaming; allow justified transitions

**Recommendation: keep the current multi-floor location runtime as the interim presentation/streaming model for deep subterranean sites.** A cave entrance at the surface should still look and behave like a physical cave mouth/door. Inside a large cave or mine, a floor transition may be retained where the vertical drop, winding route or change of playable region makes a single continuously rendered space impractical.

Good candidates to keep as streamed multi-floor locations:
- Kragmoor / Deepholds (six levels).
- Emberlode Mine (three levels).
- Thieves' Cove lower cave levels.
- Other deep dungeon/crypt networks if later expanded vertically.

These are not ordinary building doors. If a transition is retained, its destination, stair/shaft/ledge, height change and narrative reason should be explicit. Do not use an arbitrary transition simply because an interior was authored separately.

Corvin Ashgrave Barrow and Vessel-Seeker's Crypt are currently single-floor multi-room layouts with corridors. Keep them continuous on that floor; there is no need to introduce a teleport transition.

Lich Chapterhouse and Abandoned House are also single-floor locations. Their issue is exterior pairing/physical integration, not a need for teleporting.

### C. Special secret tunnel network — retain fast travel as a deliberate exception for now

The current `Campaign2TunnelNetwork` is a three-node Thieves' Guild fast-travel network:
- Palace passage beneath the council chamber.
- City passage behind the general goods store.
- Wilderness node at Thieves' Cove.

The palace/city surface passages are concealed `secret_passage` objects; the wilderness entry is at the cave. The three tunnel nodes are not represented as a continuous authored corridor between their distant world positions. Travel between them is a menu/network action, not an ordinary door opening.

**Recommendation:** keep this special fast-travel shortcut for now, clearly classified as a secret subterranean network. Preserve physical concealed doors at the palace/city surface entrances and a physical cave entrance at Thieves' Cove. Do not describe these as ordinary building teleport doors. A later world-map pass can replace the fast-travel links with continuous tunnel corridors if we decide the full route is worth authoring.

## 4. What can stay as-is

| System/content | Recommendation | Reason |
|---|---|---|
| Hollow Tankard authored interior data and presenter | Keep | It is the strongest complete 3D interior reference implementation |
| Ordinary door state owned by BuildingRegistry / WorldSimulation | Keep and extend | Correct shared authority; movement now has a shared route action to open unlocked doors |
| Multi-story location floor definitions | Keep as source data | They preserve authored floor plans, props, creatures, stairs and quest gates |
| Multi-story runtime floor activation | Keep as an interim streaming/presentation optimisation | It is not itself an exterior teleport; character axial position is retained while floor height/presentation changes |
| Deep cave/mine floor streaming | Keep | Sensible for large vertical spaces, subject to explicit transition points |
| Three-node Thieves' Guild tunnel fast-travel network | Keep as a named special exception | It represents a long hidden shortcut with no authored continuous corridor yet |
| Single-floor crypt/barrow corridors | Keep continuous | Existing connected room/corridor layout does not need teleporting |
| Existing authored axial centres and room dimensions | Preserve | They are source content; only correct verified discrepancies |
| Existing exterior building archetypes and meshes | Keep as exterior presentation | Reuse them; add matching interior composition rather than replacing exteriors wholesale |

## 5. Recommended implementation sequence

### Phase 1 — make the data join reliable

1. Add explicit stable `building_id` references to every ordinary-building location definition.
2. Add an explicit location-to-building/floor contract for multi-building complexes such as Silverhart Palace, where one location contains several rooms.
3. Resolve the Corvane Embassy and Builder's House one-hex anchor discrepancies against the source map.
4. Resolve the empty Corstane Manor and Builder's House floor definitions.
5. Identify the unlabelled Hollowmere store and decide how the Hollowmere guild den is represented externally.
6. Mark exterior-only buildings explicitly (for example, Old Mac's barn and greenskin huts awaiting interior authoring) rather than treating missing data as an accidental empty room.
7. Validate door thresholds against exterior door positions and room wall openings.

### Phase 2 — build a generic integration adapter

1. Use one building/floor definition as the source for exterior anchor, interior origin, floor elevation, door threshold, footprint and presentation.
2. Convert axial floor-plan cells to world positions relative to the exterior building anchor.
3. Compose floors, walls, ceiling/roof cutaways, stairs, props and collision through shared factories.
4. Keep logical walkability, occupancy, doors and line-of-sight in the shared simulation/registry.
5. Ensure no second map, duplicated character, or position relocation is introduced when entering an ordinary building.
6. Keep presentation streaming disposable and independent of save-state authority.

### Phase 3 — integrate by batches

Recommended first batch:
- Hollow Tankard (reference implementation; correct its exterior/interior registration).
- Hollowmere chapel, general store, elder's house, Mira's house and Oskar's house.
- Emberlode foreman's hall and bunkhouse.
- Reddale's six buildings.
- Millbrook house and Old Mac's farmhouse.

Second batch:
- Silverhart shops, houses, embassies, stables and guild rooms.
- Palace, barracks, wizard's tower and other multi-floor buildings with physical stairs.

Third batch:
- Northwatch and Ridgehold.
- Greenskin hut interiors once authored.
- Remaining wilderness/ruin structures and cave entrances.

Deep cave/mine streaming and the secret tunnel network can remain on their approved exception paths during these batches.

### Phase 4 — validation

Automated checks should verify:
- Every ordinary interior has exactly one valid exterior building ID.
- Interior anchor and exterior centre agree unless an explicit authored offset is present.
- Room footprint fits the building's walkable interior envelope.
- Every exterior door threshold maps to an actual interior wall opening.
- No ordinary building has a teleport/scene-relocation contract.
- Every multi-storey building has paired stair endpoints and physically coherent vertical geometry.
- Locked/closed/open/broken door states agree across movement, collision and line of sight.
- NPC/player identities, axial position, party membership, time, quests and save state survive presentation unload/reload.
- Caves and special tunnel links are explicitly typed and have tests for their permitted transition behaviour.

Visual validation should compare exterior shell, interior shell, threshold, wall thickness, stairs and roof/cutaway in Godot. Axial dimension matching alone is not a pass.

## 6. Final recommendation

Do **not** begin by moving all 71 locations into all 67 exterior records in one blind operation. There is enough matching data to make a bulk integration system worthwhile, but not enough stable identity and metric geometry validation to do it safely today.

The right approach is one shared integration system, one explicit reconciliation contract, then batch all compatible buildings through it. Preserve the authored source layouts. Only the genuine mismatches and missing interiors should need bespoke design work.

**Default rule:** ordinary buildings are continuous physical spaces. Deep caves/mines may use explicit streamed floor transitions. The Thieves' Guild tunnel network may retain its deliberate long-distance fast-travel shortcut until continuous corridors are actually authored.
