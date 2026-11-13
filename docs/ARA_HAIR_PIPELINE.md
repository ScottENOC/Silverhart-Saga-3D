# Ara hairstyle export pipeline

The pinned Ara generator builds catalogue and procedural hair as distinct mesh/material groups inside the character mesh. Those groups carry the same Ara bone indices and skin weights as the character. Silverhart extracts those groups from the generator's MeshData (not by cutting a finished GLB in Blender), exports them as standalone skinned GLBs, and exports a hairless male and female base body with the matching skeleton.

The **Build Ara Hair Variants** workflow builds both sexes and the curated available styles. The curated catalogue styles are exported for both body variants; the generator's fitted proxy geometry is tested against each sex's base head rather than hiding styles based on catalogue tags. Procedural buzz, mohawk, cornrows and box braids are also generated for both. The manifest records material names, vertex/triangle counts, bone names and SHA-256 hashes. Hair colour is not baked into geometry: the actor tints the imported hair material at runtime.

The player creator now offers the curated style list and maps each selection to its corresponding GLB. The actor validates that the hair and base skeletons have identical bone counts and names, duplicates the skinned mesh, and points it at the base character's skeleton. It hides the base model's embedded hair while the replacement is attached. The selector uses the matching Ara female/male base export; it deliberately does not attach Ara hair to the legacy Hollowmere female skeleton.

## Validation boundaries

The workflow runs Ara's TypeScript type-check, generates the base bodies and hairstyle meshes, imports them in Godot 4.7.2, and checks that each hairstyle has a Skin resource and non-empty skeleton. This is a structural check, not proof of visual fit or correct animation deformation. Review the generated styles in the Workshop before treating them as final. If a style fails the actor's skeleton check, it is rejected rather than attached to the wrong rig.

The generated GLBs are committed to the feature branch only after the Godot import test passes, and are also uploaded as a versioned Actions artifact.
