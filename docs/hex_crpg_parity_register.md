# Hex-crpg Content and Gameplay Parity Register

## Purpose

Silverhart Saga 3D is a new Godot implementation of the original Hex-crpg game. The original repository is the behavioural and content reference; its browser runtime and global-state architecture are not to be copied.

The goal is **content and gameplay parity**, not a literal line-for-line port. Preserve authored content, rules, character identities, narrative intent, progression, and player-facing capabilities while implementing them through the Godot simulation/presentation architecture.

This register is a living migration checklist. An item is not complete merely because a data record, placeholder, scene blockout, or UI shell exists. Record the source location, destination owner, validation, and any deliberate design change for each ported feature.

## Migration rules

1. Audit the original source before declaring a feature absent or complete.
2. Preserve source-authored identities, dialogue, quest logic, coordinates, formulas, content relationships, and edge cases unless a documented correction is necessary.
3. Keep simulation rules and persistent state out of presentation scenes. Actors, locations, UI, and cinematics present or request changes through the authoritative simulation/content APIs.
4. Prefer data-driven content and reusable systems over per-NPC or per-location special-case scripts.
5. Distinguish source parity from 3D-specific improvements. A 3D replacement may change implementation, not silently discard behaviour.
6. Track source inconsistencies explicitly. Repair only where the intended behaviour is clear; document the evidence and add regression tests.
7. Maintain stable IDs for characters, dialogue nodes, quests, items, locations, factions, and relationship records so saves and references survive content expansion.
8. Do not mark visual or gameplay acceptance complete from headless tests alone where in-game inspection is required.

## Work already visible in the 3D port

These are known slices, not evidence that the full source category is complete:

- Campaign 2 surface terrain, regional noise, waterways, authored sites, roads and settlement footprints are being ported through PRs #201–#207. The later terrain PRs are chained and must be integrated in dependency order.
- The current terrain PRs explicitly defer many interiors, structures, NPCs, creatures, props, services, dialogue and quests.
- Hollowmere opening content already has a separation between authored campaign dialogue/choice handling and cinematic presentation (PR #170).
- The official 12-spell catalogue and portions of spell construction, effects, progression and spellbook UI have been ported in earlier work (PRs #158, #163 and #169); each source spell and modifier still needs a parity audit.
- Deterministic generic NPC appearance profiles and authored character/body separation have foundations (PRs #191 and #193); appearance generation is not equivalent to complete NPC identity, behaviour or social simulation.
- Creature asset registry/presentation foundations exist (PR #196); registering an asset is not equivalent to porting the creature's source behaviours, encounters, loot or quest role.

Verify current merge status and branch ancestry before building on any PR. This register itself must target `dev`, not `dev_2`.

## Step 1 — World, geography and locations

- [ ] Complete source inventory of every region, settlement, landmark, road, waterway, cave, dungeon, interior, floor and transition.
- [ ] Preserve authored axial coordinates, footprints, entrances, exits, room connections and special encounter markers.
- [ ] Port structures as reusable pieces and composition rules, not one-off decorative shells.
- [ ] Port interiors and multi-level spaces, including stairs, ladders, doors, lifts or other source transitions.
- [ ] Preserve location services, containers, beds, shops, crafting stations, shrines, evidence and interaction points.
- [ ] Validate terrain collision, elevation, movement costs, climbing, pathfinding, chunk streaming and return transitions.
- [ ] Record deliberate corrections to source geometry and test connectivity.

## NPC authoring and complexity tiers

The original game distinguishes NPCs by the amount of authored behaviour and narrative content they carry. Preserve that distinction rather than treating every NPC as either a generic villager or a full companion.

- [ ] Audit the actual NPC complexity/type classifications and examples in Hex-crpg; use the source definitions rather than inventing a parallel tier system.
- [ ] Preserve lightweight residents with simple authored identity and dialogue.
- [ ] Preserve more involved named NPCs with their additional dialogue, routines, relationships and quest participation.
- [ ] Preserve major non-companion characters (for example, the Queen) that may approach companion-level narrative complexity without party membership.
- [ ] Preserve companions as the subset with party-specific systems such as recruitment, party banter and romance where authored.
- [ ] Ensure complexity is data/content-driven and can be expanded incrementally; do not require every NPC to be fully authored at once.
- [ ] Gradually reduce reliance on random NPC generation as authored settlement populations are ported. Do not replace all incidental populations in one disruptive pass; keep deterministic generation as a temporary fallback where authored residents are not yet available.

## Step 2 — Characters, companions and creatures

- [ ] Inventory every authored named character, companion, merchant, quest giver, faction member, hostile, summon and ambient creature.
- [ ] Preserve stable identity, authored gender/body presentation, appearance, voice/presentation references, biography, faction, occupation, affiliations and starting state.
- [ ] Preserve authored companions as named characters; do not replace them with generic procedural NPCs.
- [ ] Keep deterministic procedural generation for unnamed/background NPCs, with stable seeds and reproducible identity/profile results.
- [ ] Port creature species, variants, encounter roles, abilities, behaviour, loot, taming/summoning rules and quest links.
- [ ] Ensure actor visuals are generated/presented from canonical character data rather than becoming a second source of truth.

## Step 3 — Companion gameplay and narrative

Companions are full narrative/gameplay characters, not merely party followers.

- [ ] Port companion-specific scripted dialogue, personal histories, motivations, conflicts and personal quests.
- [ ] Port romance storylines, their authored prerequisites, stages, choices, consequences and endings.
- [ ] Port party banter and companion-to-companion conversations, including contextual triggers.
- [ ] Port reactions to player decisions, quest outcomes, factions, locations and other companions.
- [ ] Port companion approval/disapproval, disagreements, temporary departures and permanent party changes where present in the source.
- [ ] Preserve authored scenes and one-off narrative moments, with presentation separated from content and simulation state.
- [ ] Ensure banter and ambient dialogue are contextual, interruptible where appropriate, and do not repeat indiscriminately.

## Step 4 — NPC social relationships (direct port)

**This is a port of the existing Hex-crpg relationship system, not a new design exercise.** The 2D game already implements the relationship model. Its actual data fields, ranges, formulas, event modifiers, thresholds, directional semantics, decay (if any), dialogue hooks and save behaviour are authoritative.

- [ ] Locate and inventory the complete 2D relationship implementation and every caller/writer.
- [ ] Port the existing fields and calculations faithfully; do not add, rename, merge or reinterpret relationship dimensions without a separately justified compatibility change.
- [ ] Preserve the source's exact event effects, thresholds, gating and relationship-driven dialogue/romance consequences.
- [ ] Preserve directional/asymmetric behaviour exactly as implemented by the 2D game; do not assume symmetry or invent directionality if the source does not use it.
- [ ] Port existing persistence and ensure relationship state round-trips through the 3D save system.
- [ ] Separate relationship state from other source systems (such as faction reputation or suspicion) only where the original game already distinguishes them.
- [ ] Add source-derived regression tests comparing known 2D inputs/events with the Godot results.

No additional meters (for example fear, respect or affection) should be introduced simply because they seem useful. First reproduce the existing game.

## Step 5 — Disguise Self, identity and impersonation

Disguise must use the same canonical identity/social data as the rest of the game.

- [ ] Preserve the source spell's actual rules, duration, costs, restrictions and dispelling/countering interactions.
- [ ] Separate visual resemblance from identity, memories, knowledge, permissions and social relationships.
- [ ] Model recognisable features and presentation cues only where the source/game rules support them.
- [ ] Let detection depend on the observer, their familiarity with the impersonated person, scrutiny, context and relevant checks.
- [ ] Allow knowledge tests or contextual questions where authored gameplay calls for them; do not assume a disguise grants the target's memories.
- [ ] Account for companions and close acquaintances who may recognise incongruities.
- [ ] Preserve faction uniforms, access rules, guard procedures and suspicion responses.
- [ ] Test successful disguise, casual recognition, close scrutiny, failed checks, and consequences without bypassing the authoritative spell/action resolver.

## Step 6 — NPC life simulation and schedules

NPCs should not remain stationary props waiting for the player. Implement a shared, data-driven activity/schedule system.

- [ ] Audit source-authored NPC movement, patrols, schedules, day/night routines and event-driven relocation.
- [ ] Define reusable activities (sleep, work, eat, shop, socialise, guard, patrol, travel, flee, investigate, fight, rest).
- [ ] Define schedule windows, location/activity destinations, priorities, interruptibility and fallback behaviour.
- [ ] Support navigation between buildings, floors and settlements through the world traversal system.
- [ ] Allow simulation events (combat, alarms, weather, quests, closures, danger) to interrupt or alter routines.
- [ ] Persist enough schedule/activity state to avoid NPCs resetting or teleporting implausibly when chunks unload or the player leaves.
- [ ] Use deterministic/off-screen simulation where possible; do not require every NPC to run a fully animated actor every frame.
- [ ] Keep authored story scenes and quest-critical placements authoritative over ambient schedules.
- [ ] Add tests for schedule selection, interruption, resumption, off-screen progression and save/load continuity.

## Step 7 — Dialogue, quests and world interactions

- [ ] Inventory every dialogue tree, response choice, conditional branch, skill/stat check, consequence and one-off interaction.
- [ ] Preserve dialogue conditions and outcomes as data/content, not strings embedded in location scripts.
- [ ] Port the complete quest catalogue, stages, prerequisites, success/failure/alternate outcomes, evidence, journals, rewards and world-state changes.
- [ ] Preserve quest dependencies and the effects of killing, moving, disguising, recruiting or alienating important NPCs.
- [ ] Port containers, loot, doors, locks, traps, clues, books, journals, signs, shrines, gathering and other interactive objects.
- [ ] Ensure dialogue, quests and interactions call authoritative simulation actions and persist outcomes.
- [ ] Add regression tests for major quest branches and source-specific edge cases.

## Step 8 — Full game systems and content parity

This is the broader source audit; do not limit parity to the systems named above.

- [ ] Character creation, attributes, skills, abilities, advancement and respec rules.
- [ ] Combat rules, initiative, action economy, attacks, defence, status effects, AI and encounter triggers.
- [ ] Complete spell catalogue, spell construction/modifiers, costs, ranges, targets, effects, summons, reactions and presentation hooks.
- [ ] Inventory, equipment, item definitions, weapons, armour, consumables, loot tables and encumbrance (where present).
- [ ] Shops, prices, currencies, services, trading and faction-specific access.
- [ ] Crafting, gathering, resources, recipes and progression (where present).
- [ ] Factions, reputation, hostility, alliances, guards, crime and world reactions.
- [ ] Time, calendar, rest, healing, resource recovery, weather and environmental rules.
- [ ] Save/load, campaign state, journals, map markers, settings and accessibility/input behaviour.
- [ ] Audio, music, voice/dialogue presentation, animation cues and other authored presentation content.
- [ ] Every remaining source-specific subsystem discovered during the audit.

## Source audit and acceptance evidence

For each source feature, record:

| Field | Required evidence |
|---|---|
| Source | Original file, function, data record or asset path |
| Content/behaviour | What the original game actually does |
| Destination | Godot data resource, simulation service, content owner or presentation component |
| Status | Not audited / audited / planned / implemented / tested / visually accepted |
| Differences | Any intentional change from the original and why |
| Tests | Automated test names and results |
| Review | Required in-game or visual acceptance |

A category is not complete until its source inventory is reconciled against the Godot destination. Empty search results or absence from the current 3D branch are not proof that a source feature does not exist.

## Delivery sequencing

1. Finish and validate the existing terrain PR dependency chain; do not mix unrelated narrative systems into those terrain changes.
2. Continue physical structures and traversal, including Kragmoor's entrance and multi-level spaces, then the other settlements/landmarks.
3. Run the full Hex-crpg source audit in parallel and populate this register with exact source paths and destination mappings.
4. Port missing NPCs/creatures and their authored identities.
5. Implement shared relationships, disguise/social recognition and NPC schedule foundations before bulk-authoring behaviour that depends on them.
6. Port companion dialogue, romance, banter, quests and world interactions using those foundations.
7. Complete the remaining systems/content parity audit and verify save/load and end-to-end campaign branches.

**Do not declare the 3D world or campaign content complete merely because the terrain map is present.** The acceptance target is a coherent, playable 3D implementation of the original game's complete content and rules, with documented intentional improvements.
