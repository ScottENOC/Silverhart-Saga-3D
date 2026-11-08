# Equipment materials and shield heraldry

## Material-aware equipment finishes

`scripts/characters/equipment_appearance.gd` provides per-instance PBR profiles for equipment surfaces. It duplicates each material before changing it, so changing one equipped item does not mutate the shared imported GLB material.

Call `EquipmentAppearance.apply_to(item_root, surface_options)` after instantiating an equipment prop. Options are keyed by the imported material name (lowercase, spaces and hyphens converted to underscores), or by explicit `equipment_surface_<surface-index>` metadata.

Example:

```gdscript
EquipmentAppearance.apply_to(sword_instance, {
    "steel": {"profile": "gold"},
    "leather": {"profile": "leather", "colour": "#38251b"}
})
```

Profiles currently include steel, dark steel, gold, brass, wood, painted wood, leather and cloth. Material categories constrain the finish: wood can be natural or painted but cannot become metallic; leather and cloth remain non-metallic; metal can be steel, dark steel, gold or brass. Gold is a metallic PBR material, not merely yellow paint.

For reliable categorisation, exported props should use descriptive material names such as `Steel`, `Brass`, `Oak`, `Leather`, `Blade`, `Grip` and `HeraldryFace`. Unknown surface names fall back to a neutral steel profile and should be given explicit metadata before production use.

## Shield heraldry

The Blender shield builder creates a separate UV-mapped `HeraldryFace` surface on the front of round, kite and heater shields. The wooden reverse and edge construction remain separate from the front decoration; the boss and boss ring retain their own metal materials.

Apply a design with:

```gdscript
EquipmentAppearance.apply_shield_heraldry(shield_instance, {
    "field_colour": "#8b2028",
    "secondary_colour": "#e8dfc8",
    "emblem_colour": "#20232a",
    "pattern": "halves_vertical",
    "emblem": "tree"
})
```

Current field patterns: `plain`, `halves_vertical`, `halves_horizontal`, `diagonal`, `stripe`, `cross`.

Current procedural emblems: `none`, `roundel`, `cross`, `lozenge`, `star`, `tree`. This is the first heraldry pass; bespoke heraldic charges (lion, eagle, raven, wolf, stag, dragon, etc.), texture decals and raised 3D badges are a follow-on asset task. The optional border is currently off by default because its simple UV-space edge does not yet follow every shield silhouette.

Rebuild the shield/helmet GLBs with the **Build Ara Medieval Armour Props** workflow after changing the Blender generator. The generated shield front surface is required for heraldry to appear; existing previously generated GLBs do not gain it automatically.

## Current scope and limitations

- This is a reusable appearance layer, not yet a player-facing equipment customisation screen.
- Standalone props are not yet attached to character hand/back/helmet sockets by the campaign equipment system.
- The shield heraldry shader is procedural and uses the shield front UVs; no separate model is needed for each colour/pattern combination.
- The first-pass Ara shields remain blockout geometry and still need visual review in Godot against the character rigs.
