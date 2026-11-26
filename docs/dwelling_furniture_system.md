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

The previous exterior meshes were very small (cottage 4.2 × 3.3 m, abandoned house 4.7 × 3.6 m, manor 6.8 × 5.4 m). The initial footprint pass expands these to 5.8 × 4.8 m, 7.2 × 5.8 m and 10 × 8 m respectively. The country-house extension is 8.2 × 6.4 m. The manor interaction radius is widened from two to three axial hexes so its larger townhouse footprint has room on the continuous map. The country house and manor are configured for two separate furniture floors; the cottage and restored roadside house have one. These dimensions are provisional and should be checked against streamed terrain, roads and neighbouring structures in an in-game review.

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

`CampaignFurnitureCatalog` defines the first furniture range, prices and crafting recipes. The initial shop is Silverhart Furnishings in the capital, accessed at the Silverhart Palace/Noble Quarter location. Purchases deduct gold and enter the dwelling furniture inventory. The shop is exposed through the nearby-location interaction panel at the Silverhart capital marker, with dialogue choices for each catalogue item. A distinct timber-and-stone storefront now occupies the same axial anchor, with a readable FURNISHINGS sign, front windows, counter and visible sample bed, table and chest. The existing nearby-site action opens the catalogue and routes purchases through the authoritative gold/inventory transaction.

Furniture can also be crafted at an owned property from existing campaign resources: timber, hide, stone and iron ore. The first catalogue includes beds, chests, tables, chairs, a workbench and forge/anvil equipment.

## Current implementation boundary

The catalogue, purchase/crafting transactions, placement/removal validation, save persistence, dynamic bed capacity, enlarged dwelling exteriors and distinct Silverhart Furnishings storefront are implemented as the first foundation. The storefront is a physical presentation linked to the existing nearby-site interaction; it does not yet have a dedicated animated merchant character. The in-world placement-mode UI, 3D furniture rendering, room-specific placement, enclosed interior geometry and interior NPC navigation are follow-on implementation work. The current camp routine anchors remain invisible and do not furnish houses.


## Permanent household residents and Halvard Greer

A fortified, livable Silverhart Manor automatically appoints Halvard Greer as its non-companion household steward. His residence is saved in `CampaignDwellingState` independently of party membership. The world presentation creates him from the authored legacy appearance profile using the shared Ara male base mesh; there is no dedicated Halvard GLB yet. His daily routine uses the existing Ara clips and manor station hexes: sleep, wake, cook at the hearth, housekeeping, store management, welcome guests and evening cooking. No new animation or clothing assets are required.

Halvard's cooking has a small, real inventory consequence. During the 07:00–09:00 and 17:00–19:00 cooking windows, he consumes one existing food item from the player's carried supplies and stores one prepared household meal. Each window can run once per world day. A prepared meal can be consumed when establishing camp at the manor; it sets the camp's existing prepared-meal condition and improves the party's overnight nutrition. Cooking limits and ready meals are saved. If the player has no food, no meal is created.

The current resident presentation is a world-map routine with station movement, not a fully explorable interior simulation. Household residents remain independent of the party roster.
