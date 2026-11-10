# Farm animals and wilderness creatures

## Imported Quaternius models

The runtime uses the original imported glTF scenes and keeps their native skeletons and animation libraries. `CreatureActor` discovers each model's AnimationPlayer and selects the best matching clip from species-specific animation-name hints. It does not assume all animal packs use identical clip names or retarget them to Ara.

Current placements:
- Three cows in Old Mac's fenced southern pasture.
- A horse beside the farm barn as a future riding-mount candidate.
- Deer, stag, fox and wolf as ambient woodland dressing.
- Additional deer, stag, fox and wolf actors can spawn during travel once the player is beyond Hollowmere's 35-hex safety radius. The spawn roll is movement-based, capped, and old sightings are culled as the party moves on.

## Old Mac's farm quest

The 2D Campaign 2 quest `farm_wolves` is adapted to the 3D campaign journal:
- Old Mac reports that wolves have killed two cattle.
- Accepting the quest adds `Wolves at the Farm` to the journal.
- A broken fence and blood trail lead away from the western pasture edge.
- Approaching the distant den spawns three wolf combatants using the existing turn-based combat simulation.
- The objective completes only after all three wolves are defeated.
- Returning to Old Mac awards 25 gold, 150 experience and +15 reputation.

The den is intentionally outside the farm and village sightline. The encounter can be retried after retreating from the den if the party is defeated.

## Validation

Run the Godot script test:

```sh
godot --headless --path . --script res://tests/test_farm_wolves_quest.gd
```

The test checks quest acceptance, objective completion, reward payout, Old Mac reputation, and the required glTF files. The full scene and imported animation clips still require an in-editor visual play-test.
