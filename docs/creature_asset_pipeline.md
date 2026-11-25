# Creature asset pipeline

## Design

Creature source models are registered once and instantiated through
`CreatureVisualFactory`. Instance choices such as size, colour and animation
are data, not separate exported model files.

This first pass is presentation-only. The world simulation remains authoritative
for identity, AI, encounters, combat, movement and persistence. Do not make a
rendered creature node the owner of gameplay rules.

## Asset library layout

Store source models by broad creature family:

- `art/creatures/dragons/`
- `art/creatures/beasts/`
- `art/creatures/undead/`
- `art/creatures/demons/`
- `art/creatures/monsters/`

Keep the original source filename and do not overwrite the supplied source.
For each imported asset, record its source, licence/usage terms, native units,
forward/up orientation, root/pivot conventions, skeleton, animation clips,
materials/textures and any known import corrections.

Use Git LFS selectively for large source models and audio, consistent with the
repository workflow. Do not LFS-track every small texture or generated file.
Never commit an LFS pointer without its corresponding uploaded LFS object.

## First registered asset: Ashwing Drake Lite

The supplied file is stored unchanged at:

`res://art/creatures/dragons/Ashwing_Drake_Lite.glb`

The original model inspection found one skinned mesh, a 61-joint skin, and
embedded base-colour, normal and metallic/roughness textures. Its six clips are:

| Factory animation | Imported clip |
|---|---|
| idle | `idle_loop` |
| walk | `walk_loop` |
| fly | `fly_loop` |
| takeoff | `takeoff` |
| bite | `bite` |
| roar | `roar` |

The asset definition is in `scripts/creatures/creature_asset_catalog.gd`.
Its source licence is deliberately marked unverified; confirm the provider's
terms before redistributing the model in a public build.

## Runtime usage

```gdscript
var small_red := CreatureVisualFactory.create_species(
    "dragon",
    {"instance_name": "CaveDrake", "size": "small", "colour": "red", "animation": "idle"}
)

var large_gold := CreatureVisualFactory.create_species(
    "dragon",
    {"instance_name": "AncientGold", "size": "large", "colour": "gold", "animation": "fly"}
)
```

`create_species("dragon", options)` selects the registered default dragon asset,
so callers can request a creature by species without hardcoding its source
filename. Use `create_creature(asset_id, options)` when a specific model
variant is required.

Supported size names are tiny, small, medium, large, huge and ancient.
The initial multipliers are relative to the source model: 0.35, 0.65, 1.0,
1.55, 2.2 and 3.0. They are starting presentation values, not measured
in-world heights. A caller may supply an explicit positive `scale` override.

Colours are applied by duplicating StandardMaterial3D/ORMMaterial3D resources
and tinting their albedo colour. This preserves each material's existing
textures and normal/roughness maps. Custom ShaderMaterials are left unchanged
rather than destructively replacing asset-specific shader behaviour.

## Testing

1. Open `project.godot` in Godot 4.7.2.
2. Open `scenes/prototypes/creature_asset_showcase.tscn` and run it with F6.
3. Confirm the small red, medium natural and large gold variants load, retain
   texture detail, and play their idle clips.
4. Run `godot --headless --path . --script res://tests/test_creature_asset_catalog.gd`.

This first showcase validates visual instancing only. It does not yet register
dragons as combatants or place them in the campaign world.
