# In-engine cutscenes

## Hollowmere opening: Ironbond's Due

The opening is split into two presentation components:

- `CinematicDirector` owns the temporary cinematic camera, subtitles, skip control, actor framing and semantic animation requests.
- `HollowmereOpeningSequence` owns the Hollowmere-specific table staging and stand-and-face-the-Ironbond blocking. Wren's opening exchange and the Ironbond dialogue are supplied by `HollowmereCampaignContent`.

The sequence borrows the live actors from the location. It does not instantiate replacement character models or own campaign state.

### Ownership boundaries

- `WorldRoot` remains the campaign composition root.
- `WorldSimulation` remains the authority for character positions on the hex map, quests and encounter state.
- `HollowTankard` starts the opening quest, supplies its existing dialogue content, moves the Ironbond through the simulation and presents the existing choice panel.
- `HollowmereOpeningSequence` stages the live player and Wren models for the cinematic.
- `CinematicDirector` handles generic camera, subtitle and animation presentation.

The cinematic never resolves the player's decision. Reputation, faction standing, quest progress, peaceful departure and combat hand-off remain in the existing campaign handlers.

### Sequence

1. The player and Wren sit opposite each other at the east taproom table and exchange a short conversation.
2. The Ironbond arrive. The player and Wren stand, step to the ends of their own benches and face the south entrance.
3. The existing `HollowmereCampaignContent.opening_lines()` dialogue plays while the enforcers enter using normal simulation movement.
4. The cinematic restores the gameplay camera and HUD; the existing Ironbond choice panel is shown.

Skipping ends the presentation early but does not prevent the enforcers entering or bypass the decision.

### Character integration

Characters are resolved through the current actor factory hierarchy: each live actor exposes its `AraCharacterActor` at `CharacterModel`. The wrapper reports actual imported animation names and matches requested clips semantically, allowing GLB animation-library prefixes and case differences. Missing clips fail safely and are logged; the sequence does not assume that a documented Ara catalogue clip is present in every exported model.

The current taproom table and benches are used. Tankards are temporary presentation props and are removed when the sequence finishes.

Automated headless tests cover animation-name matching. A visual playtest is still required to confirm the current player/Wren exports contain suitable clips and that seating, standing, camera framing and movement look right in the running game.
