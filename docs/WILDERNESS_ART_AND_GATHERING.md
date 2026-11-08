# Wilderness art and gatherable props

## Art source

Silverhart uses a small selected subset of **Kenney Nature Kit 2.1** for the outdoor prototype:
- Oak and default deciduous trees, including autumn foliage variants
- Tall pine tree
- Large rocks
- Detailed bush, stump, log, flower and mushroom props

Kenney's Nature Kit is CC0 1.0. The CI bootstrap downloads the official archive, verifies its SHA-256, and extracts only the models used by this prototype into `art/environment/kenney_nature/`. The original `LICENSE.txt` and source manifest are retained beside the assets.

Run locally before importing the Godot project:

```bash
python tools/ci/fetch_kenney_nature_assets.py
godot --headless --editor --path . --quit
```

The source archive is intentionally not committed. This keeps the repository small while ensuring the browser export and validation jobs use the same pinned asset release.

## Seasonal trees

- Spring and summer use the green oak/default GLBs.
- Autumn swaps to the matching fall-foliage GLB.
- Winter deciduous trees use a bare-branch form.
- Evergreen pines keep their needles year-round and receive snow accents in winter.

The existing 12-month `WorldClock` remains the source of truth. Tree geometry is rebuilt only when the season changes.

## Opening-area gatherables

The Hollow Tankard approach now has visible tutorial nodes:
- Fruit tree: fruit props disappear after harvesting and return on regrowth.
- Timber tree: shows a stump while depleted; requires an axe.
- Herb patch: visible bush/flower/mushroom cluster.
- Iron outcrop: visible rock with mineral shards; requires a pickaxe.
- Stone deposit: visible rock cluster.

Move onto the corresponding hex and use **G / Gather**. The visuals refresh after harvesting and when the world clock regrows the resource. These five nodes are authored tutorial placements; random wilderness spawning and its existing save/regrowth logic remain separate.

## Visual scope

Kenney Nature Kit is deliberately a lightweight, low-poly CC0 set. It is suitable for a working prototype and establishes the imported-asset pipeline, but it is not being represented as the final realistic fantasy art direction. The seasonal model interface is replaceable, so higher-detail forest assets can be substituted later without changing resource rules or calendar logic.
