# Organic Hex Geography

## Design principle

Silverhart keeps its axial hex grid as the authority for discrete simulation, but visible geography is allowed to cross hex boundaries. This is intentional sub-hex geometry: the logical map is a useful abstraction, not a stencil that every rendered edge must follow.

A coastal hex may contain both land and water. A river can bend through several cells, widen into a pool, narrow at a ford or bridge, and leave small inlets. A forest edge can have clearings and irregular margins. These shapes are authored or generated from stable geographical data and then rendered as continuous meshes.

## Three layers

1. **Logical hex layer** — occupancy, movement, resources, construction, ownership and save-game coordinates.
2. **Geographical layer** — river centre lines and widths, coastlines, terrain elevation, biome boundaries, ridges and settlement/road routes.
3. **Presentation layer** — continuous terrain, water, banks, paths, vegetation and local detail.

The geography layer must be deterministic and shared by simulation queries and rendering. A rendered river must not wander away from the cells treated as water by pathfinding. A road may be visually narrower or curved inside a logical path corridor, but its walkable route must remain connected.

## Current Hollowmere implementation

- HollowmereVillageData now describes a meandering river centre line and variable half-width in axial coordinates. The river is narrow at the authored bridge cell (8, -25) and wider in other reaches.
- HollowmereVillage renders the river, banks and major roads as smooth variable-width ribbons rather than unions of visible hexagon polygons.
- OrganicWorldFeatures samples Catmull–Rom curves and builds the ribbons as triangle meshes.
- The bridge remains a traversable logical cell and its deck is angled to meet the river at the narrow crossing.
- The existing path-cell network and axial movement remain the gameplay authority.

This first local pass also extends Hollowmere south to Old Mac's Farmstead: the local radius and ground plane are enlarged, the road bends to the farmhouse entrance, and a farmyard lane connects the farmhouse and barn. The farmhouse, barn, irregular fields, crop rows and fenced pasture are currently procedural blockout geometry; no Ara or Blender asset generation is required. The logical door cells remain traversable while building footprints remain blocked.

It does not yet replace the flat ground plane with a full continuous elevation mesh, and it does not yet provide partial water coverage within individual hexes.

## Sub-hex terrain coverage

For later coastlines and mixed-terrain cells, do not force a single terrain ID to describe every point in a hex. Add deterministic coverage/shape data, such as:

- a water polygon or signed-distance field;
- a land/water coverage fraction for strategic-map summaries;
- a local terrain query (sample_surface, is_water_at, is_walkable_at);
- explicit bridge/ford/causeway overlays that alter traversal without deleting the underlying water.

The hex-level simulation can retain a dominant terrain classification for broad rules, while local queries handle whether a specific point is land, water, shallow bank, cliff or bridge. Characters should not be allowed to walk across a visually wet area merely because its containing hex is mostly land.

## Large-world generation

Use a deterministic region seed and low-frequency geographical fields to generate broad shapes first:

1. coastlines and major river basins;
2. elevation ranges, ridges and valleys;
3. biome regions and forest edges;
4. settlements and authored points of interest;
5. road routes that account for terrain and water;
6. local props, vegetation and small surface variation.

Do not generate every hex independently. Neighbouring cells should sample the same continuous fields so coastlines, rivers and terrain remain coherent across chunk boundaries. Chunk borders must share the same world-space samples and feature IDs.

Authored campaign locations and major geography take precedence over procedural variation. Random generation should fill the spaces between established places, not move or erase them.

## Next steps

1. Review the curved Hollowmere river, variable width, bridge and road ribbons in-game.
2. Tune the control points and widths against the actual camera view and village layout.
3. Add irregular forest edges, clearings and gentle terrain undulation.
4. Replace the river's axial-row approximation with a shared world-space channel query for both rendering and movement.
5. Extend the same geography data into the streamed wilderness chunks and campaign regions.
6. Add coastline polygons and mixed land/water hex coverage, then test movement at the shoreline and across chunk boundaries.