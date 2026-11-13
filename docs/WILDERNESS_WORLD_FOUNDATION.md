# Wilderness and expanding world foundation

## Current implementation

- `HexWorldChunkStreamer` generates deterministic axial hex terrain in 16 x 16 chunks.
- A radius-one active window loads nine chunks around the requested exploration point. Moving to another region unloads generated cells outside that window.
- The authored Hollowmere radius (40 hexes) is protected: generated chunks never overwrite or unload its hand-authored cells.
- `WorldSimulation.find_path` and committed movement request the nearby chunk window. Terrain is generated from stable axial coordinates and a fixed world seed, so revisiting a location produces the same terrain.
- Resource nodes are lazily materialised as a character enters a hex. Only changed resource nodes are stored in the save.
- Resource state is included in `WorldSimulation.to_dict/load_dict`; regrowth is driven by the existing `WorldClock`.

## Ported gathering rules

| Node | Terrain | Tool / gate | Recovery |
|---|---|---|---:|
| Ore vein | Rocky outcrop / mountain | Carried or equipped pickaxe | 72 hours |
| Stone deposit | Rocky outcrop / mountain | None | 48 hours |
| Fruit tree | Forest | None | 24 hours |
| Timber tree | Forest | Carried or equipped axe | 48 hours |
| Herb patch | Grass | None | 18 hours |
| Fishing spot | Water | None | 4 hours |

The original rare-ore distribution is retained, including very rare gems and starmetal. Nature Bounty and Keen Forager affect yields where the original rules did. The village exclusion radius remains 35 hexes.

## Deliberate limits of this milestone

This is the simulation/data foundation, not yet the complete outdoor presentation. The current Hollowmere village scene still uses its authored blockout meshes, and the tavern's visible hex floor is a separate local presentation. The next step is to connect streamed chunks to the outdoor terrain renderer and expose a gather interaction in the player UI. Distant NPCs remain outside the per-frame simulation; this work does not add a global NPC tick.
