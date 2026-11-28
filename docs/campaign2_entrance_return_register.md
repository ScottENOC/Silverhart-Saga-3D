# Campaign 2 entrance and return-point register

**Source:** `ScottENOC/Hex-crpg`, principally `campaign2World.js` and its floor/secret-passage builders  
**Target:** `ScottENOC/Silverhart-Saga-3D`, `dev` snapshot used for this register  
**Scope:** spatial entrance coordinates, floor transitions, reciprocal return routes, hidden passage locations, and the physical doorway/stair representation. Quest requirements, discovery checks, dialogue and travel-menu UX are noted only where they determine whether a spatial connection can be used; their wider mechanics remain in the campaign/mechanics audits.

This is a source-to-target register for spatial entry/return contracts. Coordinates in the manifest are local axial `(q,r)`; door/stair positions are world axial positions as recorded by the floor manifest. Engine visual acceptance is general QA and is not counted as missing map content.

## Snapshot totals

| Measure | Target snapshot |
|---|---:|
| Location records | 71 |
| Floor records | 89 |
| Tile-object records | 199 |
| Door / secret-passage objects | 77 |
| Explicit stair tile objects | 25 |
| Floor-transition records | 32 |
| Quest-gated transition records | 1 |
| Secret objects (secret door or passage) | 3 |

The explicit stair-object count is not the expected final rendered stair count: `Campaign2MultiStoryFloorMapBuilder` synthesises a stair object from an available transition when the source floor has no explicit stair tile object at that coordinate. Therefore, a transition with no literal stair object in JSON is not automatically a missing stair.

## Multi-floor transition stacks

| Location | Floors | Transition records | Spatial interpretation | Register status |
|---|---|---:|---|---|
| `kragmoor` | 0, -1, -2, -3, -4, -5 | 10 | Five reciprocal shafts; -4 to -5 is gated by `deepholds_infestation`. The Sunken Deep return stair is present on -5. | **Data present; verify in runtime** |
| `emberlode_mine` | 0, -1, -2 | 4 | Surface ↔ Working Vein ↔ Old Seam; two reciprocal shafts. | **Data present; verify in runtime** |
| `silthandriel` | 0, 1, 2 | 4 | Surface ↔ Lower Canopy ↔ Archive; two reciprocal shafts. Rope-bridge/canopy routes are spatial corridors, not floor transitions. | **Data present; verify in runtime** |
| `silverhart_palace` | 0, 1 | 2 | Grand Hall ↔ Gallery; one reciprocal shaft. | **Data present; verify in runtime** |
| `silverhart_palace_barracks` | 0, 1 | 2 | Barracks ↔ loft; one reciprocal shaft. | **Data present; verify in runtime** |
| `silverhart_palace_wizard_tower` | 0, 1, 2 | 4 | Study ↔ observatory levels; two reciprocal shafts. | **Data present; verify in runtime** |
| `thieves_cove` | 0, -1, -2, -9 | 6 | Surface ↔ den ↔ vault, plus den ↔ one-cell wilderness tunnel junction. Three reciprocal shafts. | **Data present; verify in runtime** |

The manifest contains **nine location records with multiple floors**: the seven ordinary stacks above plus the separate palace and city tunnel stubs (each with surface floor 0 and underground floor -9). The 32 ordinary transition records in the seven stacks describe 16 bidirectional shafts. PR #415 adds automated checks for reciprocal same-coordinate links, stair presentation at available shafts and the 32 directed transition count. The builder/runtime must still be manually exercised in-game for floor visibility, player placement, elevation and return. The one quest-gated link must remain unavailable until the named quest completes; its reciprocal return must remain usable from the lower floor. The two tunnel stubs are linked through the separate three-node network, not ordinary floor-transition records.

## Hidden passages and the tunnel network

| Source feature | Target spatial record | What is represented | Remaining work |
|---|---|---|---|
| Palace council-chamber secret passage | `silverhart_palace_council_chamber`, `palace_secret_passage` at (-9, -492); separate `silverhart_palace_tunnel` floor -9 junction at the same coordinate | Surface discovery object and underground junction stub exist in separate location records. | **Implemented in PR #408.** A successful 35% search reveals the surface passage as a cross-location tunnel entrance; `enter_tunnel_node` transfers to the matching floor -9 stub and `return_to_surface_passage` returns through the same revealed surface tile. Automated runtime coverage exists; the city round-trip regression is being added in PR #420. Manual visual acceptance remains outstanding. |
| General-goods secret passage | `silverhart_general_goods`, `city_secret_passage` at (-20, -489); separate `silverhart_city_tunnel` floor -9 junction at the same coordinate | Surface discovery object and underground junction stub exist in separate location records. | **Implemented in PR #408.** A successful 35% search reveals the surface passage as a cross-location tunnel entrance; `enter_tunnel_node` transfers to the matching floor -9 stub and `return_to_surface_passage` returns through the same revealed surface tile. Automated runtime coverage exists; the city round-trip regression is being added in PR #420. Manual visual acceptance remains outstanding. |
| Wilderness tunnel endpoint | `thieves_cove` floor -9, `wilderness_tunnel_junction` at (-274, 40) | Junction node is present and reached from the den by a registered transition. | **Implemented in PR #408.** `Campaign2TunnelNetwork.destinations_from()` exposes the other two nodes, and `travel_to_tunnel_node()` transfers the player between the three separate floor -9 stubs. The wilderness surface cave stair reaches floor -1 and then -9; the tunnel return to the surface uses the ordinary reciprocal cave stairs. Runtime regression coverage is being extended in PR #420. |
| Guild hidden vault | `silverhart_thieves_guild`, `guild_hidden_vault_door` at (19, -426), type `secret_door`; hidden room references that ID | Target secret-door object and hidden-room dependency are registered. Runtime supports discovering a `secret_door` within a multi-story location. | The Guild location is a single-floor site, so confirm the generic secret-door interaction is wired for this location too; otherwise the data is present but not playable. |

**Source behaviour and target adaptation:** `revealSingleTunnelEntrance` / `revealTunnelEntrances` expose the concealed palace and city passages after discovery. The target represents these as cross-location tunnel entrances rather than ordinary same-location stairs, then transfers the player to the matching floor -9 stub. `openTunnelJunction` is represented by the two alternative destinations returned at each of the three separate stubs. Do not replace this with an invented long tunnel.

## Single-floor entries and interior doorways

There are **62 single-floor location records**. Their interior door coordinates and IDs are listed in the full register below. A door object is evidence of a placed aperture, not proof that the exterior approach, interaction, return-to-world action or collision opening is implemented. PR #465 introduced the generic `exterior_entry` contract in the shared location registry/runtime and wired it to the F-key interaction path. Nineteen single-floor sites were registered through PRs #466, #472, #483, #486 and #493: six Hollowmere entries, two single-floor Emberlode entries (the mine is multi-floor), three Reddale entries and eight Silverhart house entries. PR #487 separately registered the multi-floor Wizard's Tower. This bulk pass adds 42 more single-floor entries in two source-traced batches: 19 use explicit painted approaches/road spurs, and 23 use the immediately adjacent exterior hex on the outward side of their source-defined floor-zero door. That brings the total to **61 of 62** single-floor locations. The sole unregistered single-floor site is the tavern, whose opening-sequence door is intentionally locked. The Wizard's Tower is additionally registered as the first multi-floor site with a source-grounded exterior entry. Do not infer approach coordinates from door orientation alone. The tavern remains intentionally excluded while its opening-sequence door is locked. The Guild tunnel network remains a specialised cross-location route.

- **Barrow of Corvin Ashgrave** and **Vessel-Seeker's Crypt** are single-floor multi-room layouts. Their several door objects are internal room/ossuary/ritual openings as well as the exterior entry; do not count each internal doorway as a separate world transition.
- **Northwatch Keep** and **Ridgehold Keep** each have a keep entry door. Their exterior fort gates and approaches are owned by the regional fort/map presentation, not this interior-floor manifest.
- **Silverhart Palace — Grand Hall** includes a front door, a rear Queen's Chambers door and a gallery stair. The rear door's destination/return contract must be reconciled with the Queen's Chambers spatial record; the door's presence alone does not prove a connected destination.
- **Sil'thandriel** is an open arrival clearing/canopy site. Its surface stair is the intended vertical entry; do not invent a conventional enclosed front door.

## Full location register

`Anchor` is the site's world/local axial anchor. `Doors / passages` lists physical door-like tile objects with their floor and coordinates. `Stairs` lists literal stair objects in the manifest; generated stairs from transition records are described in the stack table above. `Transitions` lists directed floor links; a reciprocal entry should exist for each traversable return route.

| Location ID | Anchor | Floors | Doors / passages (floor: ID, coordinate, type) | Explicit stairs (floor: ID, coordinate) | Directed transitions |
|---|---|---|---|---|---|
| `hollowmere_chapel` | (-14, 0) | 0 | 0: hollowmere_chapel_east_door (-11, 0) [door_open]; exterior threshold/return (-10, 0) | — | — |
| `hollowmere_general_store` | (0, 18) | 0 | 0: hollowmere_general_store_north_door (0, 15) [door_open]; exterior threshold/return (1, 14), routed around wall at (0, 14) | — | — |
| `hollowmere_house` | (0, -12) | 0 | 0: hollowmere_house_south_door (0, -10) [door_open]; exterior threshold/return (0, -9) | — | — |
| `hollowmere_store` | (14, 0) | 0 | 0: hollowmere_store_west_door (10, 0) [door_open]; exterior threshold/return (9, 0) | — | — |
| `hollowmere_tavern` | (0, 0) | 0 | 0: hollowmere_tavern_south_door (0, 4) [door_closed] | — | — |
| `mira_house` | (12, 9) | 0 | 0: mira_house_west_door (10, 9) [door_open]; exterior threshold/return (9, 9) | — | — |
| `oskar_house` | (-6, 9) | 0 | 0: oskar_house_east_door (-4, 9) [door_open]; exterior threshold/return (-3, 9), joining the general-store spur via (-2, 9) and (-1, 9) | — | — |
| `hollowmere_guild_den` | (-12, -8) | 0 | 0: hollowmere_guild_den_door (-12, -6) [door_open] | — | — |
| `kragmoor` | (908, -626) | 0, -1, -2, -3, -4, -5 | 0: gate_door (908, -605) [door_open] | 0: gate_stair_down (908, -610)<br>-1: gate_stair_up (908, -610)<br>-1: hall_stair_down (908, -626)<br>-2: hall_stair_up (908, -626)<br>-2: forge_stair_down (890, -627)<br>-3: forge_stair_up (890, -627)<br>-3: mine_stair_down (890, -617)<br>-4: mine_stair_up (890, -617)<br>-5: sunken_stair_up (890, -605) | 0→-1 @ (908, -610); -1→0 @ (908, -610); -1→-2 @ (908, -626); -2→-1 @ (908, -626); -2→-3 @ (890, -627); -3→-2 @ (890, -627); -3→-4 @ (890, -617); -4→-3 @ (890, -617); -4→-5 @ (890, -605) [quest: deepholds_infestation]; -5→-4 @ (890, -605) |
| `emberlode_bunkhouse` | (-252, 28) | 0 | 0: emberlode_bunkhouse_north_door (-252, 26) [door_open]; exterior threshold/return (-252, 25), on the source-painted spur to the west road | — | — |
| `emberlode_foremans_hall` | (-256, 22) | 0 | 0: emberlode_foremans_hall_east_door (-253, 22) [door_open]; exterior threshold/return (-252, 22), west-road endpoint | — | — |
| `emberlode_mine` | (-252, 16) | 0, -1, -2 | 0: mine_front_door (-252, 18) [door_open]; exterior threshold/return (-252, 19), on the source-painted spur to the west road | 0: mine_stair_down (-252, 15)<br>-1: working_vein_stair_up (-252, 15)<br>-1: old_seam_stair_down (-252, 17)<br>-2: old_seam_stair_up (-252, 17) | 0→-1 @ (-252, 15); -1→0 @ (-252, 15); -1→-2 @ (-252, 17); -2→-1 @ (-252, 17) |
| `old_mac_farmhouse` | (0, 194) | 0 | 0: old_mac_farmhouse_east_door (3, 194) [door_open] | — | — |
| `reddale_guardhouse` | (134, 24) | 0 | 0: reddale_guardhouse_door (137, 24) [door_open]; exterior threshold/return (138, 24), east-road endpoint | — | — |
| `reddale_guildhouse` | (146, 34) | 0 | 0: reddale_guildhouse_door (143, 34) [door_open] | — | — |
| `reddale_inn` | (138, 30) | 0 | 0: reddale_inn_door (138, 28) [door_open]; exterior threshold/return (138, 27), on the source-painted north approach | — | — |
| `reddale_manor` | (146, 14) | 0 | 0: reddale_manor_door (143, 14) [door_open] | — | — |
| `reddale_reeve_house` | (138, 18) | 0 | 0: reddale_reeve_house_door (138, 20) [door_open]; exterior threshold/return (138, 21), on the source-painted south approach | — | — |
| `reddale_smithy` | (134, 32) | 0 | 0: reddale_smithy_door (137, 32) [door_open] | — | — |
| `silthandriel` | (-252, 934) | 0, 1, 2 | — | 0: tree_stair_up (-252, 932)<br>1: tree_stair_down (-252, 932)<br>1: archive_stair_up (-264, 935)<br>2: archive_stair_down (-264, 935) | 0→1 @ (-252, 932); 1→0 @ (-252, 932); 1→2 @ (-264, 935); 2→1 @ (-264, 935) |
| `silverhart_palace` | (8, -496) | 0, 1 | 0: grand_hall_front_door (8, -491) [door_closed]<br>0: queen_chambers_rear_door (8, -501) [door_open] | 0: gallery_stair_up (8, -496)<br>1: gallery_stair_down (8, -496) | 0→1 @ (8, -496); 1→0 @ (8, -496) |
| `silverhart_palace_wizard_tower` | (-7, -482) | 0, 1, 2 | 0: wizard_tower_door (-7, -484) [door_open]; exterior threshold/return (-7, -485), on the source-painted tower apron and path to the courtyard | 0: wizard_study_stair_up (-6, -481)<br>1: wizard_observatory_stair_up (-7, -482)<br>1: wizard_study_stair_down (-6, -481)<br>2: wizard_observatory_stair_down (-7, -482) | 0→1 @ (-6, -481); 1→0 @ (-6, -481); 1→2 @ (-7, -482); 2→1 @ (-7, -482) |
| `silverhart_north_cottage_one` | (35, -507) | 0 | 0: silverhart_north_cottage_one_east_door (37, -507) [door_open]; exterior threshold/return (38, -507), source-painted Path hex immediately east of the door | — | — |
| `silverhart_north_cottage_two` | (35, -513) | 0 | 0: silverhart_north_cottage_two_east_door (37, -513) [door_open]; exterior threshold/return (38, -513), source-painted Path hex immediately east of the door | — | — |
| `silverhart_north_cottage_three` | (35, -519) | 0 | 0: silverhart_north_cottage_three_east_door (37, -519) [door_open]; exterior threshold/return (38, -519), source-painted Path hex immediately east of the door | — | — |
| `silverhart_east_house_one` | (26, -479) | 0 | 0: silverhart_east_house_one_east_door (28, -479) [door_open]; exterior threshold/return (29, -479), source-painted Path hex immediately east of the door | — | — |
| `silverhart_east_house_two` | (32, -480) | 0 | 0: silverhart_east_house_two_east_door (34, -480) [door_open]; exterior threshold/return (35, -480), source-painted Path hex immediately east of the door | — | — |
| `silverhart_east_house_three` | (23, -470) | 0 | 0: silverhart_east_house_three_east_door (24, -470) [door_open]; exterior threshold/return (25, -470), source-painted Path hex immediately east of the door | — | — |
| `silverhart_east_house_four` | (26, -471) | 0 | 0: silverhart_east_house_four_east_door (27, -471) [door_open]; exterior threshold/return (28, -471), source-painted Path hex immediately east of the door | — | — |
| `silverhart_builder_house` | (38, -492) | 0 | 0: silverhart_builder_house_south_door (38, -486) [door_open]; exterior threshold/return (38, -485), source-painted south-door apron | — | — |
| `silverhart_palace_barracks` | (22, -494) | 0, 1 | — | 0: barracks_loft_stair_up (23, -494)<br>1: barracks_loft_stair_down (23, -494) | 0→1 @ (23, -494); 1→0 @ (23, -494) |
| `silverhart_palace_wizard_tower` | (-7, -482) | 0, 1, 2 | 0: wizard_tower_door (-7, -484) [door_open] | 0: wizard_study_stair_up (-6, -481)<br>1: wizard_observatory_stair_up (-7, -482)<br>1: wizard_study_stair_down (-6, -481)<br>2: wizard_observatory_stair_down (-7, -482) | 0→1 @ (-6, -481); 1→0 @ (-6, -481); 1→2 @ (-7, -482); 2→1 @ (-7, -482) |
| `silverhart_palace_council_chamber` | (-6, -494) | 0 | 0: council_front_door (-2, -494) [door_open]<br>0: palace_secret_passage (-9, -492) [secret_passage] | — | — |
| `silverhart_thieves_guild` | (14, -426) | 0 | 0: thieves_guild_front_door (14, -428) [door_open]<br>0: guild_hidden_vault_door (19, -426) [secret_door] | — | — |
| `silverhart_stables` | (-23, -502) | 0 | 0: stables_front_door (-19, -502) [door_open] | — | — |
| `silverhart_general_goods` | (-22, -490) | 0 | 0: general_goods_front_door (-19, -490) [door_open]<br>0: city_secret_passage (-20, -489) [secret_passage] | — | — |
| `silverhart_clothier` | (-29, -502) | 0 | 0: clothier_front_door (-32, -502) [door_open] | — | — |
| `silverhart_magic_shop` | (-29, -490) | 0 | 0: magic_shop_front_door (-32, -490) [door_open] | — | — |
| `thieves_cove` | (-274, 40) | 0, -1, -2, -9 | 0: sunken_cave_front_door (-277, 40) [door_open] | — | 0→-1 @ (-274, 41); -1→0 @ (-274, 41); -1→-2 @ (-274, 38); -2→-1 @ (-274, 38); -1→-9 @ (-274, 40); -9→-1 @ (-274, 40) |
| `corvin_ashgrave_barrow` | (63, -160) | 0 | 0: barrow_entrance_door (60, -160) [door_open]<br>0: lich_sanctum_door (69, -160) [door_open] | — | — |
| `vessel_seekers_crypt` | (32, -154) | 0 | 0: crypt_entrance_door (29, -154) [door_open]<br>0: crypt_entrance_east_opening (35, -155) [door_open]<br>0: crypt_ossuary_door (37, -154) [door_open]<br>0: crypt_ossuary_east_opening (43, -154) [door_open]<br>0: crypt_ritual_door (46, -154) [door_open] | — | — |
| `millbrook_house` | (1, -366) | 0 | 0: millbrook_house_east_door (4, -366) [door_open] | — | — |
| `lich_chapterhouse` | (-39, -346) | 0 | 0: chapterhouse_east_door (-36, -346) [door_open] | — | — |
| `abandoned_house` | (14, -176) | 0 | 0: abandoned_house_west_door (11, -176) [door_open] | — | — |
| `silverhart_palace_tunnel` | (-9, -492) | 0, -9 | — | — | — |
| `silverhart_city_tunnel` | (-20, -489) | 0, -9 | — | — | — |
| `northwatch_keep` | (268, -21) | 0 | 0: northwatch_keep_door (273, -21) [door_open] | — | — |
| `ridgehold_keep` | (426, 43) | 0 | 0: ridgehold_keep_door (426, 45) [door_open] | — | — |
| `silverhart_elven_embassy` | (0, -466) | 0 | 0: silverhart_elven_embassy_east_door (3, -466) [door_open] | — | — |
| `silverhart_dwarven_embassy` | (16, -470) | 0 | 0: silverhart_dwarven_embassy_west_door (13, -470) [door_open] | — | — |
| `silverhart_aldenreach_embassy` | (0, -460) | 0 | 0: silverhart_aldenreach_embassy_east_door (3, -460) [door_open] | — | — |
| `silverhart_corvane_embassy` | (16, -463) | 0 | 0: silverhart_corvane_embassy_west_door (13, -463) [door_open] | — | — |
| `silverhart_ironbond_office` | (1, -454) | 0 | 0: silverhart_ironbond_office_east_door (4, -454) [door_open] | — | — |
| `silverhart_grand_cathedral` | (14, -451) | 0 | 0: silverhart_grand_cathedral_west_door (10, -451) [door_open] | — | — |
| `silverhart_commons_inn` | (8, -529) | 0 | 0: silverhart_commons_inn_south_door (8, -526) [door_open] | — | — |
| `silverhart_warrens_shack_west` | (2, -433) | 0 | 0: silverhart_warrens_shack_west_south_door (2, -431) [door_open] | — | — |
| `silverhart_warrens_shack_centre` | (5, -427) | 0 | 0: silverhart_warrens_shack_centre_north_door (5, -429) [door_open] | — | — |
| `silverhart_warrens_shack_east` | (11, -433) | 0 | 0: silverhart_warrens_shack_east_south_door (11, -431) [door_open] | — | — |
| `silverhart_north_cottage_one` | (35, -507) | 0 | 0: silverhart_north_cottage_one_east_door (37, -507) [door_open] | — | — |
| `silverhart_north_cottage_two` | (35, -513) | 0 | 0: silverhart_north_cottage_two_east_door (37, -513) [door_open] | — | — |
| `silverhart_north_cottage_three` | (35, -519) | 0 | 0: silverhart_north_cottage_three_east_door (37, -519) [door_open] | — | — |
| `silverhart_east_house_one` | (26, -479) | 0 | 0: silverhart_east_house_one_east_door (28, -479) [door_open] | — | — |
| `silverhart_east_house_two` | (32, -480) | 0 | 0: silverhart_east_house_two_east_door (34, -480) [door_open] | — | — |
| `silverhart_east_house_three` | (23, -470) | 0 | 0: silverhart_east_house_three_east_door (24, -470) [door_open] | — | — |
| `silverhart_east_house_four` | (26, -471) | 0 | 0: silverhart_east_house_four_east_door (27, -471) [door_open] | — | — |
| `silverhart_middle_ring_house_east` | (49, -496) | 0 | 0: silverhart_middle_ring_house_east_east_door (51, -496) [door_open] | — | — |
| `silverhart_middle_ring_house_northeast` | (49, -536) | 0 | 0: silverhart_middle_ring_house_northeast_east_door (49, -538) [door_open] | — | — |
| `silverhart_middle_ring_house_north` | (8, -536) | 0 | 0: silverhart_middle_ring_house_north_north_door (8, -538) [door_open] | — | — |
| `silverhart_middle_ring_house_west` | (-32, -496) | 0 | 0: silverhart_middle_ring_house_west_west_door (-34, -496) [door_open] | — | — |
| `silverhart_middle_ring_house_southwest` | (-32, -455) | 0 | 0: silverhart_middle_ring_house_southwest_west_door (-34, -455) [door_open] | — | — |
| `silverhart_middle_ring_house_southeast` | (22, -452) | 0 | 0: silverhart_middle_ring_house_southeast_west_door (20, -452) [door_open] | — | — |
| `silverhart_corstane_manor` | (39, -502) | 0 | 0: silverhart_corstane_manor_west_door (36, -502) [door_open] | — | — |
| `silverhart_noble_neighbor_house` | (45, -502) | 0 | 0: silverhart_noble_neighbor_house_east_door (48, -502) [door_open] | — | — |
| `silverhart_outlying_house_east` | (63, -546) | 0 | 0: silverhart_outlying_house_east_south_door (63, -544) [door_open] | — | — |
| `silverhart_outlying_house_far_east` | (88, -546) | 0 | 0: silverhart_outlying_house_far_east_south_door (88, -544) [door_open] | — | — |
| `silverhart_outlying_house_west` | (20, -476) | 0 | 0: silverhart_outlying_house_west_east_door (22, -476) [door_open] | — | — |
| `silverhart_builder_house` | (38, -492) | 0 | 0: silverhart_builder_house_west_door (34, -493) [door_open]<br>0: silverhart_builder_house_south_door (38, -486) [door_open] | — | — |
| `silverhart_outlying_house_1` | (23, -546) | 0 | 0: silverhart_outlying_house_1_south_door (23, -544) [door_open] | — | — |
| `silverhart_outlying_house_2` | (48, -546) | 0 | 0: silverhart_outlying_house_2_south_door (48, -544) [door_open] | — | — |
| `silverhart_outlying_house_3` | (-32, -476) | 0 | 0: silverhart_outlying_house_3_east_door (-30, -476) [door_open] | — | — |

## Remaining implementation tasks

1. **Resolve the tavern's opening-sequence lock and access progression separately.** The shared exterior-entry runtime must continue to reject its locked door until the intended campaign condition is met. For each location, identify the source-grounded exterior interaction hex and return hex, reference its correct floor-zero door ID, and add the contract to the location manifest. Do not guess approach coordinates from door orientation when the source map or building footprint does not establish them.
2. **Resolve the Silverhart Palace rear door.** Determine whether the Queen's Chambers door connects to a separately registered room/site, an adjoining room on the same floor, or a deliberate non-traversable set piece. Add a destination only when supported by source spatial data.
3. **Wire the Guild hidden vault door into the generic single-floor entry/secret-door interaction path.** Its secret-door record and hidden-room dependency exist; the generic interaction must support the single-floor location as well as multi-story stacks.


Generic engine verification, in-engine visual review and manual walking of all 16 reciprocal multi-floor links remain QA, not outstanding map-port content.

## Evidence reviewed

- Target: `data/world/campaign2_multistory_locations.json` (71 location records; 89 floor records).
- Target: `scripts/world/campaign2_multistory_location_registry.gd`, `scripts/simulation/campaign2_multistory_location_state.gd`, `scripts/world/campaign2_multistory_location_runtime.gd`, and `scripts/world/campaign2_multistory_floor_map_builder.gd`.
- Source: `Hex-crpg/campaign2World.js`, functions `buildThievesCoveCaves`, `revealSingleTunnelEntrance`, `revealTunnelEntrances`, `openTunnelJunction`, and `buildSilverhartPalace`.

This register intentionally records current evidence and unresolved spatial contracts. It does not infer that a missing literal tile object is a missing stair when the floor-map builder generates the stair from a transition.


## Runtime update — 26 November 2026

- PR #408 merged the three-node Thieves' Guild tunnel network. Palace and city secret passages are searchable from an adjacent hex, revealed passages transfer to their matching underground stub, and each junction offers the other two stubs. The wilderness cave retains its two-stage surface-to-cave-to-tunnel stair chain.
- PR #415 merged reciprocal multi-floor transition and stair-presentation tests. PR #416 merged streamed wall chunk-boundary continuity tests.
- The 71 location / 89 floor snapshot contains 62 single-floor locations and nine multi-floor location records. Seven are ordinary multi-floor stacks; the other two are the palace and city tunnel stubs.
- PR #465 adds the generic exterior-entry/return runtime contract and registers Hollowmere Chapel as the first implementation. The remaining 61 single-floor locations still need source-grounded contract records. The specialised Guild tunnel route remains separate.


## Runtime update — 28 November 2026

- PR #486 registers Reddale's Guardhouse, Reeve's House and Inn with source-painted approach/return hexes; all four CI checks passed before merge.
- The Wizard's Tower is now registered with an exterior threshold/return at (-7, -485), the source-painted apron immediately outside `wizard_tower_door` (-7, -484). Its existing three-floor stack is unchanged.
- The Grand Hall front door remains excluded: the source manifest marks it locked and faction-standing gated. The shared exterior-entry runtime correctly rejects locked doors; this pass does not bypass that restriction.
- Reddale's Guildhouse, Manor and Smithy remain excluded because their source-defined path painting does not establish a clear connection to their doors.


## Runtime update — 28 November 2026 (Silverhart houses)

- Registered the three north cottages and four east-quarter houses. Each contract uses the explicitly painted Path hex immediately east of its source-defined east door.
- Registered Master Builder Hallis's house using the south door at (38, -486) and its explicitly painted exterior apron at (38, -485). The west door is not used because its source connector is not the path being registered here.
- Added shared-runtime entry/return round-trip coverage for all eight sites. No location-specific runtime or Hollowmere adapter changes were needed.


## Runtime update — 28 November 2026 (bulk exterior-entry pass)

- Added six middle-ring houses using the source-painted interpolated door-to-ring paths.
- Added the three Warrens shacks using the explicit cross-row Path at r = -430.
- Added the Palace Council Chamber, Corstane Manor, Elven/Dwarven/Aldenreach embassies, Ironbond Office and Grand Cathedral using their source-painted courtyard/street connectors.
- Added Old Mac's Farmhouse, Millbrook House and the Abandoned House using their explicit source road spurs.
- Added 19 shared-runtime entry/return round-trip cases. The contracts reuse the existing registry/runtime and do not introduce location-specific services.
- Sites whose source door has no adjacent painted approach, is locked, is a secret passage, or is an internal/dungeon door remain unregistered rather than receiving invented exterior thresholds.


## Runtime update — 28 November 2026 (remaining unlocked single-floor doors)

- Registered the Hollowmere Guild Den; Reddale Guildhouse, Manor and Smithy; Silverhart Thieves' Guild front door; Royal Stables, General Goods, Clothier and Magic Shop; Corvin Ashgrave Barrow; Vessel-Seeker's Crypt; Silver Flame Chapterhouse; Northwatch and Ridgehold keeps; Corvane Embassy; Silverhart Commons Inn; Noble Quarter neighbour; and all six outlying Silverhart houses.
- For these sites the source/target manifest defines the door wall and outward side, but not every approach is paved as a dedicated Path tile. The contract uses the first adjacent exterior hex beyond that wall; these cells are ordinary walkable outdoor ground in the world map. Internal doors (e.g. the barrow sanctum and crypt chambers) are not treated as world entrances.
- Added one shared-runtime round-trip test for each of the 23 additional doors. Across all registered sites, the regression test now covers all 63 exterior contracts (61 single-floor sites plus the Emberlode Mine and Wizard's Tower multi-floor entrances).
- The locked Hollowmere Tavern remains the only single-floor location without an exterior contract. It is deliberately not bypassed.
