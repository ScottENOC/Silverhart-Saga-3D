# Skill and Spell Implementation Audit

**Baseline branch:** `dev`  
**Baseline commit:** `76f25f01332f60ec3a58738bf58553afa12437ae`  
**Audit branch:** `audit/skill-effect-parity-update`  
**Scope:** source inspection of the 257-skill catalogue, original 2D skill definitions and gameplay references, current 3D simulation/movement/combat runtime, effect tests, and relevant feature branches. This remains an evidence-based audit; absence of a hook in the inspected runtime is not proof that no implementation exists elsewhere.

## Summary

- Catalogue contains **257 skills** and **15 base spells**.
- Skill catalogue loading, purchase eligibility, prerequisites, point accounting, NPC skill allocation and save/load have automated coverage in `tests/test_simulation.gd`. These tests verify progression plumbing, not the gameplay effect of every purchased skill.
- **22 skill IDs now have direct automated effect-test coverage** on `dev` after PR #102: movement discounts, foliage movement, several racial combat passives, spectral damage reduction, parry variants/modifiers, Shield Other/Proficiency, Protector, spear reactions and Sidestep/Mastery. Foliage is only partially covered against the original 2D behaviour; see the follow-up comparison below.
- PR #102 added deterministic tests for those additional effects. PR #105 has now corrected those fixtures to keep Fast Movement and Goblin Opportunist within their catalogue max-rank limits.
- The spell file is currently a **15-entry data catalogue**. The reviewed simulation scripts contain character spell-slot/unlock storage, but this audit did not identify a spell-casting/effect resolver or spell-effect tests. All spells therefore remain unverified.
- All remaining skills are deliberately marked **UNVERIFIED**, not “broken” or “not implemented”: absence of a hook in the reviewed core files is not proof that no implementation exists elsewhere.

## Status definitions

| Status | Meaning |
|---|---|
| VERIFIED — automated effect test | Test exercises the actual gameplay effect, not merely selection or rank storage. |
| IMPLEMENTATION FOUND — effect test still required | A runtime code path reads/applies the skill, but a focused effect test is missing. |
| FEATURE BRANCH CANDIDATE — not on dev | A relevant implementation exists on a named feature branch, but is not present on `dev`; do not count it as working in the current game. |
| UNVERIFIED | No effect test or confirmed runtime hook established in this pass. Do not assume it works. |
| NPC/CREATURE | Intended primarily for NPC/monster use; still requires behaviour validation. |


## Feature-branch cross-reference (reviewed 2026-11-11)

This section records relevant work found outside `dev`. Branch presence is evidence
of an implementation candidate only. It does **not** change the current-game status
until the work is integrated into `dev` and its effect is covered by a deterministic
test. Branches below are compared with the current `dev` head
(`899931e6c37f70193c197870821bb1e0933f7589`).

| Branch | Relationship to dev | Skill/effect relevance | Audit treatment |
|---|---:|---|---|
| [`feature/vision-stealth-perception`](https://github.com/ScottENOC/Silverhart-Saga-3D/tree/feature/vision-stealth-perception) | 25 ahead / 34 behind | Adds `VisionRules`, `FogOfWar`, and a fog test. Candidate skills: `elf_vision`, `goblin_keen_senses`, `deep_sense`, `elf_darkvision`, `goblin_low_light_eyes`, `keen_perception`, plus two stealth skills with ID mismatches. | Not on dev; candidate only. The branch is substantially behind and must be reconciled, not merged wholesale. |
| [`feature/skill-magic-foundation`](https://github.com/ScottENOC/Silverhart-Saga-3D/tree/feature/skill-magic-foundation) | 70 ahead / 36 behind | Historical source for the skill/spell catalogues, progression and NPC spending foundations. Its own port plan still lists spell builder/casting and remaining effect families as future work. | The catalogues and progression foundations are now on dev. This branch is not evidence that spell effects work. |
| [`feature/movement-reactions`](https://github.com/ScottENOC/Silverhart-Saga-3D/tree/feature/movement-reactions) | 8 ahead / 121 behind | Contains movement/reaction work around Protector, Shield Other, Shield Proficiency, Sidestep, Sidestep Mastery, Spear Halt and Spear Intercept. | The relevant IDs and effect tests are already present on dev; this stale branch is not additional current coverage. |
| [`feature/combat-reaction-triggers`](https://github.com/ScottENOC/Silverhart-Saga-3D/tree/feature/combat-reaction-triggers) | 8 ahead / 126 behind | Earlier combat-reaction trigger work; no additional canonical skill ID references were found in its reviewed simulation file. | Not counted as a separate skill implementation. |
| [`feature/equipment-gameplay-stat-integration`](https://github.com/ScottENOC/Silverhart-Saga-3D/tree/feature/equipment-gameplay-stat-integration) | 5 ahead / 35 behind | Covers combat-stat integration for foliage expertise, Dwarven Axe Mastery, Goblin Opportunist, Orc Brute Strength/Ferocity and Spectral Form. | These skill reads are already present in dev's CombatRules. Several still need focused tests; branch presence does not upgrade their status. |

### Vision branch: what it actually contains

The branch adds:

- `scripts/simulation/vision_rules.gd`: base vision range 25 hexes, separate
  exploration range 30, range modifiers, low-light handling, axial-hex line of
  sight, wall/blocker and elevation occlusion, plus separate numeric helpers for
  perception and stealth.
- `scripts/presentation/fog_of_war.gd`: persistent explored/visible hex state,
  fog mesh rendering, and actor/resource visibility updates.
- `tests/test_fog_of_war.gd`: checks initial visibility/exploration, fog mesh
  coverage/culling bounds, and visibility/exploration changes after moving.

Important limits found on inspection:

1. The fog test does **not** directly test VisionRules range modifiers, line of
   sight, elevation blockers, low-light behaviour or perception/stealth bonuses.
   It exercises the fog presentation and movement state only. There is no
   dedicated `test_vision_rules.gd` on that branch.
2. The branch's `VisionRules.stealth_check_bonus()` reads
   `inconspicuous` and `shadow_weaver`, but the canonical catalogue IDs on dev
   are `stealth_agility` (display name Inconspicuous) and `stealth_rogue`
   (display name Shadow Weaver). Those two bonuses therefore will not read the
   canonical purchased ranks until the IDs are corrected.
3. `stealth_detection_bonus()` and `stealth_check_bonus()` are helper
   calculations, not a complete stealth system. The branch's own port notes
   defer suspicion, hearing, stealth movement, enemy search/pursuit, party-shared
   sightings, disguise and AI target selection.
4. The vision branch has no dedicated PR associated with its current branch name
   in the repository search. Treat it as independent work requiring review and
   reconciliation with current dev, not as a ready-to-merge feature.

### Current-dev source scan notes

A broader scan of the current `scripts/` and `tests/` tree found 74 relevant
GDScript/JSON files and 257 canonical skill IDs. The scan separates references
in gameplay rules from references used only by catalogue/progression/NPC build
logic. In particular, the fact that `npc_skill_spending.gd` knows a skill ID
does not mean that skill's gameplay effect is implemented.

The current `dev` tree has no `VisionRules`, `FogOfWar` or dedicated vision
test file. Thus all vision/stealth skills remain unavailable as working gameplay
effects on dev, despite the candidate work above.


## Skill inventory

### agility (10)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `acrobatics` | Acrobatics | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `fastMovement` | Fast Movement | VERIFIED — automated movement-cost effect test |
| `keen_perception` | Keen Perception | FEATURE BRANCH CANDIDATE — detection helper exists off `dev`; no integration/effect test |
| `riding` | Riding | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `sidestep` | Sidestep | VERIFIED — automated effect test |
| `sidestep_mastery` | Sidestep Mastery | VERIFIED — automated effect test |
| `slip_away` | Slip Away | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `stealth_agility` | Inconspicuous | FEATURE BRANCH CANDIDATE — branch helper uses the wrong skill ID (`inconspicuous`) |
| `sure_footed` | Sure-Footed | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `timePointRate` | Time Point Rate | UNVERIFIED — no effect test or confirmed runtime hook yet |

### elf (9)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `ageless_patience` | Ageless Patience | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `elf_bow_range` | Elf Bow Mastery | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `elf_darkvision` | Elf Darkvision | FEATURE BRANCH CANDIDATE — vision logic exists off `dev`; no direct effect test |
| `elf_foliage_expertise` | Woodland Stride | PARTIAL — movement effect tested; original stealth/defence effects not fully integrated |
| `elf_knowledge_nature` | Knowledge: Nature | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `elf_vision` | Keen Elf Sight | FEATURE BRANCH CANDIDATE — vision logic exists off `dev`; no direct effect test |
| `elven_grace` | Elven Grace | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `keen_hearing` | Keen Hearing | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `whisper_step` | Whisper Step | UNVERIFIED — no effect test or confirmed runtime hook yet |

### monk (7)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `agile_climber` | Agile Climber | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `disarm` | Disarm | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `focused_strike` | Focused Strike | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `iron_shirt` | Iron Shirt | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `joint_lock` | Joint Lock | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `swift_step` | Swift Step | VERIFIED — automated movement-cost effect test |
| `trip_reaction` | Counter Trip | UNVERIFIED — no effect test or confirmed runtime hook yet |

### nature (33)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `animal_companion` | Animal Companion | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `companion_agi_end` | Companion Grace | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `companion_str_end` | Companion Brawn | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `keen_forager` | Keen Forager | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_barkskin_spell` | Learn Barkskin (Spell) | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_boar_summon` | Boar Summoning | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_call_of_the_wild` | Learn Call of the Wild | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_calm_animal` | Learn Calm Animal | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_camouflage` | Learn Camouflage | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_eagle_summon` | Eagle Summoning | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_entangle` | Learn Entangle | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_natures_vigor` | Learn Nature | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_root` | Learn Root | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_spore_cloud` | Learn Spore Cloud | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_summon_animal` | Learn Summon Animal | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_tiger_summon` | Tiger Summoning | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_wild_fury` | Learn Wild Fury | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nature_armor_ease` | Wild Ease | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nature_bounty` | Forager | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nature_burst` | Nature Burst | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nature_butchery` | Butchery | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nature_cap` | Nature Cap | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nature_expand` | Nature Expansion | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nature_magnitude` | Nature Potency | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nature_mana` | Nature Mana | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nature_quickened` | Quickened Nature | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nature_range` | Nature Range | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nature_ranger` | Ranger | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nature_regen` | Nature Regeneration | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nature_slowed` | Slowed Nature | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nature_spell_slots` | Nature Spell Mastery | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nature_targets` | Nature\ | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nature_touch` | Nature Touch | UNVERIFIED — no effect test or confirmed runtime hook yet |

### misc (9)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `appraisal` | Appraisal | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `appraiser` | Appraiser | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `cooking` | Cooking | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `insight` | Insight | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `intimidation` | Intimidation | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `lockpicking` | Lockpicking | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `persuasion` | Persuasion | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `smithing` | Smithing | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `survival` | Survival | UNVERIFIED — no effect test or confirmed runtime hook yet |

### arcane (26)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `arcane_burst` | Arcane Burst | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `arcane_cap` | Arcane Cap | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `arcane_expand` | Arcane Expansion | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `arcane_magnitude` | Arcane Potency | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `arcane_mana` | Arcane Mana | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `arcane_quickened` | Quickened Arcane | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `arcane_range` | Arcane Range | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `arcane_regen` | Arcane Regeneration | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `arcane_slowed` | Slowed Arcane | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `arcane_spell_slots` | Arcane Spell Mastery | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `arcane_targets` | Arcane Fork | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `arcane_touch` | Arcane Touch | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `blood_magic` | Warlock | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `disguise_equipment` | Disguised Equipment | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_blink` | Learn Blink | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_chain_lightning` | Learn Chain Lightning | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_counterspell` | Learn Counterspell | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_disguise_self` | Learn Disguise Self | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_energy_shield` | Learn Energy Shield | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_feather_fall` | Learn Feather Fall | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_firebolt` | Learn Firebolt | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_force_push` | Learn Force Push | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_gravity_well` | Learn Gravity Well | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_haste` | Learn Haste | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_slow` | Learn Slow | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_temporal_rift` | Learn Temporal Rift | UNVERIFIED — no effect test or confirmed runtime hook yet |

### wizard (4)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `arcane_eff_magnitude` | Wizard Potency Efficiency | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `arcane_eff_range` | Wizard Range Efficiency | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `arcane_eff_speed` | Wizard Speed Efficiency | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `firebolt_hit` | Firebolt Proficiency | UNVERIFIED — no effect test or confirmed runtime hook yet |

### cleric (9)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `armistice` | Armistice | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `cleric_trigger_damage` | Divine Retribution | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `cleric_trigger_dmg_red` | Feeble Strike | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `cleric_trigger_heal_red` | Severed Grace | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `cleric_trigger_mana` | Divine Drain | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `cleric_trigger_vision` | Clouded Mind | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `divine_judgment` | Divine Judgment | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `extended_sentence` | Extended Sentence | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `holy_ground` | Holy Ground | UNVERIFIED — no effect test or confirmed runtime hook yet |

### rogue (12)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `assassinate` | Assassinate | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `dagger_quick_draw` | Dagger Quick Draw | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `dirty_fighting` | Dirty Fighting | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `initiativeBonus` | Initiative Bonus | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `pickpocket` | Pickpocket | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `quickRecovery` | Quick Recovery | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `sneak_attack_dmg` | Sneak Attack | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `speedy_stealth` | Speedy Stealth | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `stealth_rogue` | Shadow Weaver | FEATURE BRANCH CANDIDATE — branch helper uses the wrong skill ID (`shadow_weaver`) |
| `subtle_spell` | Subtle Spell | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `trap_setting` | Trap Setting | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `vanish` | Vanish | UNVERIFIED — no effect test or confirmed runtime hook yet |

### weapons (37)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `axe_cleave` | Armor Cleave | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `axe_dmg` | Axe Mastery | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `axe_hit` | Axe Proficiency | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `axe_rend` | Rend | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `bladestorm` | Bladestorm | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `bow_dmg` | Bow Mastery | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `bow_hit` | Bow Proficiency | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `club_dmg` | Club Mastery | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `club_hit` | Club Proficiency | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `dagger_dmg` | Dagger Mastery | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `dagger_feint` | Dagger Feint | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `dagger_hit` | Dagger Proficiency | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `dagger_parry` | Dagger Parry | VERIFIED — automated effect test |
| `dagger_parry_chance` | Dagger Parry Mastery | VERIFIED — automated chance-modifier test |
| `dagger_parry_cost` | Dagger Parry Efficiency | VERIFIED — automated TP-cost test |
| `dagger_throw` | Throw Dagger | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `hack_and_slash` | Hack and Slash | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `hamstring` | Hamstring | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `headsmans_blow` | Headsman's Blow | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `in_the_way` | In the Way | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `shield_bash` | Shield Bash | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `shield_other` | Shield Other | VERIFIED — automated effect test |
| `shield_proficiency` | Shield Proficiency | PARTIAL — Shield Other bonus tested; passive shield damage reduction is not applied in `CombatRules.damage_reduction()` |
| `spear_dmg` | Spear Mastery | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `spear_halt` | Spear Halt | VERIFIED — automated effect test |
| `spear_hit` | Spear Proficiency | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `spear_intercept` | Spear Intercept | VERIFIED — automated effect test |
| `sunder_armor` | Sunder Armor | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `sword_dmg` | Sword Mastery | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `sword_feint` | Sword Feint | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `sword_footwork` | Duelist's Footwork | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `sword_hit` | Sword Proficiency | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `sword_parry` | Sword Parry | VERIFIED — automated effect test |
| `sword_parry_chance` | Sword Parry Mastery | VERIFIED — automated chance-modifier test |
| `sword_parry_cost` | Sword Parry Efficiency | VERIFIED — automated TP-cost test |
| `sword_riposte` | Riposte | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `threatening_presence` | Threatening Presence | UNVERIFIED — no effect test or confirmed runtime hook yet |

### druid (9)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `barkskin_active` | Barkskin | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `druid_foliage_expertise` | Foliage Mastery | PARTIAL — movement effect tested; original stealth/defence effects not fully integrated |
| `druid_knowledge_nature` | Knowledge: Nature | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_unicorn_summon` | Unicorn Bond | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `natural_senses` | Natural Senses | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `natures_bond` | Nature | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `riding_druid` | Nature Riding | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `venomous_summon` | Venomous Summon | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `wild_shape_adaptation` | Wild Shape Adaptation | UNVERIFIED — no effect test or confirmed runtime hook yet |

### dwarf (6)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `battle_endurance` | Battle Endurance | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `deep_sense` | Deep Sense | FEATURE BRANCH CANDIDATE — vision logic exists off `dev`; no direct effect test |
| `dwarf_axe_mastery` | Dwarven Axe Mastery | PARTIAL — raw-damage helper tested, but normal attack submission does not derive `weapon_id` from equipped weapon |
| `dwarf_solid` | Solid as a Rock | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `grudge` | Grudge | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `stonewall` | Stonewall | UNVERIFIED — no effect test or confirmed runtime hook yet |

### fighter (8)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `battle_reflexes` | Battle Reflexes | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `brace` | Brace | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `press_the_advantage` | Press the Advantage | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `protector` | Protector | VERIFIED — automated effect test |
| `rally` | Rally | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `suppression` | Suppression | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `weapon_swap` | Weapon Swap | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `zone_of_control` | Zone of Control | UNVERIFIED — no effect test or confirmed runtime hook yet |

### strength (9)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `bull_rush` | Bull Rush | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `heavy_armor_training` | Heavy Armor Training | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `iron_grip` | Iron Grip | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `light_armor_training` | Light Armor Training | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `medium_armor_training` | Medium Armor Training | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `meleeDamage` | Weapon Damage | IMPLEMENTATION FOUND — CombatRules reads the rank as flat attack damage; focused effect test still required |
| `powerful_shove` | Powerful Shove | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `shove` | Shove | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `strong_back` | Strong Back | UNVERIFIED — no effect test or confirmed runtime hook yet |

### Way of the open palm (8)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `deflect_arrows` | Deflect Arrows | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `nerve_strike` | Nerve Strike | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `palm_strike` | Palm Strike | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `redirect` | Redirect | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `siphoning_palm` | Siphoning Palm | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `unarmed_dmg` | Unarmed Mastery | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `unarmed_hit` | Unarmed Proficiency | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `unarmed_reaction_block` | Pressure Point Strike | UNVERIFIED — no effect test or confirmed runtime hook yet |

### divine (25)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `divine_armor_ease` | Vestment Ease | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `divine_burst` | Divine Burst | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `divine_cap` | Divine Cap | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `divine_expand` | Divine Expansion | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `divine_magnitude` | Divine Potency | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `divine_mana` | Divine Mana | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `divine_quickened` | Quickened Divine | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `divine_range` | Divine Range | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `divine_regen` | Divine Regeneration | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `divine_slowed` | Slowed Divine | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `divine_spell_slots` | Divine Spell Mastery | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `divine_targets` | Divine Presence | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `divine_touch` | Divine Touch | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `knowledge_religion` | Knowledge: Religion | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_command` | Learn Command | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_condemn` | Learn Condemn | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_curse` | Learn Curse | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_divine_protection` | Learn Divine Protection | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_divine_silence` | Learn Divine Silence | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_divine_wrath` | Learn Divine Wrath | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_excommunicate` | Learn Excommunicate | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_heal` | Learn Heal | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_mark_of_guilt` | Learn Mark of Guilt | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_sanctuary` | Learn Sanctuary | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `learn_smite_evil` | Learn Smite Evil | UNVERIFIED — no effect test or confirmed runtime hook yet |

### monster_skills (11)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `fly` | Fly | NPC/CREATURE — runtime behaviour not yet audited |
| `furious_charge` | Furious Charge | NPC/CREATURE — runtime behaviour not yet audited |
| `gore_charge` | Gore Charge | NPC/CREATURE — runtime behaviour not yet audited |
| `land` | Land | NPC/CREATURE — runtime behaviour not yet audited |
| `life_drain` | Life Drain | NPC/CREATURE — runtime behaviour not yet audited |
| `petrify_gaze` | Petrifying Gaze | NPC/CREATURE — runtime behaviour not yet audited |
| `poison_bite` | Poison Bite | NPC/CREATURE — runtime behaviour not yet audited |
| `regeneration` | Regeneration | NPC/CREATURE — runtime behaviour not yet audited |
| `revenant_revive` | Revenant Undying | NPC/CREATURE — runtime behaviour not yet audited |
| `siren_song` | Siren Song | NPC/CREATURE — runtime behaviour not yet audited |
| `spectral_form` | Spectral Form | VERIFIED — automated damage-reduction test |

### goblin (5)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `goblin_keen_senses` | Keen Senses | FEATURE BRANCH CANDIDATE — vision logic exists off `dev`; no direct effect test |
| `goblin_low_light_eyes` | Low-Light Eyes | FEATURE BRANCH CANDIDATE — vision logic exists off `dev`; no direct effect test |
| `goblin_opportunist` | Opportunist | PARTIAL — raw-damage option tested; normal attack submission does not derive `target_caught_off_guard` from target state |
| `goblin_pack_hunter` | Pack Hunter | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `goblin_quick_reflexes` | Quick Reflexes | UNVERIFIED — no effect test or confirmed runtime hook yet |

### endurance (7)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `grit` | Grit | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `hardened` | Hardened | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `health` | Health | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `health_regen` | Constitution | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `quartermaster` | Quartermaster | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `second_wind` | Second Wind | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `unwavering` | Unwavering | UNVERIFIED — no effect test or confirmed runtime hook yet |

### leatherworker (1)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `leatherworking` | Leatherworking | UNVERIFIED — no effect test or confirmed runtime hook yet |

### lich (5)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `lich_command_the_dead` | Command the Dead | NPC/CREATURE — runtime behaviour not yet audited |
| `lich_deathless_flesh` | Deathless Flesh | NPC/CREATURE — runtime behaviour not yet audited |
| `lich_grave_chill` | Grave Chill | NPC/CREATURE — runtime behaviour not yet audited |
| `lich_soul_anchor` | Soul Anchor | NPC/CREATURE — runtime behaviour not yet audited |
| `lich_withering_touch` | Withering Touch | NPC/CREATURE — runtime behaviour not yet audited |

### orc (5)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `orc_brute_strength` | Brute Strength | VERIFIED — automated effect test |
| `orc_ferocity` | Ferocity | VERIFIED — automated half-health damage-threshold test |
| `orc_momentum` | Momentum | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `orc_relentless` | Relentless | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `orc_thick_hide` | Thick Hide | UNVERIFIED — no effect test or confirmed runtime hook yet |

### paladin (1)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `riding_paladin` | Divine Riding | UNVERIFIED — no effect test or confirmed runtime hook yet |

### runesmith (1)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `runesmithing` | Runesmithing | UNVERIFIED — no effect test or confirmed runtime hook yet |

## Spell inventory

| Spell ID | Spell | School | Current evidence status |
|---|---|---|---|
| `firebolt` | Firebolt | arcane | UNVERIFIED — catalogue data only; no confirmed cast/effect test |
| `heal` | Heal | divine | UNVERIFIED — catalogue data only; no confirmed cast/effect test |
| `smite_evil` | Smite Evil | divine | UNVERIFIED — catalogue data only; no confirmed cast/effect test |
| `divine_silence` | Divine Silence | divine | UNVERIFIED — catalogue data only; no confirmed cast/effect test |
| `sanctuary` | Sanctuary | divine | UNVERIFIED — catalogue data only; no confirmed cast/effect test |
| `divine_protection` | Divine Protection | divine | UNVERIFIED — catalogue data only; no confirmed cast/effect test |
| `summon_animal` | Summon Animal | nature | UNVERIFIED — catalogue data only; no confirmed cast/effect test |
| `counterspell` | Counterspell | arcane | UNVERIFIED — catalogue data only; no confirmed cast/effect test |
| `dragon_breath` | Dragon Breath | arcane | UNVERIFIED — catalogue data only; no confirmed cast/effect test |
| `entangle` | Entangle | nature | UNVERIFIED — catalogue data only; no confirmed cast/effect test |
| `wild_fury` | Wild Fury | nature | UNVERIFIED — catalogue data only; no confirmed cast/effect test |
| `calm_animal` | Calm Animal | nature | UNVERIFIED — catalogue data only; no confirmed cast/effect test |
| `disguise_self` | Disguise Self | arcane | UNVERIFIED — catalogue data only; no confirmed cast/effect test |
| `temporal_rift` | Temporal Rift | arcane | UNVERIFIED — catalogue data only; no confirmed cast/effect test |
| `feather_fall` | Feather Fall | arcane | UNVERIFIED — catalogue data only; no confirmed cast/effect test |

## Known implementation details and gaps

1. `SkillCatalog` loads and validates the 257-entry JSON catalogue. It does not apply effects.
2. `SkillProgression` handles purchases, prerequisites, ranks, pool spending and grants. It does not apply effects.
3. `WorldSimulation` has tested reaction paths for sword parry, Protector, Shield Other, Spear Halt, Spear Intercept and Sidestep.
4. `CombatRules` applies Orc Brute Strength in damage calculation; the simulation test asserts the resulting damage.
5. `MovementRules` reads `fastMovement`/ `fast_movement`, `swift_step`, and foliage expertise. Existing movement test exercises the legacy camelCase `fastMovement` key; add an explicit canonical-ID test.
6. The movement code reads a `climbing` rank, but the catalogue has Agile Climber and Sure-Footed rather than a matching `climbing` skill ID. Treat that as a likely wiring mismatch until resolved.
7. Character state stores `unlocked_base_spells` and `max_spell_slots`, but storage/unlock is not evidence that a spell can be cast or resolve its intended effect.

## Next audit steps

- Add focused deterministic tests for every skill with a runtime hook, including rank scaling, prerequisites, equipment/terrain restrictions and negative cases.
- Search all remaining gameplay/UI scripts for skill-ID reads and compare them against canonical catalogue IDs; flag aliases and dead keys.
- Trace spell unlock → preparation/slot selection → cast request → mana/TP payment → target validation → effect resolution → duration/expiry/save-load. Until that chain exists and is tested, spells remain unverified.
- Run the Godot 4.7.2 headless suite and record the exact commit and Actions run against this audit.


## Current-dev effect parity follow-up (2026-11-11)

This section supersedes the earlier seven-effect test count. The current `dev`
baseline is `d08bb529c32b44c1b3a00f1bae18b94c73a8b80f`, after PR #102 was
merged. The current test suite exercises **22 canonical skill IDs** through
actual movement, combat or reaction outcomes:

- Movement: `fastMovement`, `swift_step`, `sidestep`, `sidestep_mastery`.
- Foliage: `elf_foliage_expertise`, `druid_foliage_expertise` (movement only;
  not full source parity).
- Combat passives: `meleeDamage` is implemented but not yet effect-tested;
  tested: `dwarf_axe_mastery`, `orc_brute_strength`, `orc_ferocity`,
  `goblin_opportunist`, `spectral_form`.
- Defensive reactions: `sword_parry`, `dagger_parry`,
  `sword_parry_cost`, `dagger_parry_cost`, `sword_parry_chance`,
  `dagger_parry_chance`, `protector`, `shield_other`,
  `shield_proficiency`.
- Movement reactions: `spear_halt`, `spear_intercept`.

The foliage, Dwarven Axe Mastery, Shield Proficiency and Goblin Opportunist tests are **partial**, not complete. 2D Woodland Stride /
Foliage Mastery remove the foliage movement penalty, add +20 to stealth score
in foliage, and impose an additional 10-point hit-chance penalty on attacks
against a character in foliage with either skill. 3D currently tests the
movement multiplier only. `CombatRules.hit_chance()` can apply a foliage
defence penalty only when caller-supplied options explicitly set
`elf_foliage_expertise` or `druid_foliage_expertise`; it does not derive
those flags from the target's purchased skill ranks. No 3D stealth score or
stealth integration for these skills was found in the inspected runtime.

### Important original-2D / current-3D mismatches

1. **Climbing skill IDs and effects do not match.** The 2D catalogue has
   `agile_climber`, `sure_footed` and `iron_grip`. The original 2D movement
   rules stack these three skills: each reduces the TP surcharge for
   `climbRisk` terrain by 20% (minimum 40% remaining with all three), and
   each reduces combat fall chance by 10 percentage points. 3D
   `TerrainElevationRules` instead reads `skills["climbing"]` or
   `skills["climb"]` as a single rank threshold to permit steeper terrain;
   neither is a canonical catalogue ID. The existing 3D elevation test
   manually assigns `climbing` ranks 1 and 3, so it tests the placeholder
   rather than a purchasable skill. This is a **confirmed integration gap and
   semantic mismatch**, not just missing test coverage.

2. **Quick Recovery and Time Point Rate are not connected to their catalogue
   ranks.** 3D has `CharacterState.quick_recovery_rank` and
   `time_points_per_tick` fields and `ActionEconomy` consumes those fields,
   but the inspected runtime does not map canonical skill ranks
   `quickRecovery` and `timePointRate` into them. The fields currently
   behave as separate state values, not demonstrated skill effects.

3. **Initiative Bonus is not applied at combat start.** The original 2D
   initialises combat with +5 TP per `initiativeBonus` rank. 3D
   `WorldSimulation.start_combat()` only changes combat state and emits a
   signal; no skill-rank bonus is applied in the inspected start path.

4. **Health and regeneration ranks need an explicit integration pass.** The
   original 2D `health` skill increases current and maximum HP by 10 per
   rank; `health_regen` increases regeneration by 0.1 per rank. 3D
   `CharacterState` stores health and maximum health but the inspected
   progression/runtime path does not apply those canonical ranks. Do not
   confuse innate creature regeneration or the generic HP fields with
   implementation of these purchased skills.

5. **Weapon proficiency/damage skills are not automatically resolved from
   ranks.** 3D `CombatRules` accepts `weapon_skill_hit`,
   `weapon_skill_damage`, `unarmed_skill_hit` and
   `unarmed_skill_damage` as action options, but the inspected combat
   resolver does not map canonical `<weapon>_hit` / `<weapon>_dmg` skill
   ranks into those options. The catalogue/progression system can store and
   purchase them; that alone does not implement their hit/damage effects.

6. **Foliage and mounted movement remain incomplete.** 3D's tested movement
   discounts operate on the `CharacterState` passed to `MovementRules`.
   The original 2D movement code applies Fast Movement / Swift Step to the
   actual move entity (the mount when the player is riding). A full 3D riding
   implementation and explicit rider/mount skill ownership rules are still
   needed before claiming parity for mounted movement.

7. **The 3D test fixtures needed a rank correction.** Original catalogue
   max-rank values are one for Fast Movement and Goblin Opportunist. PR #102
   initially tested those effects with rank two. PR #105 corrected the
   fixtures to legal rank-one values and adjusted expected movement cost and
   damage; its Godot validation and initiative preview both passed before it
   was merged.

### Runtime coverage that is present but not yet complete

- `MovementRules` reads `fastMovement` / `fast_movement`,
  `swift_step`, `elf_foliage_expertise` and
  `druid_foliage_expertise`.
- `CombatRules` reads `meleeDamage`, `dwarf_axe_mastery`,
  `orc_brute_strength`, `orc_ferocity`, `goblin_opportunist` and
  `spectral_form`. The goblin bonus is rank-scaled in 3D, while the source
  skill is max rank one and describes a fixed +3 bonus; legal ranks therefore
  produce the same result.
- `WorldSimulation` contains the sword/dagger parry, Protector, Shield Other,
  Spear Halt, Spear Intercept and Sidestep reaction paths. Parry efficiency,
  parry chance and Sidestep Mastery are read by those paths.
- `TerrainElevationRules` reads the non-canonical `climbing` / `climb`
  aliases; this should be reconciled with the three canonical climbing skills
  rather than treated as a successful skill implementation.

### Test coverage is not parity coverage

The 22 effect-tested IDs are not 22 complete source-parity skills. The two
foliage skills currently cover only movement, and Protector's special
+10-per-rank parry chance branch is not separately asserted. The remaining
catalogue skills still require per-skill source tracing. The old 257-skill
inventory deliberately retains conservative `UNVERIFIED` labels where a
runtime hook or focused test has not been established.


8. **Several passing helper tests do not prove end-to-end combat integration.**
   `WorldSimulation._submit_attack()` passes the caller's action options
   through to `CombatRules.resolve_attack()` without deriving the equipped
   weapon ID or target's `caught_off_guard` state. Therefore the current
   Dwarven Axe Mastery test proves the raw-damage helper when supplied
   `weapon_id: "axe"`, not that a normal attack automatically supplies it.
   Similarly, Goblin Opportunist's test supplies
   `target_caught_off_guard: true` directly; the normal attack path does not
   populate that option from the target's state. Both remain partial pending
   an end-to-end action test and integration fix.

9. **Shield Proficiency is only partly applied.** The 3D Shield Other reaction
   adds the ally's `shield_proficiency` rank to the temporary shield
   reduction, and the test confirms that interaction. But ordinary passive
   damage reduction in `CombatRules.damage_reduction()` adds the equipped
   shield's reduction without adding `target.skills["shield_proficiency"]`.
   The original 2D rule applies Shield Proficiency to ordinary shield defence
   as well as the Shield Other calculation.

10. **Protector's enhanced parry chance needs its own test.** The runtime
    applies a 10-percentage-point bonus per rank for Protector parries, versus
    5 points for a self-parry. The tests cover Protector reaction resolution
    and self-parry modifiers, but do not assert that distinct Protector bonus.



### Additional branch cross-reference (rechecked against current dev)

The following branches were also compared with current `dev` on 2026-11-11.
They are not evidence of additional live skill effects:

| Branch | Relationship to dev | Relevant contents | Audit treatment |
|---|---:|---|---|
| `feature/port-action-economy` | 0 ahead / 312 behind | No branch-only changed files remain relative to current dev. | Historical/fully superseded; no candidate effect to count. |
| `feature/mechanics-port-foundation` | 1 ahead / 135 behind | Only adds/updates `docs/MECHANICS_PORT_REGISTER.md`. | Documentation only; no runtime skill effect. |
| `feature/ally-combat-reactions` | 7 ahead / 122 behind | Only relevant gameplay-file change is a one-line UI reaction prompt change. | Presentation candidate only; no additional simulation skill effect. |
| `feature/combat-resolution-foundation` | 36 ahead / 135 behind | Older combat foundation, including an earlier `CombatRules`, `CharacterState` and simulation implementation. | Stale predecessor to the current dev combat runtime; do not merge wholesale or count its effects separately. |
| `feature/action-contract-downed-lifecycle` | 10 ahead / 129 behind | Action request/result/event contracts and downed-character lifecycle changes. | Potentially useful lifecycle foundation, but no additional canonical skill-effect implementation identified. |
| `feature/animal-attributes` | 12 ahead / 4 behind | Adds `AnimalCatalog`, animal-specific state fields and creature presentation/world integration. | Relevant to the separate animal-stat work; not a riding-skill implementation. Reconcile its four commits behind dev before any integration. |

The vision branch remains the only identified off-dev branch with a direct
candidate implementation for perception/vision/stealth skills. It contains
`VisionRules`, `FogOfWar` and a fog presentation test, but it is 34 commits
behind current dev and has no dedicated effect tests for the range, LOS,
low-light, perception or stealth calculations. It remains a candidate, not
working functionality on dev.


### Current inventory totals

The 257 canonical skill rows currently resolve to:

| Evidence status | Skills |
|---|---:|
| Verified — automated effect test | 17 |
| Partial — helper or limited effect test; parity gap remains | 5 |
| Implementation found — focused effect test still required | 1 |
| Feature-branch candidate only | 8 |
| NPC/creature-focused, requiring separate behaviour audit | 15 |
| Unverified — no current-dev effect established | 211 |
| **Total** | **257** |

These are evidence labels, not a claim that 211 skills are necessarily broken.
The 22 skills with some effect-test coverage comprise 17 verified and 5
partial; the partial group is not counted as complete parity.


## Additional source-backed 2D systems with no current-dev equivalent found

The original 2D project has supporting systems outside `gameEngine.js`.
Reviewing those files confirms that some skills depend on whole gameplay
subsystems, not a simple numeric modifier:

| 2D source | Original behaviour | Current 3D status |
|---|---|---|
| `npcBuilder.js` / `skills.js` | NPC construction invokes each purchased skill's `apply(this)` hook, then tops HP to the resulting max HP and builds the NPC's prepared spellbook. | 3D progression stores ranks and NPC allocation; no equivalent general skill-application hook was found. This is why state fields such as max HP, TP regeneration and spell unlocks are not automatically derived from purchased ranks. |
| `trapSystem.js` | Material-driven traps (snare, deadfall, pressure-plate spikes), build times/material costs, concealment, detection, disarming, and a tamper rune. The legacy `trap_setting` key is retained as the broader Traps skill rank. | No trap gameplay system or trap-skill runtime integration found in current 3D GDScript. |
| `monsters.js` / `entities.js` | Rider/mount entity relationships, mount types, rider sizes, mounted movement and NPC mount training. `riding`, `riding_druid` and `riding_paladin` are eligibility skills. | Current dev has no equivalent mount relationship/action system. The off-dev `feature/animal-attributes` branch adds animal attributes/catalogue state, not rider/mount integration or the Riding skills. |
| `disguiseSelfSystem.js` plus spell pipeline | Disguise Self applies a configurable appearance and optional target identity/faction/dialogue profile; `disguise_equipment` permits visual equipment/clothing-colour overlays. | No 3D spell cast, disguise profile state or skill-driven disguise equipment integration found. |
| `npcProgression.js` / `monsters.js` | NPC archetypes and creature templates deliberately choose skills such as Riding, Quick Recovery, Initiative Bonus, spell learning, racial passives and weapon skills. | 3D NPC skill allocation can store/purchase catalogue ranks, but a rank in a skill is not evidence that the corresponding 2D gameplay subsystem exists in 3D. |

These are confirmed 2D systems and current 3D gaps from the inspected source
files. They should be treated as separate feature families when planning the
port, rather than attempting to implement every remaining skill as an
independent one-off effect.
