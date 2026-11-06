# Male anatomy blockout

The male Ara review is generated from the pinned Ara 3D Gen release with an explicit adult body configuration. The anatomy pass creates a **separate continuous body-part mesh** named `Body_Genital_Male`, using the Ara skin material and the canonical Ara armature.

## Construction

- Penis and scrotum are built as one remeshed surface component, not as a flat decal or equipment/accessory object.
- The proximal shaft is intentionally buried into the pelvis to avoid a visible attachment cap.
- The shaft has a restrained downward resting angle; the scrotum is a joined, two-lobed form below the root.
- The component is weighted to the existing Hips/Pelvis bone and exported with the same rig. No new skeleton or independent animation system is introduced.
- The component remains separate from the base torso mesh, following the independently addressable body-part pattern used by Ara's other skinned parts. Clothing can cover it without modifying the underlying anatomy.

## Review status

This is an initial procedural blockout, not final anatomy. The GitHub Actions artifact includes the GLB and front, side, rear and three-quarter renders. Review the silhouette, scale, skin-material match, pelvis intersection and behaviour in the neutral pose before refining it. The first pass uses a single Hips weight; if pose testing reveals unwanted rigidity, add a small set of dedicated pelvis/genital deformation weights or a compatible rig bone rather than faking motion with an accessory transform.

The workflow is intentionally separate from the female Ara/Wren Workshop build. It does not alter Wren's female anatomy or publish a new Workshop build.
