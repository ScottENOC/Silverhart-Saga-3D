# Silverhart Saga 3D — legacy porting matrix

This matrix tracks the port from the original `ScottENOC/Hex-crpg` into Godot. The original game is the behavioural reference. Do not mark a mechanic accepted until it has been compared with the original and tested in the 3D project.

Status meanings:
- **Not started** — no verified implementation.
- **In progress** — implementation exists but is incomplete.
- **Implemented / untested** — code exists; gameplay acceptance is outstanding.
- **Tested / accepted** — regression and in-game checks passed.

## Foundation

| System | Current status | Evidence / next action |
|---|---|---|
| Godot 4.7.2 project and 3D Hollowmere prototype | In progress | README describes the Hollow Tankard prototype and PC-first target. |
| Axial hex grid and six-direction movement | Implemented / untested | README reports keyboard movement and weighted click pathfinding; verify in current `dev`. |
| Terrain movement costs | In progress | Terrain multipliers and selected discounts exist; compare all legacy movement modifiers. |
| Elevation, slopes and climbing | In progress | Dedicated terrain prototype exists; validate gameplay rules and transitions. |
| Time Points and world clock | In progress | README reports TP movement, fixed-step clock and calendar; verify persistence and edge cases. |
| Save/load and world persistence | In progress | Audit current implementation and test round trips. |
| Character state and derived attributes | In progress | Combat attributes and defensive state are introduced by the PR #36 combat foundation; full legacy attribute parity remains to be audited. |

## RPG mechanics

| System | Current status | Next action |
|---|---|---|
| Turn order / initiative | In progress | Existing initiative scheduler; validate full round lifecycle. |
| Melee combat | In progress | PR #36 adds deterministic attack resolution, hit chance, damage, reduction, TP validation and defeat state; complete encounter loop. |
| Facing and flanking | Not started | `CharacterState` stores facing, but combat rules do not yet validate facing/LOS or flanking parity. Recover exact legacy rules. |
| Defensive and movement reactions | In progress | `WorldSimulation` already supports pending reactions, parry/protector-parry, shield-other, sidestep and spear intercept/halt flows; compare coverage and costs against legacy rules. |
| Ranged combat, line of sight and cover | Not started | Audit legacy rules and implement legal targeting. |
| Tactical enemy AI | Not started | Implement simulation-owned decisions and tests. |
| Status effects and conditions | Not started | Inventory original effects, duration, stacking and removal rules. |
| Skills and skill checks | Not started | Port the original catalogue and resolution rules. |
| Character experience and levelling | Not started | Recover progression curve, attributes and unlocks. |
| Magic and spellcasting | Not started | Inventory spells, costs, targets, effects and progression from legacy source. |
| Inventory, loot and equipment | In progress | `CharacterState` persists inventory/equipment instance data and `item_catalog.gd` exists; audit full item catalogue, capacity, loot and equip parity. |
| Crafting and gathering | In progress | `WildernessResourceSystem` and harvest actions exist; recipes, tools, crafting stations and full resource economy remain to port. |
| Economy and trading | Not started | Port merchant inventories, prices, buying/selling and persistence. |

## Campaign and world

| System | Current status | Next action |
|---|---|---|
| Campaign start and Hollowmere | In progress | Existing opening scene, authored NPCs, ambient chatter and a first encounter exist; connect quest and save progression end-to-end. |
| Regional map and location connections | In progress | `MainCampaignWorldMapData` currently contains six visible POIs. Original Campaign 2 geography is source-verified below; expand from real local hex coordinates, not guessed map positions. |
| Travel, encounters and region transitions | Not started | Build data-driven region records and travel simulation. |
| Dialogue and NPC interactions | In progress | Port original dialogue and choices; preserve consequences. |
| Quests and objectives | Not started | Inventory original quests, prerequisites, rewards and state transitions. |
| NPC schedules and idle chatter | In progress | Build on the previously scoped tavern routines; use local detail and aggregated distant simulation. |
| Factions, reputation and relationships | Not started | Recover faction and relationship rules from legacy source. |
| Seasons, weather and environment | Not started | Connect visual seasons to calendar and resource/world simulation. |

## Arena and audio

| System | Current status | Next action |
|---|---|---|
| Campaign / Arena mode selector | In progress | Original PR #5 remains an unmerged draft based on obsolete `main`; a clean port is open as PR #67 against current `dev`. |
| Shared combat and character systems | In progress | Arena must use the same simulation, character, inventory and progression as campaign. |
| Original arena gameplay | Not started | PR #5 explicitly describes Arena as a placeholder; port opponents, bouts, progression and rewards. |
| AudioManager and audio buses | In progress | A clean port is open as PR #67 against `dev`; validation and playback are pending. |
| Original music and voice assets | In progress | PR #67 adds the pinned importer and asset inventory. Generated Ogg files are not yet in the Pages build, so browser playback is not deployed. |
| Mode-specific audio routing | In progress | PR #67 adds mode gates; validate through Godot tests and actual playback before acceptance. |

## Character presentation and runtime

| System | Current status | Next action |
|---|---|---|
| First-run character creator | In progress | PR #29 stores a profile, but its description says the player is still a capsule and most appearance choices are not rendered. |
| Ara runtime assets | In progress | PR #36 defines a versioned runtime package and a separate integration test; run it against a newly generated package. |
| Modular clothing and equipment appearance | In progress | Connect visual slots to actual gameplay equipment state. |
| Animation and combat state integration | Not started | Connect simulation events to animation without putting rules in presentation nodes. |

## Canonical Campaign 2 geography (verified against Hex-crpg)

The source has two distinct layers which should not be conflated:

- `regions.js` defines the **security/prosperity hierarchy**: Hollowmere and Emberlode (villages) are under Aldervale (barony), which is under The Silverhart Kingdom (kingdom).
- `campaign2World.js` defines the **actual local world and POIs**. Hollowmere is the crossroads origin; the north road reaches Millbrook and then Silverhart; the west road reaches Emberlode; the east road reaches Reddale, then the Skarn-tooth goblin camp, Northwatch Fort and Ridgehold Fort at the human/orc border; the orc stronghold is Skarnak's Hold. Old Mac's Farmstead lies south of Hollowmere. Kragmoor is the Deepholds' mountain city-and-mine in the north-east. The map also includes Sil'thandriel, the elven capital.
- Additional exploration/quest sites are built in the same source: the Dragon Lair, Lich Barrow, Chapterhouse of the Silver Flame, Emberwood Grove, Thieves' Cove caves, Vampire Grave and Druid Grove. Some are deliberately unmarked.

The current Godot strategic map's six entries (Silverhart, Millbrook, Emberlode, Hollowmere, Reddale and Old Mac's Farmstead) are only the initial settlement subset. They are not the complete world. The next map port should add the missing visible POIs and represent hidden sites as discoverable content, while preserving the source road relationships and faction borders.

## Engineering rules

1. Simulation state owns rules and legal actions; 3D nodes only present state.
2. Campaign and Arena share character, combat, inventory, progression and save systems.
3. Preserve original behaviour where source content exists; document intentional deviations.
4. Use detailed simulation for nearby/relevant actors and aggregated updates for distant regions.
5. Generated Ara GLBs are pipeline artifacts, not prerequisites for ordinary Godot gameplay validation. Run Ara integration tests only when a versioned runtime package is supplied.
6. Feature work is developed on isolated branches, validated with Godot 4.7.2, then integrated into `dev`.
7. Update this matrix as work lands; do not promote an item to tested/accepted based on CI alone when in-game behaviour still needs review.

## Immediate sequence

1. Complete the clean PR #67 mode/audio foundation and verify asset delivery to the Pages build.
2. Port one end-to-end Arena bout (lobby → opponent → encounter → result/reward) using the existing shared combat simulation.
3. Audit and complete combat parity: facing/LOS/ranged, action validation, AI and encounter lifecycle.
4. Expand the campaign strategic map from the verified Campaign 2 geography above; add data-driven links and hidden-site discovery.
5. Continue inventory/progression/quests/social systems against the original source.
