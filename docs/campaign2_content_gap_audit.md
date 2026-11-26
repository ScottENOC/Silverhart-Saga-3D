# Campaign 2 content gap audit — NPCs, dialogue and quests

**Source:** [Hex-crpg](https://github.com/ScottENOC/Hex-crpg), `main` at `4de96f16889d43cae91e03832c8eb1c1b4b00e42`  
**Target:** [Silverhart-Saga-3D](https://github.com/ScottENOC/Silverhart-Saga-3D), `dev` at `b006f4b8828422ab1b0e6e44ef2e20e6dd3238d7` (before this audit update)  
**Audit date:** 2026-11-26  
**Scope:** Named NPC roster, authored dialogue volume/coverage, explicit quest IDs and campaign-content migration status.

This is the campaign-content companion to [the map-only gap audit](campaign2_gap_audit.md). The map audit owns *where* locations, actors and physical objects are placed and how the world is traversed. This document owns *who* the characters are, what they say and do, quest branches, relationship consequences, schedules, encounter behaviour and campaign-state changes. Do not copy these content gaps into the map audit.

## Executive baseline

| Content area | Source baseline | Target `dev` evidence | Gap reading |
|---|---:|---:|---|
| Named NPC roster | 120 named NPCs across three explicit rosters | 72 of those names appear in target character profiles or settlement placements | **48 lack an active profile/placement record** |
| Dialogue | At least 509 explicit dialogue call-sites; at least 416 literal lines passed directly to them | About 209 direct static utterances found in the current dialogue/content files | **Partial; no complete line/branch mapping exists** |
| Quests | 72 explicit source quest IDs | 28 explicit target quest IDs; 20 exact ID matches | **52 source IDs have no exact target ID** |

These are inventory counts, not a completion percentage. A profile, placement, dialogue string or quest ID is not proof that the associated actor can spawn, the full dialogue tree is reachable, or the quest's consequences work in a playable campaign.

## 1. NPC roster gap

### Counting rules

The explicit named-roster baseline is:

- `campaign2Content.js`: 98 distinct named campaign characters after excluding generic role and creature templates.
- `millbrookContent.js`: 12 named residents.
- `emberlodeExpansion.js`: 10 named residents.
- **Total: 120.**

The target comparison checks the union of `data/characters/hollowmere_npcs.json` and NPC entries in `data/world/campaign2_settlement_layouts.json`. That gives 77 unique target names, 72 of which match the 120 source-roster names. Settlement layouts contain 58 placement entries / 57 unique names; the Hollowmere profile file contains 22 characters.

The separate `data/characters/legacy_named_npcs.json` is a migration/appearance roster of 98 core Campaign 2 entries: 12 are tagged `hollowmere_profile_available` and 86 `appearance_profile_authored`. Those records preserve identity/appearance data but are not evidence of an active world actor or settlement placement. The 48 below are therefore **missing from active profile/placement coverage**, not necessarily absent from all target-side data.

### Missing from active profile/placement coverage

**Core Campaign 2 roster — 26**

- [ ] Tam Wells
- [ ] Renn Ashby
- [ ] Chief Skarnub
- [ ] Gralk the Bonecaster
- [ ] Tomas Wren
- [ ] Del Ashworth
- [ ] The Bone Trader
- [ ] Old Hessa
- [ ] Elder Nessa Wren
- [ ] Fort Soldier Halric
- [ ] Fort Soldier Wenna
- [ ] Fort Soldier Dunstan
- [ ] Fort Soldier Ysolt
- [ ] Fort Soldier Bram
- [ ] Fort Soldier Cadha
- [ ] Commander Ysolde Hart
- [ ] King Balrik Deepholm
- [ ] Foreman Dornik Coalbeard
- [ ] Ingra Silvertongue
- [ ] Thrain Emberhand
- [ ] Queen Aelwen Sil
- [ ] Sentinel Ilyndra
- [ ] Sentinel Thaeril
- [ ] Loremaster Faelan
- [ ] Healer Sylwen
- [ ] Bowmaster Ellandrie

**Millbrook expansion — 12**

- [ ] Edda Crowl
- [ ] Bran Tallow
- [ ] Brother Cale
- [ ] Marda Pell
- [ ] Iven Noll
- [ ] Rilla Noll
- [ ] Tom Ewer
- [ ] Mae Ewer
- [ ] Elsin Ward
- [ ] Pate Durn
- [ ] Sella Durn
- [ ] Nim Orrel

**Emberlode expansion — 10**

- [ ] Mara Quill
- [ ] Hobb Fen
- [ ] Dorrin Slate
- [ ] Tansy Pike
- [ ] Sister Anwen
- [ ] Jory Kest
- [ ] Elka Marrow
- [ ] Perrin Doss
- [ ] Nessa Vane
- [ ] Cal Wren

**Status for the other 72 source names:** at least one target profile or settlement placement exists. This is only a static-data match; actor-factory compatibility, spawn conditions, persistence, interaction routing and visual acceptance still need to be verified per character.

### Additional named actors to reconcile

The explicit 120-name roster does not include every named actor created by world/encounter builders. At minimum, reconcile **Kesh, Inquisitor Halden Voss, Corvin Ashgrave and Grondle** against the runtime actor registry and this roster. They are deliberately not included in the 120/48 arithmetic above. Grondle has dialogue logic in the target but lacks a static actor placement/profile in the audited records.

## 2. Dialogue coverage

### Source volume

The source scan found:

| Source module | Explicit call-sites | Literal lines passed directly |
|---|---:|---:|
| `campaign2Dialogue.js` | 376 | 325 |
| `wrenCharacterArc.js` | 10 | 8 |
| `wrenParentsInvestigation.js` | 9 | 2 |
| `wrenPriceOfSilence.js` | 14 | 12 |
| `mirabelDisguiseSelfDialogue.js` | 1 | 0 |
| `aelwenLivingAccord.js` | 10 | 4 |
| `aldenUncounted.js` | 12 | 9 |
| `aldricBrokenVigil.js` | 13 | 10 |
| `balrikLastHold.js` | 8 | 2 |
| `fennLivingBoundary.js` | 12 | 8 |
| `mirabelUnquietConcordance.js` | 27 | 23 |
| `reynaEmptyBlind.js` | 17 | 13 |
| **Total counted** | **509** | **416** |

This is a lower-bound source count. It does not include the optional-call syntax in `seraphineArc.js`, ambient chatter pools, all evergreen companion conversations, generated text or choice labels. A call-site is not necessarily a unique spoken line; the literal-line count excludes text assembled dynamically.

### Target volume and status

The target scan found approximately **209 direct static utterances**, comprising 125 direct string properties/assignments, 15 goblin conversation calls, 60 camp-companion profile lines and 9 campaign-memory openers.

The target also contains the nine later companion quest chapters and their authored text/resolution data. Their 144 text-bearing fields, and the 25 text strings in the Fenn prerequisite quest, are not counted in the 209 direct-utterance figure; they are data/narration fields and are already represented in both source and target.

**Current status: Partial.** Hollowmere opening dialogue, companion first-contact content, selected persistent-character dialogue, goblin/Skarnub content and several companion quest conversations are represented. There is not yet a line-by-line source-to-target dialogue map proving all original speakers, conditions, choices, follow-ups and effects are present. Do not interpret 209 versus 416 as a precise 50% completion result.

### Dialogue migration checklist

- [ ] Reconcile all 69 source `dialogueId` values from the NPC content index with target dialogue resources and interaction routes.
- [ ] Map the 376 `campaign2Dialogue.js` call-sites to target dialogue nodes, marking each branch and consequence.
- [ ] Map the 133 additional arc-module call-sites listed above.
- [ ] Add the optional `seraphineArc.js` dialogue and any ambient/evergreen pools to the next source census.
- [ ] For every migrated tree, verify speaker, exact authored text, choice labels, conditions, repeat behaviour, quest effects, relationship effects, inventory/reward effects and world-state consequences.
- [ ] Add regression coverage for consequential branches, not just dialogue text construction.

The existing [NPC and dialogue extraction index](campaign2_npc_dialogue_index.md) remains the source-name/dialogue-ID index; this audit records migration gaps and volume, not a replacement for that index.

## 3. Quest ID reconciliation

### Counts

- Source: **72 explicit quest IDs** — 49 from the Campaign 2 dialogue/index scan, nine companion quest chapters, eleven named character-arc quests and three Seraphine arc quests.
- Target: **29 explicit quest IDs** on `dev`.
- Exact ID overlap: **20**.
- Source IDs without an exact target ID: **52**.
- Target-only IDs: **9**.

An exact-ID difference is not proof that an entire storyline is absent. Some target quests may be adapted or renamed; those need an explicit source-to-target mapping and branch/consequence verification before being treated as migrated.

### Semantic review of the nine target-only IDs

I compared each target definition and its stated objective against the source quest definitions and the source's non-quest encounter/recruitment scripts. **None of the eight is a defensible one-to-one replacement for a source quest ID.** Two have meaningful overlap with source quest arcs, but only at sub-plot/encounter level.

| Target-only ID | Closest source material | Assessment | Migration decision |
|---|---|---|---|
| `abandoned_house_cleared` | `necromancer_hunt`; abandoned-house/undead encounter material | **Related location, different objective.** Source `necromancer_hunt` sends the player to the necromancer's crypt *past* the abandoned house after the disciple thread. The target quest clears three guardians *inside* the house. | Keep separate. Treat as an added encounter/clearance step that may lead into the source necromancer chain; it does not replace `necromancer_hunt`. |
| `hollowmere_ironbond_shakedown` | Source Hollowmere opening scene in `campaign2Dialogue.js`; `ironbond_pitch` | **Opening scene adapted into a journal quest.** The source has the same Dray/Garrick shakedown sequence, but no matching source quest ID. `ironbond_pitch` is a different task: persuading Wick Hallow to stock Ironbond goods. | Keep as a new target quest wrapper for a source event. Do not map it to `ironbond_pitch`. |
| `star_fort_companion` | `goblin_threat`, `goblin_mine_raid` | **No defensible equivalence found.** The source quests concern Skarn-tooth relations and a raid on Emberlode's gold mine; the target quest concerns resolving the Star Fort encounter in favour of the greenskins to recruit Snik. | Keep as a distinct target encounter/recruitment quest. Do not retire either source quest. |
| `aldric_rescue` | `aldricIndependentRecruitment.js`; Aldric's later `aldric_measure_of_oath` / `aldric_broken_vigil` arcs | **Source event adapted into a formal target quest.** The source explicitly has a tied captive who can be freed, recruited immediately or allowed to travel independently, but that rescue itself is not one of the 72 explicit source quest IDs. The later personal arcs are separate. | Keep as a new journal quest representing an existing source rescue/recruitment event. Do not map it to Aldric's later personal quests. |
| `reyna_dire_wolf_hunt` | `missing_child`, `farm_wolves` | **Partial story-beat overlap; not a confirmed merge.** Source `missing_child` is Hendra Wells searching for Tam Wells. Target uses Tessa and an abandoned shepherd's shelter. Both involve a child and wolves. Source `farm_wolves` is Old Mac's separate wolf-pack job, and that exact ID is already present in the target. | Mark as an adaptation candidate for the `missing_child` beat, with some overlap with the farm-wolf encounter. Do not count either source quest as fully ported until Tam/Hendra identity, encounter sequence, outcomes and the distinct Old Mac task are reconciled. |
| `mirabel_spider_ruin` | Source Mirabel recruitment/recovery event; `mirabel_unquiet_concordance` | **Recruitment prerequisite formalised as a target quest.** The source's later Concordance arc explicitly treats the book recovered from the spider ruin as its inciting object, but the recovery itself is not a separate source quest ID. | Keep as a new target quest wrapper for the source recruitment beat. It does not replace `mirabel_unquiet_concordance`. |
| `fenn_herb_gathering` | `silverleaf_tonic`; `fenn_living_boundary` | **Thematic similarity only.** `silverleaf_tonic` asks for herbs for Healer Sylwen in Sil'thandriel; target `fenn_herb_gathering` asks for three bundles for Fenn. `fenn_living_boundary` is a later, separate companion quest. | Keep separate. Do not map the herb errands merely because both request herbs. |
| `northwatch_siege` | `border_war`; source `northwatchSiegeSpawn.js` and Northwatch siege/war scripts | **Strong partial overlap, not full quest equivalence.** The source `border_war` sends the player to Northwatch's garrison and opens a broader war/mission progression. The source also has a distinct siege activation/spawn system. Target `northwatch_siege` records the defenders' successful resolution of a siege and unlocks Alden's recruitment. | Map as a candidate for the Northwatch siege encounter/sub-stage of `border_war`; retain the wider border-war objectives, missions, outcomes and follow-up until separately ported. |

**Net result:** zero source quest IDs can be safely removed from the 52-ID exact mismatch list on this evidence alone. Two target quests have plausible partial mappings (`reyna_dire_wolf_hunt` and `northwatch_siege`); three formalise source events that were not separate quest IDs (`hollowmere_ironbond_shakedown`, `aldric_rescue`, `mirabel_spider_ruin`); the remaining four are new or related-but-distinct content. The exact-ID gap therefore remains **52**, while the semantic review has narrowed where manual parity work is needed.

### Source IDs without an exact target ID — 52

**Campaign 2 dialogue/index IDs — 39**
- [ ] `border_war`
- [ ] `buried_road`
- [ ] `crimson_court`
- [ ] `deepholds_infestation`
- [ ] `deepholds_letter`
- [ ] `disciple_exposed`
- [ ] `druid_grove`
- [ ] `elven_gift`
- [ ] `eyes_on_border`
- [ ] `goblin_mine_raid`
- [ ] `goblin_spy_for_humans`
- [ ] `greenskin_spy`
- [ ] `guild_big_score`
- [ ] `guild_blood_price`
- [ ] `guild_favor`
- [ ] `guild_initiation`
- [ ] `guild_sunken_cache`
- [ ] `hidden_bodies`
- [ ] `ironbond_pitch`
- [ ] `kragmoor_runesmith_teach`
- [ ] `kragmoor_runesmith_trust`
- [ ] `millbrook_dragon`
- [ ] `missing_child`
- [ ] `necromancer_hunt`
- [ ] `necromancer_lichdom`
- [ ] `ore_road_reopened`
- [ ] `oskars_wager`
- [ ] `reddale_cut`
- [ ] `reddale_missing_watch`
- [ ] `silver_accord`
- [ ] `silverleaf_tonic`
- [ ] `spy_on_baron`
- [ ] `spy_on_guild`
- [ ] `stolen_delivery`
- [ ] `sylvan_bowmaster_teach`
- [ ] `tavern_brawl`
- [ ] `unicorn_tracking`
- [ ] `wizard_vendetta`

**Additional named character arcs — 10**

- [ ] `aelwen_living_accord`
- [ ] `alden_uncounted`
- [ ] `aldric_broken_vigil`
- [ ] `aldric_measure_of_oath`
- [ ] `balrik_last_hold`
- [ ] `mirabel_unquiet_concordance`
- [ ] `reyna_empty_blind`
- [ ] `wren_parents`
- [ ] `wren_price_of_silence`
- [ ] `wren_crown_quiet_hand`

**Seraphine arc — 3**

- [ ] `seraphine_crown_and_company`
- [ ] `seraphine_border_decree`
- [ ] `seraphine_what_crown_may_hide`

### Exact ID matches already present — 20

`a_stone_for_nella`, `baron_tribute`, `aldenreach_message`, `elder_locket`, `corvane_watch`, `dwarven_toll`, `farm_wolves`, `toll_ogre`, `goblin_threat`, `orc_stronghold_trust`, `aldric_weight_of_command`, `mirabel_borrowed_voice`, `mirabel_place_for_dangerous_books`, `fenn_fire_in_understory`, `fenn_groves_answer`, `reyna_shared_watch`, `reyna_rangers_writ`, `alden_missing_sixth`, `alden_rule_for_living`, `ironbond_missing_courier`.

These are exact-ID matches only. Their runtime triggers, all choices, completion conditions, rewards and consequences still need to pass their own parity checks.

### Target-only quest IDs — 9

`abandoned_house_cleared`, `hollowmere_ironbond_shakedown`, `star_fort_companion`, `aldric_rescue`, `reyna_dire_wolf_hunt`, `mirabel_spider_ruin`, `fenn_herb_gathering`, `northwatch_siege`, `fenn_living_boundary`.

Potential semantic relationships to investigate include `reyna_dire_wolf_hunt` versus source `missing_child` / `farm_wolves`, and `northwatch_siege` versus `border_war`. These are **unverified mapping candidates**, not accepted equivalences.

### Quest IDs with partial content implementation

**The Missing Courier — `ironbond_missing_courier`**

- [~] Added `IronbondMissingCourierContent` with Dray Coltayne's source offer, accept/decline choices, journal registration, and the source's +10 Ironbond reputation / +10 knowledge on acceptance.
- [~] Added headless regression coverage for decline, acceptance, one-time faction reward and journal save/restore.
- [ ] Not yet runtime-wired: Dray does not currently have a persistent streamed dialogue route in the target scene, and the source itself contains no courier recovery encounter or completion branch. Do not count this as a playable quest.

**The Toll-Taker — `toll_ogre`**

- [~] Added a standalone quest content resource for Petra Hollis's offer, active/defeated/completed dialogue states, the ogre-defeated objective, and the source reward (+30 gold, +120 experience, +10 Silverhart reputation / knowledge).
- [~] Added headless regression coverage for acceptance, objective gating, one-time rewards and journal save/restore.
- [ ] Still requires a live ogre actor, Petra's active world placement/interaction route, and save/load integration before it is a playable port. Do not count this as fully migrated.
### Small quest ports completed

**The Baron's Tribute**

- [x] Added `BaronTributeContent` for the source accept/active/turn-in/completed dialogue states, red-gem consumption, +20 gold, +20 Baron reputation / +20 knowledge, and +10 Silverhart standing / +15 knowledge.
- [x] Added headless regression coverage for acceptance, missing-gem retry, turn-in, all rewards, item consumption and duplicate-reward prevention.
- [x] Connected the `reddale_baron` streamed actor dialogue route and `baron_tribute_*` choice handling in `HollowTankard`. The Baron's separate espionage/double-cross branches remain unported.

**A Stone for Nella**

- [x] Added `ReddaleInnkeeperContent` with the source quest ID, source dialogue gate, accept/active/turn-in/completed states, blue-gem consumption, +20 gold and +20 Nella reputation/knowledge.
- [x] Added headless regression coverage for the quest flow, missing-gem retry, journal-read gate, rumour response, item consumption and duplicate-reward prevention.
- [x] Connected the `reddale_innkeeper` streamed actor dialogue route and `nella_*` choice handling in `HollowTankard`.
- [x] Wire the source `abandonedHouseJournalRead` world flag into the optional alternate greeting. Reading the abandoned-house journal now records the flag in the Hollow Tankard save snapshot and restores it on load; Nella's streamed greeting consumes the saved flag.

**Coin for the Deepholds**

- [x] Added `DwarvenAmbassadorContent` with the source toll dialogue, 15-gold payment, quest completion, +60 experience and +10 standing / +15 knowledge for Brokk and the dwarven kingdom.
- [x] Added headless regression coverage for acceptance, insufficient funds, exact payment, rewards, reputation/knowledge and duplicate-payment prevention.
- [x] Confirmed Brokk is an authored Silverhart settlement NPC (`ambassador_brokk_stonehammer`, dialogue ID `dwarven_ambassador`) and connected his streamed greeting, toll choices, quest registration and completion feedback to the live interaction dispatcher. Added runtime-wiring regression coverage.

**Eyes on the Border**

- [x] Added `CorvaneAmbassadorContent` with source start/wait/report/completed dialogue, gated on the `goblin_threat` quest leaving its active state.
- [x] Added headless regression coverage for the active-threat gate, integration with the existing goblin resolution service, +15 gold, +60 experience, +10 standing / +15 knowledge and duplicate-claim prevention.
- [x] Confirmed Toren is an authored Silverhart settlement NPC (`ambassador_toren_aldwyn`, dialogue ID `corvane_ambassador`) and connected his streamed greeting, report choices, quest registration and completion feedback to the live interaction dispatcher. Added runtime-wiring regression coverage.

**A Missing Locket**

- [x] Added `ElderMartaContent` with the source accept/active/turn-in flow and the source's pre-found-item shortcut.
- [x] Added headless regression coverage for both normal acceptance and finding the locket before speaking to Marta, including item consumption, +20 gold, +100 experience, +15 reputation / +20 knowledge and duplicate-reward prevention.
- [x] Confirmed Elder Marta's existing Ara profile/model and authored Hollowmere placement at `Vector2i(0, -9)`; added explicit regression assertions for both.
- [x] Connected her greeting and choice handling to the live Hollow Tankard NPC interaction dispatcher and registered the quest with the campaign journal at startup.
- [x] Added a visible Tarnished Locket pickup at the source-authored chapel hex `(-14, 0)`, reachable with the normal F-key interaction. The pickup grants one stable `elder_locket` inventory instance, is idempotent, and persists its collected flag through Hollow Tankard save/restore (also recognising an already-carried locket in older saves). Added regression coverage for item grant, duplicate prevention, authored position and save-state wiring.

**A Quiet Word**

- [x] Added `AldenreachMessageContent` for the source's accept, waiting, delivered-to-elder and report-back states.
- [x] Connected Cassia's existing streamed actor dialogue route and Elder Marta's existing local interaction route; delivery is recorded when the player speaks to Marta.
- [x] Added regression coverage for the two-stage delivery, rewards (+15 gold, +60 experience, +10 Cassia reputation / +15 knowledge) and duplicate-claim prevention.
- [x] Applied source-authored Ara appearance profiles directly to the Silverhart diplomatic-quarter envoys: Cassia Wren, Elarion, Brokk Stonehammer and Toren Aldwyn. The existing settlement actor factory consumes their eye/hair colours, hairstyles, skin tones and body proportions when creating streamed Ara actors; regression coverage checks the four profiles and Cassia's dialogue identity. This uses the shared Ara base bodies, not bespoke generated GLBs.

## 4. Work order — smallest verifiable steps first

1. [ ] **NPC reconciliation:** resolve the 48 missing active profile/placement records, starting with named NPCs already referenced by implemented quests or dialogue. Do not generate a model before confirming the character is meant to be a persistent/spawned actor.
2. [x] **Quest semantic mapping:** reviewed all eight target-only IDs against source quest and event scripts. No one-to-one source quest equivalence is safe to accept yet; two partial overlap candidates are documented above; the exact-ID gap is now 53 after six small quest-content ports.
3. [ ] **Quest branch parity:** for each source quest, compare start gates, objectives, decision branches, completion, failure/alternate outcomes, rewards and world-state consequences.
4. [ ] **Dialogue tree mapping:** reconcile the 69 dialogue IDs and then map each source call-site/branch to target nodes and typed effects.
5. [ ] **Runtime integration:** verify persistence, actor spawning, interaction routing, schedules, companion reactivity and save/load. Static data alone does not close a row.
6. [ ] **Regression coverage:** add source-derived tests for each consequential branch and replay/save-load/idempotency behaviour.

## 5. Related records and source references

- [Campaign source-port status](CAMPAIGN_SOURCE_PORT_STATUS.md) — current system-level migration status and ownership boundaries.
- [NPC and dialogue extraction index](campaign2_npc_dialogue_index.md) — source display-name and dialogue-ID inventory.
- [Chief Skarnub dialogue and trust port](skarnub_campaign_dialogue_port.md) — detailed goblin chief content and remaining runtime wiring.
- [Campaign 2 map gap audit](campaign2_gap_audit.md) — spatial work only; do not move dialogue/quest gaps into it.
- [Campaign 2 source inventory](campaign2_source_inventory.md) — source builder and content extraction context.

Pinned source files: [campaign2Content.js](https://github.com/ScottENOC/Hex-crpg/blob/4de96f16889d43cae91e03832c8eb1c1b4b00e42/campaign2Content.js), [millbrookContent.js](https://github.com/ScottENOC/Hex-crpg/blob/4de96f16889d43cae91e03832c8eb1c1b4b00e42/millbrookContent.js), [emberlodeExpansion.js](https://github.com/ScottENOC/Hex-crpg/blob/4de96f16889d43cae91e03832c8eb1c1b4b00e42/emberlodeExpansion.js), [campaign2Dialogue.js](https://github.com/ScottENOC/Hex-crpg/blob/4de96f16889d43cae91e03832c8eb1c1b4b00e42/campaign2Dialogue.js).

---

**Audit limitation:** this is a source-to-target static inventory at the pinned commits above. It does not claim that every source function, runtime actor, ambient conversation, generated dialogue branch or dynamically created quest has been exhaustively enumerated. As migrations land, update the individual checklist items with target file/test evidence and retain unresolved semantic mappings as unresolved.
