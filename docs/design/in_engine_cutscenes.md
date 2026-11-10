# In-engine cutscenes

## Hollowmere opening: Ironbond's Due

The opening sequence in `HollowTankard` is presented by the reusable
`CinematicDirector` (`scripts/presentation/cinematic_director.gd`). It uses
the live world, current character actors, appearance and equipment. It does
not render or play a pre-recorded video.

The director owns a dedicated cinematic camera and temporary subtitle/skip
UI. It temporarily hides the gameplay HUD and deactivates the gameplay camera,
then restores both when the sequence ends. The orbit camera rig itself is not
repurposed or destroyed.

### Sequence

1. Wren greets the player and the pair exchange a short introductory
   conversation.
2. The Ironbond enforcers enter the tavern using the existing hex movement.
3. The existing `HollowmereCampaignContent.opening_lines()` dialogue plays:
   the narrator announces the entrance, Dray makes the demand, Garrick
   protests, and Dray makes his threat.
4. The director restores the gameplay camera and HUD, then the existing
   `HollowmereCampaignContent.shakedown_choices()` choices are presented.

The director does not resolve the player's decision. The existing choice
handler remains responsible for reputation, faction standing, quest progress,
peaceful departure, and the combat hand-off. Combat is not part of the
cutscene.

### Skip behaviour

Skipping ends the remaining dialogue and camera presentation only. It still
ensures the enforcers have entered the tavern and always presents the
Ironbond decision. No faction is selected automatically and the quest cannot
be bypassed by skipping.

### Extending the system

Future sequences can reuse `CinematicDirector.begin()`,
`present_line()`, `was_skipped()`, and `finish()`. Keep quest/reputation
decisions in their simulation/content systems; the director should remain a
presentation layer.
