# Skill and Spell Implementation Audit

**Baseline branch:** `dev`  
**Baseline commit:** `bd270192da5c2ffd4317580175b76be53e46394e`  
**Audit branch:** `audit/skill-spell-implementation-baseline`  
**Scope:** source inspection of the skill catalogue, progression, movement, combat and current simulation tests. This is an initial evidence-based baseline, not a claim that every possible call site has been exhaustively searched.

## Summary

- Catalogue contains **257 skills** and **15 base spells**.
- Skill catalogue loading, purchase eligibility, prerequisites, point accounting, NPC skill allocation and save/load have automated coverage in `tests/test_simulation.gd`. These tests verify progression plumbing, not the gameplay effect of every purchased skill.
- **7 skill effects have direct automated test coverage** in the current simulation test suite: Sword Parry, Protector, Shield Other, Spear Halt, Spear Intercept, Sidestep and Orc Brute Strength.
- Additional runtime hooks were found for movement discounts, foliage movement, dagger/sword parry modifiers, shield proficiency, Sidestep Mastery, dwarf axe mastery, orc ferocity, goblin opportunism and spectral form. These need focused tests before being called verified.
- The spell file is currently a **15-entry data catalogue**. The reviewed simulation scripts contain character spell-slot/unlock storage, but this audit did not identify a spell-casting/effect resolver or spell-effect tests. All spells therefore remain unverified.
- All remaining skills are deliberately marked **UNVERIFIED**, not “broken” or “not implemented”: absence of a hook in the reviewed core files is not proof that no implementation exists elsewhere.

## Status definitions

| Status | Meaning |
|---|---|
| VERIFIED — automated effect test | Test exercises the actual gameplay effect, not merely selection or rank storage. |
| IMPLEMENTATION FOUND — effect test still required | A runtime code path reads/applies the skill, but a focused effect test is missing. |
| UNVERIFIED | No effect test or confirmed runtime hook established in this pass. Do not assume it works. |
| NPC/CREATURE | Intended primarily for NPC/monster use; still requires behaviour validation. |

## Skill inventory

### agility (10)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `acrobatics` | Acrobatics | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `fastMovement` | Fast Movement | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `keen_perception` | Keen Perception | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `riding` | Riding | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `sidestep` | Sidestep | VERIFIED — automated effect test |
| `sidestep_mastery` | Sidestep Mastery | IMPLEMENTATION FOUND — effect test still required |
| `slip_away` | Slip Away | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `stealth_agility` | Inconspicuous | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `sure_footed` | Sure-Footed | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `timePointRate` | Time Point Rate | UNVERIFIED — no effect test or confirmed runtime hook yet |

### elf (9)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `ageless_patience` | Ageless Patience | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `elf_bow_range` | Elf Bow Mastery | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `elf_darkvision` | Elf Darkvision | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `elf_foliage_expertise` | Woodland Stride | IMPLEMENTATION FOUND — effect test still required |
| `elf_knowledge_nature` | Knowledge: Nature | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `elf_vision` | Keen Elf Sight | UNVERIFIED — no effect test or confirmed runtime hook yet |
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
| `swift_step` | Swift Step | IMPLEMENTATION FOUND — effect test still required |
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
| `stealth_rogue` | Shadow Weaver | UNVERIFIED — no effect test or confirmed runtime hook yet |
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
| `dagger_parry` | Dagger Parry | IMPLEMENTATION FOUND — effect test still required |
| `dagger_parry_chance` | Dagger Parry Mastery | IMPLEMENTATION FOUND — effect test still required |
| `dagger_parry_cost` | Dagger Parry Efficiency | IMPLEMENTATION FOUND — effect test still required |
| `dagger_throw` | Throw Dagger | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `hack_and_slash` | Hack and Slash | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `hamstring` | Hamstring | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `headsmans_blow` | Headsman's Blow | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `in_the_way` | In the Way | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `shield_bash` | Shield Bash | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `shield_other` | Shield Other | VERIFIED — automated effect test |
| `shield_proficiency` | Shield Proficiency | IMPLEMENTATION FOUND — effect test still required |
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
| `sword_parry_chance` | Sword Parry Mastery | IMPLEMENTATION FOUND — effect test still required |
| `sword_parry_cost` | Sword Parry Efficiency | IMPLEMENTATION FOUND — effect test still required |
| `sword_riposte` | Riposte | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `threatening_presence` | Threatening Presence | UNVERIFIED — no effect test or confirmed runtime hook yet |

### druid (9)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `barkskin_active` | Barkskin | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `druid_foliage_expertise` | Foliage Mastery | IMPLEMENTATION FOUND — effect test still required |
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
| `deep_sense` | Deep Sense | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `dwarf_axe_mastery` | Dwarven Axe Mastery | IMPLEMENTATION FOUND — effect test still required |
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
| `meleeDamage` | Weapon Damage | UNVERIFIED — no effect test or confirmed runtime hook yet |
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
| `spectral_form` | Spectral Form | IMPLEMENTATION FOUND — effect test still required |

### goblin (5)

| Skill ID | Skill | Current evidence status |
|---|---|---|
| `goblin_keen_senses` | Keen Senses | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `goblin_low_light_eyes` | Low-Light Eyes | UNVERIFIED — no effect test or confirmed runtime hook yet |
| `goblin_opportunist` | Opportunist | IMPLEMENTATION FOUND — effect test still required |
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
| `orc_ferocity` | Ferocity | IMPLEMENTATION FOUND — effect test still required |
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
