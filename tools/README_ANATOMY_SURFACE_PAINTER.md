# Ara anatomy surface painter

This is a Godot-native authoring tool for the exact imported Ara GLB mesh data used by the game. It deliberately avoids a Blender round-trip: a re-export can change vertex order and invalidate authored vertex labels.

## Launch

1. Open the project in Godot 4.7.2.
2. In the FileSystem dock, open `res://tools/anatomy_surface_painter.tscn`.
3. Run the scene (F6).
4. Choose Female Ara or Male Ara, then choose the mesh surface and anatomical region.
5. Paint directly on the body. Right-drag to orbit, mouse wheel to zoom, left-drag to paint.
6. Save the current surface mask to the suggested `.tres` path under `res://data/characters/anatomy_masks/`.

The first run may take a little longer while Godot imports the GLB and creates static picking geometry.

## Semantic label groups

The selector groups the 73 supported fine surface IDs into:

- Head and neck: face, lips, ears and neck surfaces.
- Torso and chest: clavicles, breasts, areolae, nipples, underbust, back, abdomen, waist and flanks.
- Pelvis and external anatomy: pelvis, hips, buttocks, groin, perineum, anal/perianal surface and the applicable external vulvar, penile and scrotal regions.
- Arms and hands: shoulders, elbows, forearms, wrists, palms and backs of hands.
- Legs and feet: inner/outer thighs, knees, calves, ankles, tops of feet and soles.

Only paint a region on a body where that anatomy is present. The shared vocabulary does not mean the male and female boundaries are identical. For example, breast, areola and nipple masks must be independently reviewed on each base. Use left/right mirroring as a first pass only; verify both sides in the viewport.

These masks support surface queries for fitting and contact. They are not garment seam curves, collision volumes, rig joints or permission flags. The separate garment-guide layer still needs to author neckline/armhole loops, bust and underbust guides, waist/hip loops, crotch junctions, inseams/outseams and limb openings. Animation uses rig landmarks; cutscenes use contact anchors; combat uses pose-aware volumes. Those systems should consume this shared anatomy contract rather than adding offsets to individual animations.

## Painting controls

- **Mesh surface** selects the exact skinned mesh surface being authored. Painting a different surface is blocked until it is selected.
- **Anatomical region** selects one semantic channel.
- **Brush radius** is in metres; strength controls the amount added or removed per stroke.
- **Paint / add** increases weights toward 1.0; **Erase / subtract** decreases them toward 0.0.
- **Mirror paired left/right region** mirrors a stroke across the body's local X=0 plane and writes to the paired semantic ID (left/right breasts, hips or buttocks). The tool reports how many vertices could be paired. The mirror map uses nearest-position matching within 12 mm; inspect the mirrored result before saving.
- **Clear selected region** clears the selected channel in the current in-memory surface mask.
- Blue markers show non-zero weights for the selected region. Rotate the body and inspect the boundaries before saving.

Central regions (underbust, waist, groin) mirror to themselves. Mirroring is optional and can be disabled for asymmetric anatomy.

## Output and runtime use

Each saved resource targets one body asset, mesh-node path and surface index. It includes the imported surface's vertex count, name and SHA-256 signature plus one packed weight array per authored semantic region. Saving runs the same strict validation used at runtime. If the GLB topology changes, the old resource is rejected and must be re-authored.

Saved resources are registered in `data/characters/anatomy_masks/manifest.tres`. That manifest explicitly references every mask so Godot includes them in exported builds. `CharacterSurfaceRegionMaskLibrary` loads only entries whose `body_asset_path` exactly matches the actor's loaded GLB when the actor first requests `get_surface_regions()`. The painter updates the manifest whenever a mask is saved. Do not use the synthetic one-vertex mask from the contract test.

## Current limitations

- The tool paints the canonical imported rest-pose mesh. It does not author dynamic morph-specific masks or pose-specific masks.
- The first version paints vertices by a 3D Euclidean brush radius, not by geodesic distance over the surface. A surface-normal hemisphere filter suppresses most opposite-facing hits, but closely folded or adjacent surfaces can still be affected; inspect the far side for unintended paint.
- Mirror matching is geometric nearest-neighbour matching, not a guaranteed topological correspondence. Check the reported match count and visually inspect both sides.
- The marker overlay is a vertex point cloud, not a continuous heatmap. Use multiple viewing angles and small brushes for boundaries.
- It does not automatically infer anatomical labels. Production labels require human visual judgement and review, including checks against Reyna and Dagna.
- It authors masks only. It does not change body geometry, create missing female morph targets, or fit garments.

## Garment guide curves (separate follow-on authoring layer)

The separate runtime contract is `CharacterGarmentGuideCurve`. A guide point is attached to a source triangle using three vertex indices and barycentric weights, not a free-floating coordinate. The resource is tied to the exact body asset, mesh surface and rest-mesh signature. Runtime evaluation uses the shared deformation-aware vertex evaluator and returns position, normal, tangent, binormal and a local frame for every guide point.

The first supported guide IDs cover neckline/collar, shoulder seams, armholes, chest line/cup apexes, underbust, waist/hip loops, seat/crotch junctions, inseams/outseams, limb openings and foot alignment. `CharacterGarmentGuideLibrary` supplies body-specific resources to Ara actors.

The guide manifest is currently empty. The test fixture is synthetic and must not be used for fitting. Production curves still need to be traced and visually reviewed on both canonical bodies. A dedicated visual curve editor is the next authoring-tool task; the existing vertex painter does not author curves.

## Launch the garment guide curve editor

1. Open the project in Godot 4.7.2.
2. Open `res://tools/garment_guide_curve_editor.tscn` and run it (F6).
3. Select Female Ara or Male Ara, then the exact mesh surface and guide type.
4. Left-click sequentially on the skin to trace the curve. Right-drag to orbit and use the wheel to zoom. Use Undo/Clear while refining the line.
5. Enable Closed loop for circumferences, inspect the line from several angles, then save the validated resource. Saving also registers it in `data/characters/garment_guides/manifest.tres`.

Each click is stored as a source triangle plus barycentric coordinates. The editor's collision surface is a rest-pose picking proxy; the saved attachment is subsequently evaluated by the runtime skinning/blend-shape evaluator. Trace male and female guides independently. Start with major loops (neckline, underbust, natural waist, high/full hip) before adding armholes, crotch junctions and limb openings. These are construction guides, not garment meshes or finished fit solutions.
