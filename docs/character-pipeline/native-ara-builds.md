# Native Ara character build pipeline

## How the character base works

Each character profile is passed to Ara's procedural generator. Ara starts from its shared MakeHuman-derived source data and applies that character's body, face and detail parameters during generation. The resulting GLB is already the character-specific morphed mesh.

We must **not** export one generic Ara GLB and assume that all body morphs can be applied to it later. The exported GLB's documented morph targets are facial expression and speech shapes; body shape is generated from the parameter file. The reusable asset is Ara's source data, not one finished body mesh.

## CI strategy

The Aldric, Reyna and Mirabel workflows share `.github/actions/character-build-setup`:

- Ara source data is cached between GitHub Actions runs in `.cache/ara3d`.
- The Ara CLI npm package is cached separately.
- Downloaded Ubuntu packages are cached, avoiding repeated Blender and Xvfb package downloads.
- Blender, NumPy, Pillow, EGL/Mesa and Xvfb are installed together.
- The CLI is pinned to Ara 0.7.4 so its cached source-data version is predictable.

Each workflow still generates its own character from its own JSON profile, then applies project-specific anatomy, sculpt, texture and detail passes. This preserves Ara's intended morph workflow while eliminating repeated source-data and dependency downloads.

The current preview render remains in each character workflow so every uploaded bundle contains a GLB and its matching review images. Splitting preview rendering into a dependent job is deferred until a successful run shows that preview rendering, rather than dependency installation, is the next measured bottleneck.
