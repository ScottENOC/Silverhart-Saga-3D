# Player character visual integration — Phase 1

## Scope

Phase 1 connects the existing first-run character profile to an actual 3D preview and to the player actor spawned in Hollowmere. The player body is selected independently from gender presentation and pronouns.

## Runtime asset contract

The game resolves these replaceable paths:

- Female baseline: `res://art/characters/hollowmere/player_avatar.glb` (from the Hollowmere NPC model artifact).
- Male body: `res://art/characters/ara_runtime/ara_person_male_body.glb` (from the latest available Wren Workshop runtime package).

The male body is deliberately treated as a replaceable Workshop export. Its geometry is not copied into scripts or merged into the game repository. The web-export workflow retrieves the newest unexpired `ara-runtime-assets-*` artifact from recent Wren Workshop runs and unpacks it into the path above. If the package or file is not available, the creator reports that fact and Hollowmere uses the neutral capsule fallback rather than silently showing the wrong body.

When the male body is updated in the Workshop, the next successful runtime package is picked up by the next game web export. No game-code path change should be necessary unless the asset filename or package contract changes.

## Live preview and profile

The first-run creator uses a SubViewport with its own camera, environment and directional light. The user can rotate the preview and change:

- Body model: female baseline or male Workshop body.
- Skin, eye and hair colour, where matching materials exist in the exported GLB.
- Height: a restrained whole-model scale adjustment.
- Body build: a restrained width scale adjustment.

Body build and height are temporary whole-model proportion controls, not true anatomical morphs. Replace them with validated Ara morph targets or generated body variants when the authoring pipeline exposes them.

Hair style and starting shirt/legwear remain saved profile fields, but the current exported assets do not yet provide independently swappable styles and garment meshes for both body variants. The creator states this limitation instead of implying those choices are already rendered.

## In-game application

The same selected body path is used when Hollowmere spawns the player. After loading, `AraCharacterActor.apply_player_profile()` applies the supported material tints and proportion controls. The player's name label, gender presentation and pronouns remain separate from the body model selection.

## Deliberate next work

1. Finalise and replace the male Workshop body export.
2. Validate the male and female exports against the same skeleton contract and test deformations.
3. Fit a minimal shirt, trousers and footwear set independently to both bodies.
4. Add real body morphs and independently swappable hair assets.
5. Extend visual equipment selection so saved shirt/legwear IDs resolve to actual compatible meshes.

This phase establishes the replaceable runtime boundary and visible player selection. It does not claim the male wardrobe or full anatomical morph system is complete.
