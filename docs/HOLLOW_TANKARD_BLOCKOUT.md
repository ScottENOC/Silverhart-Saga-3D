# Hollow Tankard — first 3D blockout

## Purpose

This is the first authored location in Silverhart Saga 3D. It replaces the temporary outdoor hex test field as the project's launch scene. It is a visual and movement blockout, not yet the complete Campaign 2 opening.

## Agreed building envelope

- Rectangular internal hall: 16m × 11m.
- Approximate exterior footprint: 16.7m × 11.7m.
- Wall thickness: 0.35m.
- Eaves: 3.2m; ridge: 5.8m (provisional).
- Pitched roof ridge runs along the long axis.
- Centred south entrance: 1.6m wide × 2.4m high.
- Bar on the north wall; fireplace on the west wall.
- Two central tables with benches and a clear central route.
- Small windows on the north, east and west walls.

## Current implementation

- One continuous flat-top axial grid covers the room and a small outdoor approach.
- Logical map cells are separate from rendered meshes.
- Wall, furniture and doorway footprints influence logical walkability.
- The roof is a separate cutaway layer, hidden by default; press **V** to show/hide it.
- Temporary capsule-and-sphere actors mark the player, Wren Talbot, Garrick Holt, Mira Ashbrook, Oskar Vinn, Dray Coltayne, Tomlin Brask and Hask Greel.
- The existing orbit camera and six-direction movement controls remain in use.

## Not implemented yet

- Detailed character models, rigs, clothing, facial features or animation.
- Seated player pose and Wren's introductory interaction.
- Soldier entry choreography, dialogue, timed shakedown beats or branching decision.
- Doors as interactive/lockable simulation objects.
- Physical collision bodies for walls and furniture; current movement blocking is logical hex occupancy.
- Real prop meshes, textures, lighting polish, audio or a finished roof/gable/chimney kit.
- Save/load integration for this location.

## First review checklist

1. Does the room feel appropriately spacious with the current human placeholders?
2. Is the entrance legible and comfortable to move through?
3. Are the bar, fireplace and tables in sensible positions?
4. Can the player navigate between furniture without unexpected blocked cells?
5. Does the roof cutaway make it easy to inspect the interior?
6. Does the camera remain useful inside the room and just outside the entrance?

Treat measurements as a first blockout. Adjust the room and grid together based on the running scene rather than preserving a dimension that feels wrong in play.
