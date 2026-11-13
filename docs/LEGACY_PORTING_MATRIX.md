# Silverhart Saga 3D — legacy porting matrix

This matrix tracks the port from the original `ScottENOC/Hex-crpg` into Godot. The original game is the behavioural reference. Do not mark a mechanic accepted until it has been compared with the original and tested in the 3D project.

Status meanings:
- **Not started** — no verified implementation.
- **In progress** — implementation exists but is incomplete.
- **Implemented / untested** — code exists; gameplay acceptance is outstanding.
- **Tested / accepted** — regression and in-game checks passed.

## Foundation

| System | Current status | Evidence / next action |
|---|---|---|
| Godot 4.7.2 project and 3D Hollowmere prototype | In progress | README describes the Hollow Tankard prototype and PC-first target. |
| Axial hex grid and six-direction movement | Implemented / untested | README reports keyboard movement and weighted click pathfinding; verify in current `dev`. |
| Terrain movement costs | In progress | Terrain multipliers and selected discounts exist; compare all legacy movement modifiers. |
| Elevation, slopes and climbing | In progress | Dedicated terrain prototype exists; validate gameplay rules and transitions. |
| Time Points and world clock | In progress | README reports TP movement, fixed-step clock and calendar; verify persistence and edge cases. |
| Save/load and world persistence | In progress | Audit current implementation and test round trips. |
| Character state and derived attributes | In progress | Combat attributes and defensive state are introduced by the PR #36 combat foundation; full legacy attribute parity remains to be audited. |

## RPG mechanics

| System | Current status | Next action |
|---|---|---|
| Turn order / initiative | In progress | Existing initiative scheduler; validate full round lifecycle. |
| Melee combat | In progress | PR #36 adds deterministic attack resolution, hit chance, damage, reduction, TP validation and defeat state; complete encounter loop. |
| Facing and flanking | Not started | `CharacterState` stores facing, but combat rules do not yet validate facing/LOS or flanking parity. Recover exact legacy rules. |
| Defensive and movement reactions | In progress | `WorldSimulation` already supports pending reactions, parry/protector-parry, shield-other, sidestep and spear intercept/halt flows; compare coverage and costs against legacy rules. |
| Ranged combat, line of sight and cover | Not started | Audit legacy rules and implement legal targeting. |
| Tactical enemy AI | Not started | Implement simulation-owned decisions and tests. |
| Status effects and conditions | Not started | Inventory original effects, duration, stacking and removal rules. |
| Skills and skill checks | Not started | Port the original catalogue and resolution rules. |
| Character experience and levelling | Not started | Recover progression curve, attributes and unlocks. |
| Magic and spellcasting | Not started | Inventory spells, costs, targets, effects and progression from legacy source. |
| Inventory, loot and equipment | In progress | `CharacterState` persists inventory/equipment instance data and `item_catalog.gd` exists; audit full item catalogue, capacity, loot and equip parity. |
| Crafting and gathering | In progress | `WildernessResourceSystem` and harvest actions exist; recipes, tools, crafting stations and full resource economy remain to port. |
| Economy and trading | Not started | Port merchant inventories, prices, buying/selling and persistence. |

## Campaign and world

| System | Current status | Next action |
|---|---|---|
| Campaign start and Hollowmere | In progress | Existing opening scene, authored NPCs, ambient chatter and a first encounter exist; connect quest and save progression end-to-end. |
| Regional map and location connections | In progress | `MainCampaignWorldMapData` currently contains six visible POIs. Original Campaign 2 geography is source-verified below; expand from real local hex coordinates, not guessed map positions. |
| Travel, encounters and region transitions | Not started | Build data-driven region records and travel simulation. |
| Dialogue and NPC interactions | In progress | Port original dialogue and choices; preserve consequences. |
| Quests and objectives | Not started | Inventory original quests, prerequisites, rewards and state transitions. |
| NPC schedules and idle chatter | In progress | Build on the previously scoped tavern routines; use local detail and aggregated distant simulation. |
| Factions, reputation and relationships | Not started | Recover faction and relationship rules from legacy source. |
| Seasons, weather and environment | Not started | Connect visual seasons to calendar and resource/world simulation. |

## Arena and audio

| System | Current status | Next action |
|---|---|---|
| Campaign / Arena mode selector | In progress | Original PR #5 remains an unmerged draft based on obsolete `main`; a clean port is open as PR #67 against current `dev`. |
| Shared combat and character systems | In progress | Arena must use the same simulation, character, inventory and progression as campaign. |
| Original arena gameplay | Not started | PR #5 explicitly describes Arena as a placeholder; port opponents, bouts, progression and rewards. |
| AudioManager and audio buses | In progress | A clean port is open as PR #67 against `dev`; validation and playback are pending. |
| Original music and voice assets | In progress | PR #67 adds the pinned importer and asset inventory. Generated Ogg files are not yet in the Pages build, so browser playback is not deployed. |
| Mode-specific audio routing | In progress | PR #67 adds mode gates; validate through Godot tests and actual playback before acceptance. |

## Character presentation and runtime

| System | Current status | Next action |
|---|---|---|
| First-run character creator | In progress | PR #29 stores a profile, but its description says the player is still a capsule and most appearance choices are not rendered. |
| Ara runtime assets | In progress | PR #36 defines a versioned runtime package and a separate integration test; run it against a newly generated package. |
| Modular clothing and equipment appearance | In progress | Connect visual slots to actual gameplay equipment state. |
| Animation and combat state integration | Not started | Connect simulation events to animation without putting rules in presentation nodes. |

## Equipment and clothing visual migration audit (2026-11-10)

This is a three-layer audit of the original Hex-crpg item art, Silverhart 3D model assets (including feature-branch generation work), and runtime equip/stat integration.

### Acceptance rule

An item is **Complete** only when all three are verified:
1. The original 2D inventory/equipment image is available.
2. A usable 3D model is present in the project/runtime asset package (not merely a generator, workflow, or temporary Actions artifact).
3. The game can equip it, display the correct 3D model/garment, and apply its relevant stats/effects.

**Audit result: no held weapon, shield, armour piece, or clothing item is yet verified Complete against all three requirements.** The underlying item catalogue and inventory/stat foundations are much further along than the 3D visual integration.

### Implemented foundations

| Layer | Status | Evidence / boundary |
|---|---|---|
| Original item definitions | Implemented | PR #47 migrated the 63 definitions from Hex-crpg/equipment.js. Current data/items/item_definitions.json contains 76 entries after adding 13 clothing entries. |
| 2D inventory icon atlas | Implemented | PR #47 migrated the original SVG icon artwork into art/ui/item_icon_atlas.svg (57 atlas cells). The migration uses simple fallback shapes for missing axe, shield and torch icon shapes. Clothing entries currently have no icon_index in item_definitions.json. |
| Inventory/equip state | Implemented | PR #46 added persistent item instances, equip/unequip and the Character / Inventory panel. |
| Weapon and armour combat stats | Implemented for supported slots | CombatRules reads equipped weapon damage, armour reduction and explicitly typed shield reduction. Armour weight class feeds movement cost. |
| Clothing visual toggling | Implemented / untested | AraCharacterActor has inventory-driven garment surface visibility and complete-token matching. PR #84 merged the matching fix, but its description explicitly says a Godot runtime/visual test remains outstanding. |
| Separate weapon prop generation | Implemented as pipeline; runtime assets not confirmed | PR #75 merged Ara weapon-prop generation for sword, knife, axe, spear, bow, mace and club. The PR changed files contain generators/workflows, not the seven generated prop GLBs. |
| Shield and helmet blockout generation | Implemented as pipeline; not production-ready | PR #75 adds round/kite/heater shield and nasal helm/kettle hat/great helm/bascinet blockout generation. These are first-pass geometry requiring fit review. No props directory is present under art/characters/ara_runtime on dev. |
| Unified reusable garment library | In progress on feature branch | Draft PR #87 adds a local Blender extraction/retargeting pipeline. It requires a local Blender build and Godot visual inspection; ara_person_garments.glb is not yet verified as a built runtime asset. |

### Held weapons and tools

| Items | 2D inventory art | 3D state | Runtime state / missing work |
|---|---|---|---|
| Dagger, sword, axe, club, spear, bow | Atlas art exists; several also have dedicated original 2D art files | Ara generator supports knife, sword, axe, club, spear and bow; generated runtime GLBs are not present in dev's tracked props directory | Equip and damage metadata work. Actor mappings exist, but the actual prop files must be built/installed and hand attachment visually checked. |
| Sword of Arrow Deflection, Starforged Blade | Atlas icon | Reuse sword prop | Equip/stat metadata exists; special skill/material treatment and visible sword prop remain to validate. |
| Featherweight Dagger | Atlas icon | Reuses knife prop | Equip/stat metadata exists; actual prop/runtime attachment remains to validate. |
| Stormcaller Spear | Atlas icon | Reuses spear prop | Equip/stat metadata exists; special glow/material and actual attachment remain to validate. |
| Nightowl Bow, Hunting Bow | Atlas icons | Reuse bow prop | Equip/stat metadata exists; special effects/material and actual attachment remain to validate. |
| Ashenwood Club | Atlas icon | Reuses club prop | Equip/stat metadata exists; special material and actual attachment remain to validate. |
| Torch, Pickaxe, Chair, Bottle | Atlas art | No corresponding Ara prop generator/mapping | Item definitions and basic equip/damage/tool metadata exist; visible held props and any item-specific runtime behaviour need implementing/testing. |
| Battering ram, giant club (source art) | Original 2D files exist | No matching player-held 3D implementation identified | These are art assets, not entries in the current 76-item catalogue; determine whether they are legacy NPC/siege visuals or should become item definitions before porting. |

### Shields

| Item | 2D art | 3D state | Runtime state / missing work |
|---|---|---|---|
| Wooden Shield | Original round shield art and atlas icon | Round shield blockout generator exists; generated GLB is not in dev runtime props | Offhand equip and reduction work. Actor maps it to round_shield; install model, fit left-hand socket and visually test. |
| Bulwark of the Steadfast | Generic shield atlas icon | Kite shield blockout generator exists; generated GLB is not in dev runtime props | Offhand equip and reduction work. Actor maps it to kite_shield; add item-specific heraldry/material and validate. |
| Heater shield | No matching current catalogue item | Blockout generator exists | Future visual variant only; do not count as a ported item yet. |

PR #76 adds material profiles and a procedural shield-heraldry shader, but is a draft and requires rebuilding/reviewing the shield exports. It is not a completed shield implementation.

### Body armour and helmets

| Items | 2D art | 3D state | Runtime state / missing work |
|---|---|---|---|
| Light Armor, Medium Armor, Heavy Armor | Original light/medium/heavy body armour images and atlas armour icon | No distinct fitted 3D armour tiers verified. Current actor maps all three to one generic "leather armor" garment surface. | Equipped armour reduction and weight-class movement effects work. Need distinct fitted models/surfaces, fit review and runtime visual tests. |
| Reinforced Leather Armor | Atlas icon | Uses the same generic leather-armour surface mapping | Equip and reduction work; no unique 3D model/material yet. |
| Moonlit Chain, Dragonscale Mail | Atlas icons | No dedicated model or actor visual mapping | Armour reduction metadata exists; distinctive appearance, aura/effect integration and runtime visual support remain. |
| Nasal Helm | Original 2D front/back art and atlas helmet icon | Nasal helm blockout generator exists; no fitted runtime GLB verified | Helmet item/equip metadata and actor mapping exist, but equipped helmet item reduction is not currently read directly by CombatRules. Model, fit, and stat integration remain. |
| Huntsman's Helm | Atlas icon | Actor maps it to the same nasal_helm prop | Needs its own visual identity and validation; helmet reduction from the item instance is not yet proven to affect combat. |
| Light, Medium, Heavy Barding | Original mount-barding SVG images | No 3D barding assets identified | Original game treats these as mount equipment, not player armour. Mount equipment visuals and the corresponding 3D mount/equip flow remain unported. |

### Clothing and footwear already represented in the 3D character system

These 13 item IDs are in item_definitions.json and have garment_visual mappings in AraCharacterActor. The current modular Ara GLB provides a shared surface-based clothing asset; these are not 13 individually exported GLBs.

| Item ID | Runtime garment token | Current status |
|---|---|---|
| bra | bra | Partial — equip/visibility mapping; no inventory icon_index; exact variant coverage and in-game fit need testing. |
| briefs | briefs | Partial — equip/visibility mapping; no inventory icon_index; exact variant coverage and in-game fit need testing. |
| long_tunic | long_tunic | Partial — mapped; source-specific 2D design correspondence and fit need testing. |
| trousers | trousers | Partial — mapped; fit and visibility need testing. |
| tunic | tunic | Partial — mapped; fit and visibility need testing. |
| wrapper_long | wrapper_long | Partial — mapped; fit and visibility need testing. |
| uniform_shirt | uniform_shirt | Partial — mapped; fit and visibility need testing. |
| fatigue_pants | fatigue_pants | Partial — mapped; fit and visibility need testing. |
| wrapper_knee | wrapper_knee | Partial — mapped; fit and visibility need testing. |
| tattered_shirt | tattered_shirt | Partial — mapped; fit and visibility need testing. |
| fatigue_shirt | fatigue_shirt | Partial — mapped; fit and visibility need testing. |
| sandals | sandals | Partial — mapped; footwear fit and visibility need testing. |
| combat_boots | combat_boots | Partial — mapped; footwear fit and visibility need testing. |

These clothes are cosmetic in the original item catalogue and do not grant armour reduction. The 3D system must preserve that separation from body armour.

### Original 2D clothing designs still lacking an exact, verified 3D/game item counterpart

The original images/equipment/clothing directory contains a much wider range of character-layer art than the 13 current clothing item definitions. The current 3D garment tokens should not be treated as proof that every original cut/design has been ported.

- **Bras/tops:** plunge bra, strapless bra, alternate halter bra, female bra variants, collared shirt, lace dress shirt, mesh turtleneck, plunge shirt, tie-tank, blouse, dress top, masculine laced top and female shirt top.
- **Lower underwear:** female briefs and g-string briefs as distinct designs.
- **Trousers/legwear:** monk trousers, monk wrap, baggy wraps, breeches, fitted shorts, hose, lattice pants and shorts.
- **Other garments:** full cloak, lace corset, skirt and fishnet tights.
- **Footwear:** original front/back/side boots images need a verified matching fitted 3D garment and runtime slot, rather than assuming Ara combat boots are an exact match.

Some lace/fishnet and backless slit-dress work exists in the Wren/Ara Workshop history and feature branches. These are not all distinct campaign item definitions or proven runtime campaign equipment. In particular, the halter lace and fishnet options must be reconciled with the canonical item catalogue and garment library before counting them as ported items.

### Other equipment catalogue gaps

The 2D equipment catalogue also contains accessories and mount equipment that do not have a verified 3D character attachment implementation:

- Accessories: Glowing Ring, Orcbane Pendant, Wolfward Charm, Locket of the Restless Dead, Silvertongue Ring, Traveler's Cloakpin, Shadowcloak and Deep Crystal Pendant.
- Bag of Holding: inventory/carry-capacity item rather than a worn visual slot.
- Mount barding: light, medium and heavy variants.

Their item definitions/icons are not equivalent to 3D models or equipped visual behaviour.

### Next work to close the gap

1. Build and install the seven Ara weapon props locally; validate each grip orientation on both Ara body variants.
2. Build and install the three shield and four helmet blockouts locally; fit and visually inspect them on both Ara body variants.
3. Fix helmet equipment stat handling so an equipped helmet's reduction is included in CombatRules, then add regression tests.
4. Build the unified Ara garment library locally from PR #87, run its Godot assembly test, and inspect every supported clothing/footwear surface in-game.
5. Add inventory icon treatment for the 13 clothing entries and decide which original 2D clothing designs become separate catalogue items.
6. Add distinct body-armour meshes/materials, then migrate the remaining original clothing cuts, accessories and mount barding as separate scoped work.
7. Do not mark any item Complete until its icon, installed 3D asset, equip/unequip behaviour, visual fit and relevant stats have all been verified in the running game.

## Canonical Campaign 2 geography (verified against Hex-crpg)

The source has two distinct layers which should not be conflated:

- `regions.js` defines the **security/prosperity hierarchy**: Hollowmere and Emberlode (villages) are under Aldervale (barony), which is under The Silverhart Kingdom (kingdom).
- `campaign2World.js` defines the **actual local world and POIs**. Hollowmere is the crossroads origin; the north road reaches Millbrook and then Silverhart; the west road reaches Emberlode; the east road reaches Reddale, then the Skarn-tooth goblin camp, Northwatch Fort and Ridgehold Fort at the human/orc border; the orc stronghold is Skarnak's Hold. Old Mac's Farmstead lies south of Hollowmere. Kragmoor is the Deepholds' mountain city-and-mine in the north-east. The map also includes Sil'thandriel, the elven capital.
- Additional exploration/quest sites are built in the same source: the Dragon Lair, Lich Barrow, Chapterhouse of the Silver Flame, Emberwood Grove, Thieves' Cove caves, Vampire Grave and Druid Grove. Some are deliberately unmarked.

The current Godot strategic map's six entries (Silverhart, Millbrook, Emberlode, Hollowmere, Reddale and Old Mac's Farmstead) are only the initial settlement subset. They are not the complete world. The next map port should add the missing visible POIs and represent hidden sites as discoverable content, while preserving the source road relationships and faction borders.

## Engineering rules

1. Simulation state owns rules and legal actions; 3D nodes only present state.
2. Campaign and Arena share character, combat, inventory, progression and save systems.
3. Preserve original behaviour where source content exists; document intentional deviations.
4. Use detailed simulation for nearby/relevant actors and aggregated updates for distant regions.
5. Generated Ara GLBs are pipeline artifacts, not prerequisites for ordinary Godot gameplay validation. Run Ara integration tests only when a versioned runtime package is supplied.
6. Feature work is developed on isolated branches, validated with Godot 4.7.2, then integrated into `dev`.
7. Update this matrix as work lands; do not promote an item to tested/accepted based on CI alone when in-game behaviour still needs review.

## Immediate sequence

1. Complete the clean PR #67 mode/audio foundation and verify asset delivery to the Pages build.
2. Port one end-to-end Arena bout (lobby → opponent → encounter → result/reward) using the existing shared combat simulation.
3. Audit and complete combat parity: facing/LOS/ranged, action validation, AI and encounter lifecycle.
4. Expand the campaign strategic map from the verified Campaign 2 geography above; add data-driven links and hidden-site discovery.
5. Continue inventory/progression/quests/social systems against the original source.
