# Silverhart Saga 3D — Source Content Census

**Audit date:** 2026-11-10  
**Audited port ref:** `dev`  
**Census branch:** `docs/content-census` (based on `dev`)  
**Source:** [ScottENOC/Hex-crpg](https://github.com/ScottENOC/Hex-crpg), `main`  
**Port:** [ScottENOC/Silverhart-Saga-3D](https://github.com/ScottENOC/Silverhart-Saga-3D), `dev`

This document inventories concrete source catalogues and reconciles them with the current Godot data files. It complements `CONTENT_PARITY_AUDIT.md`, `LEGACY_PORTING_MATRIX.md` and `MECHANICS_PORT_REGISTER.md`.

## Status rules

- **Data ported** means an identifiable source record exists in the 3D data layer. It does not mean its visuals, mechanics, UI or persistence are complete.
- **Profile/model required** means the record exists but still lacks a suitable 3D appearance/model asset.
- **Mechanic missing** means the 3D project does not yet have the corresponding catalogue or functional system.
- **Needs reconciliation** means exact source-to-port equivalence, duplicate handling or runtime coverage still needs checking.
- No category is marked accepted solely because a JSON file or scene exists.

## Executive census

| Content family | Original source inventory | 3D `dev` inventory | Census result |
|---|---:|---:|---|
| Named NPCs | 98 identifiable roster records extracted from `campaign2Content.js` | 98 records in `legacy_named_npcs.json` | <badge color="warning">86 appearance profiles required</badge> |
| Creature/enemy templates | 35 in `monsters.js` | 35 in `legacy_enemy_roster.json` | <badge color="danger">35 3D models required</badge> |
| Items/equipment | 63 definitions in `equipment.js` | 76 definitions in `item_definitions.json` | <badge color="warning">Data ported; runtime parity pending</badge> |
| Skills | 186 keyed definitions in `skills.js` | No equivalent skill catalogue found in 3D data tree | <badge color="danger">Not ported as a catalogue</badge> |
| Spells | 15 base spells in `spells.js` | No equivalent spell catalogue found in 3D data tree | <badge color="danger">Not ported</badge> |
| Quest/dialogue content | 49 named title entries surfaced in `campaign2Dialogue.js`; many more IDs and story modules | No complete quest/dialogue catalogue found | <badge color="danger">Major content port outstanding</badge> |
| Arena | 18 opponents, 6 beast options, 8 scenario types, 3 lobby NPCs in source-backed 3D roster | Matching arrays in `arena_opponents.json` | <badge color="warning">Data ported; playable mode incomplete</badge> |
| Strategic world map | 16×16 map and many POIs/hidden sites | 16×16 foundation, 6 visible locations | <badge color="warning">Only opening subset represented</badge> |

**Important correction to the first high-level audit:** the port already has a source-backed 98-record named-NPC roster, a 35-record enemy roster, and a 76-entry item-definition file. The major gaps are not simply the absence of data files: they are 3D character/creature presentation, skills/spells, complete quests/dialogue, world content and connected gameplay.

---

# 1. Named NPC census

**Source:** `Hex-crpg/campaign2Content.js`  
**3D data:** `data/characters/legacy_named_npcs.json`

The source-to-port roster count matches at **98 records**. The 3D roster uses stable IDs and retains source references.

## 3D presentation status

| Status | Count |
|---|---:|
| Hollowmere appearance profile available | 12 |
| Appearance profile required | 86 |
| Total roster records | 98 |

The roster data is therefore substantially migrated, but most named NPCs still need appearance profiles and generated/validated Ara GLBs. A data record does not prove the NPC has been spawned in the correct location, has their original dialogue, or has their gameplay behaviour.

## Full 3D roster

1. Garrick Holt
2. Mira Ashbrook
3. Oskar Vinn
4. Wick Hallow
5. Dray Coltayne
6. Tomlin Brask
7. Hask Greel
8. Yvette Marlow
9. Hendra Wells
10. Tavern Patron
11. Tam Wells
12. Renn Ashby
13. Rowan Fletcher
14. Old Mac
15. Captain Ilsa Rennick
16. Watchman Bram Oswick
17. Reeve Aldous Finch
18. Nella Brook
19. Torvald Anvik
20. Mirella Thorn
21. Ser Aldric Thorne
22. Reyna Fletcher
23. Mirabel Quill
24. Fenn Oakheart
25. Petra Hollis
26. Elder Marta Wynfield
27. Corran Vale
28. Bettina Marrow
29. Baron Corwin Aldervale
30. Guildmaster Petra Voss
31. Guild Watchman Corley
32. Guild Assassin
33. Steward Halvard Greer
34. Queen Seraphine Corrin
35. Royal Guard Denna
36. Royal Guard Corwin
37. Royal Guard Ashe
38. Royal Guard Petra
39. Royal Guard Osric
40. Royal Guard Isolde
41. Wall Guard Brennan
42. Wall Guard Yara
43. Wall Guard Tomas
44. Wall Guard Sela
45. Wall Guard Draven
46. Wall Guard Ottilie
47. Tomas Wren
48. Master Builder Hallis
49. Petra Ashfield
50. Ossian Fell
51. Mirelle Sondhe
52. Corvin Ashe (elf record)
53. Perrin Vance
54. Quartermaster Osric Vane
55. Tessa Nightshade
56. Corvin Ashe (human record)
57. Marsh Dobbins
58. Del Ashworth
59. Rennik Coalmarrow
60. Mira Selk
61. Silas Crane
62. The Bone Trader
63. Lady Miriel Corstane
64. Chancellor Merric Vane
65. Court Wizard Thessaly
66. Ambassador Elarion
67. Ambassador Brokk Stonehammer
68. Ambassador Cassia Wren
69. Ambassador Toren Aldwyn
70. Factor Willem Drass
71. High Cleric Adelram
72. Old Hessa
73. Fort Soldier Halric
74. Fort Soldier Wenna
75. Fort Soldier Dunstan
76. Fort Soldier Ysolt
77. Fort Soldier Bram
78. Fort Soldier Cadha
79. Commander Ysolde Hart
80. Quartermaster Rurik Voss
81. Elder Nessa Wren
82. King Balrik Deepholm
83. Hall Guard (dwarf male)
84. Hall Guard (dwarf female)
85. Foreman Dornik Coalbeard
86. Ingra Silvertongue
87. Thrain Emberhand
88. Sentinel Ilyndra
89. Sentinel Thaeril
90. Loremaster Faelan
91. Healer Sylwen
92. Bowmaster Ellandrie
93. Hollis Vane
94. Sergeant Bell
95. Nix the Cutpurse
96. Osric Fenn
97. Greta Aldwyn
98. Tomlin Reed

### NPC follow-up checks

- [ ] Generate appearance profiles for the 86 outstanding records.
- [ ] Verify the 12 profile-available records have correct GLBs, rigs, materials and clothing.
- [ ] Resolve duplicate display names using stable IDs (e.g. Corvin Ashe, Hall Guard).
- [ ] Verify race, gender, faction, class, equipment, skills and source location for every record.
- [ ] Match all 98 records to the correct source spawn/creation conditions.
- [ ] Port every NPC dialogue tree, schedule, quest role and consequence.
- [ ] Distinguish fixed named NPCs from generic/repeatable roles and dynamically spawned actors.

---

# 2. Creature and enemy census

**Source:** `Hex-crpg/monsters.js`  
**3D data:** `data/characters/legacy_enemy_roster.json`

All **35 source templates** have corresponding 3D roster records. However, the current 3D roster marks all 35 as requiring a 3D model.

| # | Source creature/template | 3D model status |
|---:|---|---|
| 1 | Goblin | Required |
| 2 | Elite Goblin | Required |
| 3 | Orc | Required |
| 4 | Bandit | Required |
| 5 | Siege Engine | Required |
| 6 | Wolf | Required |
| 7 | Deer | Required |
| 8 | Wild Boar | Required |
| 9 | Horse | Required |
| 10 | Troll | Required |
| 11 | Young Dragon | Required |
| 12 | Adult Dragon | Required |
| 13 | Ancient Dragon | Required |
| 14 | Skeleton | Required |
| 15 | Zombie | Required |
| 16 | Imp | Required |
| 17 | Spider | Required |
| 18 | Bear | Required |
| 19 | Ogre | Required |
| 20 | Boar | Required |
| 21 | Tiger | Required |
| 22 | Eagle | Required |
| 23 | Unicorn | Required |
| 24 | Wraith | Required |
| 25 | Basilisk | Required |
| 26 | Harpy | Required |
| 27 | Minotaur | Required |
| 28 | Revenant | Required |
| 29 | Goblin Wolf Rider | Required |
| 30 | Horse Archer | Required |
| 31 | Grishnak | Required |
| 32 | Sir Alistair | Required |
| 33 | Viper | Required |
| 34 | Krog the Unstoppable | Required |
| 35 | Sylvara the Huntress | Required |

### Creature follow-up checks

- [ ] Select reusable 3D archetypes (humanoid, quadruped, flying, undead, dragon, siege).
- [ ] Build/import all missing models and animations.
- [ ] Verify each template's scale, skeleton, materials, collision, navigation and hitbox.
- [ ] Port HP, TP, attributes, attacks, armour, skills, tags, AI and loot.
- [ ] Verify mountable species and rider attachment/animation.
- [ ] Verify summonable species and summon duration/upkeep.
- [ ] Verify unique boss identity, abilities, encounter placement and rewards.
- [ ] Test all 35 in combat, not merely in a model viewer.

**Note:** the source distinguishes some related templates (e.g. Wild Boar and Boar, Young/Adult/Ancient Dragon, Wolf Rider Goblin) which may share a model but must retain distinct gameplay data.

---

# 3. Items, equipment and clothing census

**Source:** `Hex-crpg/equipment.js`  
**3D data:** `data/items/item_definitions.json`

The source has **63 keyed equipment/item definitions**. The current 3D catalogue has **76 entries**, including the original content and additional clothing entries. This is a strong data migration result, but still requires a field-by-field comparison and runtime testing.

## Original 63 source IDs

```text
dagger, sword, axe, club, spear, bow,
light_armor, medium_armor, heavy_armor,
light_barding, medium_barding, heavy_barding,
nasal_helm, torch, wooden_shield, pickaxe,
chair, bottle, fruit, fish, herbs, game_meat, hide,
ore_iron, wood, stone, ore_silver, ore_gold,
gem_red, gem_blue, gem_green, starmetal_ore,
dragon_scale, deep_crystal, sword_arrow_deflection,
potion_health, glowing_ring, orcbane_pendant,
wolfward_charm, undying_locket, silvertongue_ring,
stormcaller_spear, nightowl_bow, featherweight_dagger,
bulwark_shield, ashenwood_club, travelers_cloakpin,
moonlit_armor, huntsman_helm, shadowcloak, magic_backpack,
starforged_blade, dragonscale_mail, deepcrystal_pendant,
hunting_bow, reinforced_leather_armor, elder_locket,
phylactery_shard, guild_ledger_evidence, baron_tariff_evidence,
disciple_evidence, wizard_corruption_evidence, deepholds_sealed_letter
```

## Additional 3D catalogue entries

The 76-entry 3D data file also contains clothing records:

- Basic Bra
- Basic Briefs
- Long Tunic
- Trousers
- Tunic
- Long Wrapper
- Uniform Shirt
- Fatigue Trousers
- Knee-length Wrapper
- Tattered Shirt
- Fatigue Shirt
- Sandals
- Combat Boots

## Item presentation observations

- The 3D item catalogue declares 76 items.
- The SVG icon atlas declares 57 icon slots. Some items deliberately reuse icons, so this is not automatically a 19-item defect; verify icon mapping and fallback for every item.
- The source includes weapons, armour, barding, shields, tools, food, gathered resources, rare materials, magic items, quest evidence and clothing.
- The 3D item file includes equipment slots, weights and icon metadata. The gameplay systems still need complete shared-party inventory, shops, loot, stack behaviour, item use, equipment readiness and persistence.

### Item follow-up checks

- [ ] Automated ID comparison: source 63 IDs against the 3D item catalogue.
- [ ] Compare every stat, price, weight, slot, skill grant, aura, description and special rule.
- [ ] Verify all 76 records can be loaded, displayed, acquired, equipped/used and saved as applicable.
- [ ] Verify all original quest items are awarded/consumed at the right story points.
- [ ] Verify all clothing/equipment variants render correctly on Ara bodies.
- [ ] Verify mount barding separately from player armour.
- [ ] Verify every icon mapping and reused atlas cell.

---

# 4. Skills census

**Source:** `Hex-crpg/skills.js`

The source has **186 keyed skill definitions**. No equivalent full skill catalogue was found in the 3D `data/` tree or the current simulation scripts inspected on `dev`. The 3D porting matrix also records skills and skill checks as not started.

The full source ID list is:

```text
health, health_regen, meleeDamage, light_armor_training, medium_armor_training,
heavy_armor_training, iron_grip, shove, protector, battle_reflexes,
timePointRate, fastMovement, riding, riding_druid, riding_paladin, sidestep,
sidestep_mastery, stealth_agility, keen_perception, sure_footed,
shield_proficiency, shield_bash, shield_other, quickRecovery, initiativeBonus,
dagger_quick_draw, stealth_rogue, subtle_spell, speedy_stealth, regeneration,
unarmed_hit, unarmed_dmg, unarmed_reaction_block, deflect_arrows,
siphoning_palm, swift_step, trip_reaction, agile_climber, disarm,
arcane_expand, divine_expand, nature_expand, arcane_burst, divine_burst,
nature_burst, blood_magic, arcane_touch, divine_touch, nature_touch,
arcane_targets, divine_targets, nature_targets, learn_boar_summon,
learn_tiger_summon, learn_eagle_summon, elf_vision, elf_bow_range,
elf_darkvision, elf_foliage_expertise, druid_foliage_expertise,
druid_knowledge_nature, elf_knowledge_nature, nature_butchery, nature_bounty,
nature_ranger, knowledge_religion, divine_armor_ease, nature_armor_ease,
dwarf_axe_mastery, dwarf_solid, goblin_opportunist, goblin_keen_senses,
goblin_low_light_eyes, goblin_quick_reflexes, goblin_pack_hunter,
orc_brute_strength, orc_thick_hide, orc_ferocity, orc_momentum,
orc_relentless, cleric_trigger_damage, cleric_trigger_mana,
cleric_trigger_vision, cleric_trigger_dmg_red, cleric_trigger_heal_red,
assassinate, sneak_attack_dmg, pickpocket, zone_of_control, animal_companion,
learn_unicorn_summon, poison_bite, life_drain, spectral_form, petrify_gaze,
siren_song, gore_charge, revenant_revive, furious_charge, fly, land,
companion_str_end, companion_agi_end, powerful_shove, bull_rush, slip_away,
acrobatics, second_wind, grit, hardened, unwavering, brace, suppression,
rally, press_the_advantage, weapon_swap, iron_shirt, joint_lock,
focused_strike, palm_strike, nerve_strike, redirect, extended_sentence,
holy_ground, armistice, divine_judgment, barkskin_active, wild_shape_adaptation,
natures_bond, venomous_summon, natural_senses, stonewall, grudge, deep_sense,
battle_endurance, keen_hearing, elven_grace, whisper_step, ageless_patience,
vanish, dirty_fighting, trap_setting, learn_blink, learn_slow, learn_force_push,
learn_haste, learn_chain_lightning, learn_energy_shield, learn_temporal_rift,
learn_gravity_well, learn_curse, learn_command, learn_mark_of_guilt,
learn_divine_wrath, learn_excommunicate, learn_condemn, learn_root,
learn_barkskin_spell, learn_natures_vigor, learn_spore_cloud,
learn_call_of_the_wild, learn_camouflage, lich_deathless_flesh,
lich_grave_chill, lich_withering_touch, lich_command_the_dead,
lich_soul_anchor, runesmithing, leatherworking, strong_back, sunder_armor,
hamstring, appraiser, keen_forager, quartermaster, persuasion, insight,
intimidation, lockpicking, survival, appraisal, smithing, cooking,
learn_feather_fall, learn_disguise_self, disguise_equipment
```

### Skill follow-up checks

- [ ] Port all 186 IDs with names, descriptions, trees, max ranks, prerequisites and costs.
- [ ] Preserve active/passive/reaction distinction and all source effects.
- [ ] Port racial and class-specific trees.
- [ ] Port skill checks in dialogue, stealth, exploration, crafting, gathering and combat.
- [ ] Connect effects to the simulation rather than just rendering skill names.
- [ ] Test rank caps, prerequisite chains, respec and progression.
- [ ] Verify NPC and monster skills use the same definitions.

---

# 5. Spell census

**Source:** `Hex-crpg/spells.js`

The source base spell catalogue contains **15 spells**. No matching spell data catalogue or casting system is present in the current 3D data tree.

| # | Spell | School | Source effect family |
|---:|---|---|---|
| 1 | Firebolt | Arcane | Ranged damage |
| 2 | Heal | Divine | Healing |
| 3 | Smite Evil | Divine | Damage vs tagged targets |
| 4 | Divine Silence | Divine | Ongoing debuff/damage |
| 5 | Sanctuary | Divine | Ongoing protection |
| 6 | Divine Protection | Divine | Ongoing buff |
| 7 | Summon Animal | Nature | Summoning |
| 8 | Counterspell | Arcane | Dispel |
| 9 | Dragon Breath | Arcane | Area damage |
| 10 | Entangle | Nature | Area debuff |
| 11 | Wild Fury | Nature | Timed buff |
| 12 | Calm Animal | Nature | Animal-only control/debuff |
| 13 | Disguise Self | Arcane | Self-targeted disguise |
| 14 | Temporal Rift | Arcane | Time skip |
| 15 | Feather Fall | Arcane | Timed self-buff |

This is the base catalogue only. The source also has learnable spell unlocks and skill-based spell customisation/expansion (targets, bursts, touch and other modifiers). These must be reconciled against the skill list rather than treating the 15 base spells as the entire magic system.

### Spell follow-up checks

- [ ] Port all 15 base spell definitions and exact parameters.
- [ ] Port learnable spell unlocks and class/race eligibility.
- [ ] Port spell planner and modifiers.
- [ ] Implement costs, range, target validation, hit checks, duration, upkeep and cancellation.
- [ ] Implement summon lifecycle, dispel, status effects and persistence.
- [ ] Connect spells to enemy AI, companion AI, dialogue, exploration and world interactions.

---

# 6. Quest and dialogue census

**Source:** `Hex-crpg/campaign2Dialogue.js`, `campaign2Content.js` and dedicated story modules.

A first extraction finds **49 distinct named title entries** in `campaign2Dialogue.js`. This is not a definitive count of every quest node: the file also contains nested stages, dialogue options and event labels, and separate arc files contribute additional story content. Treat 49 as an initial named-title index, not a final total quest count.

## Named title entries extracted

1. The Sunken Cache
2. The Big Score
3. Blood Price
4. A Favor for the Guild
5. Initiation
6. A Snatched Delivery
7. The Missing Boy
8. Wolves at the Farm
9. The Herbalist
10. The Vessel-Seeker
11. The Barrow of Corvin Ashgrave
12. The Missing Watch
13. Eyes on the Border
14. Reddale
15. A Stone for Nella
16. Eyes on the Guildhouse
17. The Baron
18. A Look at the Ledgers
19. Prove Your Strength
20. A Hand on the Inside
21. A Favor for the Tribe
22. The Skarn-tooth Tribe
23. Ashveil of the Ashfall Peaks
24. The Toll-Taker
25. Ore Road Reopened
26. The Buried Road
27. Prove Your Worth
28. A Missing Locket
29. A Noble
30. The Silver Accord
31. A Gift of Green
32. A Tonic for the Sickbed
33. A Word to the King
34. Coin for the Deepholds
35. A Quiet Word
36. Good for Business
37. Whispers of the Crimson Court
38. Loose Ends
39. The Missing Courier
40. Oskar
41. Rowdy Brawler
42. The Tavern Brawl
43. The Northwatch Line
44. The Silver Trail
45. The Old Faith
46. What Nests Below
47. The Forge Trusts a Stranger
48. The Forge Remembers Its Own
49. The Bow Remembers the Hand

## Dedicated narrative modules in the original

These source files identify substantial story/character arcs that need individual reconciliation, not just a generic quest framework:

- `ironbondArc.js`
- `lichHunt.js`
- `wrenCharacterArc.js`
- `wrenParentsInvestigation.js`
- `wrenPriceOfSilence.js`
- `wrenCrownQuietHand.js`
- `wrenAldricEvergreenDialogue.js`
- `aldricBrokenVigil.js`
- `aldricIndependentRecruitment.js`
- `aldricMeasureOfOath.js`
- `reynaEmptyBlind.js`
- `mirabelUnquietConcordance.js`
- `mirabelDisguiseSelfDialogue.js`
- `petraIronbondFactor.js`
- `fennLivingBoundary.js`
- `balrikLastHold.js`
- `seraphineArc.js`
- `thessalyCourtWizard.js`
- `thrainRuneKeeper.js`
- `nessaGroveWarden.js`
- `aelwenLivingAccord.js`
- `adelramCathedralShepherd.js`
- `aldenUncounted.js`

### Quest/dialogue follow-up checks

- [ ] Extract a structured quest manifest: stable ID, title, act/region, stages, prerequisites, branch choices, failure states, rewards and source file.
- [ ] Extract all NPC dialogue trees and choice effects.
- [ ] Distinguish actual quests from journal headings, rumours, ambient dialogue and event labels.
- [ ] Compare each quest stage and dialogue choice against the 3D journal and campaign content.
- [ ] Port companion-specific story and relationship consequences.
- [ ] Add regression tests for important branches and save/load in the middle of a quest.

**Current 3D status:** Hollowmere opening content and a first encounter exist, but no complete quest manifest or dialogue-tree catalogue was found in the current 3D data files. Treat campaign quest/dialogue parity as outstanding.

---

# 7. World and location census

**Source:** `Hex-crpg/campaign2World.js`, `worldMap.js`, `regions.js`  
**3D data:** `scripts/world/main_campaign_world_map_data.gd`, `scripts/world/hollowmere_village_data.gd`

The original has a 16×16 strategic map and a detailed local hex world. The current 3D strategic map is also 16×16, but currently defines six location entries.

## Six current 3D strategic-map entries

- Silverhart
- Millbrook
- Emberlode
- Hollowmere
- Reddale
- Old Mac's Farmstead

## Additional source POIs / settlements / exploration sites to reconcile

- Skarn-tooth goblin camp
- Northwatch Fort
- Ridgehold Fort
- Skarnak's Hold (orc stronghold)
- Kragmoor (Deepholds mountain city and mine)
- Sil'thandriel (elven capital)
- Dragon Lair
- Lich Barrow
- Chapterhouse of the Silver Flame
- Emberwood Grove
- Thieves' Cove caves
- Vampire Grave
- Druid Grove

These 13 entries are a minimum list from the source geography and existing port notes. Some are hidden/discoverable and should not be exposed as visible map markers before discovery. More individual buildings, local encounter areas and interior spaces exist within the locations.

### World follow-up checks

- [ ] Add all visible source POIs with source-derived coordinates and road connections.
- [ ] Add hidden sites with source discovery conditions, not as initially visible markers.
- [ ] Census every enterable building, dungeon, fort, cave, mine and interior.
- [ ] Compare source local hex terrain, roads, rivers, faction borders and elevation.
- [ ] Record which sites are campaign-critical, optional, hidden, or dynamically spawned.
- [ ] Verify every POI can be reached and entered in 3D where the source allows it.

---

# 8. Arena content census

**3D data:** `data/arena/arena_opponents.json`

The 3D roster has source-backed arrays:

- **18** opponent pool entries.
- **6** beast pool entries.
- **8** scenario types.
- **3** lobby NPCs.
- **3** dragon unlock milestones.

Scenario types: standard, void bridge, ranged standoff, tunnel boss, flag defend, flag attack, lava flood and three-way.

Dragon unlocks: Young Dragon after 6 completed fights; Adult Dragon after 12; Ancient Dragon after 20.

All three lobby NPCs (Arena Announcer, Mercenary Recruiter and Arena Shopkeeper) still require 3D models. The source-backed roster file itself says scenario geometry/win conditions and named boss configurations/rewards need separate extraction. The actual Arena mode remains a placeholder/incomplete loop.

---

# 9. Character creation census

The original `data.js` defines:

**Races (5):** human, dwarf, elf, goblin, orc.

**Classes (6):** fighter, rogue, cleric, wizard, druid, monk.

The 3D character creation rules include source-backed race/class starting data. Full attribute/derived-stat parity, every skill tree, level progression, appearance choice coverage and all starting equipment still require reconciliation.

---

# 10. Economy, crafting, gathering and living-world census

The original has dedicated modules for the following systems. This is a module census, not yet an itemised recipe/merchant/interaction catalogue:

| System | Source modules | 3D status |
|---|---|---|
| Regions and faction standing | `regions.js`, `factions.js` | Initial journal/faction data only; full system outstanding |
| Resources and harvesting | `resources.js` | Initial wilderness resource system |
| Crafting | `crafting.js` | No complete recipe catalogue/system |
| Construction | `construction.js` | No complete system |
| Camps | `campSystem.js`, `campDeploymentSystem.js` | No complete system |
| Expeditions | `expeditionSystem.js` | No complete system |
| Shops and party inventory | `equipment.js`, `partyInventory.js`, campaign content | Item data ported; full economy/UI incomplete |
| NPC routines | `npcRoutineScheduler.js`, `eventDrivenNpcSchedules.js` | Initial chatter only; full schedules outstanding |
| Civilian persistence | `civilianPersistence.js`, `generatedCivilianPopulation.js` | Not fully ported |
| Travelling NPCs | `persistentRoadTravellers.js`, `roadTravellerPersistence.js` | Not ported |
| Living world/events | `worldPulse.js`, `wildernessLivingWorld.js`, `wildernessIncidents.js` | Not ported as complete simulation |
| Disguise/stealth | `disguiseSelfSystem.js`, `disguiseDialogueSystem.js` | Not ported |
| Sieges | `siegeSectorSystem.js`, `northwatchSiegeSpawn.js` and related modules | Not ported |

Next census pass should extract every recipe, resource node type, merchant stock list, shop service, construction option, camp upgrade, expedition and world incident into record-level manifests.

---

# 11. Audio and presentation census

The source includes `audio.js` and `musicDirector.js`, plus the `audio/` asset tree and dialogue presentation. The 3D project has an AudioManager foundation and an audio migration plan, but the current porting matrix notes generated Ogg files are not yet in the Pages build and browser playback is not accepted.

- [ ] Enumerate every original music track and map it to a 3D game state/region/mode.
- [ ] Enumerate dialogue voice/audio assets and verify they are included in builds.
- [ ] Enumerate sound effects and assign 3D event hooks.
- [ ] Verify campaign and arena audio independently.
- [ ] Verify browser deployment asset paths and actual playback.

---

# 12. Measurable parity scorecard

These are catalogue coverage counts, not overall gameplay-completion percentages.

| Catalogue | Records in 3D data | Remaining known gap |
|---|---:|---|
| Named NPC roster | 98 / 98 | 86 appearance profiles; dialogue/spawn/behaviour verification |
| Enemy templates | 35 / 35 | 35 3D models; AI/combat/animation verification |
| Original item IDs | 63 / 63 represented in a 76-entry catalogue | Exact field/runtime parity; 13 extra clothing entries |
| Skills | 0 / 186 as a full catalogue | 186 definitions/effects |
| Base spells | 0 / 15 | 15 definitions/effects plus spell planner/unlocks |
| Quest titles | No complete manifest | 49 extracted titles need structured reconciliation; further source arcs |
| Strategic POIs | 6 current entries | At least 13 additional source POIs/sites to reconcile |
| Arena opponents | 18 / 18 roster entries | Mode loop, geometry, bosses, rewards and models |
| Arena scenarios | 8 / 8 named types | Geometry and win conditions |
| Arena lobby NPCs | 3 / 3 records | 3 models and functional lobby roles |

Do not average these rows into one percentage: one NPC roster record and one skill definition are not equivalent units of effort, and gameplay acceptance is separate from catalogue presence.

---

# 13. Next execution sequence

1. **Close visual census gaps:** generate 86 named NPC appearance profiles and plan reusable 3D creature archetypes for the 35 enemy templates.
2. **Build missing data catalogues:** migrate 186 skills and 15 base spells to Godot Resources/JSON with source metadata.
3. **Build quest manifest:** extract every quest ID, title, stage, prerequisite, choice and reward from `campaign2Dialogue.js` and dedicated arc files.
4. **Complete world POI manifest:** add all source locations and hidden-site discovery conditions; then enumerate all buildings/interiors.
5. **Verify items:** automated field-by-field comparison of the 63 original item definitions with the 3D catalogue.
6. **Arena:** extract scenario geometry, boss configurations, reward progression and complete the lobby → fight → reward loop.
7. **Economy and world simulation:** recipes, merchants, schedules, travellers, camps, construction, factions and events.
8. **Acceptance:** source-backed tests and in-game verification for each catalogue and system.

## Reproducibility / source files

Original source files used for this census:

- `campaign2Content.js`
- `campaign2World.js`
- `campaign2Dialogue.js`
- `monsters.js`
- `equipment.js`
- `skills.js`
- `spells.js`
- `data.js`
- `worldMap.js`
- `regions.js`
- `resources.js`
- `crafting.js`
- `construction.js`
- `campSystem.js`
- `expeditionSystem.js`
- `npcRoutineScheduler.js`
- `persistentRoadTravellers.js`
- `wildernessLivingWorld.js`
- `musicDirector.js`

3D files used:

- `data/characters/legacy_named_npcs.json`
- `data/characters/legacy_enemy_roster.json`
- `data/characters/hollowmere_npcs.json`
- `data/items/item_definitions.json`
- `data/arena/arena_opponents.json`
- `scripts/world/main_campaign_world_map_data.gd`
- `scripts/simulation/` and `docs/LEGACY_PORTING_MATRIX.md`
- `docs/MECHANICS_PORT_REGISTER.md`

This is a first reproducible census pass. Exact quest-stage, dialogue-node, recipe, merchant-stock, building and audio-track manifests remain follow-up extraction tasks.
