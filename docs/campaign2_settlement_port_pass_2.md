# Campaign 2 settlement port — Emberlode and Reddale

## Scope

This pass extends the source-backed Campaign 2 settlement catalogue beyond Hollowmere and Millbrook. It migrates the authored surface layouts and named resident placements for:

- **Emberlode** — foreman's hall, bunkhouse, mine entrance, Corran Vale, Bettina Marrow and Rennik Coalmarrow.
- **Reddale** — guardhouse, reeve's house, inn, Ironbond guildhouse, Baron's manor, smithy, and twelve named surface residents.

The source of truth is the original `ScottENOC/Hex-crpg` Campaign 2 implementation, principally `campaign2World.js` (`buildEmberlode`, `buildReddale`) and `campaign2Content.js`. Coordinates remain in the original Campaign 2 local axial `(q,r)` frame. No map rescaling or guessed settlement-centre offsets are introduced.

## What is now represented in Godot data

- Six new Emberlode/Reddale building records with source centres, footprints, doors and entrance orientation.
- Five authored road-approach records across the two settlements, retaining the source-painted cells rather than inventing a route from each door.
- Fifteen named surface NPC profiles and placements, retaining source IDs, display names, race/body variant, faction, class/skill/equipment metadata and dialogue IDs where the source defines them.
- Three Emberlode interior records and six Reddale interior/service records.
- Emberlode's three mine levels (surface, -1, -2), stair destinations, gold and gem ore nodes, ledger, and the two spiders authored on level -2.
- Reddale's guild-ledger and Baron-tariff evidence anchors, plus the smithy's authored service inventory.

The canonical settlement adapter now preserves interior records rather than discarding them. The shared building factory has reusable inn, guardhouse, smithy and mine-entrance archetypes; existing cottage, shop and manor archetypes cover the remaining structures. The canonical settlement catalogue now resolves Hollowmere, Millbrook, Emberlode and Reddale through the same registry and chunk presenter.

## Important limits — not yet gameplay parity

This pass is a data and exterior-presentation migration, not a claim that every source interaction has been ported:

- The shared chunk presenter can create the exterior buildings and surface NPC actors from these records.
- Interior room geometry, floor transitions, mine creatures, ore harvesting, evidence reading, merchant services, bribery, dialogue consequences and quests are retained as source metadata where described, but are **not yet wired into playable 3D interactions**.
- NPC schedules and runtime persistence across unload/reload still need end-to-end validation.
- The source's full capital, forts, strongholds, farmstead, dungeons, capitals and remaining wilderness features are not yet migrated as settlement/building content.
- The source-wide content parity register and deterministic runtime extraction/diff remain outstanding.

Do not mark either settlement as complete until the actual scenes, interaction paths, services, quest consequences and save/reload behaviour pass their own tests and visual review.

## Validation added

- The canonical registry is expected to expose four entries: Hollowmere, Millbrook, Emberlode and Reddale.
- Tests check source coordinates, building/path counts, NPC IDs and placements, interior/floor records, mine ore/spider metadata, and supported exterior archetypes.
- The adapter test validates all settlement records and checks that interiors survive canonical conversion.
