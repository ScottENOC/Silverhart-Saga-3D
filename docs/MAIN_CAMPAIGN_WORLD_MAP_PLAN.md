# Main Campaign and World Map Plan

## Campaign identity

The playable campaign opening being built in Silverhart Saga 3D is the **Hollowmere opening from the original Hex-crpg Campaign 2**. The start screen should call this the **Main Campaign — Hollowmere**.

Keep the internal campaign ID as `2`. In the 2D source, `worldMap.js` uses Campaign 2 for the 16×16 regional map and `campaign2World.js` / `campaign2Content.js` define Hollowmere and its opening cast. Do not assign this content the old Campaign 3 ID: that path loads the separate embedded 400×400 map from `world_map_data.js`.

## Opening village: Hollowmere

The first playable location remains the Hollow Tankard and its surrounding village, all on one logical axial hex grid.

### Layout anchors

These coordinates are the current 3D village data and follow the 2D source layout:

| Feature | Axial coordinate |
|---|---:|
| Hollow Tankard centre | (0, 0) |
| General store | (0, 18) |
| Chapel | (-14, 0) |
| Elder's house | (0, -12) |
| Mira's house | (12, 9) |
| Oskar's house | (-6, 9) |
| Stream | r = -25 |
| Bridge | (8, -25) |
| Signposted crossroads | (8, 24) |

The 2D opening places the general store south of the tavern, chapel west, elder's house north, Mira's house east and Oskar's house west/south. A stream runs north of the settlement and the north road crosses it by bridge. The 3D scene should preserve those relationships and keep the tavern, exterior, doors, paths and interiors on a shared coordinate system.

### Opening cast and event

The authored opening cast includes Wren Talbot (companion), Garrick Holt (tavern keeper), Mira Ashbrook and Oskar Vinn (patrons), Yvette Marlow and Hendra Wells (background patrons), Wick Hallow (storekeeper), Elder Marta Wynfield, and the Ironbond Company trio Dray Coltayne, Tomlin Brask and Hask Greel. Tam Wells is encountered through the missing-child thread rather than standing in the tavern at scene start. Rowan Fletcher is a wandering hunter near the crossroads.

The opening event is the Ironbond shakedown: the entrance is closed until the soldiers arrive, then the player chooses how to respond. Preserve the dialogue branches, faction/reputation consequences and later investigator follow-up as they are migrated. Do not reduce the opening to a static tavern scene.

## Regional world map: source-backed shape

The original Campaign 2 map is a **16×16 odd-q hex grid**, not the separate 400×400 embedded map used by the old Campaign 3 default. The initial 3D strategic map now mirrors the source's major geography:

- Columns 0–1: western ocean.
- Columns 2–9: human Silverhart lands.
- Columns 10–15: orc-held eastern lands, with terrain variation.
- Columns 12–15, rows 0–4: north-eastern dwarven mountain range.
- Rows 12–15, columns 2–9: southern elven forest realm.
- A river crosses the map from the western coast toward the north-east, following the original 15-cell river path.
- Faction borders are distinct from terrain; the source intentionally trades a few north-eastern border cells between dwarves and orcs.

The first named map locations are the source-backed opening-region anchors: Hollowmere at column 6 / row 6, Millbrook three world cells north, Silverhart farther north, Reddale one cell east, Emberlode two cells west, and Old Mac's Farmstead south. The data helper also exposes the original local-to-world coordinate conversion: 130 local axial hexes per strategic map cell, with the Hollowmere crossroads as the origin.

## Map implementation boundaries

The in-game map is currently a **strategic reference view**. It is not yet a route planner or travel simulation. The local Hollowmere map remains the detailed movement space. Future work should add, in order:

1. Source-derived POIs for Skarn-tooth Camp, Skarnak's Hold, Northwatch, Ridgehold, Kragmoor, Sil'thandriel, dungeons and other authored locations. Derive each from its real local hex using the shared 130:1 conversion; do not hand-place approximate markers.
2. Road and river travel links, travel time/cost, encounters and settlement entry points.
3. Player map knowledge, fog of war, discovered landmarks and journal/map annotations.
4. Region ownership and faction changes driven by campaign state, rather than hard-coded display-only colours.
5. Seamless local-to-regional transitions and persistence of world-map changes.

The 3D strategic map should remain a coarse overview; it must not replace the detailed local hex maps or create arbitrary loading-screen boundaries between nearby spaces.
