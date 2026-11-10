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
| Combat | Highest-TP initiative and initial deterministic attack resolver implemented (hit chance, damage, reductions, TP cost, seeded outcomes) | Unified action contract, range/weapon readiness/critical/facing/cover/LOS, reactions, downed/death lifecycle, AI, encounter start/end and cleanup |
| Movement | Paid adjacent movement and weighted A* implemented | Roads, cover, encumbrance, hamstring, friendly squeezing, mounts, occupancy exceptions, reactions, visibility-aware path costs and NPC pathing |
| Elevation | 3D height samples and slope/climbing costs in progress | Ledges, falls, ladders/stairs, climbing actions, fall damage and height-aware LOS |
| Presentation | 3D hex terrain, camera, actor and Ara modular-character integration | Combat/interaction animation hooks and state-driven UI |
| Hollowmere | Village/tavern blockout and authored NPC data | Event-driven opening, dialogue, branching consequences, interiors and full playable loop |
| Save/load | Character/world-clock dictionary serialisation only | Versioned whole-world persistence and round-trip tests |
| Other gameplay systems | Not yet represented in the simulation layer | See backlog below |


## Combat Time Point initiative and timeline HUD

The first 3D initiative presentation slice is implemented on `feature/combat-initiative-timeline`.

- `ActionEconomy` and `CombatTurnScheduler` remain authoritative. The HUD never selects turns, spends TP or changes recovery.
- `CombatInitiativeModel` produces a presentation-only roster sorted by current TP (highest first), with stable ID ordering for equal values. The scheduler's actual tie resolution remains its own seeded/random selection.
- The roster includes living player- and enemy-side combatants, including downed characters for status visibility. Downed characters cannot act. It excludes dead characters, riders, combat-dormant background NPCs and neutral bystanders.
- `CombatInitiativeTimeline` is attached to the Hollow Tankard HUD. It appears only during combat, marks the active actor, shows health, mana (when applicable), and TP as a plain number, and opens that character's details when selected.
- The original `entities.js` sets `initialTimePoints = 0` and a separate `maxTimePoints = 120` (commented `Allow going over 100`). The intended 3D campaign rule is that newly created characters begin at 100 TP, and characters registered into an already-active combat are set to 100 TP. Existing combatants retain their current TP when combat starts. The 100 TP combat-readiness threshold and 80 TP normal turn-end threshold remain separate rules. The original engine also has an independent 150 TP regeneration gate; it is not a hard cap. The HUD displays TP as a plain number, not as a fraction or progress bar.
- Initiative cards now reserve a face portrait viewport. They display a name-initial fallback until the 3D presentation layer supplies `CharacterState.portrait_texture`; the model and UI already accept that texture. Actual face capture/rendering is still future work, including creature portrait fallbacks.
- The timeline refreshes from simulation state and does not sort or reshuffle the peaceful-exploration roster. It is hidden outside combat.

### Remaining initiative work

1. Port and test the remaining source action costs and recovery modifiers against the original browser engine.
2. Add actual 3D portrait capture using the existing Ara character/equipment presentation, with a fallback for creatures and unloaded NPCs.
3. Connect all combat entry points and future encounters to the same HUD, rather than only the Hollow Tankard opening encounter.
4. Add save/load coverage for an active combat encounter and define how an active turn is resumed safely after loading.
5. Reconcile any remaining source distinctions between the entity's `initiative`, `timePoints`, and `timePointsPerTick`; do not silently collapse them into one statistic.

## Current next porting slice

The first attack resolver is a foundation, not a complete combat port. The next work should be ordered to avoid layering more mechanics on an incomplete state model:

1. **Completed in this slice:** typed action requests/results/events provide a shared validation/commit path for movement and attacks; compatibility wrappers remain for existing callers.
2. **Completed in this slice:** negative-HP downed band, unconscious targetability/turn exclusion, healing wake-up and the -50% max-HP true-death threshold are represented in character state and attack resolution.
3. **Completed in the previous slice:** reaction requests are simulation events; dead, unconscious or reaction-blocked reactors resolve immediately with no choice, and incapacitation during a pending request clears it immediately. Pending reactions hold normal turn completion and transient waits are not restored from saves.
4. **Initial attack-reaction integration in this slice:** a source-eligible sword/dagger defender can interrupt an attack with Parry. Damage is held until the reaction resolves; a successful parry cancels the hit, consumes the defender's per-turn parry allowance and TP, and still charges the attacker for the attempted action. Parry chance and efficiency/mastery modifiers follow the original game's skill rules. Passive dodge remains part of hit chance; the source does not define a separate generic active-dodge reaction.
5. **Implemented:** attack reaction choices can be paid for by a nearby ally; Protector Parry and Shield Other use the ally's TP, and a successful Protector Parry cancels the pending hit. Shield Other applies its shield/proficiency reduction to that hit only. The equipment slot must contain an explicit shield item dictionary; legacy string-only offhand IDs are deliberately not assumed to be shields.
6. **Implemented in this slice:** movement steps pause before committing when an eligible adjacent reactor can use Spear Intercept, Spear Halt or Sidestep. Intercept resolves before movement continues; Halt commits the triggering step and signals the path controller to stop; Sidestep opens a second destination-selection stage and only accepts free, walkable, non-water, same-elevation adjacent hexes. TP and sidestep allowance are spent only after a valid destination is chosen.
7. **Next:** connect AI reaction selection and source-specific combatant equipment/skill data to authored encounters; then port attack range/type, facing, cover and line of sight.
6. **Encounter slice:** simple tactical AI, encounter start/end conditions and loot, connected to 3D actor/animation presentation.

Do not begin a broad spell/skill/content migration until these shared action and character-state foundations are in place. The first campaign vertical slice remains the Hollow Tankard opening, but its combat branch should consume this reusable combat loop rather than bespoke scripted damage.

## Port backlog and order

### M1 — Finish the simulation kernel

- [x] Stable character IDs and serialisable character state foundation.
- [x] Fixed-step world clock and calendar foundation.
- [x] Time Point combat-readiness and turn-end thresholds.
- [x] Highest-Time-Point initiative selection.
- [x] Paid hex movement and weighted A* using the same terrain cost resolver.
- [x] Initial source-backed character creation: race/class attribute pools and tree markers, class levels, level/XP fields, mana caps, gold, difficulty, identity and class starting equipment. Full derived stats, mana use/regeneration, XP/level progression, racial/class skill trees and status effects remain to be ported.
- [x] Initial action command/result/event contract for movement and attacks. Extend it to cast, interact, use item and rest as those systems are ported.
- [ ] Tick pipeline: world time, TP regeneration, HP/mana/status ticks, upkeep, schedules and world events, with combat-turn pauses matching the source.
- [ ] Whole-world versioned save/load: characters, party, map diffs, explored/known state, inventory, quests, relationships, factions, regions, schedules, events and campaign flags.

### M2 — Tactical combat and traversal

- [x] Initial deterministic attack resolver: seeded hit roll, base hit chance, damage, reductions, TP spending and defeated-state result.
- [ ] Complete attack resolution: weapon readiness, attack type/range, criticals, facing, cover and line of sight. Initial sword/dagger Parry reaction is implemented.
- [x] Initial movement reactions: Spear Intercept, Spear Halt and Sidestep, with a resumable movement step and validated second-stage destination selection. Player-facing modal selection is connected; automated AI reaction policy is not yet implemented.
- [x] Initial ally defensive reactions: Protector Parry and Shield Other. Equipment item definitions and broader combatant data migration remain incomplete.
- [ ] Combat turn lifecycle: complete action costs, initiative, remaining defensive reactions, interruption, forced movement, combat start/end and encounter boundaries.
- [ ] Downed/unconscious/death states, recovery, corpse/loot handling and companion/NPC consequences. The resolver now preserves negative HP: characters at or below zero but above -50% max HP are unconscious, while <= -50% max HP is true death.
- [ ] Status-effect framework: duration, stacking/refresh rules, periodic effects, dispel/cleanse, resistances and save/load.
- [ ] Tactical AI: perception, threat selection, movement/attack/cast choices, retreat and faction/relationship-aware hostility.
- [ ] Terrain interactions: climbing, ledges, falls/fall damage, doors, walls, stairs, multi-storey buildings, hazards, traps, cover and height-aware LOS.
- [ ] Mounts/riders, formations, group movement, squeezing past allies and mounted combat.
- [ ] Stealth, detection, disguise and suspicion; preserve dialogue reactions and risk when a disguise is seen through.

### M3 — Character progression, equipment and magic

- [x] Character-creation race/class bonuses and initial class level are data-backed from the original game; class/race markers populate the relevant attribute pools. Easy mode applies its source starting gold bonus and free Health rank (+10 HP); hard mode applies the source 10% damage dealt/taken modifier.
- [ ] Full attribute and skill trees, rank limits, prerequisites, skill costs, respec/difficulty rules and derived effects.
- [ ] XP/level progression and NPC progression policies/modes.
- [x] Initial persistent inventory item instances, equipment-slot swap/unequip operations, and data-backed Character/Inventory panel. The original 63-item catalogue (including source stats, prices, descriptions and carry weights) is now data-backed; Hollowmere NPC starting equipment is assigned from the original campaign data. The inventory panel uses a 2D SVG icon atlas migrated from the original game. Equipped item damage/reduction and armour weight metadata feed combat/movement rules.
- [ ] Remaining inventory systems: original shared-party pool, stack rules, currency, loot, shops, equipment readiness, encumbrance, item identity and complete inventory persistence. The current slice uses per-character item instances; class-based player starting kits are now assigned during character creation.
- [ ] Spells as simulation actions with targeting, range, costs, durations/upkeep, interruption, multi-target/fork modifiers, summons and world effects.
- [ ] Preserve the original design principle: magic and skills are **world verbs**, not merely damage buttons. Include traversal, concealment, illusion, divination, communication, influence, manipulation, investigation and transformation where supported by the source.
- [ ] Crafting, gathering, farming, construction, camp deployment, resource processing and trade.

### M4 — Social simulation, dialogue and quests

- [x] Initial source-backed Hollowmere opening dialogue and branching social resolution, connected to the campaign journal. [ ] Reusable dialogue graph conditions, skill checks, command effects and broader campaign migration.
- [x] Initial simulation-owned quest journal: definition registration, prerequisites, staged objectives with required/optional completion, persistent decision choices, quest completion/failure and faction-standing deltas. State serializes independently of UI. [ ] Timed expiry, rewards and full journal history.
- [x] Initial nearby-NPC ambient chatter: role/time/event-aware exchange selection, pair cooldowns and anti-repeat memory in Hollowmere. [ ] Persistent personality, relationship-aware banter, NPC knowledge and conversation memory.
- [ ] NPC identity and persistence independent of loaded 3D actors; schedules, routines, sleep/work/tavern movement, civilian persistence and road travellers.
- [ ] Disguise/equipment identity and dialogue reactions; hearing/range and social-facing rules.
- [x] Initial faction-standing ledger is part of the campaign journal and records reasoned deltas independently per faction. [ ] Source-specific reputation dimensions, hostility thresholds, faction beliefs, double-cross consequences and political state.

### M5 — Living world, economy and campaign

- [ ] Regional prosperity/security/other stats and cascading consequences.
- [ ] World pulse/event queue: caravans, bandit camps, wilderness incidents, rumours, faction pressure, seasonal effects and autonomous events.
- [x] Distinct local Hollowmere hex map and initial 16×16 Main Campaign regional reference map, translated from the original Campaign 2 terrain/faction layout and river path. [ ] Travel routes, fog of war, map knowledge and location discovery.
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


## Game start and race/class creation

- [x] Game-start UI separates Campaign and Arena selection. The Main Campaign now opens in Hollowmere using the original Campaign 2 content identity (internal ID `2`); Arena remains unavailable until its lobby/combat loop is ported.
- [x] Five source races and six source classes are represented as data with their exact attribute bonuses from `Hex-crpg/data.js`.
- [x] Player creation applies race/class bonuses into attribute pools, writes race/class tree marker ranks, initializes level 1 and classLevels, and assigns source class starting equipment.
- [x] Easy mode applies the original +50% starting gold and free Health rank (+10 HP). Hard mode applies the original 10% player damage dealt/taken modifier.
- [x] Race/class, mode, campaign, difficulty, Ironman intent, gold, attributes, identity and equipment are serialized on CharacterState.
- [x] Main Campaign start selection and first regional map reference view are connected to the Hollowmere opening. [ ] Full racial/class skill trees and rank purchasing; class-specific mana/spell progression; complete Main Campaign world/travel runtime; Arena; Ironman save enforcement.


## Campaign quest journal foundation

The first social-simulation mechanic is implemented in `scripts/simulation/campaign_journal.gd`. Quest definitions are registered as data; runtime state is held by the simulation, not by a scene or dialogue widget. The journal supports prerequisite gating, required and optional objective progress, one-time branch decisions, explicit completion/failure, faction/NPC standing and knowledge, dampened reputation changes and merchant influence. All of that state serializes. Journal changes are forwarded through `WorldSimulation.action_committed` as `SimulationEvent` values so later dialogue, NPC and world systems can react without coupling to UI.

The journal foundation now supports the first source-backed Hollowmere quest and dialogue slice below. Continue migrating campaign content into data definitions and simulation-owned effects; do not copy browser callbacks or global window state.


## Hollowmere opening dialogue and ambient chatter

The initial Hollowmere social slice now registers the original Ironbond shakedown as a simulation-owned quest and presents the source-authored opening lines from `campaign2Dialogue.js`. The player can stay out, reinforce Ironbond's demand, or side with Garrick in a playable fight. Each branch records its persistent decision and applies the original faction/NPC reputation and merchant-influence consequences immediately. The fight branch leaves the quest active until combat victory; if all five player-side combatants are incapacitated, the quest fails but the chosen branch consequences remain.

Garrick, Mira, Oskar, Wick, Yvette and Hendra have initial talk interactions. Their greetings and follow-up lines respond to the shakedown choice and individual standing. Press **F** near a neutral NPC to talk. The three Ironbond soldiers path into the tavern for the opening; peaceful outcomes send them back outside. Dialogue presentation is separate from the content definitions and simulation journal.

Ambient chatter uses the original `ambientChatterExpansion.js` as its behavioural reference: nearby neutral NPC pairs exchange short conversations every 16 seconds of real time, with a 120-second in-world pair cooldown, recent-exchange/topic suppression, occupation-specific options, time-of-day conditions and outcome-specific shakedown aftermath. It is presented as temporary speech bubbles and pauses during dialogue or combat. The current content set is a broader Hollowmere subset, not the entire old game's multi-settlement catalogue or personality/relationship layer. Security-threshold exchanges remain defined but regional security is not yet connected to this scene.

Headless tests cover the shakedown content and journal data, branch availability and faction deltas, chatter eligibility, event gating, midnight time windows and pair cooldowns.

The campaign journal seeds human-player reputation at +5 (dwarf/elf at 0; goblin/orc at -15), with knowledge at zero and Ironbond merchant influence over Silverhart at 30. The shakedown ports the original 40%-per-tier authority cascade from Garrick to Hollowmere's elder, baron and Silverhart, including knowledge-based dampening; Mira and Oskar receive local personal changes only. Merchant influence changes by +1 for staying out, +2 for backing payment and -2 for fighting.


## Hollowmere Ironbond combat encounter

The shakedown fight now uses the existing `WorldSimulation` combat engine rather than a scene-local damage shortcut. The encounter setup assigns the player, Wren, Garrick, Mira and Oskar to the player side, Dray/Tomlin/Hask to the enemy side, and marks other tavern residents combat-dormant so they do not enter initiative. Their authored loadouts supply weapon and armour metadata; the encounter assigns initial combat profiles and the original weapon skill ranks.

The player attacks the nearest enemy in the equipped weapon's range with **Space** or the Attack button. Attack resolution uses `WorldSimulation.try_attack_character`, including the existing hit, damage, armour and reaction rules. The 10 TP attack cost matches the original `gameEngine.js` main-attack caller. **Enter** or End Turn ends the active party member's turn and forfeits unused TP down to the 80 TP turn-end threshold, preventing immediate reselection. The player switches between the player character and Wren with **Tab**. Garrick, Mira and Oskar join the player side as AI-controlled allies, matching the original branch; Dray, Tomlin and Hask are enemies. Both enemy soldiers and allied NPCs use a basic tactical loop: select the nearest able opponent, move one pathfinding step toward an attack hex, or attack when in weapon range; each AI combatant takes one action per turn. Defensive reactions by AI-controlled NPCs are resolved automatically rather than shown as player prompts.

The encounter ends when all three soldiers are incapacitated/dead, or fails if all five player-side combatants are incapacitated. The victory dialogue is migrated from the original `hollowmere_victory` entry. The enemy AI is intentionally a first combat slice: it does not yet use the original full combat directives, spell use, flanking, cover, retreat, morale or group tactics. The Oskar sparring duel is still separate and remains unavailable until that encounter is ported.

Headless tests cover encounter setup, combatant sides, bystander initiative suppression, the real simulation attack resolver, win/loss detection, all three quest outcomes, named reputation consequences and outcome-specific ambient chatter.

Follow-up source content not yet ported: Dray's later approach and the Missing Courier quest after a peaceful departure; the Loose Ends/body-disposal quest and the later Ironbond investigator if Dray is killed; the original full enemy combat directives and the broader Hollowmere world/security response.

Peaceful choices also move the soldiers back to their outdoor waiting hexes. The later Dray approach/Missing Courier hook is still a separate follow-up and is not yet implemented.
