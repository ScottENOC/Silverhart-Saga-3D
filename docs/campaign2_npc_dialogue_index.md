# Campaign 2 NPC and dialogue content index — extraction pass 1

**Sources:** `campaign2Content.js` (55,268 characters) and `campaign2Dialogue.js` (355,444 characters), original repository `ScottENOC/Hex-crpg`, branch `main`.

This index is a mechanical first-pass inventory of source identifiers and display-name literals. It is not a complete semantic mapping of every NPC to a location, nor does it imply the dialogue/quest logic has been ported.

## Source size and extraction counts

- 114 unique `name:` string literals in `campaign2Content.js`. This includes named characters, generic role templates and creature/combatant specs; it is not a count of simultaneously spawned NPCs.
- 69 unique explicit `dialogueId` values in that file.
- 56 named function declarations in `campaign2Dialogue.js`.
- 49 unique literal quest-ID-like values found by a first-pass source scan. Some quest IDs are created dynamically and this scan is not a canonical quest count.
- Dialogue is implemented both as a central `window.npcDialogueTrees` registry and as scripted helper functions/actions. Porting just visible dialogue text would lose the branch effects.

## Display-name index

- Ambassador Brokk Stonehammer
- Ambassador Cassia Wren
- Ambassador Elarion
- Ambassador Toren Aldwyn
- Baron Corwin Aldervale
- Bettina Marrow
- Bowmaster Ellandrie
- Broodmother
- Captain Ilsa Rennick
- Cave Spider
- Chancellor Merric Vane
- Chief Skarnub
- Commander Ysolde Hart
- Corran Vale
- Corvin Ashe
- Court Wizard Thessaly
- Del Ashworth
- Dray Coltayne
- Elder Marta Wynfield
- Elder Nessa Wren
- Factor Willem Drass
- Fenn Oakheart
- Foreman Dornik Coalbeard
- Fort Soldier Bram
- Fort Soldier Cadha
- Fort Soldier Dunstan
- Fort Soldier Halric
- Fort Soldier Wenna
- Fort Soldier Ysolt
- Garrick Holt
- Goblin Skulker
- Goblin Warrior
- Gralk the Bonecaster
- Greta Aldwyn
- Guild Assassin
- Guild Watchman Corley
- Guildmaster Petra Voss
- Hall Guard
- Hask Greel
- Healer Sylwen
- Hendra Wells
- High Cleric Adelram
- Hollis Vane
- Ingra Silvertongue
- King Balrik Deepholm
- Lady Miriel Corstane
- Loremaster Faelan
- Marsh Dobbins
- Master Builder Hallis
- Mercenary Recruiter
- Mira Ashbrook
- Mira Selk
- Mirabel Quill
- Mirella Thorn
- Mirelle Sondhe
- Nella Brook
- Nix Sharpear
- Nix the Cutpurse
- Old Hessa
- Old Mac
- Orc Guard
- Orc Skirmisher
- Oskar Vinn
- Osric Fenn
- Ossian Fell
- Perrin Vance
- Petra Ashfield
- Petra Hollis
- Quartermaster Osric Vane
- Quartermaster Rurik Voss
- Queen Aelwen Sil
- Queen Seraphine Corrin
- Reeve Aldous Finch
- Renn Ashby
- Rennik Coalmarrow
- Reyna Fletcher
- Rowan Fletcher
- Royal Guard Ashe
- Royal Guard Corwin
- Royal Guard Denna
- Royal Guard Isolde
- Royal Guard Osric
- Royal Guard Petra
- Sentinel Ilyndra
- Sentinel Thaeril
- Ser Aldric Thorne
- Sergeant Bell
- Silas Crane
- Steward Halvard Greer
- Tam Wells
- Tavern Patron
- Tessa Nightshade
- The Bone Trader
- Thrain Emberhand
- Tomas Wren
- Tomlin Brask
- Tomlin Reed
- Torvald Anvik
- Wall Guard Brennan
- Wall Guard Draven
- Wall Guard Ottilie
- Wall Guard Sela
- Wall Guard Tomas
- Wall Guard Yara
- Warlord Grukk Ironhide
- Watchman Bram Oswick
- Wick Hallow
- Yvette Marlow

## Explicit dialogue IDs in content specs

- `aldenreach_ambassador`
- `bone_trader`
- `border_war_quartermaster`
- `builder_tomas`
- `chief_skarnub`
- `corran_vale`
- `corvane_ambassador`
- `deepholds_foreman`
- `deepholds_runesmith`
- `deepholds_trader`
- `dray_coltayne`
- `dwarf_king`
- `dwarven_ambassador`
- `elder_nessa_wren`
- `elf_archivist`
- `elf_healer`
- `elf_queen`
- `elven_ambassador`
- `emberlode_miner`
- `fenn_oakheart`
- `garrick_holt`
- `guild_investigator`
- `hendra_wells`
- `high_cleric`
- `hollowmere_hunter`
- `ironbond_envoy`
- `ironbond_merchant`
- `lady_corstane`
- `manor_neighbor`
- `marta_wynfield`
- `mira_ashbrook`
- `mirabel_quill`
- `nix_sharpear`
- `northwatch_commander`
- `old_mac`
- `orc_warlord`
- `oskar_vinn`
- `palace_chancellor`
- `petra_hollis`
- `reddale_baron`
- `reddale_blacksmith`
- `reddale_captain`
- `reddale_disciple`
- `reddale_guard`
- `reddale_guildmaster`
- `reddale_innkeeper`
- `reddale_reeve`
- `reddale_steward`
- `reyna_fletcher`
- `royal_wizard`
- `silverhart_clothier`
- `silverhart_general_goods`
- `silverhart_innkeeper`
- `silverhart_magic_dealer`
- `silverhart_mercenary_broker`
- `silverhart_outlying_resident_1`
- `silverhart_outlying_resident_2`
- `silverhart_outlying_resident_3`
- `silverhart_queen`
- `silverhart_retrainer`
- `silverhart_stablehand`
- `silverhart_watch_sergeant`
- `sylvan_bowmaster`
- `thieves_guild_debtor`
- `thieves_guild_fence`
- `thieves_guild_informant`
- `thieves_guildmaster`
- `wick_hallow`
- `yvette_marlow`

## First-pass quest ID index

- `a_stone_for_nella`
- `aldenreach_message`
- `baron_tribute`
- `border_war`
- `buried_road`
- `corvane_watch`
- `crimson_court`
- `deepholds_infestation`
- `deepholds_letter`
- `disciple_exposed`
- `druid_grove`
- `dwarven_toll`
- `elder_locket`
- `elven_gift`
- `eyes_on_border`
- `farm_wolves`
- `goblin_mine_raid`
- `goblin_spy_for_humans`
- `goblin_threat`
- `greenskin_spy`
- `guild_big_score`
- `guild_blood_price`
- `guild_favor`
- `guild_initiation`
- `guild_sunken_cache`
- `hidden_bodies`
- `ironbond_missing_courier`
- `ironbond_pitch`
- `kragmoor_runesmith_teach`
- `kragmoor_runesmith_trust`
- `millbrook_dragon`
- `missing_child`
- `necromancer_hunt`
- `necromancer_lichdom`
- `orc_stronghold_trust`
- `ore_road_reopened`
- `oskars_wager`
- `reddale_cut`
- `reddale_missing_watch`
- `silver_accord`
- `silverleaf_tonic`
- `spy_on_baron`
- `spy_on_guild`
- `stolen_delivery`
- `sylvan_bowmaster_teach`
- `tavern_brawl`
- `toll_ogre`
- `unicorn_tracking`
- `wizard_vendetta`

## Important implementation implication

The dialogue source contains more than conversation text: quest acceptance/completion, reputation and faction changes, rewards, recruitment, combat starts, timed encounters, world-state flags, evidence discovery, settlement access and later follow-up triggers. These must be represented as explicit Godot dialogue nodes plus typed simulation commands/effects. Do not attempt to execute or embed the JavaScript source in Godot.

For migration tracking, each source dialogue ID should have:
1. A stable Godot dialogue resource ID (retain the source ID as a migration key).
2. All player-visible lines and choices.
3. Branch conditions and prerequisite flags.
4. A list of effect commands and their parameters.
5. Resulting quest, reputation, inventory, party, world and NPC-state changes.
6. A source test or new Godot regression test for each consequential branch.

## Status

Index generated from source literals and first-pass pattern scans. Names and IDs should be reconciled with actual spawn sites, builders and tests before marking any character or quest as migrated. This file is an inventory aid, not proof of parity.
