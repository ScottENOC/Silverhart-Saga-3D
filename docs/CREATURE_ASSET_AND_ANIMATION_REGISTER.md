# Creature, Monster and Animation Asset Register

**Purpose:** Single production checklist for the creature and enemy models that need to be sourced, built, rigged, animated, imported and connected to gameplay in Silverhart Saga 3D.

**Source roster:** `data/characters/legacy_enemy_roster.json`, derived from `ScottENOC/Hex-crpg/monsters.js` (35 entries).
**Runtime foundations:** `CreatureActor` discovers imported AnimationPlayer clips at runtime; `AnimalCatalog` supplies gameplay profiles for the currently supported animal models.
**Last audited:** 2026-11-26.

This is an asset-production register, not a claim that every listed enemy is already implemented. A legacy 2D sprite is reference material, not a 3D asset. A model file existing in the repository does not mean its rig, animation coverage or gameplay integration has been accepted.

## Status key

- **Model needed:** no suitable dedicated 3D model is currently present in the repository.
- **Existing reusable model:** a model is present and can be used as a starting point/current representation; it still needs visual and animation acceptance.
- **Shared humanoid pipeline:** should use the reusable humanoid/NPC character workflow where appropriate, with creature/race-specific proportions, equipment and animations. This is not a request to build every humanoid enemy as a separate mesh.
- **Animation audit pending:** imported animation clips have not yet been inventoried and checked in Godot. Do not assume an idle/walk/attack/death set exists just because a glTF file imports.
- **Accepted:** reserve this status for a model and its required animation set that have been inspected in-game and connected to the actor/gameplay pipeline.

## Priority production queue

| Priority | Asset / encounter | Model state | Animation state | Why it is next |
|---|---|---|---|---|
| P0 | Denning troll at Skarnak's Hold | Model needed | Not started | Required to make the current **Prove Your Strength** quest playable end-to-end |
| P1 | Goblin and elite goblin | Shared humanoid pipeline; no accepted 3D enemy build | Not started | Skarn-tooth Camp and goblin campaign content |
| P1 | Orcs and Grukk's stronghold fighters | Shared humanoid pipeline; no accepted 3D enemy build | Not started | Skarnak's Hold and faction encounters |
| P1 | Wolf-rider goblin | Wolf model exists; rider/combined presentation needed | Not started | Source enemy archetype; needs mounted combat presentation |
| P2 | Skeleton, zombie and revenant | Model needed | Not started | Undead encounters and ruins |
| P2 | Spider | Model needed | Not started | Spider ruin encounter |
| P2 | Dragon tiers | Model needed | Not started | Dragon lair and boss encounters |
| P2 | Remaining wild animals and monsters | Mixed; see inventory | Not started | Expand source encounter coverage after the immediate campaign enemies |

Priorities are implementation order, not a claim about narrative importance or final art quality.

## Legacy enemy roster — 35 source entries

The source has 35 enemy templates/variants. The three source entries with a currently available matching animal model are Wolf, Deer and Horse. The other entries have no accepted matching enemy model in the current asset tree. Humanoid variants should share the reusable humanoid pipeline where sensible.

| ID | Enemy | Model / production approach | Model status | Animation status |
|---|---|---|---|---|
| `goblin` | Goblin | Goblin humanoid body/rig, modular equipment | Model needed | Not started |
| `elite_goblin` | Elite Goblin | Reuse goblin base; elite gear/proportions | Model needed | Not started |
| `orc` | Orc | Orc humanoid body/rig, modular equipment | Model needed | Not started |
| `bandit` | Bandit | Reuse human NPC pipeline and enemy equipment | Shared humanoid pipeline | Not started |
| `siege_engine` | Siege Engine | Dedicated mechanical/construct model | Model needed | Not started; mechanical movement only if required |
| `wolf` | Wolf | `art/creatures/quaternius/Wolf.gltf` | Existing reusable model | Audit pending |
| `deer` | Deer | `art/creatures/quaternius/Deer.gltf` | Existing reusable model | Audit pending |
| `wild_boar` | Wild Boar | Dedicated boar model | Model needed | Not started |
| `horse` | Horse | `art/creatures/quaternius/Horse.gltf` | Existing reusable model | Audit pending |
| `troll` | Troll | Dedicated large humanoid/giant model | Model needed | Not started |
| `dragon_young` | Young Dragon | Shared dragon rig; young scale/proportions | Model needed | Not started |
| `dragon_adult` | Adult Dragon | Shared dragon rig; adult scale/proportions | Model needed | Not started |
| `dragon_ancient` | Ancient Dragon | Shared dragon rig; ancient scale/proportions | Model needed | Not started |
| `skeleton` | Skeleton | Dedicated skeletal humanoid rig | Model needed | Not started |
| `zombie` | Zombie | Undead humanoid rig | Model needed | Not started |
| `imp` | Imp | Small demon model/rig | Model needed | Not started |
| `spider` | Spider | Multi-legged creature rig | Model needed | Not started |
| `bear` | Bear | Dedicated bear model | Model needed | Not started |
| `ogre` | Ogre | Reuse giant-humanoid pipeline if practical | Model needed | Not started |
| `boar` | Boar | Reuse wild-boar model with gameplay variant | Model needed | Not started |
| `tiger` | Tiger | Dedicated tiger model | Model needed | Not started |
| `eagle` | Eagle | Flying bird model/rig | Model needed | Not started |
| `unicorn` | Unicorn | Equine base plus unicorn-specific appearance | Model needed | Not started |
| `wraith` | Wraith | Spectral humanoid model/effects | Model needed | Not started |
| `basilisk` | Basilisk | Dedicated reptilian creature model | Model needed | Not started |
| `harpy` | Harpy | Winged humanoid model/rig | Model needed | Not started |
| `minotaur` | Minotaur | Bull-headed giant humanoid | Model needed | Not started |
| `revenant` | Revenant | Reuse skeletal/undead humanoid rig with elite variant | Model needed | Not started |
| `wolf_rider_goblin` | Wolf Rider Goblin | Goblin rider + existing wolf; mounted actor/animation integration | Partial assets | Not started |
| `horse_archer` | Horse Archer | Human NPC + existing horse; mounted equipment/animation integration | Partial assets | Not started |
| `grishnak` | Grishnak | Audit source identity; likely shared humanoid/creature variant | Model needed | Not started |
| `sir_alistair` | Sir Alistair | Audit source identity; use humanoid pipeline if human | Model needed | Not started |
| `viper` | Viper | Audit source identity before selecting humanoid/creature base | Model needed | Not started |
| `krog_the_unstoppable` | Krog the Unstoppable | Audit source identity; likely boss variant of a shared archetype | Model needed | Not started |
| `sylvara_the_huntress` | Sylvara the Huntress | Audit source identity; use humanoid pipeline if human | Model needed | Not started |

**Important:** the 3D roster's old `model_status` field currently labels all 35 entries `3d_model_required`. This register refines that status for the Wolf, Deer and Horse assets now present in the repository, and distinguishes shared/partial humanoid and mounted assets. Update the source roster only when the registry/actor integration is actually changed; do not let two conflicting status lists persist.

## Existing non-monster animal assets

These are present under `art/creatures` and are useful for farm, settlement and ambient wildlife scenes. They are not substitutes for the missing fantasy enemy models.

| Asset | File | Runtime/gameplay support | Animation status |
|---|---|---|---|
| Sheep | `art/creatures/generated/Sheep.tscn` | Generated scene | Audit pending |
| Alpaca | `art/creatures/quaternius/Alpaca.gltf` | CreatureActor/AnimalCatalog kind | Audit pending |
| Bull | `art/creatures/quaternius/Bull.gltf` | CreatureActor/AnimalCatalog kind | Audit pending |
| Cow | `art/creatures/quaternius/Cow.gltf` | CreatureActor/AnimalCatalog kind | Audit pending |
| Deer | `art/creatures/quaternius/Deer.gltf` | CreatureActor/AnimalCatalog kind | Audit pending |
| Donkey | `art/creatures/quaternius/Donkey.gltf` | CreatureActor/AnimalCatalog kind | Audit pending |
| Fox | `art/creatures/quaternius/Fox.gltf` | CreatureActor/AnimalCatalog kind | Audit pending |
| Horse | `art/creatures/quaternius/Horse.gltf` | CreatureActor/AnimalCatalog kind | Audit pending |
| White horse | `art/creatures/quaternius/Horse_White.gltf` | Reusable visual variant; gameplay alias to verify | Audit pending |
| Husky | `art/creatures/quaternius/Husky.gltf` | CreatureActor/AnimalCatalog kind | Audit pending |
| Shiba Inu | `art/creatures/quaternius/ShibaInu.gltf` | CreatureActor/AnimalCatalog kind | Audit pending |
| Stag | `art/creatures/quaternius/Stag.gltf` | CreatureActor/AnimalCatalog kind | Audit pending |
| Wolf | `art/creatures/quaternius/Wolf.gltf` | CreatureActor/AnimalCatalog kind | Audit pending |

The existing runtime code is a good base: `CreatureActor` loads a model's own AnimationPlayer and selects clips by hints. The next asset task is to inspect each imported model's actual clip names and test whether the clips loop and play correctly; then improve per-species mapping rather than assuming all packs use the same names.

## Animation acceptance checklist

For each creature model, record actual clip names and tick these off only after an in-game check.

### Common ground creature
- [ ] Idle / breathing / characteristic rest loop
- [ ] Walk
- [ ] Run / charge (where the creature can run)
- [ ] Turn / directional locomotion looks acceptable
- [ ] Attack (species-appropriate)
- [ ] Hit reaction
- [ ] Death / collapse
- [ ] Return to idle without snapping or sliding

### Humanoid enemy
- [ ] Idle
- [ ] Walk
- [ ] Run
- [ ] Unarmed / weapon attack variants as needed
- [ ] Block / parry where used by combat rules
- [ ] Hit reaction
- [ ] Knockdown / unconscious
- [ ] Death
- [ ] Weapon and armour attachment alignment

### Flying creature
- [ ] Ground idle
- [ ] Take-off
- [ ] Flight loop
- [ ] Turning / banking
- [ ] Landing
- [ ] Attack / special ability
- [ ] Hit reaction and death/fall

### Special cases
- [ ] Troll/giant: large locomotion, reach and attack timing fit the tactical footprint
- [ ] Spider: leg cycle, turn, bite/poison attack and death
- [ ] Dragon: ground/flight states, breath attack timing, turn, landing and death
- [ ] Siege engine: deployment/rotation/attack/destruction, if animated in the chosen presentation
- [ ] Mounted units: rider and mount remain aligned during idle, move, attack, hit and death

## Per-asset record template

Copy this block for each newly built or accepted asset:

```text
Asset ID:
Source / licence:
Model file:
Model authoring status: not started | blockout | modelled | textured | imported | accepted
Rig status: not started | rigged | validated
Animation clip names:
Idle: 
Move:
Run:
Attack:
Hit:
Death:
Special:
Godot import check:
In-game visual check:
CreatureActor / actor-factory integration:
Gameplay state / AnimalCatalog or enemy registry:
Outstanding issues:
```

## Working rules

1. Keep the source IDs from `legacy_enemy_roster.json`; display names may change, persistent IDs should not.
2. Reuse humanoid bases for goblins, orcs, bandits and named humanoid enemies where that preserves the intended look. Do not create needless one-off rigs.
3. Reuse animal models only when the species actually matches. A wolf is not a boar; a horse is not a unicorn without the required visual changes.
4. Model, rig, animation, import and gameplay integration are separate statuses.
5. Preserve the original asset pack's skeletons and animation libraries when using Quaternius glTFs. Do not retarget quadrupeds to the Ara humanoid skeleton.
6. A creature is complete only after the model and required animation clips are tested in the running game and the relevant actor/encounter can use them.
7. Update this register whenever a creature is added, a model is accepted, animation clips are mapped, or an encounter requires a new creature.
