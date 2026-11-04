# Architecture baseline

## 1. Non-negotiable separation

### Simulation
Owns authoritative gameplay state:
- Stable character IDs and character data.
- Logical hex occupancy, movement legality and path costs.
- Health, attributes, skills, equipment and status effects.
- Action/time-point economy and reactions.
- Relationships, faction standing, reputation and political state.
- Quest state, world events, NPC schedules and campaign state.
- Resource and inventory state.

Simulation code must be testable without loading 3D scenes.

### Presentation
Owns visual representation:
- Character models, rigs, animation and facing.
- Smooth interpolation between logical positions.
- Camera, lighting, particles, sound and UI.
- Visual feedback for movement, attacks and status changes.

Presentation may request actions but cannot independently decide whether they are legal. A visual tween is never proof that a move succeeded.

## 2. World coordinates

Use flat-top axial hex coordinates with a separate elevation/floor dimension.

For hex radius s:
- x = 1.5 × s × q
- z = √3 × s × (r + q/2)
- y = elevation

The initial radius of 1.25m is provisional. Validate against human scale, doorway clearance, furniture, two-character passing and melee reach before building the tavern.

Buildings share the world grid. A building's rendered architecture is separate from its logical representation: walkable cells, walls, doors, furniture obstruction, line of sight, floor and elevation.

## 3. Identity and persistence

- Use stable IDs, never display names as unique keys.
- NPC simulation state persists when its 3D presentation is unloaded.
- Presentation nodes are disposable projections of simulation state.
- Save files use a new versioned schema; legacy browser saves are not required for the first prototype.
- Saves must include world time, NPC state, relationships, faction state, event queue and consequences—not merely currently loaded scene nodes.

## 4. Movement and combat

Logical occupancy and legal movement remain simulation-owned. The presentation layer interpolates between accepted positions.

The eventual combat system preserves the source game's real-time world simulation and action/time-point economy, including movement and attack costs, reactions, interruptions, AI decisions and status effects. Do not replace it with conventional turn-based combat or free physics movement as the authority.

AStar3D may support discrete graph pathfinding. NavigationServer3D/NavMesh may support continuous movement presentation where useful, but neither replaces the logical hex rules.

## 5. Events and commands

Use explicit simulation commands for state-changing actions and events for observable outcomes. Dialogue choices should resolve through commands, not mutate global state from UI callbacks.

The Hollow Tankard opening should be event-driven, not copied as a chain of arbitrary setTimeout calls. Its milestones include Wren's introduction, the shakedown, soldier entry, dialogue beats, player decision and branch consequences. Save/load must not replay an already-resolved opening.

## 6. Scene and content strategy

- One persistent world state; load/unload presentation as needed.
- Authored world and campaign content should be data, not executable browser globals.
- Convert content definitions that embed JavaScript functions into explicit effect definitions and resolvers.
- Build the Hollow Tankard as a real rectangular building first, then fit the logical grid to it.
- Do not build the entire village before the tavern vertical slice is playable.

## 7. Simulation port: first increment

The first simulation increment is deliberately independent of the 3D scene:

- `ActionEconomy` owns the 100 TP combat-readiness threshold, 80 TP turn-end threshold, Quick Recovery adjustment and 150 TP regeneration gate.
- `CharacterState` stores TP, TP regeneration rate, health, axial position and stable identity, with dictionary serialisation.
- `WorldClock` advances in fixed 0.4-second world-time steps. Exploration advances at 5 world-seconds per real second; combat waiting advances at 40, reflecting the source engine's different cadence. Time and TP progression pause while a combatant is taking a turn.
- The calendar uses twelve 30-day months, preserving the source month names.
- `CombatTurnScheduler` selects the eligible living, conscious, non-rider, non-dormant character with the highest TP; equal-TP ties are random.
- `WorldSimulation` owns the clock, scheduler, occupancy and movement commands. It emits events for presentation to observe.

This is a tested foundation slice, not the completed port. Terrain-specific movement costs, the full status-effect tick, spell durations, combat actions/reactions, active-radius simulation culling, NPC schedules, world events and a versioned whole-world save service remain outstanding. The current M1 movement harness still uses free debug movement; gameplay movement uses the TP-costed command.
