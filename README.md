# Silverhart Saga 3D

A standalone Godot 4 project exploring a 3D implementation of the existing Silverhart Saga / Hex-crpg game. The original browser game remains independent and is the behavioural reference.

## Current status

**Milestone:** M1 prototype foundation  
**Engine baseline:** Godot 4.7.2 stable (GDScript, Forward+)  
**Target:** Windows PC first  
**Prototype:** generated hex test field, six-direction logical movement, smooth 3D presentation and player-controlled orbit camera.  
**Simulation port in progress:** character Time Points, fixed-step world clock, Silverhart calendar, TP-costed movement API and combat initiative scheduler.

The current movement harness intentionally retains free debug movement. Gameplay code can use the cost-bearing movement API. Combat attacks, spells, reactions, AI turns, full character progression, dialogue, campaign content and complete save/load are still to come.

## Open the project

1. Install Godot 4.7.2 stable (standard build, not .NET).
2. Clone this repository.
3. In Godot, import `project.godot`.
4. Run the project (F6/F5).

Controls:
- `Q W E / A S D`: move to one of the six adjacent logical hexes.
- Hold right mouse button and drag: orbit camera.
- Mouse wheel: zoom.

## Project principles

- The simulation owns logical state and legal actions.
- 3D nodes present that state; they do not decide game rules.
- Logical movement is flat-top axial hex movement.
- The rendered world should not require visible hex tiles in the finished game.
- The original `Hex-crpg` repository is read-only reference material for this project.
- Do not copy the old browser runtime or its global-state architecture.

## Repository workflow

- `main`: stable, playable integration.
- `dev`: integration branch.
- `feature/<topic>`: isolated work.
- Use Git LFS selectively for source art and large audio/model files. Do not automatically put every texture or small exported asset in LFS.

## Tests

With Godot installed, run:

```powershell
godot --headless --path . --script res://tests/test_hex_grid.gd
godot --headless --path . --script res://tests/test_simulation.gd
```

The test scripts are included but have not yet been executed in this environment. See `docs/` for the technical decisions and milestone plan.
