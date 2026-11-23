# Character movement and animation presentation

## Current implementation

Simulation movement remains authoritative and hex-based. The presentation layer treats each successful adjacent-hex move as a continuous visual transition:

- Human character actors interpolate between world-space hex centres.
- The actor turns towards the direction of travel using the same six-direction orientation convention used at spawn.
- The Ara actor uses the shared animated benchmark rig to drive compatible gameplay body meshes, switches to a semantic walk/locomotion clip while travelling and returns to idle when the transition completes.
- A new movement step can interrupt the previous visual tween without snapping the actor to a stale target.
- Player, companion, NPC and individual combatant movement use the same simulation movement event and presentation path.
- Vertical floor transitions remain authored snaps so actors do not travel through the tavern shell.

## Animation asset contract

The runtime actor searches its imported AnimationPlayer for clips whose names contain `walk`, `locomotion` or `run`, and `idle` or `stand`. This accommodates case and suffix changes in Workshop exports.

The focused regression test verifies semantic clip selection, mid-transition interpolation, facing and interrupted movement using a synthetic AnimationPlayer. A second Godot integration test loads both committed female and male gameplay body GLBs, binds their visible skinned meshes to the animated benchmark skeleton, and verifies that real walk and idle clips drive the gameplay skeleton. The runtime only uses the benchmark carrier when the selected body has a compatible skeleton; incompatible models retain their native pose and emit a warning. Visual review in Godot is still required to confirm every companion/NPC model, foot contact, clipping and walk-cycle timing against movement speed.

If a particular character GLB has no locomotion clip, the actor will still move smoothly and face its travel direction, but it cannot display a skeletal walk cycle until an animation source is wired to that rig. Do not substitute a procedurally generated bob for a real walk cycle.

## Combat movement

There is no group movement or formation-following mode. Exploration and turn-based combat both move characters individually. In combat, every combatant moves on its own turn and remains subject to the existing movement allowance, pathfinding, occupancy and terrain rules. The presentation tween changes only how an authorised move is displayed; it does not grant extra movement or alter simulation state.
