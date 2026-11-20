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

Load the resulting resources and pass them to `CharacterSurfaceRegions.configure(character_root, body_root, mask_resources, body_asset_path)`. Collect resources for all authored surfaces of that body into the array. Do not use the synthetic one-vertex mask from the contract test.

## Current limitations

- The tool paints the canonical imported rest-pose mesh. It does not author dynamic morph-specific masks or pose-specific masks.
- The first version paints vertices by a 3D Euclidean brush radius, not by geodesic distance over the surface. On thin or closely opposed body surfaces, inspect the far side for unintended paint.
- Mirror matching is geometric nearest-neighbour matching, not a guaranteed topological correspondence. Check the reported match count and visually inspect both sides.
- The marker overlay is a vertex point cloud, not a continuous heatmap. Use multiple viewing angles and small brushes for boundaries.
- It does not automatically infer anatomical labels. Production labels require human visual judgement and review, including checks against Reyna and Dagna.
- It authors masks only. It does not change body geometry, create missing female morph targets, or fit garments.
