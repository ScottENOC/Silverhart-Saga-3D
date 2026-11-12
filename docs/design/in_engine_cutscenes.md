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

### Ara animation integration

Live actors are the same Ara-backed character instances used by gameplay. Their
`AraCharacterActor` wrapper exposes embedded animation clip names and a
semantic clip matcher. The cinematic requests sitting, drinking, talking,
standing, walking and idle clips by name fragments, with safe fallbacks when a
particular export does not contain a requested action. The exact imported clip
names are logged at runtime when a requested action is unavailable.

The opening stages the player and Wren at the existing east dining table,
places temporary tankards on the tabletop, attempts the available sitting and
drinking clips, then hides the tankards and stages both characters facing the
entrance as the Ironbond arrive. The Ironbond actors are asked to play their
available walking clips during their existing hex movement. Original actor
transforms are restored when the cinematic ends, before the existing player
decision is shown.

The Ara export pipeline requests animations for the high-detail body exports.
Sitting, drinking and standing are not assumed to exist: the runtime matcher
uses them only when the imported GLB actually contains a matching clip. A
visual playtest is still required to verify clip names, retargeting, seating
alignment, hand/prop interaction and timing on the shipped exports.

## Ara animation catalogue usage in the Hollowmere opening

The opening uses clip labels from the Ara 3D Gen animation catalogue rather than
invented semantic guesses:

- `Sit idle` keeps the player and Wren seated at the east dining table.
- `Talk with gestures` is requested for dialogue speakers.
- `Stand up (on a chair)` plays when the Ironbond entrance is announced.
- `Walk` carries each character a short distance to a position beside their
  own bench; they then return to `Idle`.

The documented chain is `Idle → Sit down → Sit idle → Stand up (on a chair) → Idle`.
The catalogue does not document a drinking/sipping clip, so the opening no
longer requests one. Tankards remain tabletop props.

At cinematic start, the runtime logs the exact imported AnimationPlayer clip
names and the GLB path for the player and Wren under
`[Ara animation catalogue]`. This is intentional: the catalogue documents
available generator clips, but a particular GLB export may contain a subset.
A visual playtest is still required to confirm the standing transition and
bench-side positions look correct in the assembled tavern.