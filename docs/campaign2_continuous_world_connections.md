# Campaign 2 continuous-world connections

**Source:** `ScottENOC/Hex-crpg` Campaign 2 world and interior definitions  
**Target:** `ScottENOC/Silverhart-Saga-3D`  
**Status:** Exterior building-door teleportation has been removed. This document records the intended architecture and the remaining work.

## Non-negotiable world rule

A normal building door is a physical connection in one continuous world. Opening it changes the door's state; it does not load, activate, or switch to a different location and it does not relocate the player to a paired coordinate.

- The player walks up to the actual door tile.
- A closed or locked door blocks movement (and line of sight where appropriate).
- Opening the door changes the authoritative door state and the same doorway becomes traversable.
- The player physically crosses the threshold in either direction.
- The outdoor approach and indoor landing are ordinary neighbouring world cells, not a stored entry/return pair.
- Quest, faction, key and scripted restrictions govern whether a door can be opened; they do not create a separate travel mechanism.

The Campaign 2 location manifest therefore contains no `exterior_entry` contracts. The registry and runtime expose no exterior-entry lookup, enter or exit methods. The old F-key handler that searched for nearby registered thresholds and relocated the player into/out of an interior has been removed.

## What remains in the data

The manifest retains source-authored location anchors, floor footprints, walls, doors, furniture, actors, creatures, secret-door dependencies and stair positions. Door IDs and local coordinates remain useful authoring data. The old paired exterior/return coordinates have been deleted because normal movement and collision determine how a character crosses a doorway.

The Hollow Tankard is the starting building in Hollowmere, not a special exception to the rule. Its front door is at source hex `(0,4)`, initially closed and locked for the opening scene. The shakedown sequence opens it for the soldiers, then closes it while leaving it unlocked. The outdoor path begins at `(0,5)`; the player walks through the same door without a location transfer.

## Multi-storey buildings

The current multi-storey runtime retains source-authored floor stacks and reciprocal stair connections. At a stair, the character moves onto the authored stair hex and the runtime changes the active floor presentation and actor elevation. This is not an exterior door teleport, but it is still a floor-activation model: inactive floors are hidden and their cells are removed from the active movement map.

A more fully continuous 3D building should eventually keep the building's connected floors present together, with visible physical stair geometry joining them. Whether every floor can be represented simultaneously depends on camera, collision, navigation and presentation constraints. The present floor-stack data is retained as a migration source; do not reintroduce exterior door teleportation as a workaround.

## Remaining integration work

1. Embed each authored building footprint into the regional world map so exterior ground, walls, interior floor and door occupy their real world coordinates at the same time.
2. Make one shared door-state/presentation path consume the existing door IDs and open/closed/locked state. It must update movement blocking and line of sight, not just rotate a visual mesh.
3. Integrate multi-storey floor geometry and stair connections without swapping to a separate location scene. The current floor-state transition is a stepping stone, not proof that stacked interiors are fully continuous.
4. Convert the special secret-tunnel network from node-to-node location transfers into connected world-space corridors when its regional underground geometry is authored. It is currently a distinct legacy traversal path, not an ordinary building-door interaction.
5. Add tests that move a character through the real adjacent world cells and verify door blocking, opening, closing, occupancy, line of sight and floor connectivity. Tests must not simulate a door by inserting a fake exterior hex and teleporting between coordinates.

## Scope of the teleport-removal change

This change removes the generic exterior-entry/return system and its 63 manifest contracts. It does not claim that every building interior has already been merged into the regional terrain or that every door is fully interactive. Those are the next continuous-world implementation tasks. The important architectural guarantee is that normal building doors no longer have a teleport path to fall back on.
