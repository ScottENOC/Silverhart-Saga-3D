# Player dwelling interiors and furniture

## Design contract

Player-owned dwellings are continuous-world properties. They are not detached menu scenes or fixed camp backdrops. The long-term interior scene will be entered through the exterior door and will use the same campaign clock, characters, inventory, weather and save state.

A property starts unfurnished. Ownership, restoration and structural improvements establish the building and usable floor area; they do not grant beds, tables, storage or crafting stations.

## Existing map locations and current footprints

The properties already have exterior world anchors in `CampaignDwellingWorldPresentation`:

- Crossroads cottage plot: axial `(13, 27)`.
- Abandoned roadside house: axial `(14, -176)`.
- Corstane townhouse / Silverhart manor: axial `(39, -502)`.
- The royal grant interaction is at Silverhart Palace: axial `(8, -496)`.

The previous exterior meshes were very small (cottage 4.2 × 3.3 m, abandoned house 4.7 × 3.6 m, manor 6.8 × 5.4 m). The initial footprint pass expands these to 5.8 × 4.8 m, 7.2 × 5.8 m and 10 × 8 m respectively. The country-house extension is 8.2 × 6.4 m. The manor interaction radius is widened from two to three axial hexes so its larger townhouse footprint has room on the continuous map. These dimensions are provisional and should be checked against streamed terrain, roads and neighbouring structures in an in-game review.

## Furniture ownership and placement

Furniture is separate from character equipment inventory. The dwelling state tracks:
- Furniture inventory counts, shared between the player's properties.
- Placed furniture instances per dwelling, with stable instance IDs, local floor position and quarter-turn rotation.
- The next instance ID, all included in save data.

Placement currently validates that an object fits inside the property's floor bounds and does not overlap another placed object. Moving an object removes it from the floor and returns it to furniture inventory; it is never destroyed.

Sleeping capacity is derived from placed beds:
- Single bed: one person.
- Double bed: two people.
- Bunk bed: two people.

No dwelling grants beds automatically. A structurally habitable but unfurnished property can still be used as a sheltered camp; all party members without a placed bed retain the existing outdoor sleeping and ambush-risk rules.

## Acquisition

`CampaignFurnitureCatalog` defines the first furniture range, prices and crafting recipes. The initial shop is Silverhart Furnishings in the capital, accessed at the Silverhart Palace/Noble Quarter location. Purchases deduct gold and enter the dwelling furniture inventory.

Furniture can also be crafted at an owned property from existing campaign resources: timber, hide, stone and iron ore. The first catalogue includes beds, chests, tables, chairs, a workbench and forge/anvil equipment.

## Current implementation boundary

The catalogue, purchase/crafting transactions, placement/removal validation, save persistence, dynamic bed capacity and enlarged exterior meshes are implemented as the first foundation. The actual capital shopkeeper and shop UI, in-world placement-mode UI, 3D furniture rendering, room-specific placement, enclosed interior geometry and interior NPC navigation are follow-on implementation work. The current camp routine anchors remain invisible and do not furnish houses.
