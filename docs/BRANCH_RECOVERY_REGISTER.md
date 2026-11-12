# Branch recovery register — deep audit supplement (12 November 2026)

**Integration baseline:** `dev_2` at `6e6aaa78a9b5031978dfa239f43441d58f4ea6be` (PR #124 equipment-rules port).
**Live branch inventory:** 131 branches, refreshed 12 November 2026.
**Scope of this supplement:** source-tree and full recursive Git tree comparisons for the large orphan branches listed below. This supplements `FEATURE_BRANCH_AUDIT_2026-11-12.md`; it does not declare the repository-wide audit complete.

## Method and interpretation

- Compared each named branch against `dev_2` using GitHub's compare endpoint, then compared recursive Git trees by exact path.
- `ahead/behind` counts describe commit ancestry, not how much useful work is absent. They are especially misleading for branches created from old baselines and branches whose PRs were squash-merged.
- A path existing on both branches does not mean its contents are equivalent. For important paths, blob SHAs and file sizes were checked.
- A path absent from `dev_2` is a recovery candidate, not automatically a merge candidate. It may be obsolete tooling, an old workflow or a prototype.
- Binary GLB/PNG files are represented in Git tree listings; text fetches cannot be used to inspect binary contents. Visual acceptance remains separate from CI.
- No branch was deleted, reset or force-pushed during this audit. No code was merged in this supplement.

## Deep comparison findings

### `feat/ara-hairstyles-medieval-equipment`

- Compare against `dev_2`: 33 commits ahead / 103 behind; 182 changed paths relative to its merge base.
- Recursive tree: 310 tracked files on branch; only **3 paths are absent** from current `dev_2`:
  - `scripts/presentation/modular_character_assembler.gd`
  - `tools/blender/build_wren_blockout.py`
  - `tools/blender/prepare_wren_sculpt.py`
- The branch's 169 paths under `art/` are already represented in the current tree. Its `art/characters/ara_runtime/hair/manifest.json` has the exact same blob SHA on the branch and `dev_2`; both manifests declare 14 hairstyles for each of female and male (short variants, afro, bob, braid, long, ponytail, buzz, mohawk, cornrows and box braids).
- Its current actor/creator snapshots and three historical build workflows are not merge candidates merely because compare marks them changed from the old merge base.
- **Disposition:** hairstyle and related art payload is already present; no re-port. Preserve the branch as provenance/recovery history. The three absent paths should be tracked against their own source branches (the assembler is also in `feature/modular-character-poc`); do not import Wren blockout tools without a demonstrated current need. Check medieval armour/weapon outputs by visual acceptance in the graphics stream, not by ancestry count.

### `feature/cosmo-tree-gen-evaluation`

- Compare: 23 ahead / 58 behind; 181 changed paths relative to merge base.
- Recursive tree: 1,037 tracked files; only four paths absent from `dev_2`:
  - `.github/workflows/cosmo-tree-gen.yml`
  - `scenes/prototypes/cosmo_tree_gallery.tscn`
  - `scripts/prototypes/cosmo_tree_gallery.gd`
  - `tools/cosmo_tree_gen/generate_collection.gd`
- The addon source, MIT/upstream licence files, presets, textures and all generated `art/environment/trees/cosmo_generated/*.glb` assets are present in the current tree. The binary GLBs were confirmed by tree-path presence; they were not text-decoded.
- **Disposition:** do not merge the whole branch. The four missing files are evaluation/generation tooling, not required runtime assets. Keep this branch as generator provenance. If future maintainers need reproducible regeneration, recover the generator workflow and gallery as a separate, documented tools-only port after verifying the current add-on/licence state. The generated tree collection is not lost.

### `feature/opening-village`

- Compare: 194 ahead / 358 behind; 35 changed paths relative to merge base.
- Recursive tree: 59 tracked files; eight paths absent from `dev_2`. Five are historical Hugging Face / validation workflows, and three are Wren-era tools:
  - `.github/workflows/hf-storage-audit.yml`
  - `.github/workflows/hollowmere-screenshots.yml`
  - `.github/workflows/hollowmere-validation.yml`
  - `.github/workflows/male-anatomy.yml`
  - `.github/workflows/reset-hf-space.yml`
  - `scripts/presentation/modular_character_assembler.gd`
  - `tools/blender/build_wren_blockout.py`
  - `tools/blender/prepare_wren_sculpt.py`
- The village scripts and actor paths exist on both trees but are not identical: branch `hollowmere_village.gd` is 13,782 characters versus 29,866 in `dev_2`; `hollowmere_village_data.gd` is 5,898 versus 8,495; `ara_character_actor.gd` is 3,309 versus 26,429. The branch therefore contains earlier snapshots, not missing complete current files.
- No unique binary art assets were found in its branch tree.
- **Disposition:** retain the original village implementation as historical design lineage; do not replace current village scripts with these older versions. Any specific building/layout/detail absent from the current 601-line village implementation must be identified and selectively recovered with a test. Old HF workflows and Wren blockout tools are not current deployment sources.

### `feature/iphone-hollowmere-ara-preview`

- Compare: 178 ahead / 358 behind; 36 changed paths relative to merge base.
- Recursive tree: 60 tracked files; nine paths absent from `dev_2`: old HF storage/reset workflows, its iPhone-preview workflow, `tools/deploy_web.py`, the modular assembler and two Wren blockout tools.
- `tools/deploy_web.py` is explicitly tied to the old Hugging Face Space `Thisisausername836/silverhart-saga-3d`; it writes a manifest and publishes to that Space. It is not a suitable replacement for the current GitHub Pages deployment workflow. Its manifest-generation idea may be reusable only if a concrete integrity/provenance requirement remains unmet.
- No unique binary art assets were found in its branch tree.
- **Disposition:** preserve as deployment history; do not merge its HF-specific publishing code. The current Pages workflow remains the source to reconcile separately with the intended deployment branch.

### `feature/anatomy-geometry-revision`

- Compare: 205 ahead / 58 behind; 34 changed paths relative to merge base.
- Recursive tree: 875 tracked files; 19 paths absent from `dev_2`, including:
  - Character assembly: `scripts/presentation/character_assembly_resolver.gd`, `data/characters/body_profiles.json`, `tools/character_definitions.py`, `tools/ara/validate_body_profiles.py`, `tools/ci/validate_character_definitions.py`
  - Garment/anatomy pipeline: `tools/blender/build_ara_garment_library.py`, `normalize_ara_garment_rig.py`, `compare_ara_footwear_rigs.py`, `audit_anatomy_pipeline.py`, `review_anatomy_closeup.py`, `test_gltf_vertex_colours.py`, `validate_ara_body_variant.py`, `validate_ara_gender_variants.py`
  - Tests and architecture records: `tests/test_character_assembly.gd`, `tests/test_character_assembly_resolver.gd`, `tests/test_character_definitions.py`, `docs/characters/character-assembly-architecture-audit.md`, `docs/characters/unified-character-assembly.md`, and `.github/workflows/anatomy-review.yml`.
- The branch's body-profile proposal defines ten canonical bases (five builds for each sex/body model). Its own description says per-character variation is then applied through morphs/modifiers. This is a proposal, not an accepted design decision. It differs from the current project direction of validating one accepted male and one accepted female base, then applying character morphs and fitting clothing against those rigs.
- The branch removes `hollowmere_loadouts.json` and changes the NPC manifest/schema; the existing audit records that the branch has only 14 NPC records while current `dev_2` has 22. The migration is not safe to adopt as-is.
- **Disposition:** preserve as a high-value, active recovery source, not a wholesale merge. Keep this work separate from the live anatomy geometry acceptance workflow. Once the branch audit is complete, recover the resolver, garment tooling, tests and docs as individually reviewable slices. Before any port: decide base-body versus profile strategy; migrate all 22 NPCs and their quest/companion state; verify generated assets actually exist; fix resolver validation/idempotency and duplicate inventory IDs; run Godot tests and Blender export/rig/garment checks. No current visual acceptance is implied by the branch's CI history.

### `feature/male-anatomy-skinned-mesh`

- Compare: 143 ahead / 358 behind; 21 changed paths relative to merge base.
- Recursive tree: 48 tracked files; six paths absent from `dev_2`: old HF audit/reset workflows, `.github/workflows/male-anatomy.yml`, `scripts/presentation/modular_character_assembler.gd`, `tools/blender/build_wren_blockout.py`, and `tools/blender/prepare_wren_sculpt.py`.
- Most compared files are old Ara/Wren snapshots also represented in the current tree; compare ancestry is not evidence that the branch's old character scripts should be merged.
- **Disposition:** retain as a historical male-anatomy development line. No wholesale port. The absent male-anatomy workflow may preserve useful validation steps; compare its actual job commands against current anatomy workflows before deciding whether any test logic is missing. The Wren blockout tools are not automatically relevant to the current Ara base workflow.

### `feature/shared-character-system`

- Compare: 125 ahead / 358 behind; 18 changed paths relative to merge base.
- Recursive tree: 45 tracked files; five paths absent from `dev_2`: old HF audit/reset workflows, `scripts/presentation/modular_character_assembler.gd`, and the two Wren blockout/s sculpt scripts.
- The branch includes early `character_appearance.gd`, accessory attachment, assembly helpers, workshop and tests, but these are earlier snapshots of a code line now evolved substantially.
- **Disposition:** preserve as an architectural predecessor to the modular character work. Do not merge old appearance/actor/workshop files. Recover a specific missing contract or test only if the current resolver/actor pipeline demonstrably lacks it. Its relationship to `feature/modular-character-poc` and #87 must be retained in the dependency map.

### `feature/modular-character-poc`

- Compare: 51 ahead / 358 behind; 17 changed paths relative to merge base.
- Recursive tree: 45 tracked files; 18 paths absent from `dev_2`, including:
  - `scripts/presentation/modular_character_assembler.gd`
  - `scripts/presentation/character_accessory_factory.gd`
  - `scripts/presentation/character_attachment_rig.gd`
  - `scripts/simulation/character_appearance.gd` and `character_appearance_store.gd`
  - `shaders/garment_fabric.gdshader`
  - `art/characters/ara/modular/socket_calibration.json`
  - `tools/ara/blender_body_review.py`, `export_modular_component.ts`, `patch_ara_clothing.py`, `prepare_npc_variants.py`, and `npc_presets.json`
  - prototype/completion documentation and an older workflow.
- This is a distinct early component-assembly architecture, not merely a duplicate of the current #87 resolver. It uses a body-owned canonical Skeleton3D, independently skinned garments/hair, explicit accessory attachment rigs, appearance store and garment shader. It is a useful source for socket calibration and garment/attachment concepts, even if the current runtime resolver is preferred.
- **Disposition:** retain as a high-value prototype and recovery source. Do not merge wholesale. Compare attachment/socket calibration and shader logic with current Ara output; preserve useful test cases and exporter tooling as a separate port. Record any reusable concepts in the architecture review without reintroducing the competing assembler unless a concrete runtime gap is found.

### `feature/missing-skill-runtime-port`

- Compare: 21 ahead / 12 behind; eight changed files: character creation rules, CharacterState, CombatRules, SimulationActionRequest, skill progression, WorldSimulation, player creator and simulation tests.
- These files overlap the current skill/progression implementation; the branch is close enough to current ancestry that file-by-file diff review is more useful than an ancestry summary.
- **Disposition:** provisional selective-salvage candidate, not closed as redundant. Compare each changed function and each added assertion against current `dev_2`, especially skill effect application, runtime action paths and regression cases. Preserve any test scenario not already covered even if its old fixture needs rewriting.

### `feature/farm-wildlife-creatures`

- Compare: 22 ahead / 55 behind; nine changed paths. Current tree comparison and prior source review establish that `farm_wolves_quest.gd`, `creature_actor.gd`, their tests and docs are byte-identical to `dev_2`; village script is an older snapshot.
- The branch also changes two Quaternius GLTF source descriptors. These should be checked for exact blob equality/current importer relevance before any disposition is called final.
- **Disposition:** gameplay quest/creature code is already integrated; no re-port. Keep branch as provenance. Check the two GLTF descriptor diffs and any test coverage delta before final archival classification.

### `feature/character-inventory-panel`

- Compare: 14 ahead / 140 behind; eight changed paths. Current `CharacterPanel` has evolved beyond the branch's 262-line version; current panel is 317 lines and includes catalogue integration, equipment-change signal and scroll-position preservation.
- CharacterState and test changes are old snapshots; they must not replace current simulation files.
- **Disposition:** no wholesale merge. Compare the unique test assertions and UI interactions, and inspect the SVG icon atlas only for an icon genuinely absent from current UI. Preserve the branch.

### `feature/arena-and-full-character-roster`

- Compare: 7 ahead / 105 behind; seven changed paths. The arena opponent data, legacy enemy roster, roster validator and tests are byte-identical to current `dev_2` (as recorded in the primary audit).
- **Disposition:** content and validation are integrated. No port; preserve historical branch and test lineage.

## Dependencies and recovery map (initial)

- `feat/ara-hairstyles-medieval-equipment` → `feature/modular-character-poc`: the former has an absent assembler path that is present in the latter. Treat the latter as the source of that prototype, not as a reason to restore the entire old branch.
- `feature/shared-character-system` → `feature/modular-character-poc` → `feature/unified-character-assembly` / `feature/anatomy-geometry-revision`: successive or overlapping character-system approaches. Preserve all histories; do not cherry-pick overlapping snapshots without checking the exact target contract.
- `feature/opening-village` and `feature/iphone-hollowmere-ara-preview` share the old Ara/Wren workshop and village lineage. Their old character actor and village scripts are ancestors of current files, not parallel current implementations.
- `feature/cosmo-tree-gen-evaluation` → `feature/hollowmere-cosmo-forest`: generator/add-on provenance and forest use should be assessed together; current runtime generated assets are already present.
- `feature/anatomy-geometry-revision` intersects #87 character assembly and the separate active anatomy stream. Keep its recovery work staged and do not modify the anatomy branch during this branch-preservation audit.
- `feature/missing-skill-runtime-port` overlaps #90 skill/progression and the current runtime; function-level diff required before a final redundant/salvage label.
- `feature/farm-wildlife-creatures` is a source ancestor for later farm quest work; its integrated current code must not be confused with the separate #99 Tessa/dire-wolf quest extension or #110 riding system.

## Remaining work before audit completion

1. Continue branch-by-branch review of all 131 live branches, including small branches and branches with no unique commits. For each, distinguish commit ancestry, tree paths, blob equality, changed logic/assets, CI evidence, dependencies and recovery route.
2. Review all open PRs at their current head SHA; the earlier PR register is a snapshot, not current status.
3. Inspect remaining deployment/workshop branches and exact current Pages artifact paths. Keep deployment-source choice separate from feature integration.
4. Complete exact comparisons of all unique tests and GLTF/GLB/texture assets on the remaining candidate branches.
5. Keep PR #123 draft until this register and the main audit are complete. Do not merge the audit as “complete” while any of the above remains open.


## Deployment and Workshop branch group — deep comparison

The following comparisons were made against `dev_2` after the main register was created. They are workflow/source comparisons, not an attempt to deploy or change the Pages source.

### Current deployment workflow

- Current `.github/workflows/godot-web-export.yml` on `dev_2` is 329 lines (blob `c598027c73a2f7654e5d607e2294208d1830c3bf`). It is materially more capable than the old 135-line `feature/godot-web-pages-export` workflow.
- It independently retrieves the Hollowmere Ara model artifact, optionally retrieves Workshop body/prop packages, builds and validates the Godot web/PWA export, uploads the game artifact, and deploys a combined Pages tree with the Workshop site when available (falling back to the checked-in `site/` shell).
- **Confirmed integration defect / unresolved deployment decision:** its `workflow_run` and `push` filters are `dev`; checkout refs and all artifact discovery queries are also `dev`. Therefore this workflow on `dev_2` does not build or deploy `dev_2` changes. This is not fixed by merging any of the old deployment branches. Do not retarget it until the intended source-of-truth branch and how the user's iPhone review should follow `dev_2` are explicitly settled.

### Branch-by-branch disposition

| Branch | Compare vs dev_2 | File-level result | Recovery/disposition |
|---|---:|---|---|
| `feature/godot-web-pages-export` | 13 ahead / 166 behind; 5 files | Old 135-line workflow; checkout v4, older Pages actions and a deployment gate requiring the Workshop artifact to be ready. | Superseded by current 329-line workflow. Keep history; no wholesale merge. |
| `feature/hollowmere-github-pages` | 5 / 163; 4 files | Older 170-line workflow plus old iPhone-preview workflow and HF deploy helper. | Superseded; retain as deployment lineage. Do not restore HF deploy helper. |
| `feature/ios-game-pwa` | 12 / 161; 3 files | `tools/pwa/package_godot_pwa.py` has the exact same blob SHA on branch and `dev_2`; workflow is older; includes phone-testing documentation. | PWA packager is already integrated byte-for-byte. Review only phone-testing doc for any still-valid manual acceptance checklist; no code port. |
| `fix/combined-game-workshop-pages-deploy` | 4 / 119; 4 files | Separate combined deploy workflow and older export workflow; both target `dev`. | Its artifact-composition approach is represented by the current workflow. Preserve as historical fallback; no wholesale merge. |
| `deploy/wren-workshop-github-pages` | 1 / 167; 1 file | Old Wren-only Pages workflow snapshot. | Superseded by current Workshop artifact workflow and combined deploy. No merge. |
| `fix/pages-deploy-artifact-based-v2` | 4 / 117; 2 files | Old artifact-based workflow pair. | Compare history retained; no unique current integration gap established. |
| `fix/pages-deploy-game-and-workshop-artifacts` | 9 / 118; 4 files | Another prior combined artifact/deploy iteration and doc. | Current workflow has since incorporated the combined artifact path and optional Workshop fallback. No wholesale merge. |
| `fix/pages-game-artifact-path` | 1 / 115; 1 file | Old 250-line export workflow. | Superseded by current workflow; no merge. |
| `fix/split-game-export-and-pages-deploy` | 1 / 116; 1 file | Old 250-line export workflow; substantially the same design as the prior artifact-path iteration. | Superseded; no merge. |
| `maintenance/single-iphone-preview-pipeline` | 0 / 168; 0 files | No unique commits/files relative to `dev_2`. | No port; keep historical branch. |
| `fix/workshop-dress-and-game-loading-stages` | 4 / 158; 3 files | Old Workshop workflow/site plus an early 3,345-character `WorldRoot` loading overlay. | The loading UI is a potential UX reference only; current `WorldRoot` is substantially evolved. Do not replace it. Compare interaction semantics only if current loading feedback has a concrete gap. |
| `fix/publish-all-male-workshop-previews` | 1 / 144; 1 file | Old 34,889-character Workshop workflow versus current 35,501-character workflow. | No direct merge. Review the actual male artifact discovery/validation logic against current workflow before marking fully superseded; if a male preview is missing, port only that job/step and add a test. |
| `feat/wren-only-pages-two-character-workshop` | 5 / 157; 3 files | Earlier two-character Workshop and Pages composition workflow/site. | Superseded by current combined workflow; retain as history. |
| `fix/ara-review-crash-remove-legacy-wren-build` | 4 / 156; 4 files | Its `godot-web-export.yml` is exactly the same blob as `feat/wren-only-pages-two-character-workshop` (same SHA); changes are mostly validation/Workshop workflow and docs. | Preserve as a focused historical fix. Compare its Ara review crash fix against current character validation workflow before final disposition; do not merge old workflow snapshots. |

### Additional dependency and deployment notes

- `feature/ios-game-pwa`'s PWA packager is already present in `dev_2` with exact blob identity; it is not a missing implementation.
- `fix/pages-game-artifact-path` and `fix/split-game-export-and-pages-deploy` are successive near-identical workflow variants; neither supersedes the current 329-line workflow.
- `feat/wren-only-pages-two-character-workshop` and `fix/ara-review-crash-remove-legacy-wren-build` share the exact same export workflow blob, despite their different branch names.
- `fix/publish-all-male-workshop-previews` still deserves a narrow logic comparison: its purpose is a male-preview publication fix, and branch-level workflow similarity alone is insufficient to prove the current workflow covers it.
- No deployment workflow was merged or changed during this audit. The source-branch mismatch on `dev_2` is deliberately left as a recorded decision/blocker, not silently fixed as part of branch preservation.
