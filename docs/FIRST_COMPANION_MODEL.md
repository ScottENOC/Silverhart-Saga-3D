# First named companion model: Ser Aldric Thorne

This is a separate companion appearance manifest, not another Hollowmere resident spawn. It uses the pinned Ara human base with a distinct adult male build, warm olive complexion settings, dark hair, short beard, navy/steel palette and sword. The profile links to the original `skarn_tooth_camp` encounter through `location_id`; it deliberately does not invent a local village coordinate.

The workflow exports the Ara GLB, then runs the existing Blender full-coverage armour shell tool with a new metallic Silver Vigil plate finish. The output is a first-pass, reviewable model artifact, not yet visually accepted production art. The armour shell inherits the Ara body's vertex weights and covers torso, back, shoulders, upper arms and legs; the model still needs inspection for fit, clipping, deformation and silhouette.

The original campaign encounter is source-backed: Aldric is held tied near the Skarn-tooth goblin campfire. The player can free him, recruit him immediately or allow him to travel independently toward Reddale. The camp and surrounding approach need a dedicated world-expansion implementation before this model is placed in the playable world.

## Review

- Ara source profile: `data/characters/companion_models.json`
- Blender armour pass: `tools/blender/create_full_coverage_armor.py --style steel`
- Artifact: `ser-aldric-companion-model`
- Expected model: `ser_aldric_thorne_armoured.glb`

Do not treat the profile or successful export as proof that the visual design is approved.
