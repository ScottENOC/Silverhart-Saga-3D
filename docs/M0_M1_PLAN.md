# M0 and M1 implementation plan

## M0 — Project foundation

### Deliverables
1. Godot project opens and runs headlessly.
2. Core axial hex conversion and distance functions.
3. Basic map data independent of scene nodes.
4. Character state with stable ID and serialisation shape.
5. Simulation object that validates a one-cell move.
6. Test harness for coordinate conversion and basic state.
7. Save schema design and event/command contracts.
8. Git workflow and selective LFS configuration.

### Acceptance tests
- Axial-to-world and world-to-axial round-trip over a broad coordinate sample.
- Every one of the six neighbours has distance 1.
- Missing or blocked cells reject movement.
- Non-adjacent movement is rejected.
- Character state can serialise and reconstruct without losing ID or hex.
- Simulation tests run without loading a 3D scene.

## M1 — 3D movement and camera prototype

### Deliverables
1. Small outdoor test environment.
2. One character presentation node.
3. Smooth movement between adjacent logical hexes.
4. High-angle orbit camera with free yaw, pitch limits and zoom.
5. Obstacles that reject logical movement.
6. Debug hex display or coordinate readout, toggleable and absent from final art.
7. A small set of movement tests with visual/manual verification.

### Acceptance tests
- Six-direction movement follows the axial map.
- Character visual ends at the simulation's authoritative hex.
- Rejected movement does not move the visual actor.
- Camera orbit and zoom do not alter simulation state.
- Camera can rotate continuously without forced cinematic changes.
- The player remains visible and readable while zooming from exploration to tactical distance.
- No obvious visual snapping between adjacent cells.
- The same logical map can be tested headlessly.

## M1 decision gate

Do not build the tavern kit until these questions are answered by a running prototype:
- Does 1.25m hex radius produce believable human scale?
- Can a character pass through a realistic doorway?
- Can two characters pass or fight in a modest room?
- Does hex-constrained movement look natural enough?
- Is the camera comfortable at both exploration and tactical distances?
- Can physical props obstruct movement without creating disagreement with logical occupancy?
