# Ara hairstyle export pipeline

The pinned Ara generator builds catalogue and procedural hair as distinct mesh/material groups inside the character mesh. Those groups carry the same Ara bone indices and skin weights as the character. Silverhart now extracts those groups from the generator's MeshData (not by cutting a finished GLB in Blender), exports them as standalone skinned GLBs, and exports a hairless male and female base body with the matching skeleton.

The manual **Build Ara Hair Variants** workflow creates the base bodies and available curated hairstyles for both sexes. Catalogue variants are filtered by the generator's male/female tags; procedural buzz, mohawk, cornrows and box braids are generated for both. The manifest records material names, vertex/triangle counts, bone names and SHA-256 hashes. Hair colour is intentionally not baked into geometry: it can be changed by tinting the imported hair material at runtime.

The Godot smoke test verifies each base and hair GLB imports, has a skeleton, and that every standalone hair mesh retains a Skin resource. This is a structural check only. It does not prove that the hair is correctly aligned to the current Workshop body, that bone ordering matches in every export, or that the runtime attachment works. The generated male/female base and hairstyle GLBs must be visually reviewed before replacing the current preview assets or enabling the selector.

## Runtime integration

A separate hair GLB contains its own copy of the Ara skeleton. To attach it, the actor must validate bone count and names against its base skeleton, duplicate the skinned MeshInstance3D, and retarget its Skeleton3D path to the base actor skeleton. Do not attach a hairstyle to the legacy Hollowmere female model: it must use the matching Ara female base export. Keep the original base hair hidden when a replacement is attached.
