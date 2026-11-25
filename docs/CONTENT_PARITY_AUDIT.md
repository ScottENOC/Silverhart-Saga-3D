# Silverhart Saga 3D — 2D Content Parity Audit

**Audit date:** 2026-11-10  
**Audit branch:** `docs/content-parity-audit` (based on `dev`)  
**Reference game:** [ScottENOC/Hex-crpg](https://github.com/ScottENOC/Hex-crpg)  
**Port:** [ScottENOC/Silverhart-Saga-3D](https://github.com/ScottENOC/Silverhart-Saga-3D)

## Purpose

This is the content-completeness companion to [LEGACY_PORTING_MATRIX.md](LEGACY_PORTING_MATRIX.md) and [MECHANICS_PORT_REGISTER.md](MECHANICS_PORT_REGISTER.md).

The goal is approximately **99% content and gameplay parity** with Hex-crpg, while allowing deliberate 3D adaptations where appropriate (for example, stairs, upper floors, building interiors, camera and interaction presentation). This is not a requirement to reproduce the old JavaScript architecture or its 2D rendering.

This is an initial repository/source audit, not a claim that every listed feature has been manually tested in a running build. Existing code, data, tests and the current porting documents were inspected. Items are not accepted merely because an asset, data file or stub exists.

## Status vocabulary

- **Not started:** no meaningful 3D implementation identified.
- **Partial / in progress:** some content or mechanics exist, but source parity or a complete playable loop is missing.
- **Implemented, needs verification:** implementation is present; source comparison and in-game acceptance are outstanding.
- **Content not yet audited:** the source contains a substantial catalogue that needs a systematic item-by-item inventory.
- **Accepted:** only after source behaviour/content has been compared, tests pass, persistence works, and the feature is playable in 3D.

---

# 1. Existing project tracking

The 3D repository already contains useful tracking documents:

- `docs/LEGACY_PORTING_MATRIX.md` — high-level system-by-system status and immediate priorities.
- `docs/MECHANICS_PORT_REGISTER.md` — detailed mechanics backlog, implementation notes and source modules.
- `docs/MIGRATION_MAP.md` — migration architecture.
- `docs/MAIN_CAMPAIGN_WORLD_MAP_PLAN.md` — campaign map plan.
- `docs/AUDIO_MIGRATION.md` — audio migration.
- Character, terrain, wilderness and village design documents under `docs/`.

The original 2D repository also has `TASKS.md`, `ROADMAP.md`, `VISUAL_ROADMAP.md` and `COMPLETED_TASKS.md`. These describe the original game's own ongoing work; they are not a 3D port checklist.

**Branch caution:** the 3D repository's default `main` branch is an early scaffold. This audit uses the much more developed `dev` branch. Always state the audited branch when reporting status.

---

# 2. World, geography and exploration

## Present in 3D (partial)

- Axial hex-grid logic and six-direction movement.
- Weighted A* click-to-move and keyboard-adjacent movement.
- Terrain-aware movement costs and initial elevation/slope work.
- A 3D Hollowmere / Hollow Tankard starting area.
- A separate elevation prototype with valley, slope and ridge/escarpment tests.
- Initial 16×16 strategic campaign reference map.
- Main campaign map data currently has six visible settlement/location entries: Silverhart, Millbrook, Emberlode, Hollowmere, Reddale and Old Mac's Farmstead.
- Terrain/resource visual foundations and seasonal tree presentation.

## Missing or incomplete

- [ ] Full original Campaign 2 local-world geography and all connected road networks.
- [ ] Remaining visible locations and their actual source hex positions, road links and faction borders.
- [ ] Hidden/discoverable sites and discovery rules.
- [ ] Regional transitions and playable travel between locations.
- [ ] Fog of war, explored/known map state and knowledge-aware routing parity.
- [ ] Full terrain catalogue, terrain interactions, obstacles and object placement.
- [ ] Full map objects: doors, walls, furniture, containers, traps, harvestables, cover and interactive scenery.
- [ ] Complete building catalogue and interiors, including enter/exit, doors, floors and upper levels.
- [ ] Stairs, ladders, climbing, ledges, falling and fall damage.
- [ ] Height-aware line of sight, ranged targeting and cover.
- [ ] Rivers, bridges, streams, water crossings and terrain hazards.
- [ ] Road travel, long-distance route selection and travel encounters.
- [ ] World chunk streaming / large-world performance and persistence strategy.
- [ ] Full world map POI discovery, visited/known state and map annotations.

## Source geography that must not be lost

The source's regional hierarchy is Hollowmere and Emberlode under Aldervale, under the Silverhart Kingdom. Campaign 2 local geography includes:

- Hollowmere (crossroads origin)
- Millbrook and Silverhart to the north
- Emberlode to the west
- Reddale to the east
- Skarn-tooth goblin camp
- Northwatch Fort and Ridgehold Fort
- Skarnak's Hold (orc stronghold)
- Old Mac's Farmstead to the south
- Kragmoor (Deepholds mountain city and mine)
- Sil'thandriel (elven capital)

Additional sites include Dragon Lair, Lich Barrow, Chapterhouse of the Silver Flame, Emberwood Grove, Thieves' Cove caves, Vampire Grave and Druid Grove. Some are intentionally unmarked and should be discovered rather than simply displayed from the start.

The six current strategic-map entries are an initial subset, not the complete world.

---

# 3. Buildings, settlements and interiors

## Present in 3D (partial)

- Hollow Tankard tavern blockout and access.
- Hollowmere village blockout and authored data.
- Initial building/interior work and roof visibility concept.
- Main campaign map settlement references.

## Missing or incomplete

- [ ] Audit every original enterable building and map it to a 3D building/interior.
- [ ] Openable doors and reliable enter/exit transitions for all appropriate buildings.
- [ ] Interior rooms, furniture, containers, usable objects and NPC placement.
- [ ] Upper floors, stairs/ladders and vertical navigation.
- [ ] Roof hide/show behaviour for all applicable buildings, not only the tavern.
- [ ] Shops and service interiors with functional interaction.
- [ ] Inns/taverns, beds, resting and time advancement.
- [ ] Forts, keeps, castles, palace and dungeon interiors.
- [ ] Building damage, locked doors, keys, traps and access conditions.
- [ ] Settlement population, street dressing and district identity.
- [ ] Correct visual and collision integrity: enclosed rooms, floors, wall rings and door openings.
- [ ] Settlement changes reflecting prosperity, security, faction control and quest outcomes.

Background buildings may use simpler interiors or remain locked where the original game does not support entry. Do not build empty interiors just to tick a box.

---

# 4. Characters, NPCs and creatures

## Present in 3D (partial)

- Ara modular character runtime and character presentation integration.
- Female and male Ara body assets; hair, appearance and modular clothing pipelines.
- Character creator foundation.
- Data-backed legacy named NPC and enemy roster files.
- Hollowmere NPCs and authored loadouts.
- Initial ambient chatter for a subset of Hollowmere residents.
- Seasonal trees and wilderness resource visuals.
- Creature asset imports and a growing creature asset library.

## Missing or incomplete

- [ ] Full named NPC census from all original campaign locations.
- [ ] Every original NPC's identity, appearance, race, class, attributes, skills, equipment and faction.
- [ ] Correct 3D visual identity for important named characters, not generic placeholders.
- [ ] Complete civilian population and visual diversity.
- [ ] NPC persistence independent of whether their 3D actor is loaded.
- [ ] NPC daily schedules: sleep, work, shop, tavern, patrol, travel and home.
- [ ] NPC routines while the player is away; correct simulation when the player returns.
- [ ] NPC perception, hostility, detection, investigation and combat behaviours.
- [ ] Guard, patrol, merchant, civilian, animal and faction-specific behaviours.
- [ ] Full enemy and monster roster, including source statistics and abilities.
- [ ] All animal species and appropriate movement/behaviour.
- [ ] Animal interactions, taming/ownership where applicable, and mounts/riders.
- [ ] Mounted movement, mounted combat and dismounting.
- [ ] Summoned creature catalogue and persistence/upkeep behaviour.
- [ ] Children/family population systems where present in the source.
- [ ] NPC progression policies and persistence of changed NPC state.
- [ ] NPC equipment appearance, clothing identity and disguise interactions.

## Character creator parity

The source includes five races and six classes. Initial source-backed race/class creation is present in 3D, but the following need completion and acceptance:

- [ ] All original race/class choices and exact starting modifiers.
- [ ] Full attribute allocation and derived statistics.
- [ ] Appearance options and rendered preview for all supported body types.
- [ ] Hair, skin, eye, facial hair, body markings and equipment choices.
- [ ] Full class starting kits and equipment visuals.
- [ ] Save/load of the complete player appearance and build.
- [ ] NPC/player use of the same modular character and equipment systems where appropriate.

---

# 5. Combat and tactical rules

## Present in 3D (partial)

- Highest-Time-Point initiative foundation.
- Initial deterministic melee attack resolution.
- Hit chance, damage, reductions and TP spending foundation.
- Downed/unconscious and true-death thresholds.
- Initial Parry, Protector Parry, Shield Other, Spear Intercept, Spear Halt and Sidestep reaction flows.
- Shared simulation action request/result/event foundation.
- Hollowmere opening fight connected to the simulation combat engine.

## Missing or incomplete

- [ ] Full original attack catalogue and weapon-specific attack rules.
- [ ] Weapon readiness, drawing, sheathing, disarming and re-arming.
- [ ] Facing, flanking, rear attacks and directional combat modifiers.
- [ ] Ranged weapons, ammunition, range and projectile behaviour.
- [ ] Line of sight, cover and height-aware targeting.
- [ ] Critical hits, misses and all source-specific hit/damage modifiers.
- [ ] Complete TP costs, regeneration and turn lifecycle.
- [ ] Every defensive reaction, trigger condition, cost, limit and interruption.
- [ ] Forced movement, knockback, movement interruption and collision rules.
- [ ] Full status effects, stacking, duration, resistance, cleansing and periodic ticks.
- [ ] Tactical enemy AI: perception, target choice, attack, movement, retreat and spell choices.
- [ ] Faction/relationship-aware hostility and combat avoidance.
- [ ] Encounter start/end conditions, reinforcements, victory/defeat and cleanup.
- [ ] Downed recovery, death, corpse, loot and companion/NPC consequences.
- [ ] Traps, environmental hazards and combat interactions.
- [ ] Summoned units and flying-unit combat rules.
- [ ] Full combat animation, hit reactions, death animation, sound and visual effects.

The first attack resolver and reaction system are foundations, not a complete combat port.

---

# 6. Skills, attributes and progression

## Present in 3D (partial)

- Initial race/class attribute pools and class-level markers.
- Initial level/XP fields and mana caps.
- Character creation difficulty modifiers.
- Basic character panel and initial inventory/equipment integration.

## Missing or incomplete

- [ ] Complete original attribute list and formulas for derived stats.
- [ ] Complete skill tree catalogue, grouped by race, class, weapon and other categories.
- [ ] Every skill rank, cap, prerequisite, point cost and effect.
- [ ] Skill unlocks and progression rules.
- [ ] XP awards and level-up thresholds.
- [ ] Attribute/skill point allocation on level-up.
- [ ] NPC progression modes and policies.
- [ ] Respec and difficulty-dependent progression.
- [ ] All passive, triggered and reaction skills.
- [ ] Skill checks in dialogue, exploration, stealth, crafting and combat.
- [ ] Skill effects connected to all relevant world actions.
- [ ] Save/load and UI for full character progression.

---

# 7. Magic and spellcasting

**Assessment: major system not yet ported.**

The original source contains separate spell catalogues, spell planning and upkeep behaviour, including summons and multi-target modifiers.

- [ ] Full spell catalogue and spell metadata.
- [ ] Spell schools/trees and class/race access.
- [ ] Spell learning and progression.
- [ ] Mana costs, regeneration, upkeep and cancellation.
- [ ] Targeting, range, line of sight and area effects.
- [ ] Cast interruption and reactions.
- [ ] Multi-target/fork mechanics.
- [ ] Summoning and summon lifecycle.
- [ ] Damage, healing, buffs, debuffs and status effects.
- [ ] Utility spells for concealment, illusion, divination, communication, influence, investigation and transformation.
- [ ] Spells that affect terrain, travel, doors, traps, NPCs and world state.
- [ ] AI spell selection and enemy spell behaviour.
- [ ] Spell UI, feedback, audio and animations.
- [ ] Persistence of active effects and summons.

Magic must be ported as world interaction verbs, not merely a list of combat damage buttons.

---

# 8. Inventory, items, equipment and economy

## Present in 3D (partial)

- Initial 63-item legacy catalogue data migration.
- Persistent item instances and equipment slot operations.
- Character/inventory panel foundation.
- Initial source-backed character equipment and NPC loadouts.
- Ara modular clothing and equipment appearance pipeline.
- Initial armour/weapon metadata affecting combat and movement.

## Missing or incomplete

- [ ] Verify every original item, including all metadata, icons and descriptions.
- [ ] Complete shared party inventory/pool rules.
- [ ] Stack sizes, splitting, merging and item identity.
- [ ] Currency and gold handling across all systems.
- [ ] Loot drops and container contents.
- [ ] Full shop catalogue, stock, prices and buying/selling.
- [ ] Merchant restocking and shop persistence.
- [ ] Equipment readiness and all equip/unequip restrictions.
- [ ] Complete equipment slots and item compatibility.
- [ ] Weight, encumbrance and capacity effects.
- [ ] Item durability/condition or other source-specific state, if applicable.
- [ ] Equipment identity and disguise/social effects.
- [ ] Weapon, armour, clothing and accessory visuals for all relevant items.
- [ ] Dyes, appearance customisation and modular layering.
- [ ] Complete save/load of inventory, containers, shops and equipment state.

---

# 9. Dialogue, quests and story content

## Present in 3D (partial)

- Hollowmere opening / Ironbond shakedown dialogue.
- Initial branching player choices and social consequences.
- Initial quest journal and staged objectives.
- Initial faction-standing changes.
- First group of Hollowmere NPC talk interactions.
- Ambient chatter for a limited set of NPCs.
- Campaign journal foundations.

## Missing or incomplete

- [ ] Full dialogue census from original dialogue modules.
- [ ] Every named NPC conversation, topic, greeting and follow-up.
- [ ] Reusable dialogue graphs with conditions, checks and command effects.
- [ ] Dialogue skill checks and alternative non-combat solutions.
- [ ] Dialogue hearing/range and social-facing rules.
- [ ] Full quest census: main, side, companion, faction, wilderness and hidden quests.
- [ ] Quest prerequisites, branches, objectives, timers, rewards, failure and replay consequences.
- [ ] Full journal history and objective tracking.
- [ ] All campaign chapters and character story arcs.
- [ ] Dialogue and quest consequences on NPCs, factions, regions, shops and world state.
- [ ] Quest item and evidence handling.
- [ ] Hidden discoveries, clues and investigation.
- [ ] Story event sequencing and save-safe progression.
- [ ] Full narrator/ambient dialogue integration.
- [ ] Dialogue presentation, portraits, voice playback and subtitles.

The first Hollowmere quest is a vertical slice, not evidence that the original campaign's full story has been migrated.

---

# 10. Companions, relationships and romance

**Assessment: major content and simulation gap.**

The original has many dedicated modules for companion relationships, affinity, personality, dialogue memory, agency, progression and quest chains.

- [ ] Full companion roster and recruitment.
- [ ] Companion party membership and party management.
- [ ] Companion combat builds, equipment and progression.
- [ ] Affinity and relationship progression.
- [ ] Companion-specific personality and preferences.
- [ ] Contextual banter and party conversations.
- [ ] Conversation memory and knowledge.
- [ ] Reactions to major quest decisions.
- [ ] Companion world agency and autonomous behaviour.
- [ ] Companion quest chains and personal story arcs.
- [ ] Relationship moments and progression milestones.
- [ ] Romance and relationship-choice systems.
- [ ] Triad conversations and supported relationship configurations.
- [ ] Physical affection interactions where supported by the original.
- [ ] Companion reactions to disguise, appearance and equipment.
- [ ] Relationship and companion state persistence.

Important source module families include `companionRelationships`, `companionAffinity`, `companionWorldAgency`, `companionQuestChains`, `companionRomance`, `companionConversationMemory` and the contextual/personality dialogue modules.

---

# 11. Factions, reputation and politics

## Present in 3D (partial)

- Initial faction-standing ledger in the campaign journal.
- Initial Hollowmere shakedown reputation consequences.
- Source geography and faction-border references.

## Missing or incomplete

- [ ] Full original faction roster and relationships.
- [ ] All faction standing dimensions and starting values.
- [ ] Reputation thresholds, hostility and access gates.
- [ ] Regional security, prosperity and other statistics.
- [ ] Cascading consequences between NPC, settlement, barony and kingdom.
- [ ] Faction beliefs, knowledge and political state.
- [ ] Recruitment, faction equipment and faction-specific merchants.
- [ ] Disguise and identity-based faction access.
- [ ] Faction quests and branching story outcomes.
- [ ] Faction control changes and territorial consequences.
- [ ] Sieges, fort attacks, defenders, siege equipment and triggers.
- [ ] Persistent faction state in save/load.

---

# 12. Living world, time, weather and environment

## Present in 3D (partial)

- Fixed-step world clock and 12-month calendar foundation.
- Initial TP regeneration/action timing.
- Seasonal tree visuals.
- Initial NPC ambient chatter.
- Wilderness resource system and visuals.
- Initial wilderness world foundation.

## Missing or incomplete

- [ ] Complete source time progression and action-specific time costs.
- [ ] Sleep/rest and time advancement.
- [ ] Full world tick pipeline: health, mana, status effects, upkeep, NPC schedules and events.
- [ ] Day/night lighting and gameplay effects.
- [ ] Weather and seasonal simulation.
- [ ] Seasonal resource and environmental changes.
- [ ] NPC daily routines and persistent road travellers.
- [ ] Physical caravans and travelling merchants.
- [ ] Wilderness incidents and autonomous encounters.
- [ ] Bandit camps and repopulation.
- [ ] World rumours and local information networks.
- [ ] Regional prosperity/security effects visible in settlements.
- [ ] Guards responding to world events and security.
- [ ] Cleared-area persistence and world reactivity.
- [ ] Distant-world simulation and actor activation/culling.
- [ ] World event persistence and save/load.

---

# 13. Gathering, crafting, farming, construction and camps

## Present in 3D (partial)

- Initial wilderness resource nodes and harvesting system.
- Initial gathering interaction and resource visuals.

## Missing or incomplete

- [ ] Complete resource catalogue and harvesting rules.
- [ ] Resource respawn/regrowth and seasonal rules.
- [ ] Tools and equipment requirements.
- [ ] Crafting recipes and stations.
- [ ] Crafting outputs, costs and skill modifiers.
- [ ] Farming, planting, tending, harvesting and persistence.
- [ ] Construction/building system.
- [ ] Camp deployment, camp upgrades and camp lifecycle.
- [ ] Expeditions and resource processing.
- [ ] Player property and settlement construction.
- [ ] Trade and resource economy integration.
- [ ] NPC/faction use of these systems.

---

# 14. Arena mode

## Present in 3D (partial)

- Main menu separates Campaign and Arena selection.
- Arena placeholder scene and UI.
- Arena opponent data foundation.
- Shared combat and character systems are intended to underpin both modes.

## Missing or incomplete

- [ ] Arena lobby and full entry flow.
- [ ] Opponent selection and original opponent roster.
- [ ] Arena bouts, rules and encounter generation.
- [ ] Arena combatants and source-specific builds.
- [ ] Victory/defeat results.
- [ ] Rewards, gold, equipment and progression.
- [ ] Return-to-lobby and repeat-bout loop.
- [ ] Original arena dialogue and announcer/narrator sequences.
- [ ] Arena music, stingers and sound effects.
- [ ] Persistence of arena progression.
- [ ] Complete end-to-end acceptance: lobby → bout → result/reward → lobby.

Arena is not complete simply because a menu option and placeholder scene exist.

---

# 15. Audio, music and presentation

## Present in 3D (partial)

- AudioManager foundation.
- Audio migration document and import tooling.
- Original audio asset inventory/import work.
- Ara character presentation and modular appearance.
- 3D terrain, camera and seasonal visual foundations.

## Missing or incomplete

- [ ] Verify all original music, dialogue and effects assets are imported and delivered in builds.
- [ ] Verify browser/Pages deployment includes generated audio assets.
- [ ] Mode-specific audio routing.
- [ ] Campaign location, time, faction, stealth, threat and combat music states.
- [ ] Arena music and stingers.
- [ ] Dialogue voice playback and subtitles.
- [ ] Footsteps, movement, doors, interaction and environmental ambience.
- [ ] Combat, weapon, spell, hit, parry and death effects.
- [ ] Volume controls and audio settings.
- [ ] Animation state integration for movement, combat, interaction and social scenes.
- [ ] UI feedback, visual effects and transitions.

---

# 16. UI, controls, settings and accessibility

## Present in 3D (partial)

- Main menu and mode selection.
- Character creator and character panel foundations.
- Inventory panel.
- Reaction prompt.
- Mouse/keyboard movement and orbit camera.
- Initial web preview/Pages workflow.

## Missing or incomplete

- [ ] Full character sheet and skill/attribute screens.
- [ ] Full inventory, party inventory and equipment management UI.
- [ ] Spellbook and skill-tree interfaces.
- [ ] Quest journal and dialogue UI.
- [ ] World map, travel and discovery UI.
- [ ] Shop/trade, crafting and resource interfaces.
- [ ] Party and companion management.
- [ ] Faction/reputation information.
- [ ] Combat action controls, target selection and turn/TP feedback.
- [ ] Settings, graphics, audio and input configuration.
- [ ] Save slots, load, delete and recovery UI.
- [ ] Tooltips, tutorials and contextual interaction prompts.
- [ ] Touch/mobile controls and responsive layouts if mobile remains a target.
- [ ] Accessibility options and readable UI scaling.
- [ ] Full controller support if required by target platforms.

---

# 17. Persistence, save/load and reliability

**Assessment: incomplete.**

The current documentation describes character/world-clock dictionary serialisation, not a complete campaign save system.

- [ ] Versioned save schema and migration.
- [ ] Player identity, appearance, stats, skills and progression.
- [ ] Party and companion state.
- [ ] Inventory, equipped items, containers and currency.
- [ ] NPC state, schedules, positions, deaths and relationships.
- [ ] Quests, decisions, dialogue history and journal.
- [ ] Factions, reputation and regional state.
- [ ] World terrain changes, doors, objects and building state.
- [ ] Explored/known map and discovered POIs.
- [ ] Time, weather, seasons and world event queue.
- [ ] Shops, crafting, camps, resources and player property.
- [ ] Arena progression and campaign state.
- [ ] Round-trip tests for complete world state.
- [ ] Recovery from interrupted or invalid saves.

---

# 18. Original source content inventory still to enumerate

The source repository has a large set of dedicated modules. These are useful audit entry points, not a claim that each file represents one standalone feature.

| Source area | Important reference modules |
|---|---|
| Core simulation | `gameEngine.js`, `entities.js`, `terrain.js`, `hexMap.js`, `worldTime.js` |
| Combat | `weaponReadiness.js`, `trapSystem.js`, `combatFX.js` |
| Skills and magic | `skills.js`, `spells.js`, `spellPlanner.js` |
| Character/equipment | `characterCreation.js`, `equipment.js`, `partyInventory.js`, `clothingSystem.js`, `physicalWearables.js` |
| Dialogue/quests | `dialogue.js`, `campaign2Dialogue.js`, `questLog.js`, `ordinaryDialogueConsequences.js`, `leverage.js` |
| Stealth/disguise | `disguiseSelfSystem.js`, `disguiseDialogueSystem.js`, `espionageQuests.js` |
| Party/companions | `roster.js`, `companionRelationships.js`, `companionAffinity.js`, `companionWorldAgency.js`, `companionQuestChains.js` |
| NPCs | `npcProgression.js`, `npcRoutineScheduler.js`, `civilianPersistence.js`, `persistentRoadTravellers.js` |
| World/politics | `factions.js`, `regions.js`, `worldPulse.js`, `wildernessLivingWorld.js`, `wildernessConsequences.js` |
| Economy/activities | `resources.js`, `crafting.js`, `construction.js`, `campSystem.js`, `expeditionSystem.js` |
| Campaign content | `campaign2Content.js`, `campaign2World.js`, `campaign2Dialogue.js` plus dedicated character/quest arc modules |
| Audio | `audio.js`, `musicDirector.js` |

A subsequent content census should enumerate exact records, not just modules:
- every race/class and skill;
- every spell;
- every item and equipment variant;
- every creature and named NPC;
- every location, building and interior;
- every quest, dialogue branch and companion arc;
- every faction and reputation dimension;
- every resource, recipe, shop and service;
- every audio track, voice line and effect.

---

# 19. Recommended order of work

This order prioritises reusable systems and end-to-end playable slices rather than creating large amounts of disconnected content.

1. **Finish the simulation kernel:** tick pipeline, action contract, character state, save/load and movement/elevation rules.
2. **Finish one complete combat loop:** weapon readiness, facing, range, LOS, cover, AI, reactions, status effects, encounter lifecycle and loot.
3. **Finish the Hollowmere opening:** complete village navigation/buildings, NPC interactions, branching opening, combat/non-combat consequences and persistence.
4. **Complete character and equipment parity:** full player/NPC data, attributes, progression, inventory and equipment visuals.
5. **Port magic and skills:** source-backed catalogues and effects integrated into combat, dialogue and exploration.
6. **Expand campaign geography:** all settlements, forts, dungeons, roads, hidden sites and travel.
7. **Port the story and social systems:** quests, dialogue, factions, companions and relationship arcs.
8. **Build the living world:** schedules, travellers, rumours, regional state, weather, resources and autonomous events.
9. **Port economy and player activities:** shops, trade, gathering, crafting, farming, camps and construction.
10. **Complete Arena mode:** full lobby/bout/reward loop using shared simulation.
11. **Complete audio, presentation and UI:** all original assets and game feedback integrated.
12. **Run a full parity acceptance pass:** compare every source catalogue and important gameplay path, then close remaining gaps.

---

# 20. Definition of 99% parity

A feature is not complete because its script exists, its asset imports, or its UI control is visible.

For each feature/content record:

1. The original source behaviour or authored content is identified.
2. A 3D implementation or documented 3D equivalent exists.
3. It is connected to the relevant simulation, UI, world and presentation systems.
4. It has appropriate tests for normal, boundary and failure cases.
5. Its state persists correctly where persistence is relevant.
6. It has been checked in a playable 3D build.
7. Any intentional deviation from the 2D game is recorded and approved.

The 99% target should be measured against a finite, enumerated source catalogue and gameplay acceptance checklist. Do not use percentage estimates based only on code files, asset counts or completed milestones.

## Audit limitations / next audit pass

This initial audit establishes the major systems and known content gaps from the current `dev` branch and the original source structure. It does **not** yet enumerate every individual quest, spell, skill, NPC, creature, building, item, recipe or dialogue branch. Those catalogues need dedicated extraction and reconciliation against the corresponding 3D data files before any claim of near-total parity.

Keep this document and `LEGACY_PORTING_MATRIX.md` aligned: this document tracks content completeness; the matrix tracks implementation status and engineering evidence.
