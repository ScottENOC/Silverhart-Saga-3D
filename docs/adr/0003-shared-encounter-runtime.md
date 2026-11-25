# ADR 0003: Shared encounter and combat runtime

- Status: accepted for incremental migration
- Date: 2026-11-26
- Scope: campaign combat orchestration, encounter lifecycle and presentation boundaries
- Does not replace: `WorldSimulation`, `CombatRules`, `CombatTurnScheduler`, `CombatAI`, `CharacterState`, or existing combat action/reaction rules

## Context

The starting location controller `scripts/world/hollow_tankard.gd` currently contains both location-specific interactions and shared encounter orchestration. In addition to starting particular tavern/farm encounters, it owns active encounter flags and rosters, AI turn dispatch, player attack targeting, turn completion, combat HUD updates, and a large encounter-resolution dispatcher.

This creates the wrong dependency direction. A new camp ambush would have to call into a tavern controller or duplicate the same logic. Other locations would face the same pressure. The project already has reusable simulation primitives (`WorldSimulation`, `CombatAI`, `CombatTurnScheduler`, `CombatRules`) and a presentation HUD, but it lacks a shared encounter lifecycle/controller boundary.

The world-building architecture already establishes the relevant principle: location controllers should own local interaction and presentation, while reusable systems own shared behaviour. Quest/domain rules also belong in their services, not in location scripts.

## Decision

Build one reusable encounter runtime. It composes existing combat systems; it is not a second combat simulation.

The target responsibilities are:

### 1. Encounter content and definitions

An encounter definition/service supplies:
- stable encounter ID and encounter kind;
- participant specifications (existing character IDs or spawn requests);
- team/side assignment and player-control policy;
- optional start modifiers such as surprise/initiative;
- encounter-specific context needed by the owning quest or activity.

It owns enemy selection, quest prerequisites, rewards, retreat/victory consequences and persistence of its domain outcome. It does not own generic turn processing, HUD controls or actor nodes.

### 2. Simulation encounter service

A reusable simulation-layer service owns the logical encounter lifecycle:
- validate participant IDs and spawn specifications before mutating state;
- register/remove encounter participants through `WorldSimulation` and its occupancy/lifecycle APIs;
- establish party/enemy/neutral sides and active/dormant status;
- start and end combat through `WorldSimulation`;
- retain the active roster and stable encounter identity;
- apply explicit, data-driven encounter-start modifiers (including detection-dependent surprise) through existing initiative/time-point rules;
- return structured completion/retreat outcomes to encounter content.

It must not depend on Nodes, scenes, actor factories, UI, dialogue, audio, location names or presentation paths. Save/load must preserve authoritative character and quest state; transient encounter state must be safely reset or explicitly serialised according to the campaign save contract.

### 3. Shared combat runtime/controller

A shared runtime coordinates the active combat loop:
- read the current combatant from `WorldSimulation`;
- dispatch non-player turns through `CombatAI`;
- expose player attack/turn/reaction requests to the existing simulation rules;
- coordinate pending reactions and turn advancement;
- detect generic terminal conditions (all active members of a side defeated, retreat requested, or encounter ended).

It must reuse `WorldSimulation`, `CombatAI`, `CombatTurnScheduler` and the existing action APIs. It must not reimplement hit resolution, movement, initiative scheduling, status effects or reactions. The runtime should be testable without a location scene.

### 4. Combat presentation adapter

A presentation-layer component owns:
- creation/removal/update of combatant actor nodes through existing actor factories;
- mapping stable character IDs to disposable presentation actors;
- HUD visibility/status and player control callbacks;
- alarm/narration/audio cues and other presentation feedback;
- forwarding player intent to the shared combat runtime.

Presentation actors never become the authoritative combatant state. No simulation service may instantiate a Node or reference a HUD.

### 5. Location and activity controllers

A location controller may:
- detect local interaction/proximity conditions;
- provide its map context and valid spawn-cell query;
- request an encounter definition/service;
- supply local presentation anchors and callbacks.

It may not own shared turn processing, AI dispatch, attack targeting, combat HUD orchestration, generic roster/side lifecycle or a switch statement for unrelated encounter types.

Camp, farmstead, tavern, ruins and future encounters must use the same runtime. Location-specific geometry and authored placement remain with their location data/presenter; quest and camp consequences remain with their respective domain services.

## Current implementation status

The first incremental slice is now present:

- `CombatEncounterController` owns shared turn-loop orchestration, AI dispatch, player attack requests, pending-reaction handling and combat HUD state.
- `CombatEncounterService` owns participant validation, side/dormancy setup, combat start/end and restoration of the pre-encounter side/dormancy state. It has no Node, scene, HUD or location dependency.
- The farm-wolf pack encounter and Reyna's dire-wolf hunt both use the shared simulation lifecycle service and the same presentation controller.
- The farm-wolf location path retains only its wolf spawn/presentation and quest outcome work; it no longer repeats the generic participant setup loop.

This is not yet the target architecture. The service does not yet own spawn/remove requests, encounter identity, save/load serialization or surprise modifiers. The tavern Ironbond/abandoned-house encounters and other farm encounters still need migration, and `HollowTankard` still owns encounter rosters and a resolution dispatcher. Those gaps remain explicit work, not implied as complete.

## Migration sequence

1. Audit current combat call sites and record ownership before moving code.
2. Extract the shared combat loop and HUD/actor adapter from `HollowTankard` without changing behaviour. Preserve the current authored tavern encounters as regression cases.
3. Move tavern encounter setup/resolution into dedicated encounter content/services; leave `HollowTankard` as a caller and location presenter.
4. Move farm/wolf setup and resolution into its own encounter service and migrate it to the shared runtime.
5. Connect camp night-watch results to the same encounter service/runtime. Detection changes the encounter's surprise/initiative configuration; the simulation remains unaware of camp visuals.
6. Add integration tests for multiple encounter kinds, defeat, victory, retreat, pending reactions, actor cleanup/recreation, save/load boundaries and deterministic surprise.
7. Delete obsolete generic combat state and methods from `HollowTankard`.

The migration is incremental. Do not perform a risky wholesale rewrite of all combat rules or the location scene.

## Required invariants

- No generic combat loop, AI turn dispatch, attack targeting or HUD orchestration remains in a location controller.
- At least two materially different encounter types use the same runtime before camp ambush is considered integrated.
- Simulation services have no dependency on scene Nodes, presentation factories, UI or location-specific resources.
- Presentation actor creation/removal never creates or destroys authoritative combat state implicitly.
- Encounter participants are registered, occupied, saved and removed only through the existing simulation ownership APIs.
- Encounter definitions/services own their own quest/camp consequences; no global encounter-kind switch accumulates in the location controller.
- Existing combat, reaction, movement, spell and quest behaviour remains unchanged unless an explicit tested design decision says otherwise.
- Every migration step validates with Godot 4.7.2 against the exact branch head.

## Explicit non-goals

- Rewriting `WorldSimulation` or replacing the combat rules.
- Creating a generic event scripting language or over-general encounter framework.
- Moving location-specific spawn anchors or environmental presentation into simulation.
- Adding new combat mechanics beyond the explicitly configured surprise/initiative effect.
