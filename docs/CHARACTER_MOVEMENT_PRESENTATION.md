# Character movement and animation presentation

## Current implementation

Simulation movement remains authoritative and hex-based. The presentation layer now treats each successful adjacent-hex move as a continuous visual transition:

- Human character actors interpolate between world-space hex centres.
- The actor turns towards the direction of travel using the same six-direction orientation convention used at spawn.
- The Ara actor switches to a semantic walk/locomotion clip while travelling and returns to idle when the transition completes.
- A new movement step can interrupt the previous visual tween without snapping the actor to a stale target.
- NPC movement and combat movement use the same `WorldSimulation.character_moved` signal and therefore the same presentation path.
- Vertical floor transitions remain authored snaps so actors do not travel through the tavern shell.

## Animation asset contract

The runtime actor searches its imported AnimationPlayer for clips whose names contain `walk`, `locomotion` or `run`, and `idle` or `stand`. This accommodates case and suffix changes in Workshop exports.

The current regression test verifies semantic clip selection and movement interpolation using a synthetic AnimationPlayer. The Ara runtime integration test separately verifies that the packaged benchmark rig contains imported animation clips. Visual review in Godot is still required to confirm that the installed player, companion and NPC GLBs expose the expected clips and that the walk cycle is correctly timed against movement speed.

If a particular character GLB has no locomotion clip, the actor will still move smoothly and face its travel direction, but it cannot display a skeletal walk cycle until an animation source is wired to that rig. Do not substitute a procedurally generated bob for a real walk cycle.

## Next phase: party formation movement

Group movement should be layered above the existing pathfinder and simulation rather than moving actors directly. The planned behaviour is:

1. A Group Move control toggles formation movement for the current party.
2. The selected character remains the formation leader; companions receive destination hexes relative to the leader's destination and facing.
3. Each companion uses the existing pathfinder and movement rules. Impassable terrain, elevation, doors and occupied hexes remain authoritative.
4. Followers re-plan when the leader changes direction, a destination becomes blocked, or a companion falls behind.
5. Followers use the same movement event and presentation path as ordinary player/NPC movement.
6. Combat keeps its existing turn economy. Formation movement is an exploration command; during combat, each character must still spend its own movement allowance on its own turn.

Formation slots must be treated as desired positions, not guaranteed teleport destinations. When a slot is blocked, the follower should choose the nearest valid reachable hex and continue to seek its assigned slot.
