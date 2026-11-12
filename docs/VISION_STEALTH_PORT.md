# Vision, line of sight and stealth port

## Integrated foundation (this branch)

- `VisionRules` provides a reusable hex LOS query, range calculation, and source-backed skill modifiers.
- Tests cover base and modified vision range, low-light exemptions, perception/stealth bonuses, clear LOS, explicit blockers, ridge occlusion, and range boundaries.
- The LOS API is deliberately a spatial query. It does **not** decide whether a hidden target is detected, what an NPC remembers, or what an AI should do.

## Explicitly not integrated yet

The original feature branch also contains a Hollowmere fog renderer and profiling instrumentation. Those pieces are not included in this foundation merge: they are tightly coupled to `HollowTankard`, have not passed their dedicated fog test, and do not persist exploration through campaign save/load. They need a separate architecture/integration pass.

The following gameplay remains future work, not completed functionality:

- Stealth checks and concealment from sight.
- Light-source propagation and the source's detailed low-light model.
- Hearing, movement/casting noise, and suspicion accumulation.
- Per-character knowledge and memory, including last-known positions and timestamps.
- Enemy investigation, search, pursuit, loss of contact, and shared sightings.
- Player exploration/fog persistence.
- Reuse of the same visibility/perception contracts by ranged attacks and AI target selection.
- Doors, buildings, and dynamic obstruction state in LOS.

## Architecture constraints for the next phase

Keep these concepts distinct:

1. **Spatial visibility** — can observer A geometrically see hex/target B, given range, terrain, elevation, doors and lighting?
2. **Character knowledge** — what has this particular character observed or heard, when, and with what confidence? This includes stale last-known positions.
3. **Detection** — has an observer actually detected a concealed target? Geometric visibility alone must not reveal every hidden actor.
4. **Presentation** — what the player is currently shown, what has been explored, and what is hidden by fog. This must not become the source of truth for AI knowledge.
5. **AI policy** — what to do with current observations and uncertain memories: investigate, search, pursue, guard, or abandon.

Combat targeting, exploration, stealth, and AI should consume shared query/contracts rather than maintain separate line-of-sight implementations. Do not let an AI read the player's visibility map or current hidden actor position directly.

## Source behaviour to preserve

The original `Hex-crpg` behaviour includes vision modifiers, hex-ray LOS, terrain/elevation obstruction, stealth scoring, lighting, hearing, remembered opponents, shared sightings, and movement/casting effects on stealth. Port those behaviours deliberately, documenting any 3D design deviations rather than silently simplifying them.

## Known limitations of the current query

- Missing intermediate map cells conservatively block LOS; callers must load the relevant spatial area.
- The initial low-light implementation uses the source's 0.2 range factor and racial exemptions but does not calculate dynamic light fields.
- Blocker height and terrain opacity are currently cell metadata; integration with actual door/building state remains to be designed.
- The current helper skill IDs/ranks are source-backed but are not yet wired to the complete skill progression/effect architecture.
