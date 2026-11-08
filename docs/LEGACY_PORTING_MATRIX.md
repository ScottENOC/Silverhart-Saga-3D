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
| Facing, flanking and reactions | Not started | Recover exact legacy rules, then implement deterministic rules and tests. |
| Ranged combat, line of sight and cover | Not started | Audit legacy rules and implement legal targeting. |
| Tactical enemy AI | Not started | Implement simulation-owned decisions and tests. |
| Status effects and conditions | Not started | Inventory original effects, duration, stacking and removal rules. |
| Skills and skill checks | Not started | Port the original catalogue and resolution rules. |
| Character experience and levelling | Not started | Recover progression curve, attributes and unlocks. |
| Magic and spellcasting | Not started | Inventory spells, costs, targets, effects and progression from legacy source. |
| Inventory, loot and equipment | Not started | Port item data, slots, capacity and equip rules; connect to Ara presentation. |
| Crafting and gathering | Not started | Recover recipes, resources, tools and world interactions. |
| Economy and trading | Not started | Port merchant inventories, prices, buying/selling and persistence. |

## Campaign and world

| System | Current status | Next action |
|---|---|---|
| Campaign start and Hollowmere | In progress | Existing opening scene and NPC work; connect to complete campaign loop. |
| Regional map and location connections | Not started | Extract exact geography, location names and travel links from Hex-crpg before authoring the 3D map. |
| Travel, encounters and region transitions | Not started | Build data-driven region records and travel simulation. |
| Dialogue and NPC interactions | In progress | Port original dialogue and choices; preserve consequences. |
| Quests and objectives | Not started | Inventory original quests, prerequisites, rewards and state transitions. |
| NPC schedules and idle chatter | In progress | Build on the previously scoped tavern routines; use local detail and aggregated distant simulation. |
| Factions, reputation and relationships | Not started | Recover faction and relationship rules from legacy source. |
| Seasons, weather and environment | Not started | Connect visual seasons to calendar and resource/world simulation. |

## Arena and audio

| System | Current status | Next action |
|---|---|---|
| Campaign / Arena mode selector | Implemented / untested | PR #5 describes the selector; verify it is integrated into `dev`. |
| Shared combat and character systems | In progress | Arena must use the same simulation, character, inventory and progression as campaign. |
| Original arena gameplay | Not started | PR #5 explicitly describes Arena as a placeholder; port opponents, bouts, progression and rewards. |
| AudioManager and audio buses | Implemented / untested | PR #5 describes Music, Dialogue, SFX, Ambience and UI buses, saved levels and crossfades; verify integration. |
| Original music and voice assets | Not started | Run and verify `tools/import_legacy_audio.py`; inventory and version converted Ogg files. |
| Mode-specific audio routing | Implemented / untested | Verify Arena dialogue/music cannot leak into Campaign and vice versa. |

## Character presentation and runtime

| System | Current status | Next action |
|---|---|---|
| First-run character creator | In progress | PR #29 stores a profile, but its description says the player is still a capsule and most appearance choices are not rendered. |
| Ara runtime assets | In progress | PR #36 defines a versioned runtime package and a separate integration test; run it against a newly generated package. |
| Modular clothing and equipment appearance | In progress | Connect visual slots to actual gameplay equipment state. |
| Animation and combat state integration | Not started | Connect simulation events to animation without putting rules in presentation nodes. |

## Engineering rules

1. Simulation state owns rules and legal actions; 3D nodes only present state.
2. Campaign and Arena share character, combat, inventory, progression and save systems.
3. Preserve original behaviour where source content exists; document intentional deviations.
4. Use detailed simulation for nearby/relevant actors and aggregated updates for distant regions.
5. Generated Ara GLBs are pipeline artifacts, not prerequisites for ordinary Godot gameplay validation. Run Ara integration tests only when a versioned runtime package is supplied.
6. Feature work is developed on isolated branches, validated with Godot 4.7.2, then integrated into `dev`.
7. Update this matrix as work lands; do not promote an item to tested/accepted based on CI alone when in-game behaviour still needs review.

## Immediate sequence

1. Audit and integrate the PR #36 combat foundation after checking current PR state and checks.
2. Verify the PR #5 mode selector and AudioManager foundation.
3. Extract the original arena rules, opponent data, rewards, music and voice inventory.
4. Complete one end-to-end arena encounter using shared simulation systems.
5. Extract and document original campaign locations and their actual connections before building the regional map.
