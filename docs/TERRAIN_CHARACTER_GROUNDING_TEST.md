# Terrain character grounding test

This prototype adds physics-driven capsule proxies to the existing valley / slope / ridge terrain scene. It is deliberately independent of production character scenes so terrain collision can be validated while character modelling continues.

## What is exercised

- Three stationary `CharacterBody3D` proxies spawn over the valley floor, a moderate slope and the ridge.
- A fourth proxy walks horizontally toward and across the ridge, reversing when its capsule encounters a wall.
- Each proxy uses a capsule collision shape and a matching capsule visual.
- The terrain renderer creates a static concave collision shape from the exact mesh used for rendering.
- The screenshot capture script waits for physics to settle and fails if any proxy is not reported as grounded.

## What this does not prove yet

- It does not validate production skeletons, foot placement, retargeted walk cycles or root motion.
- The walker is a simple horizontal physics test, not the game's hex-step movement controller.
- It does not yet test slope-specific climbing permissions, edge-profile ledges, animation adaptation, navmesh behaviour or terrain ray picking.
- The current terrain is still a coarse prototype mesh; successful capsule grounding is not evidence that its visual quality is production-ready.

The next integration step is to replace the capsule visual with an instance of a production character scene while keeping the same physics body / terrain test route. Then compare visual foot contact and animation against the physics body's grounded position.
