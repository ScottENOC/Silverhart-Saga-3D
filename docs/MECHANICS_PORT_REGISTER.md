# Hex-crpg → Silverhart Saga 3D: Mechanics Port Register

## Purpose and source of truth

`ScottENOC/Hex-crpg` is the behavioural and content reference. `Silverhart-Saga-3D` is the new Godot implementation. Port mechanics and outcomes, not the browser runtime, Canvas renderer, DOM UI, global `window` state, or timing hacks.

The old project is a substantial game, not just a hex movement prototype: its source tree includes a large simulation engine, skills and spells, tactical combat, equipment/inventory, quests and dialogue, factions and regional politics, persistent companions, NPC schedules, a living world, crafting/economy, settlements, sieges and campaign content. The old repository also contains dedicated Playwright/unit regression suites; these should be treated as behavioural specifications where practical.

## Porting rules

1. **Simulation owns truth.** GDScript simulation services decide legal actions and mutate state. Scenes, animations, camera and UI only present state or submit commands.
2. **Stable IDs.** Never key persistent state by display name. Keep source IDs where practical; introduce explicit migration aliases where not.
3. **Data before scripts.** Convert content to Resources/JSON and explicit effect definitions. Do not copy embedded JS callbacks or browser globals.
4. **Preserve interactions.** Port systems as connected mechanics (e.g. skills affect movement, combat, dialogue and world traversal), not isolated UI checkboxes.
5. **Test behaviour.** Every ported rule needs headless GDScript tests. Use old tests and source code to establish expected outcomes; add deterministic seeds for random resolution.
6. **Incremental vertical slices.** Each feature branch should leave `dev` playable and should include its dependencies, tests and a short implementation note.
7. **No premature content dump.** Build reusable mechanics first, then migrate authored campaigns/locations on top.

## Current 3D implementation — verified from `dev`

| System | Current state | Remaining work |
|---|---|---|
| Axial hex grid and logical map | Implemented | Extend map data for all terrain/objects/visibility and multiple floors |
| Character state | Foundation | Attributes, full derived stats, XP/levels, mana, stamina/resources, status effects, identity/relationships |
| Time Points | Initial rules implemented | All action costs, regeneration modifiers, combat/exploration differences and reactions |
| World clock/calendar | Fixed-step clock and 12-month calendar implemented | Source event hooks, sleep/rest, time speed and world scheduling |
| Combat initiative | Highest-TP scheduler implemented | Full combat lifecycle, active turns, AI, interruption, death/downed states and cleanup |
| Movement | Paid adjacent movement and weighted A* implemented | Roads, cover, encumbrance, hamstring, friendly squeezing, mounts, occupancy exceptions, reactions, visibility-aware path costs and NPC pathing |
| Elevation | 3D height samples and slope/climbing costs in progress | Ledges, falls, ladders/stairs, climbing actions, fall damage and height-aware LOS |
| Presentation | 3D hex terrain, camera, actor and Ara modular-character integration | Combat/interaction animation hooks and state-driven UI |
| Hollowmere | Village/tavern blockout and authored NPC data | Event-driven opening, dialogue, branching consequences, interiors and full playable loop |
| Save/load | Character/world-clock dictionary serialisation only | Versioned whole-world persistence and round-trip tests |
| Other gameplay systems | Not yet represented in the simulation layer | See backlog below |

## Port backlog and order

### M1 — Finish the simulation kernel

- [x] Stable character IDs and serialisable character state foundation.
- [x] Fixed-step world clock and calendar foundation.
- [x] Time Point combat-readiness and turn-end thresholds.
- [x] Highest-Time-Point initiative selection.
- [x] Paid hex movement and weighted A* using the same terrain cost resolver.
- [ ] Complete character model: attributes, derived stats, HP/mana, regeneration, XP, levels, class/race traits, status effects and resistances.
- [ ] Action command/result/event contract. All actions (move, attack, cast, interact, use item, rest) go through the same authoritative resolver.
- [ ] Tick pipeline: world time, TP regeneration, HP/mana/status ticks, upkeep, schedules and world events, with combat-turn pauses matching the source.
- [ ] Whole-world versioned save/load: characters, party, map diffs, explored/known state, inventory, quests, relationships, factions, regions, schedules, events and campaign flags.

### M2 — Tactical combat and traversal

- [ ] Basic attack resolution: weapon readiness, attack type/range, hit/defence, damage, criticals, facing, cover and line of sight.
- [ ] Combat turn lifecycle: action costs, initiative, reactions, interruption, forced movement, combat start/end and encounter boundaries.
- [ ] Downed/unconscious/death states, recovery, corpse/loot handling and companion/NPC consequences.
- [ ] Status-effect framework: duration, stacking/refresh rules, periodic effects, dispel/cleanse, resistances and save/load.
- [ ] Tactical AI: perception, threat selection, movement/attack/cast choices, retreat and faction/relationship-aware hostility.
- [ ] Terrain interactions: climbing, ledges, falls/fall damage, doors, walls, stairs, multi-storey buildings, hazards, traps, cover and height-aware LOS.
- [ ] Mounts/riders, formations, group movement, squeezing past allies and mounted combat.
- [ ] Stealth, detection, disguise and suspicion; preserve dialogue reactions and risk when a disguise is seen through.

### M3 — Character progression, equipment and magic

- [ ] Attribute and skill trees, rank limits, prerequisites, skill costs, respec/difficulty rules and derived effects.
- [ ] XP/level progression and NPC progression policies/modes.
- [ ] Inventory instances, stack rules, currency, loot, shops, equipment slots, armour/weapon/shield readiness, encumbrance and item identity.
- [ ] Spells as simulation actions with targeting, range, costs, durations/upkeep, interruption, multi-target/fork modifiers, summons and world effects.
- [ ] Preserve the original design principle: magic and skills are **world verbs**, not merely damage buttons. Include traversal, concealment, illusion, divination, communication, influence, manipulation, investigation and transformation where supported by the source.
- [ ] Crafting, gathering, farming, construction, camp deployment, resource processing and trade.

### M4 — Social simulation, dialogue and quests

- [ ] Data-driven dialogue graph with conditions, choices, command effects, skill checks and persistent consequences.
- [ ] Quest state machine: prerequisites, stages, optional branches, failure/expiry, rewards and journal history.
- [ ] Party/companion roster, affinity, multiple relationship dimensions, personality/knowledge, banter, conversation memory, agency and companion quest chains.
- [ ] NPC identity and persistence independent of loaded 3D actors; schedules, routines, sleep/work/tavern movement, civilian persistence and road travellers.
- [ ] Disguise/equipment identity and dialogue reactions; hearing/range and social-facing rules.
- [ ] Faction standings and reputation remain separate dimensions. Preserve faction-specific beliefs, hostility thresholds, double-cross consequences and political state.

### M5 — Living world, economy and campaign

- [ ] Regional prosperity/security/other stats and cascading consequences.
- [ ] World pulse/event queue: caravans, bandit camps, wilderness incidents, rumours, faction pressure, seasonal effects and autonomous events.
- [ ] Distinct local hex map and wider world/region map, travel routes, fog of war, map knowledge and location discovery.
- [ ] Settlements, shops/hours, markets, resources, prices, recruitment, construction and player property.
- [ ] Campaign 2 content migration: Hollowmere opening first, then farmstead/goblin camp/Emberlode/Emberwood/Millbrook/Reddale/Silverhart/Northwatch/Ridgehold and associated dungeons, arcs and siege branches.
- [ ] Preserve explicitly gated set pieces: for example, Northwatch attackers/catapult/crew must remain dormant until the appropriate dialogue or explicit siege trigger; ordinary combat must not activate the siege.
- [ ] Music/audio state driven by location, time, faction, stealth, threat and combat.

## First playable migration slices

1. **Hollow Tankard opening:** Wren introduction, shakedown, soldier entry, player choices, combat/non-combat resolution, quest/faction/reputation effects, and save-safe event progression.
2. **One complete combat encounter:** movement, attack, defence/cover/LOS, AI, status effects, death/downed state and loot.
3. **One complete social quest:** conditional dialogue, multiple approaches (including non-combat skill/spell options), consequences, journal and persistence.
4. **One living-world loop:** NPC schedule + regional state + event + rumour + visible local consequence.

## Source modules to use as behavioural references

- Core rules: `gameEngine.js`, `entities.js`, `terrain.js`, `hexMap.js`, `worldTime.js`, `realtimeTickCadence.js`, `skills.js`, `spells.js`, `spellPlanner.js`, `weaponReadiness.js`, `trapSystem.js`.
- Character/equipment: `characterCreation.js`, `equipment.js`, `partyInventory.js`, `clothingSystem.js`, `clothingLayers.js`, `physicalWearables.js`.
- Social/quests: `dialogue.js`, `campaign2Dialogue.js`, `questLog.js`, `ordinaryDialogueConsequences.js`, `leverage.js`, `disguiseSelfSystem.js`, `espionageQuests.js`.
- Party/NPC: `roster.js`, `companionRelationships.js`, `companionAffinity.js`, `companionWorldAgency.js`, `npcProgression.js`, `npcRoutineScheduler.js`, `civilianPersistence.js`, `persistentRoadTravellers.js`.
- World/economy: `factions.js`, `regions.js`, `worldPulse.js`, `wildernessLivingWorld.js`, `wildernessConsequences.js`, `resources.js`, `crafting.js`, `construction.js`, `campSystem.js`, `expeditionSystem.js`, `worldMap.js`, `persistence.js`.
- Campaign content: `campaign2Content.js`, `campaign2World.js`, `campaign2Dialogue.js` and the focused arc modules named after their quests/characters.

## Regression reference

The old repository's `tests/` and `tests-unit/` suites are a rich behaviour catalogue (combat, spells, skills, quests, factions, companions, NPC schedules, world pulse, wilderness, shops, farming, crafting, siege, persistence and more). They are not to be copied verbatim; translate the rule assertions into headless Godot tests and add scene-level tests only where presentation is involved.

## Definition of done

A mechanic is considered ported only when:
- its rules and edge cases are documented against the source behaviour;
- the simulation implementation is independent of presentation;
- tests cover normal, boundary, failure and persistence cases;
- it is connected to relevant existing systems;
- its data and state survive save/load; and
- the feature is playable in the 3D world, not just represented in code.
