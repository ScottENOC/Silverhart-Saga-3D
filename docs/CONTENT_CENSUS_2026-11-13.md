# Source-content census — 13 November 2026

## Purpose and scope

This is a refreshed source-to-target census for the Silverhart Saga 3D recovery/integration audit. It compares the original `ScottENOC/Hex-crpg` `main` branch with the exact current `ScottENOC/Silverhart-Saga-3D` `dev_2` head.

**Source reference:** `Hex-crpg/main`, commit `4de96f16889d43cae91e03832c8eb1c1b4b00e42` (last pushed 10 October 2026).  
**Target reference:** `Silverhart-Saga-3D/dev_2`, commit `a8b5987ebdc12b016d99e2550349f17a8fd62645` (13 November 2026).

This is a repository and implementation census, not a claim that every original gameplay rule has been exhaustively traced. The original source is the behavioural reference. The target's data, runtime, automated tests, persistence and playable/visual acceptance are assessed separately.

## Repository scale — corrected counts

| Measure | Original 2D source | Current 3D target | Interpretation |
|---|---:|---:|---|
| Tracked file blobs | 822 | 1,105 | Recursive Git trees contain directories as well as files; an earlier 893 count mistakenly included directory entries. |
| JavaScript files | 490 | — | Includes application code, tests, tooling and other JS files; not 490 gameplay systems. |
| GDScript files | — | 113 | Includes simulation, presentation, UI, world and support scripts. |
| Original Playwright test files | 206 | — | Includes one shared helper; tests cover a broad set of game behaviours. |
| Target `tests/test_*` files | — | 23 | Includes gameplay/data tests and Ara/asset pipeline checks; not all are end-to-end gameplay tests. |
| Target test/support/capture files under `tests/` | — | 31 | Includes the 23 `test_*` files plus capture, diagnostic and save-restore runner files. |

The original repository's recursive tree contained 893 entries, but 71 of those were directories. The correct tracked-file count is 822.

## Canonical content counts

| Content family | Original 2D source | Current 3D `dev_2` | Status |
|---|---:|---:|---|
| Skills | 186 direct declarations in `skills.js`; 71 additional unique generated weapon-skill entries; **257 canonical skills** | **257** entries in `data/skills/skill_definitions.json` | Catalogue data migrated. This does not establish that all skill effects work. |
| Registered base spells | **15** in `spells.js` | **15** in `data/magic/base_spells.json` | Definitions migrated; no cast/preparation/effect runtime found in the current simulation script inventory. **0/15 verified castable.** |
| Spell-learning skill definitions | `learn_*` entries in `skills.js`; 19 unlock IDs have no matching registered base spell/effect path in the inspected original magic pipeline | Skills are present in the 257-entry catalogue | Do not turn the 19 orphan source unlocks into invented spells. The original source itself is inconsistent here. |
| Equipment/item definitions | **63** in `equipment.js` | **76** in `data/items/item_definitions.json` | The target includes 13 additional clothing entries. Item definitions are not proof of complete model, icon, equip, stat and visual parity. |
| Named NPC records | **98** in the original named-NPC census | **98** in `data/characters/legacy_named_npcs.json`; **22** first-pass Hollowmere adult cast records in `hollowmere_npcs.json` | Roster data exists; not all 98 are instantiated, scheduled, voiced, quest-connected or playable. |
| Enemy/creature templates | **35** in `monsters.js` | **35** in `data/characters/legacy_enemy_roster.json` | Roster records exist; species-specific AI, combat abilities, presentation and encounter integration are not complete. |
| Arena content | Source arena content and scenarios in the original game | 18 opponent-pool entries, 6 beast-pool entries, 8 scenario types and 3 lobby NPC records | Data exists; target UI remains an arena placeholder and a complete bout loop is not implemented. |

Counts were read from the source files and current target JSON, not copied from the older `docs/content-census` branch. In particular, the target skill JSON records 257 entries and explicitly documents the generated-skill expansion.

## Campaign 2 and world geography

The source campaign is not just a single village map:

- The original Campaign 2 strategic map is 16×16. The local world is continuous and uses 130 local hexes per strategic cell as a scale reference.
- The source's main world bootstrap is in `campaign2World.js` (about 334 KB); authored content and dialogue are in `campaign2Content.js` (about 55 KB) and `campaign2Dialogue.js` (about 356 KB).
- The original source includes Hollowmere and a network of named settlements, forts, faction holdings, dungeons, quest sites, roads, rivers and other locations. The prior source extraction in `docs/campaign2_source_inventory.md` records verified coordinates and relationships.
- Current 3D `data/world/campaign2_geography.json` contains **24 location records and 22 connections**. `campaign2_settlement_layouts.json` currently contains **one settlement layout**.
- PR #125 brought across source-derived geography, road paths, settlement manifests/builders, terrain data and macro/regional preview scenes. Those previews and manifests are development/authoring foundations, not proof that all locations are built as navigable, populated, persistent 3D settlements.
- Hollowmere is the current playable world focus. The broader continuous world, settlement interiors, services, quest paths, schedules and travel relationships are not complete.

**Classification:** Campaign 2 geography and location identity are substantially represented as data; full playable world parity is not.

## Implementation census by system

### Core simulation and combat

**Present in `dev_2`:**
- Axial hex grid, logical map data, weighted pathfinding and terrain-aware movement costs.
- World clock/calendar foundation and Time Point/action-economy rules.
- Character state, initiative scheduling, deterministic attack resolution and combat lifecycle foundations.
- Typed simulation action request/result/event structures.
- Several defensive/movement reaction paths: Parry, Protector Parry, Shield Other, Spear Intercept, Spear Halt and Sidestep.
- Downed/unconscious/true-death state handling and an initial status-effect framework.
- Spatial vision and hex line-of-sight foundations.

**Still materially incomplete against the source:**
- Full action costs/regeneration/tick lifecycle and all source-derived combat rules.
- Weapon readiness, all attack types/ranges, criticals, facing/flanking, ranged combat, cover and complete height-aware targeting.
- Full tactical AI, combat directives, group tactics, retreat/morale, creature-specific abilities and complete encounter start/end/loot handling.
- General forced movement/control effects, all status effects and their stacking, duration, dispel, resistances and persistence rules.
- Complete stealth detection, persistent hidden/suspicion state, observer-specific knowledge and AI response. Vision/LOS foundations are not a complete stealth system.

### Skills and progression

**Present:** canonical 257-skill JSON catalogue, catalogue loader/validation, skill purchase eligibility/prerequisites/point accounting, NPC rank allocation and persistence of skill ranks.

**Not equivalent to full parity:** skill rank storage and catalogue presence do not prove the original `apply()` hooks or gameplay effects have been ported. The existing skill-effect audit reports 17 verified effect tests, 5 partial effects and many unverified entries, but that audit explicitly uses an older `dev` baseline. Treat those counts as provisional until rechecked against this exact `dev_2` head. The current 3D implementation should not advertise all 257 skills as working.

### Magic

**Present:** 15 registered base spell definitions and character fields for spell-related state.

**Missing:** a complete spell preparation/variant builder, learn/unlock integration, cast request and target validation, mana/TP payment, spell effect handlers, active-effect duration/upkeep/cancellation, Counterspell and other casting reactions, save/load lifecycle, and NPC spell planning. The current target's script inventory contains no spell-casting resolver. The 19 orphan `learn_*` source unlocks without registered source spells remain excluded.

### Inventory and equipment

**Present:** 76 target item definitions, persistent per-character item instances, equip/unequip foundations, Character/Inventory panel, migrated SVG icon atlas, supported weapon/armour combat metadata, and initial Ara garment visibility mapping.

**Incomplete:** full source party-shared inventory, all stacking/container/currency/loot/shop behaviours, complete equipment readiness and encumbrance, full helmet/barding/accessory handling, and verified item-by-item 3D visual/stat parity. The existing equipment audit explicitly says no held weapon, shield, armour piece or clothing item has yet been verified complete across source art, installed runtime asset, equip display and stat/effect integration.

### Creatures and mounts

**Present:** the 35-entry legacy enemy roster as data; animal profiles for the currently supported animal assets; animal registration, save/restore and riding simulation foundations have been selectively integrated. PR #130 adds mount controls and rider presentation but remains a draft and awaits PC visual acceptance.

**Incomplete:** all 35 original creature templates as working combatants, their special abilities/AI/encounters, full rider-size and mounted-combat rules, mounted NPC archetypes and source Riding skill parity. A mount model/profile or a roster JSON row is not a complete creature implementation.

### Campaign, dialogue, quests and relationships

**Present:** 98 named-NPC roster records, 22 Hollowmere cast records, Hollowmere opening/shakedown branches, a simulation-owned campaign journal, initial ambient chatter, farm/wildlife quests and the Tessa rescue / Reyna dire-wolf quest.

**Incomplete:** broad campaign dialogue and quest migration, reusable dialogue conditions/skill checks/command effects, all companion arcs and relationship/romance/world-agency systems, NPC schedules and persistent routines, full faction knowledge/standing rules, and campaign-wide consequence chains. A journal data record is not proof that the quest is playable end-to-end.

### Living world, economy and player activities

**Present:** world clock/calendar, initial wilderness resource harvesting, seasonal presentation, local Hollowmere geography and selected world/animal actors.

**Missing or only foundational:** source regional security/prosperity cascades, autonomous world pulse/events, caravans and persistent road travellers, wilderness faction beliefs/incidents/consequences, shops/hours/markets/trading, full crafting and recipes, farming, player construction/property, camp deployment, expedition logistics, traps, espionage/infiltration and disguise mechanics. The original has dedicated modules and regression tests for these systems; they should be treated as distinct port families, not assumed to follow from the world clock or resource-harvest foundation.

### Arena, audio and persistence

**Arena:** opponent/beast/scenario/lobby data is present, but the target arena screen is a placeholder; no complete lobby → opponent selection → bout → result/reward loop is accepted.

**Audio:** an AudioManager and import/workflow foundations exist. Asset delivery and actual browser/Pages playback still require separate verification; source audio files existing in the old repository does not prove that the target deployment includes them.

**Persistence:** SaveManager, multiple manual slots, quicksave/autosave and character/world-clock serialization foundations exist. This is not yet whole-world persistence for every source system: quests, relationships, faction/region state, schedules, events, map diffs, containers, active encounters and other world state need explicit round-trip coverage.

## Test parity

The original source contains **206 Playwright test files** covering areas including combat, spells, skills, quests, factions, companions, schedules, world pulse, wilderness, shops, farming, crafting, sieges, persistence, geography and rendering.

The current target contains **23 `tests/test_*` files** plus eight capture/diagnostic/save-restore support files. These target tests cover useful foundations such as simulation, save management, Hollowmere, Campaign 2 manifests/roads/settlements, farm wolves, building framework, NPC pass-through, seasonal trees and Ara assets. They are not a one-to-one migration of the original 206 tests and do not establish equivalent behavioural coverage.

Prioritise translating source assertions into deterministic GDScript tests for:
1. combat action legality, facing/range/cover/LOS and status lifecycle;
2. skill effects and skill unlock/progression interactions;
3. spell learning, casting, cost, effects and persistence;
4. quests/dialogue consequences and companion/faction state;
5. regional/world pulse, schedules, caravans, wilderness and economy;
6. crafting, traps, camps, farming, construction and trade;
7. campaign geography, settlement access and quest-location connectivity.

## How to read this census

Every system must be tracked across separate evidence layers:

1. **Source content:** original definitions, data, dialogue, map/coordinates and tests.
2. **3D data migration:** corresponding JSON/Resources and stable identifiers.
3. **Runtime implementation:** GDScript rules and services that consume the data.
4. **Automated validation:** tests exercise actual behaviour and boundary cases.
5. **Persistence:** state survives save/load and scene/chunk transitions.
6. **Playable/visual acceptance:** the system works in the running game; CI alone is not visual acceptance.

Do not combine these layers into a single “ported” checkbox. Keep source records and feature branches preserved even when their current implementation is superseded.

## Evidence and limitations

- Original source counts: recursive Git tree at `Hex-crpg` commit `4de96f16889d43cae91e03832c8eb1c1b4b00e42`; source files `skills.js`, `spells.js`, `monsters.js`, `equipment.js`, and `tests/`.
- Target counts: recursive Git tree at `Silverhart-Saga-3D` commit `a8b5987ebdc12b016d99e2550349f17a8fd62645`; JSON catalogues and GDScript/test paths on `dev_2`.
- The source repository's recursive tree has 893 entries, including directories; it contains 822 file blobs. Do not report 893 as the tracked-file count.
- Existing detailed audits cited above were written against earlier `dev` baselines. Their detailed effect-level findings remain useful research, but any claim about current runtime behaviour must be rechecked on `dev_2`.
- This census is a prioritisation and parity baseline, not exhaustive per-line review of all 490 JavaScript files or all 206 source tests. It identifies high-confidence catalogue counts and major implementation boundaries, and names the next source-test families to translate.
