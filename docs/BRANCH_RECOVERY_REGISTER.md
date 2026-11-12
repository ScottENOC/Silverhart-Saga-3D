# Branch recovery register — deep audit supplement (12 November 2026)

**Initial integration baseline:** `dev_2` at `6e6aaa78a9b5031978dfa239f43441d58f4ea6be` (PR #124 equipment-rules port).
**Latest integration baseline:** `dev_2` at `374d4a2894e0c118c4a35d075a23ca568ff51209` (PR #127 equipment appearance/heraldry utility).
**Live branch inventory:** 134 branches, refreshed 12 November 2026.
**Scope of this supplement:** source-tree and full recursive Git tree comparisons for the large orphan branches listed below. This supplements `FEATURE_BRANCH_AUDIT_2026-11-12.md`; it does not declare the repository-wide audit complete.

## Method and interpretation

- Compared each named branch against `dev_2` using GitHub's compare endpoint, then compared recursive Git trees by exact path.
- `ahead/behind` counts describe commit ancestry, not how much useful work is absent. They are especially misleading for branches created from old baselines and branches whose PRs were squash-merged.
- A path existing on both branches does not mean its contents are equivalent. For important paths, blob SHAs and file sizes were checked.
- A path absent from `dev_2` is a recovery candidate, not automatically a merge candidate. It may be obsolete tooling, an old workflow or a prototype.
- Binary GLB/PNG files are represented in Git tree listings; text fetches cannot be used to inspect binary contents. Visual acceptance remains separate from CI.
- No branch was deleted, reset or force-pushed during the initial comparison pass. Subsequent user-directed selective code merges are recorded below; original feature branches remain intact.

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

- Fresh compare: 22 ahead / 58 behind; nine changed paths. `farm_wolves_quest.gd`, `tests/test_farm_wolves_quest.gd` and `docs/FARM_AND_WILDLIFE.md` are byte-identical to current `dev_2`. `creature_actor.gd` is an older snapshot; current adds hex position and CharacterState linkage (`axial_hex`, `simulation_state`). Village/HollowTankard/workflow files are older snapshots.
- Both Quaternius GLTF source descriptors (`Horse_White.gltf` and `ShibaInu.gltf`) were checked and are byte-identical to current `dev_2`.
- **Disposition revised:** quest/test/docs and model descriptors are already represented; no re-port. Preserve branch as provenance. Its older CreatureActor and scene snapshots must not replace the current simulation-aware actor.

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

1. Complete the remaining full branch-by-branch review of all 134 live branches, including small branches and branches with no unique commits. The register now has name coverage for all 134; full tree/blob/asset/test/dependency review is still required for the remaining candidates.
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


### Focused exception: `fix/publish-all-male-workshop-previews` is not fully superseded

A deeper workflow comparison found a unique contribution that was not apparent from the one-file compare summary:

- The branch's `wren-workshop.yml` is 652 lines versus 687 current on `dev_2`.
- It generates three male body builds (`base`, `small`, `large`), creates separate processed anatomy GLBs and review renders for all three, and publishes all three to the Workshop site/package.
- Current `dev_2` generates and publishes the standard male base only. It does not currently have the branch's small/large profile generation steps.
- This is a real workflow capability gap, not just a stale workflow copy. However, it encodes three male base meshes, while the current character design discussion has favoured one accepted male base and one accepted female base with character-level morphs. It must not be merged as a new permanent body-profile architecture without resolving that design decision.
- **Disposition revised:** preserve as an explicit alternative/profile-testing source. After the current base-body/morph strategy is settled, decide whether small/large exports are useful as temporary comparative validation fixtures. If yes, port only the generator/review matrix and keep those outputs out of the runtime character catalogue unless separately approved. Add validation that garment fit and morph deformation remain correct across the intended supported range.

## Current open PR snapshot (12 November 2026)

The refreshed open-PR listing returned 19 PRs. #123 is still a draft audit PR targeting `dev_2`; #121 is a draft visual-acceptance candidate targeting `dev_2`. The other open PRs still mostly target `dev`, including #110 riding, #99 farmstead rescue, #96 vision/fog, #90 skills/magic, #89 content census, #88 world port, #87 character assembly, #77/#76 clothing/equipment, #74 player inventory, #73 companion model, #34 workflow consolidation, #29 creator, #26/#25 pipeline/clothing, #8 anatomy and #5 audio/mode selection.

This confirms that the audit and the old PRs are not ready for bulk merge. Before acting on any of them, refresh its head SHA, base SHA, changed files and current-head workflow evidence. Keep #123 draft until every live branch has a documented recovery/disposition. No PR was merged or closed during this snapshot.


## Further salvage-candidate tree checks

These checks extend the branch-by-branch register beyond the first orphan batch. Missing paths below are exact recursive-tree differences against current `dev_2`; they are recovery candidates, not permission to merge an entire branch.

### `feature/reusable-npc-workshop`

- Compare: 5 ahead / 358 behind; five compare-diff paths; 33 tracked paths in the branch tree.
- Seven paths absent from `dev_2`: old HF audit/reset workflows, `scripts/presentation/modular_character_assembler.gd`, `tools/ara/build_npc_previews.py`, `tools/ara/npc_profiles.json`, and the two Wren blockout/s sculpt tools.
- The two NPC preview/profile files are the distinct contribution relevant to a large reusable NPC roster; the assembler is an earlier alternate architecture.
- **Disposition:** deferred tooling salvage candidate. Preserve branch. Review preview builder inputs/outputs and adapt them to current canonical NPC definitions/resolver before any port. Do not revive its old assembler or HF workflows.

### `feat/equipment-materials-heraldry`

- Compare: 14 ahead / 102 behind; seven changed files; 314 tracked paths; seven absent paths.
- The distinct missing deliverable consists of `scripts/characters/equipment_appearance.gd`, `shaders/shield_heraldry.gdshader`, `tests/test_equipment_appearance.gd`, and its design document. The other three missing paths are the old modular assembler and Wren blockout tools.
- The helper is a library candidate, not yet proven to be used by the current Ara actor/equipment presentation pipeline. The branch tests use synthetic meshes/materials; they do not prove that exported shield/helmet assets expose stable metadata or that the game invokes the helper.
- **Disposition revised:** selective helper/shader/test/doc slice was recovered and merged by PR #127. The helper is now available in current `dev_2`, but is not yet claimed to be wired into the runtime equipment presentation path. The branch's armour-prop generator and mesh changes remain with the separate modelling stream.

### `feat/tapered-split-dress-v2`

- Compare: 8 ahead / 102 behind; five changed files; 310 tracked paths; only three absent paths (the old modular assembler and Wren blockout tools).
- No unique art path is absent from the current tree. The candidate's value is its newer dress-generator logic and the resulting reviewable variant, not a missing asset directory.
- **Disposition:** hold for visual acceptance. Compare the generator function-level changes and exact GLB/material output against current before deciding whether any source or asset needs recovery. Do not replace the default dress based only on CI.

### `feature/ser-aldric-first-companion-model`

- Compare: 7 ahead / 103 behind; five changed files; 132 tracked paths; five absent paths.
- Two relevant absent paths are `data/characters/companion_models.json` and `docs/FIRST_COMPANION_MODEL.md`; the remaining three are the old modular assembler/Wren tools. No missing companion model binary path was found by this tree-path comparison.
- **Disposition:** retain as an asset candidate and provenance. Inspect its manifest/workflow and actual GLB path against current canonical character definitions. Do not add a separate companion registry if the current resolver can express the same model choice. Visual/rig/armour acceptance remains outstanding.

### `feature/full-world-port-foundation`

- Compare: 47 ahead / 28 behind; 27 changed paths; 1,078 tracked paths; 20 paths absent from `dev_2`.
- Missing unique world content and tooling includes:
  - Data: `data/world/campaign2_geography.json`, `campaign2_road_paths.json`, `campaign2_settlement_layouts.json`.
  - Source/parity documents: `docs/campaign2_npc_dialogue_index.md`, `campaign2_source_inventory.md`, `full_world_2d_to_3d_port_plan.md`, `full_world_fidelity_and_inspection.md`, `original_2d_campaign2_source_audit.md`, `source_to_3d_world_gap_audit.md`.
  - Preview/builders: macro/regional preview scenes and scripts, `scripts/world/campaign2_settlement_builder.gd`, `campaign2_world_terrain_data.gd`.
  - Tests: four geography/road/settlement/terrain manifest tests.
  - Strict runner: `tools/ci/run_godot_checked.sh`.
- This is not merely an old snapshot: the missing geography/road/settlement data and builder/test suite are a substantial source-content preservation package. Earlier CI evidence says hex-grid/simulation tests passed but Godot workflow #42994727983 failed on a synthetic clothing material tint/null-material assertion. The strict runner correctly surfaced errors; do not weaken it to obtain green CI.
- **Disposition revised:** Campaign 2 geography/road/settlement data, previews/builders, tests and strict runner were selectively recovered by PR #125 and merged into current `dev_2`. The original branch remains intact as provenance for its unrelated world-simulation, appearance and other snapshots; do not merge those wholesale. This is world data plus development previews, not a completed playable world-travel system.

### `feature/farmstead-bear-creature-model`

- Compare: 27 ahead / 28 behind; five changed paths; 1,058 tracked paths; one absent runtime path: `scripts/simulation/farmstead_dire_wolf_encounter.gd`.
- The unique service is the Tessa rescue/dire-wolf encounter implementation recorded in the primary audit. It is not already represented by the farm-wolf quest actor alone.
- **Disposition:** retain as a distinct quest salvage candidate. The branch's encounter health setup double-applies Health ranks at character registration and its dormancy handling does not restore all characters' previous state. Do not port until those lifecycle/state issues are fixed and quest state is integrated with current journal/companion IDs.



## Further simulation and combat lineage checks

### `feature/animal-attributes` and `feature/animal-riding-validation`

- Compare: 29 ahead / 24 behind for `feature/animal-attributes`; 30 ahead / 24 behind for riding. The riding branch is the one-commit continuation.
- Riding branch tree: 1,066 paths; three paths absent from current `dev_2`: `.github/workflows/riding-preview.yml`, `scripts/simulation/animal_catalog.gd`, and `tests/capture_riding_preview.gd`.
- Both branches also change existing `CharacterState`, `WorldSimulation`, `HollowTankard`, village and creature actor files. Those are stale snapshots and must be reviewed as selective diffs, not copied.
- The animal catalogue and riding-preview capture are genuinely missing paths; the current tree's farm/wolf creature actor is not an animal simulation catalogue or mount lifecycle.
- **Disposition revised:** animal catalogue, mount state, riding simulation and lifecycle/save-load regression coverage were selectively recovered by PR #126 and merged into current `dev_2`. The old branches remain intact. The distinct riding-preview workflow/capture script was not merged; preserve it for later visual review, noting that it currently uses a fixed parent/offset rather than a production mount-visual attachment API.

### `feature/skill-magic-foundation`

- Compare: 70 ahead / 56 behind; 16 changed paths. Its recursive branch tree has no paths absent from `dev_2`.
- Key skill definitions/catalogue/progression/NPC spending and spell JSON already exist in the current tree. The branch's `companion_campaign_content.gd`, `farmstead_bear_encounter.gd` and skill/magic plan are not identical, but direct comparison shows its two extra companion lines are an older non-canonical-ID path; current `dev_2` correctly checks both original and canonical party IDs. The branch's one extra bear line adds an animal tag now not needed in the same form by current data/logic.
- **Disposition:** no wholesale port and no missing file recovery. Keep it as lineage for the skill/quest work. If a specific skill effect or quest dialogue is not covered in current tests, recover that scenario individually; do not restore older canonical-ID or encounter snapshots. Spellcasting remains a separate unimplemented runtime system despite the existing spell data.

### `feature/action-contract-downed-lifecycle`

- Compare: 10 ahead / 149 behind; nine changed paths. The only branch-tree paths absent from current `dev_2` are the old modular assembler and two Wren blockout tools; its action-request/result/event, CharacterState, CombatRules and WorldSimulation paths all exist in current.
- **Disposition:** action contract/downed lifecycle is represented in the evolved current simulation. Do not port old simulation files. Preserve the branch as implementation/test lineage; inspect only whether a specific regression assertion is missing from the current suite.

### `feature/combat-initiative-timeline`

- Compare: 36 ahead / 55 behind; 11 changed paths. Its recursive tree has no paths absent from `dev_2`.
- Crucially, `combat_initiative_model.gd`, `combat_initiative_timeline.gd` and `tests/capture_initiative_timeline.gd` are each byte-for-byte identical between the branch and current `dev_2`. Current `HollowTankard.gd` preloads the timeline, constructs/configures it and connects its character-selected signal.
- **Disposition revised:** initiative timeline presentation is already integrated and wired; do not treat it as an outstanding salvage candidate or merge it again. The old branch's remaining changes are older simulation/world snapshots and workflow/docs history. Visual acceptance of the current panel is still separate.

### `feature/ally-combat-reactions`, `feature/combat-reaction-triggers`, `feature/movement-reactions`, `feature/reaction-resolution-turn-safety`, and `feature/combat-resolution-foundation`

- Current compare file lists show changes only to old simulation snapshots, tests, documentation and (for the broad foundation branch) old workflow/character pipeline files. Their current-tree paths exist in `dev_2`; do not infer missing implementation from their ahead counts.
- The action contract, reaction trigger/turn safety and downed lifecycle foundations have since been integrated/evolved. The remaining work is adversarial current-head test coverage for pending reaction cancellation, reactor/target incapacitation, nested requests, combat end, movement opportunity reactions and safe turn advancement.
- **Disposition:** preserve all five branches as history and regression-scenario sources. No wholesale merge. Recover a specific assertion only after confirming the current test suite lacks it.

### Farmstead follow-up

`feature/farmstead-bear-creature-model` has one unique missing runtime service (`farmstead_dire_wolf_encounter.gd`) as recorded above. The broader `feature/skill-magic-foundation` branch contains an older bear encounter implementation and companion dialogue snapshot; the two branches must be reconciled with current quest IDs and canonical companion identity before either quest extension is recovered. Do not merge either old `HollowTankard` or `WorldSimulation` snapshot.


## Current-head PR and workflow evidence refresh

Refreshed 12 November 2026 against the current open PR metadata. “No runs” below means the commit-specific PR-workflow query returned no PR-triggered workflow run for that exact head SHA; it does not prove that no manual or non-PR workflow has ever run. A green workflow only validates its tested scope and does not waive visual acceptance.

| PR | Current head SHA (abbreviated) | Base | Current-head PR workflow evidence | Current disposition |
|---|---|---|---|---|
| #121 | `a614c6e` | `dev_2` | Godot validation passed. | Hold for in-game cinematic visual acceptance; mergeable metadata true. |
| #110 | `1c2a103` | `dev` | No PR-triggered run returned for exact head. | Hold; current-head validation required; mergeable metadata false. |
| #99 | `30672f5` | `dev` | Godot validation passed. | Selective quest salvage only; fix health/dormancy state defects; mergeable false. |
| #96 | `06db693` | `dev` | No PR-triggered run returned for exact head. | Do not merge wholesale; latest previously recorded run failed; salvage only after perception architecture is designed; mergeable false. |
| #90 | `ab312d5` | `dev` | No PR-triggered run returned for exact head. | No wholesale merge; audit isolated skill/quest changes; mergeable false. |
| #89 | `12d2f46` | `dev` | No PR-triggered run returned for exact head. | Update/reconcile source census as documentation only; mergeable true. |
| #88 | `717ca26` | `dev` | Audio/mode validation passed; character pipeline passed; combat initiative CI/preview passed; Godot validation failed. | Fix strict-runner/material issue and review world data in slices; mergeable true. |
| #87 | `85291ec` | `dev` | No PR-triggered run returned for exact head. | Major character-assembly salvage; no wholesale merge; schema/NPC migration and asset gaps remain; mergeable false. |
| #77 | `406c601` | `dev` | Character pipeline validation passed. | Hold for dress render/fit acceptance; mergeable true. |
| #76 | `7124ad0` | `dev` | Character pipeline and Godot validation passed. | Selective helper/shader port only after actual runtime wiring and asset review; mergeable true. |
| #74 | `194b0b3` | `dev` | Character pipeline passed; Godot validation cancelled. | Development/test inventory only; do not ship as campaign starting inventory; mergeable false. |
| #73 | `4b0bbfb` | `dev` | Character pipeline and Godot validation passed; Hollowmere Ara character build failed. | Hold model pending asset workflow repair and visual/rig/armour review; mergeable false. |
| #34 | `6a19ae2` | `dev` | Hollowmere village, Godot/Blender and screenshot workflows passed. | Do not apply historical workflow deletions; reconcile against current independent workflows; mergeable false. |
| #29 | `8956d00` | `dev` | No PR-triggered run returned for exact head. | Creator UI only as selective salvage; current Ara creator is newer; mergeable false. |
| #26 | `4d7fe0e` | `fix/dress-selector-and-loading-review` | No PR-triggered run returned for exact head. | Stale stacked pipeline/cache work; split from parent and revalidate; mergeable true. |
| #25 | `345f08b` | `dev` | Village validation, screenshot capture, Godot/Blender and male anatomy blockout passed. | Visual/source review and split deployment from anatomy/clothing; mergeable false. |
| #8 | `b8a401c` | `dev` | No PR-triggered run returned for exact head. | Preserve; do not merge wholesale; current Ara pipeline differs; mergeable false. |
| #5 | `a563b16` | `dev` | Godot audio/mode validation passed. | Foundation already integrated/evolved; Arena remains placeholder; no re-merge; mergeable false. |

The PR base SHA recorded by GitHub may predate later `dev_2` commits. In particular, #121 was created against an earlier `dev_2` head; its current target remains `dev_2`, but any merge decision must be based on a fresh comparison/revalidation against the then-current base. None of these PRs was merged or closed during this refresh.


## User-directed stage-1 integration status (12 November 2026)

The user confirmed that the separate character/clothing/hair/equipment modelling workstream should not be duplicated in this branch audit, and that the Cosmo Tree Generator evaluation tooling is not required. The four previously highlighted areas were reconciled as follows:

### Campaign 2 world — integrated

- Selective recovery PR **#125** merged into `dev_2` at `b5e26431fba576c0727e27dd389bac7ce5760d3a`.
- Godot 4.7.2 validation passed on the exact PR head. Existing simulation/building/save/restore/character tests passed; all four new Campaign 2 data/terrain tests passed; macro-world and regional-world preview smoke tests passed.
- Recovered geography, road and settlement manifests, preview scenes/scripts, settlement builder, terrain data, source/design documentation, tests, strict Godot output checker, CI coverage and main-menu preview entry points.
- This is **world data plus development previews**, not a completed playable world-travel system. The source branch `feature/full-world-port-foundation` remains intact. Its unrelated stale WorldSimulation/HollowTankard/appearance snapshots were not merged.

### Animal riding — selectively integrated

- PR **#126** merged after the exact current-head Godot 4.7.2 workflow passed (run `43187949002`), at `69a0f715a9b01efca3aec017cc703fc62e317ffb`.
- Ported animal catalogue and persistent animal/mount state into current CharacterState/WorldSimulation architecture; retained current building, status-effect, save, reaction and progression code rather than copying stale snapshots.
- Corrected the source branch's double-applied Health issue: horse/wolf use 10 base HP plus innate Health ranks once (nominal 50/20 HP).
- Added mount/dismount, mount-profile movement/TP use, reciprocal save/load links, turn-end TP capping and forced detachment when either rider or mount is incapacitated, with regression tests.
- This is simulation/runtime foundation only; player-facing riding controls and final mount visual/animation attachment remain separate work. The original PR #110 remains open for its separate preview workflow/capture disposition.

### Equipment appearance/heraldry — selectively integrated

- PR **#127** merged into `dev_2` at `374d4a2894e0c118c4a35d075a23ca568ff51209`; refreshed full Godot 4.7.2 workflow run `43188654261` passed.
- Merged only the EquipmentAppearance helper, shield heraldry shader, focused test, scope/usage documentation and CI invocation.
- The helper is available in current `dev_2`, but is not yet claimed to be invoked by runtime equipment presentation. Armour-prop generation, shield/helmet GLBs and actor/equipment visual wiring remain with the separate modelling stream.

### Combat initiative — already integrated

- Initiative model, timeline UI and capture test are byte-identical to `dev_2`; current `HollowTankard` preloads and wires the timeline. No additional port.

### Explicitly out of scope

- Cosmo Tree Generator evaluation/gallery/regeneration tooling: user confirms the generator was only used to produce assets that have already been accepted. Current generated tree assets are present; no need to recover the evaluation tools.
- Separate character, clothing, hair and equipment modelling workstream: do not duplicate its work in this integration sequence.



### Animal riding — merge completed

- PR **#126** passed the full current-head Godot 4.7.2 workflow (run `43187949002`) and merged into `dev_2` at `69a0f715a9b01efca3aec017cc703fc62e317ffb`.
- Confirmed green steps included engine import, hex grid, the full simulation/movement/combat/animal/riding test suite, building/door, SaveManager, campaign restore, character appearance, wilderness/creature tests, all Campaign 2 tests and all scene smoke tests.
- The old `feature/animal-riding-validation` branch and PR #110 remain intact pending the broader audit of its preview-capture workflow and any remaining branch-only material. Do not delete the branch or blindly merge the old PR.

### Equipment appearance — merge completed

- PR **#127** was refreshed after #126, passed the current-head Godot 4.7.2 workflow `43188654261`, and merged at `374d4a2894e0c118c4a35d075a23ca568ff51209`.
- Only the helper, shader, focused test, scope documentation and CI invocation were merged. Runtime asset wiring remains with the separate modelling stream.


### Equipment appearance/heraldry — utility integrated

- Selective recovery PR **#127** merged into `dev_2` at `374d4a2894e0c118c4a35d075a23ca568ff51209`.
- Refreshed current-head Godot 4.7.2 workflow `43188654261` passed. This included the new equipment appearance/heraldry test, animal/riding tests, Campaign 2 tests and the full existing simulation/scene suite.
- Merged only `EquipmentAppearance`, the shield heraldry shader, the focused test and usage/scope documentation, plus its CI invocation.
- Intentionally did not merge Blender armour-prop generation, shield/helmet GLB changes, or actor/equipment visual wiring. The helper is now available on `dev_2`, but is **not yet claimed to be invoked by the runtime equipment presentation path**. The separate modelling stream can wire it to accepted assets without needing to recover this helper again.

### Four-item reconciliation

| Area | Result on `dev_2` |
|---|---|
| Campaign 2 world data/previews | PR #125 merged; full relevant CI passed |
| Animal profiles/riding simulation | PR #126 merged; full relevant CI passed |
| Equipment appearance/heraldry utility | PR #127 merged; full relevant CI passed; runtime wiring remains separate |
| Combat initiative timeline | Already present and wired before this recovery pass; no merge required |

The user's requested four-item recovery is therefore complete at the code/test foundation level. The Cosmo evaluation tooling is excluded by user direction; generated tree assets remain in the current tree. The parallel character/clothing/hair/equipment modelling stream is excluded from this recovery pass.

**This does not close Stage 1 as a whole.** The repository-wide branch inventory/recovery register still needs final review of all remaining branches, open PRs and their dependencies. PR #123 remains draft and must not be treated as the final audit sign-off.


## Live inventory refresh — later 12 November 2026 snapshot

This refresh supersedes earlier branch-count and compare-count snapshots above where they differ. It is an additive audit update; historical branch names and earlier findings remain recorded.

- Live GitHub API returned **134 branches** across two pages (100 + 34), including protected integration history and all original feature branches.
- There are **19 open PRs**. #123 remains draft and targets `dev_2`; #121 remains draft and targets `dev_2` for visual cinematic acceptance. The other 17 open PRs still target `dev` or a stacked feature branch. No source feature branch was deleted.
- Current `dev_2` head is `374d4a2894e0c118c4a35d075a23ca568ff51209` (PR #127). The earlier inventory/register baseline at #124 is stale by three successful selective merges: #125 Campaign 2, #126 riding, #127 equipment appearance.
- New names in this later branch inventory relative to the previous 131-branch snapshot include `docs/content-parity-audit`, `feat/wren-only-pages-two-character-workshop`, `feature/in-game-reaction-prompt`, `fix/hollowmere-cast-validator`, and the newer integration branches created for #125–#127. These must be classified separately; the integration branches are recovery records, not source feature branches.

### Refreshed comparisons of large historical branches

All counts below are fresh `dev_2...branch` compare-endpoint values at the current head. The file lists are merge-base diffs; they are not a substitute for recursive-tree or blob comparisons.

| Branch | Ahead / behind | Changed paths | Current audit conclusion |
|---|---:|---:|---|
| `feature/opening-village` | 194 / 361 | 35 | Earlier village/NPC/actor snapshots; no unique binary art. Do not replace current village/actor files. Retain history; selectively recover a specific absent building/layout detail only with a test. |
| `feature/iphone-hollowmere-ara-preview` | 178 / 361 | 36 | Same old village/Ara lineage plus HF-specific deploy helper and preview workflow. No unique binary art. Preserve as deployment history; do not restore HF publisher. |
| `feature/shared-character-system` | 125 / 361 | 18 | Earlier appearance/accessory/actor snapshots. Keep as architectural lineage; no wholesale port. Its relationship to modular-character-poc and #87 remains important. |
| `feat/ara-hairstyles-medieval-equipment` | 33 / 106 | 182 | The 182-path compare diff is mostly asset and workflow ancestry; the previous recursive-tree/blob audit found the 169 art paths and hair manifest already present in current. Do not re-port assets or duplicate the separate modelling stream. |
| `feature/modular-character-poc` | 51 / 361 | 17 | Still has genuinely absent prototype paths, including modular assembler, accessory factory/attachment rig, appearance store, garment shader, socket calibration and exporter/review tools. Preserve as a high-value architecture prototype; no wholesale merge. |
| `feature/missing-skill-runtime-port` | 21 / 15 | 8 | The branch's CharacterState, action request, skill progression, creation rules, player creator and simulation-test lines are represented in evolved `dev_2`. Its older WorldSimulation movement-reaction/lifecycle implementations are superseded by current versions with expanded contracts. No unique test lines were found in the branch snapshot. Retain as lineage; no direct port currently justified. |
| `feature/animal-attributes` | 29 / 27 | 10 | Animal catalogue and simulation files are represented in the merged riding implementation, with current catalogue content evolved. Its preview workflow/capture script remain a separate missing pair; see below. |
| `feature/action-contract-downed-lifecycle` | 10 / 152 | 9 | Existing action/event/result/lifecycle paths are evolved in current. Retain for history and regression provenance; no old snapshot port. |
| `feature/combat-reaction-triggers` | 8 / 149 | 4 | Changes are to existing simulation/test/docs paths. Current reaction system is evolved; preserve as test-history source, not a wholesale merge. |
| `feature/combat-resolution-foundation` | 36 / 158 | 18 | Broad old combat and workflow snapshot. Current paths exist and have since evolved; no wholesale merge. |
| `feature/movement-reactions` | 8 / 144 | 5 | Existing movement/reaction paths are evolved in current. Preserve regression lineage; no wholesale merge. |
| `feature/status-effects-combat-debuffs` | 10 / 14 | 6 | `scripts/simulation/status_effect_rules.gd` is byte-identical to current `dev_2`; other files are older snapshots. No port. |

### Animal riding preview — retained but not yet accepted

- PR #126 merged the simulation/catalogue/mount lifecycle work, but did not import `.github/workflows/riding-preview.yml` or `tests/capture_riding_preview.gd` from the original animal branches.
- The preview workflow renders three rider-on-horse screenshots (female, male and side view), and prints the rider animation list and skeleton bone names. This is potentially useful evidence for the later visual stream.
- The capture script currently parents an Ara rider directly under a `CreatureActor` and applies a fixed local offset (`y = 1.35)); it does not call or validate a production mount-visual attachment API. Therefore its output is a **prototype composition preview**, not proof that runtime riding visuals, animation retargeting or seat alignment work.
- **Disposition:** preserve both original animal branches and this capture workflow. Do not close PR #110 as wholly superseded until the preview's value is decided. If adopted later, move the preview to the current CI branch and update it to exercise the actual runtime attachment contract once that exists. No branch deletion.

### Current audit controls

- Do not close #110 yet: its simulation payload is selectively integrated by #126, but its distinct preview capture remains unaudited for final use.
- Keep #121 open/draft until a human visual playtest confirms GLB animation clips, seated/standing alignment, framing and skip behaviour.
- Keep #123 draft. The refreshed count is not a completed inventory: the remaining small, deployment, diagnostics, test, content and integration branches still need exact path/blob/test/dependency dispositions.
- Preserve all original feature branches. Closing an obsolete PR later does not imply deleting its source branch.
- No gameplay branch has been merged in this refresh. The next audit pass should cover the newly visible branch names and then finish the remaining branch groups, especially the deployment/workshop variants and isolated test/diagnostic branches.


## Remaining small-branch and focused-lineage pass — 12 November 2026

The following are fresh `dev_2...branch` comparisons and targeted file/blob checks. “No port” means the relevant behaviour or asset is already represented in the evolved current tree, not that the source branch should be deleted.

### Documentation, validation and reaction UI

| Branch | Fresh compare | Findings | Disposition |
|---|---:|---|---|
| `docs/content-parity-audit` | 1 ahead / 59 behind; 1 file | Adds a 607-line 2D-to-3D content parity audit, based on old `dev`. It is useful source inventory, but explicitly describes an early project state and cannot be treated as current implementation status. | Preserve as a documentation source. Reconcile its source checklist against current `dev_2` and the branch recovery register before publishing a current parity baseline. |
| `feature/in-game-reaction-prompt` | 2 / 146; 2 files | Its modal prompt and HollowTankard wiring are present in current `dev_2`; the current prompt file is a later version and current HollowTankard connects reaction and movement-reaction events. Its HollowTankard is an old snapshot. | Already evolved/integrated. No re-port; preserve branch history. |
| `fix/hollowmere-cast-validator` | 1 / 14; 1 file | The validator file is byte-identical to current `dev_2` (same blob SHA). | Already integrated; no port. |
| `feature/character-pipeline-foundation` | 2 / 529; 1 file | Adds only the older character-pipeline design document. | Documentation lineage only; retain and mine for any unrecorded decisions, but do not merge an old baseline document unchanged. |
| `feature/ara-character-evaluation` | 4 / 383; 4 files | Old Ara evaluation workflow/site/docs changes; no simulation/runtime paths. | Keep as pipeline history. Do not conflate it with the Cosmo Tree Generator evaluation tooling that the user explicitly excluded. |
| `feat/wren-only-pages-two-character-workshop` | 5 / 160; 3 files | Old two-character Workshop/export workflow and site shell; current combined workflow is more advanced. | Superseded deployment history; no merge. |

### Dialogue, encounters and world presentation

- `feature/hollowmere-dialogue-ambient-chatter` compares 16 ahead / 137 behind with six changed paths. Its ambient chatter script is an older version of the current script; current adds shakedown-choice context. Its campaign-content file is also an older snapshot. Current `dev_2` already contains the core Garrick/Mira/Oskar greetings and ambient chatter phrases, but has expanded choice-specific responses and a richer NPC/faction reputation plus merchant-influence model. The old branch's `npc_deltas`/standing mutation code is superseded; its fight choice is marked unavailable whereas current campaign content supports the fight path.
  - **Disposition revised:** no distinct dialogue payload has been shown to be missing. Preserve as provenance; do not port its old standing model, greeting function or ambient-chatter script over current content.
- `feature/hollowmere-shakedown-combat` compares 50 ahead / 131 behind with eight changed paths. Its `hollowmere_encounter.gd` exists in current but is an older version; its campaign content, journal, turn scheduler, HollowTankard and ambient chatter are older snapshots. No missing encounter script path was found.
  - **Disposition:** retain as encounter-design/test lineage. Do not merge the stale encounter or scene. Reconcile any unique narrative/choice consequences with the current quest and reaction systems after the branch inventory is complete.
- `feature/organic-hollowmere-geography` compares 17 ahead / 89 behind with five changed paths. The organic-world helper and village data paths exist in current; the branch's versions are older than current. The current village implementation has evolved stream/road and farm/wilderness presentation.
  - **Disposition:** no wholesale port. Preserve the branch and selectively compare a specific missing geographical feature only if a current scene/data review demonstrates a gap.
- `feature/main-campaign-world-map` compares 12 ahead / 140 behind; its map UI/data and documentation paths are already represented by the current campaign-map implementation. Its changed player creator/HollowTankard/world-root files are older snapshots.
  - **Disposition:** no re-port; preserve the planning and design history.

### Character, clothing and equipment focused branches

These branches belong to, or directly overlap, the separate character/clothing/hair/equipment modelling stream. They are inventoried to preserve their work, not to duplicate or alter that stream.

| Branch | Fresh compare | Current-tree check / disposition |
|---|---:|---|
| `diagnostic/ara-garment-surface-report` | 1 / 63; 1 file | One Ara actor diagnostic change. Preserve as diagnostic evidence; do not merge into the game runtime. |
| `diagnostic/ara-report-on-character-configure` | 1 / 62; 1 file | One Ara actor diagnostic change. Preserve; do not merge runtime diagnostics. |
| `feature/ara-skeleton-animation-validation` | 0 ahead | No unique commits/files relative to current. Keep history. |
| `feature/ara-visual-animation-review` | 0 ahead | No unique commits/files relative to current. Keep history. |
| `feature/character-starting-clothing` | 12 / 67; 6 files | Its `tests/test_starting_clothing.gd` is byte-identical to current; changed loadout/item/actor/creator/scene files are old snapshots. Preserve; no wholesale port. |
| `feature/player-character-creator-dev` | 10 / 162; 9 files | Creator, actor, NPC manifest and scene are old snapshots; the current creator/runtime has evolved. Validator paths are represented in current. Preserve as design lineage; no wholesale port. |
| `feature/game-real-hollowmere-character-art` | 6 / 163; 5 files | The cast validator files are present in current; remaining workflow/docs changes are older pipeline snapshots. Preserve for asset-pipeline provenance; do not replace current workflow. |
| `feature/player-custom-avatar-selection` | 1 / 68; 1 file | Only an older HollowTankard snapshot; current scene already selects the player avatar with fallback. No port. |
| `fix/generic-clothing-visibility` | 3 / 64; 1 file | Ara actor-only change in the parallel modelling stream. Preserve; no integration here. |
| `fix/keep-body-visible-under-clothing` | 2 / 66; 1 file | Ara actor-only change in the parallel modelling stream. Preserve; no integration here. |
| `fix/player-equipment-visuals` | 4 / 68; 2 files | Actor/HollowTankard visual changes belong to the modelling stream; no merge in this audit. |
| `fix/wren-lace-fishnet-and-anatomy` | 19 / 169; 6 files | Workflow/site and Blender/review-tool changes belong to the modelling stream. Preserve; do not copy into the game branch. |
| `fix/male-anatomy-surface-sampling` | 1 / 148; 1 file | Blender male-anatomy tool change belongs to the separate anatomy stream. Preserve and leave untouched. |
| `fix/modular-outfit-review-material-duplicates` | 6 / 165; 2 files | Review renderer/workflow changes belong to the modelling pipeline. Preserve for that stream; no game-runtime merge. |
| `fix/anatomy-pelvic-landmark-port` | 0 ahead | No unique commits/files relative to current. Keep branch history. |
| `feature/runtime-tattoos` | 8 / 140; 3 files | Older Workshop workflow/docs/site snapshot; runtime tattoo support is already present in current. No re-port. |
| `feat/player-morphs-inventory-weapons` | 7 / 103; 7 files | Character pipeline/test inventory rather than production-ready campaign starting inventory. Keep for later visual and inventory review; do not ship its test loadout wholesale. |
| `feat/tapered-split-dress-v2` | 8 / 102; 5 files | No unique art path absent from current; hold its generator/output for visual fit acceptance. |

### Save/load, items, inventory and other previously compared branches

- `feature/save-load-system` remains a source/provenance branch. Its SaveManager and save/load menu are represented in current `dev_2`; the branch's eight-file compare is dominated by older README/project/HollowTankard/world-root snapshots and the already-integrated test/doc material. No re-port.
- `feature/hollowmere-items-and-inventory-art` has the same item icon atlas blob as current. ItemCatalog is already integrated; its CharacterPanel is older than the current panel, and its data/scene/test files are historical snapshots. No wholesale port; no missing icon atlas recovery.
- `feature/character-inventory-panel` remains an older UI iteration; current panel has evolved catalogue/equipment-change/scroll behaviour. Preserve for interaction history, not as a replacement.
- `feature/arena-and-full-character-roster` remains byte-identical for its arena data/roster validator/test contribution. No re-port.
- `feature/terrain-character-grounding-test`, `feature/port-action-economy`, `fix/anatomy-pelvic-landmark-port`, `feature/ara-skeleton-animation-validation` and `feature/ara-visual-animation-review` currently have zero commits ahead of `dev_2`; their branch names remain preserved, but they do not represent unmerged code at this baseline.
- `feature/equipment-gameplay-stat-integration` is the old source lineage for PR #124. Its relevant equipment rule changes are already integrated; do not merge the old branch.
- `feature/combat-initiative-timeline` remains already integrated and wired; its old preview workflow and capture files are not proof of a missing runtime timeline.

### Integration branch disposition

- `integration/campaign2-world-dev2`, `integration/animal-riding-dev2`, and `integration/equipment-heraldry-dev2` are the source branches for merged PRs #125–#127. Keep as merge provenance; do not re-merge.
- `integration/equipment-rules-dev2` is the source for merged PR #124. Keep as provenance; do not re-merge.
- `integration/two-storey-tankard-dev2` and `integration/vision-foundation-dev2` are the sources for previously merged building/door and vision foundation work (#119/#122). Keep as provenance; do not re-merge.
- `integration/save-load-dev2` contains save/load integration work already represented in current; no additional merge from the stale branch.
- `integration/opening-cinematic-dev2` remains the live head for draft PR #121. It is not merged; visual acceptance remains the blocker.
- `integration/hollowmere-dev-visual-review`, `integration/hollowmere-npc-visuals`, `integration/hollowmere-world-simulation` and `integration/wren-modular-clothing` have zero commits ahead of current `dev_2`; preserve as historical integration snapshots.

### What this pass does not sign off

This pass adds dispositions for the small/focused branches above, but it does not certify the full 134-branch inventory complete. The remaining deployment variants, diagnostics, test-only branches, large character assembly/anatomy sources and every current open PR still need final per-branch records for unique assets/tests, workflow head SHA and dependency relationships. Stage 1 remains open.


## Test, CI, source-parity and remaining world-system branch pass — 12 November 2026

### Test-only branches

| Branch | Fresh compare | Exact check | Disposition |
|---|---:|---|---|
| `test/save-manager-hardening` | 1 / 8; 1 file | `tests/test_save_manager.gd` is byte-identical to current `dev_2`. | Already represented; no port. |
| `test/save-restore-scene` | 6 / 7; 4 files | Its boot/runner files are an older snapshot; the current runner/boot files are present and have evolved. | No wholesale port. Retain history. |
| `test/save-restore-scene-dev2` | 15 / 6; 6 files | Its save-restore runner and boot scene are byte-identical to current; `tests/diagnose_tavern_script_load.gd` is also byte-identical to current. Its HollowTankard/workflow changes are older snapshots. | Already represented; no port. |
| `test/additional-skill-effect-coverage` | 3 / 27; 1 file | The branch's whole old test file is superseded, but it contains higher-rank Fast Movement and Goblin Opportunist test values (rank 2) not used verbatim in current tests. Current tests include broader vision, status-effect, parry, sidestep and lifecycle coverage. | Preserve as an additional rank-scaling test source. Do not replace current test file. If extended later, adapt the rank-2 cases to current fixtures and assert exact scaling at ranks 1 and 2. |
| `ci/enable-dev2-validation` | 1 / 10; 1 file | Old validation workflow; current workflow is materially broader and is already configured for the current integration baseline. | Superseded; no port. |
| `ci/incremental-character-pipeline` | 30 / 164; 10 files | Older export/workshop workflow, anatomy scripts, site and custom loading shell. It overlaps the separate character pipeline stream; current Pages workflow is more advanced. | Preserve as pipeline history. Do not merge stale workflow or Blender snapshots into the game. |
| `test/chatgpt-session-write-access-20261105` | Not a production test candidate | Session/tool-access branch only. | Preserve as operational history; do not merge into the game. |

### Workflow consolidation, repository hygiene and deployment cleanup

- `chore/consolidate-preview-and-review-workflows` compares 7 / 158 with seven changed workflow/doc files. It removes historical workflows and consolidates older preview jobs, but those deletions are based on a previous workflow topology. Current `dev_2` has a more capable independent character/workshop/export workflow set.
  - **Disposition:** retain the workflow-consolidation rationale and `docs/CI_WORKFLOWS.md` as a reference; do not apply its historical deletions wholesale. Reconcile each current workflow's triggers/artifacts against the intended deployment branch separately.
- `chore/remove-huggingface-deployment` compares 2 / 167 and only deletes the old HF storage/reset workflows. Those workflows are absent from the current tree and GitHub Pages is now the deployment target.
  - **Disposition:** already reflected in current deployment state; no port.
- `chore/repository-formatting-rules` compares 2 / 65. Both `.editorconfig` and `.gitattributes` are byte-identical to current `dev_2`.
  - **Disposition:** already integrated; no port. Formatting enforcement remains a separate question because existing GDScript files have not all been normalised.
- `ci/incremental-character-pipeline` and `chore/consolidate-preview-and-review-workflows` are not evidence that current Pages deployment should be changed. The previously recorded `dev` versus `dev_2` source mismatch remains unresolved by design.

### Source parity and mechanics documentation branches

- `docs/content-census` compares 2 / 59 and adds `docs/CONTENT_CENSUS.md` plus an older `docs/CONTENT_PARITY_AUDIT.md`. The census file is not present in current `dev_2`; it is a source-content inventory, not runtime code.
  - **Disposition:** preserve as a valuable source reference. Reconcile against current source repositories and the current 22-NPC roster before deciding whether to port a revised census. Do not merge the stale parity checklist unchanged.
- `docs/content-parity-audit` is a separate one-commit documentation branch with a 607-line parity checklist, also based on old `dev`. It overlaps the census branch's parity document but has its own content.
  - **Disposition:** preserve both documents until their unique source findings are reconciled; then publish one current, dated parity baseline rather than merging duplicate historical documents.
- `audit/spell-parity-and-test-findings` adds `docs/SPELL_PARITY_AUDIT.md`; current `dev_2` already has a later/different version of that path. The branch document is not a reason to restore old spell status.
  - **Disposition:** preserve as source notes; reconcile only genuinely missing spell definitions or tests against current data and runtime. Spellcasting remains unimplemented as a complete runtime loop.
- `audit/skill-effect-parity-update` and `audit/skill-effect-branch-cross-reference` modify the existing `docs/SKILL_SPELL_IMPLEMENTATION_AUDIT.md`. The current document has evolved; the branch versions contain older references/status rows.
  - **Disposition:** no document replacement. Review any branch-only source citations or test cases before finalising the current audit.
- `audit/skill-spell-implementation-baseline` has zero commits ahead of current `dev_2`; it is an ancestor/snapshot only.
- `feature/legacy-porting-matrix`, `feature/legacy-porting-matrix-dev2` and `feature/mechanics-port-foundation` are documentation-only historical snapshots. Current `LEGACY_PORTING_MATRIX.md` and `MECHANICS_PORT_REGISTER.md` are already present and have evolved. Preserve the older branch notes as provenance; do not overwrite current registers.

### Game-start, audio and cinematic lineages

- `feature/skill-magic-foundation-current-dev` has zero commits ahead of current `dev_2`; no port.
- `feature/game-start-race-class` and `feature/game-start-race-class-validation` point to the same branch head and are the same older implementation lineage (11 / 141, 11 changed paths). Their creation-rules data/script, CharacterState, CombatRules, creator, panel, scene and tests are older snapshots. Current creation and simulation systems have evolved.
  - **Disposition:** preserve both names/history; no wholesale port or replacement.
- `feature/legacy-audio-menu-dev` and `feature/legacy-audio-menu-dev2` are two iterations of the same audio/menu foundation. The following paths are byte-identical to current `dev_2`: `scripts/audio/audio_manager.gd`, `tools/import_legacy_audio.py`, `scenes/main_menu.tscn` and `scenes/arena/arena_placeholder.tscn`. The current `scripts/ui/main_menu.gd` is newer than the branch snapshot. Audio binary assets are fetched by the importer rather than committed as branch binaries.
  - **Disposition:** foundation already integrated/evolved; no re-merge. The arena scene remains a placeholder and should not be mistaken for a completed arena mode.
- `feature/hollowmere-ironbond-opening-cutscene` is the older cinematic source line. Its director/actor/scene changes were reapplied to current `dev_2` as PR #121. Keep the old branch as provenance; visual acceptance belongs to #121, not this older branch.

### Wilderness, forest and environmental asset branches

- `feat/wilderness-art-and-gatherable-visuals` compares 18 / 123 with 11 changed paths. Its `wilderness_resource_visual.gd`, visual test, and Kenney asset-fetch script are all byte-identical to current `dev_2`. Its modified seasonal/resource/world/scene/test files are older snapshots.
  - **Disposition:** wilderness gathering visuals and validation are already represented; no port.
- `feat/wilderness-world-foundation` compares 9 / 126 with six changed paths. `hex_world_chunk_streamer.gd` is byte-identical to current. Its `wilderness_resource_system.gd` is an older version of the current file; WorldSimulation and HollowTankard are older snapshots.
  - **Disposition:** no re-port; preserve as architecture lineage.
- `feat/seasonal-wilderness-visuals` compares 5 / 125 with four changed paths. The current `seasonal_tree_visual.gd` is longer/evolved and supports imported Kenney Nature Kit assets with procedural fallback; the branch version is older.
  - **Disposition:** already evolved in current; no port.
- `feature/hollowmere-cosmo-forest` contains the Cosmo addon/demo and generated tree collection. The previous recursive-tree/blob audit found that generated GLBs and their runtime paths are already in current `dev_2`. The remaining addon/demo files are generator provenance and are not required to use the accepted generated assets.
  - **Disposition:** follow the user's direction: no need to recover evaluation/gallery/regeneration tooling. Preserve source branch as provenance; do not merge its large addon/demo payload.

### Final caveats for this pass

- The old skill-effect branch has a small number of rank-2 test cases worth retaining, but current test coverage is substantially broader. This is a test-design note, not a current CI failure.
- Several branches with nonzero ahead counts are simply alternate historical documents or snapshots. Compare ancestry alone must not drive a merge.
- No test, CI, documentation, audio, or wilderness branch was merged during this pass. All original branch refs remain intact.


## Additional remaining branch families — 12 November 2026

### Fog of war, campaign journal, NPC workshop and companion model

- feature/vision-stealth-perception compares 27 / 57 with seven changed paths. The current VisionRules LOS/range foundation is already represented by merged PR #122, but this source branch also has distinct scripts/presentation/fog_of_war.gd, tests/test_fog_of_war.gd and docs/VISION_STEALTH_PORT.md. These are not equivalent to the current LOS foundation.
  - **Disposition:** preserve as a high-value deferred salvage source. Do not merge the stale WorldSimulation/HollowTankard or the old vision implementation wholesale. Before porting fog presentation, design explored/known state, observer knowledge, save/load representation and interaction with campaign map discovery. PR #96 remains open against old dev; its latest recorded workflow failed/no current-head pass. Revalidate on a fresh dev_2 integration branch only after that design.
- feature/campaign-quest-journal compares 5 / 138 with four changed paths. Its CampaignJournal, WorldSimulation and tests are older snapshots; current journal is substantially longer and includes faction knowledge, NPC standings/knowledge, merchant influence and expanded persistence/event handling.
  - **Disposition:** no wholesale port. Preserve any distinct quest text/test scenario as source material; current journal remains canonical.
- feature/reusable-npc-workshop compares 5 / 361 with five changed paths. The older modular assembler is not current, but tools/ara/build_npc_previews.py and tools/ara/npc_profiles.json are distinct absent preview/profile tooling for a reusable NPC roster.
  - **Disposition:** preserve as a deferred tooling candidate. Adapt its inputs/outputs to the current canonical 22-character manifest and whichever resolver/assembly contract is ultimately accepted. Do not revive its old assembler or Wren/HF workflow.
- feature/ser-aldric-first-companion-model compares 7 / 106 with five changed paths. data/characters/companion_models.json and docs/FIRST_COMPANION_MODEL.md are distinct absent paths; no companion-model GLB binary path is present in that branch tree. Its builder/armour tools need comparison with the current Ara pipeline.
  - **Disposition:** retain as model/companion provenance, not as a finished model delivery. No separate companion registry until the current character assembly design is settled; verify the actual generated GLB and rig/armour visually before accepting it.
- feature/farmstead-bear-creature-model compares 27 / 31 with five changed paths. Its distinct farmstead_dire_wolf_encounter.gd service remains absent from current, although its companion content, scene and tests are old snapshots.
  - **Disposition:** preserve as a separate Tessa rescue/dire-wolf quest salvage candidate. Fix the double-applied Health ranks and restore all characters' prior dormancy/side state; reconcile quest/journal and canonical companion IDs before any selective port. Do not copy its old HollowTankard or campaign content snapshots.

### Character presentation and anatomy review branches

These remain in the parallel character/anatomy stream and are inventoried only to protect their history.

- feat/ara-shields-helmets-hairstyles compares 15 / 106 with seven changed paths: two armour-prop workflows, equipment pipeline documentation, two asset tests and Blender weapon/armour builders. It overlaps feat/ara-hairstyles-medieval-equipment and the separate modelling stream.
  - **Disposition:** preserve. Do not merge workflow, asset generator or actor changes through this audit. Visual/rig/fit acceptance remains the correct gate.
- feature/male-anatomy-geometry-review compares 5 / 151 with three workflow/site/Blender-tool paths. It belongs to the current anatomy review lineage.
  - **Disposition:** preserve and leave untouched by the integration audit.
- feature/player-character-visual-phase1 compares 12 / 128 with five changed paths. It adds an older player-visual phase document and changes Ara actor, creator, HollowTankard and export workflow snapshots; current actor/creator are evolved.
  - **Disposition:** retain as design history; do not replace current player/actor code. Any unique acceptance criteria in the document should be reconciled with the current male/female base + morph direction by the modelling stream.
- feature/hollowmere-building-port-spec compares 39 / 58 with nine changed paths, but its building registry, door-state persistence, simulation hooks, specification and tests are the source of the already-merged two-storey building/door foundation (#119).
  - **Disposition:** already integrated. Keep as provenance; no re-merge.
- feature/hollowmere-cosmo-forest is the large addon/generated-tree branch. The user's explicit exclusion applies to its generator/evaluation/gallery tooling; generated assets are already in current. No merge.
- feature/skill-magic-foundation-current-dev and the older audit/skill-spell-implementation-baseline are zero-ahead snapshots; no port.

### Follow-up constraints

- Fog of war is the only newly confirmed deferred vision deliverable in this group; it is not equivalent to the LOS code already merged. Keep it separate from the current branch-audit task until the save/discovery state contract is decided.
- NPC preview generation and the dire-wolf quest are genuine absent-path candidates, but both depend on current canonical NPC/quest state and should not be ported from their old scene snapshots.
- No branches in this group were merged or closed. Original feature branches remain intact.


## Final unmentioned branch-name pass — 12 November 2026

- feat/campaign-loading-feedback compares 1 / 105 with one WorldRoot change. Current WorldRoot has since evolved; the branch's loading overlay is an earlier loading-stage implementation. Preserve as UX history; do not replace current scene transitions.
- feat/character-preview-loading-progress compares 3 / 104 with one PlayerCharacterCreator change. The current creator includes the threaded resource loading progress, per-asset status and failure reporting from this lineage, with additional body/hair readiness states. No re-port.
- feature/audio-and-mode-select is the earlier PR #5 lineage. AudioManager, legacy importer, main-menu/arena scenes and migration doc are represented in current; main_menu.gd has evolved. Arena remains a placeholder. No re-merge.
- feature/iphone-web-preview-pipeline has zero commits ahead of current dev_2. No port; preserve its historical branch ref.
- feature/main-campaign-world-map-validated has the same head SHA as feature/main-campaign-world-map and the same 12 / 140, eight-file compare. Treat as duplicate validation alias for the same lineage; current map implementation is already represented. No separate integration.
- feature/wren-anatomy-piercings-halter-fit is the 179-commit source branch for open PR #8. Its 24 changed paths are a large historical Wren/modular clothing/anatomy pipeline, including Blender tools, review renderer, workflows, accessory/appearance helpers and workshop content. This is within the user's separate character/clothing/anatomy stream. Preserve untouched; no merge or PR closure from this audit.
- fix/skill-effect-test-rank-fixtures compares 1 / 25 with one test file. It is an older test_simulation.gd snapshot; the rank-1 expectations and core cases are represented in current tests, while the broader current suite has additional vision/status/reaction/lifecycle coverage. No wholesale test replacement; preserve as test-history.

The branch-name reconciliation now confirms that all 134 live branch names are mentioned in this register (the audit branch itself is the document's own source branch). This is a name-coverage check only: it does not mean every branch has had full tree/blob/CI/asset review or that Stage 1 is complete.


- audit/feature-branch-consolidation is this audit's own working branch and the source of PR #123; it is a documentation-only recovery record targeting dev_2. Keep the PR draft until the full audit is signed off.


## Open pull-request evidence refresh — exact current heads, 12 November 2026

Refreshed from the live open-PR list and commit-specific PR-triggered workflow queries. A zero-run result means the query returned no PR-triggered run for that exact head SHA; it does not prove no manual run ever occurred. Successful CI is not visual acceptance.

| PR | Head SHA | Base | Exact-head PR workflow evidence | Current action/disposition |
|---:|---|---|---|---|
| #123 | 40017e46c1e6c6367532e5b0ee6667b338f33f3c | dev_2 (base SHA 143e1b0, now stale) | No PR-triggered run | Draft documentation audit. Keep draft until full Stage 1 sign-off; update/reconcile against current base before merge. |
| #121 | a614c6e802d5b0aadbb242cb2b7f47324640715c | dev_2 (base SHA 585f914, now stale) | Godot validation passed, run 43151102411 | Hold for PC visual playtest. Before merge, refresh against current dev_2 head 374d4a2 and rerun validation; confirm actual GLB clips, actor alignment, camera and skip. |
| #110 | 1c2a1039c01b691d6a8408d08b56cde56fb62cbd | dev | No PR-triggered run | Runtime riding selectively superseded by #126; preview workflow/capture remains a distinct candidate. Keep open until its preview disposition is settled; do not merge old simulation snapshots. |
| #99 | 30672f5c54623fabe0bf37792fed11e275042f51 | dev | Godot validation passed, run 42987629965 | Preserve Tessa rescue/dire-wolf quest as selective salvage; fix health/dormancy lifecycle defects and port against current journal/companion state only after Stage 1. |
| #96 | 06db693c101f059c469e15a6ff87a16b2d9c25db | dev | No PR-triggered run | Current LOS foundation is #122; fog-of-war presentation/test remain distinct. Do not merge wholesale; design explored/known save-state first. |
| #90 | ab312d52e535a7cd068c9219636c9d3c05e9765f | dev | No PR-triggered run | Historical skill/magic source; no wholesale merge. Current runtime/data evolved; spellcasting still requires separate implementation. |
| #89 | 12d2f4677c78890a634e4d1b88d70caa84fb2f50 | dev | No PR-triggered run | Content census/parity docs are useful but stale. Reconcile into one current doc; do not merge unchanged. |
| #88 | 717ca26d21448aebede343a1fb58e955a128f168 | dev | Audio/mode pass 42994733145; character pipeline pass 42994727840; initiative pass 42994728267; Godot validation failed 42994727983 | Campaign 2 source data/builders/previews selectively recovered by #125. Keep other unique content/provenance; fix strict-runner/material test defect rather than weakening checks. |
| #87 | 85291ecc6b453e64e436ea5ad8a5caaea712e725 | dev | No PR-triggered run | High-value character assembly source, but no wholesale merge: 14-vs-22 NPC migration, absent body/garment assets, resolver validation/idempotency and base-body strategy remain. Parallel modelling stream owns acceptance. |
| #77 | 406c601280a3a407fb6bc4978aa2be8507471d02 | dev | Character pipeline passed, run 42523557776 | Hold for dress render/fit review; no unique art path missing from current tree. |
| #76 | 7124ad01a4b1ac4eaa151d349a9970689e3b758f | dev | Character pipeline passed 42522266864; Godot passed 42522266845 | Helper/shader/test slice already merged via #127. Do not merge old PR; remaining mesh/actor modelling stays separate. |
| #74 | 194b0b30eb5efd9de06281bc561e00ea466a7991 | dev | Character pipeline passed 42476563807; Godot cancelled 42476563828 | Development/test inventory only. Not production-ready campaign starting inventory; no merge. |
| #73 | 4b0bbfb2814d52d2c5e1d8f1ba14485d9024b6ee | dev | Character pipeline passed 42473677508; Godot passed 42473677553; Hollowmere Ara build failed 42473677510 | Hold companion model pending asset workflow repair and visual/rig/armour review; no completed GLB path confirmed. |
| #34 | 6a19ae285689c39a9df909ec7751575a42f13d17 | dev | Village validation passed 42408658352; Godot/Blender passed 42408658216; screenshot capture passed 42408658331 | Historical workflow consolidation only. Do not apply deletions to current workflows wholesale. |
| #29 | 8956d001f9891bca7350e34520c4b9b7e3759579 | dev | No PR-triggered run | Creator UI is an older snapshot; retain as design lineage, no wholesale merge. |
| #26 | 4d7fe0ed4288ac4159d7d981984d5507803f822a | fix/dress-selector-and-loading-review | No PR-triggered run | Stacked pipeline/cache branch; preserve and split/revalidate only if a concrete current pipeline gap remains. |
| #25 | 345f08b60083392a2510629ada6e916f1f32fac4 | dev | Village validation passed 42342623831; screenshot capture passed 42342623865; Godot/Blender passed 42342623840; male anatomy blockout passed 42342624135 | Hold for source/visual review; split deployment from anatomy/clothing; current base has evolved. |
| #8 | b8a401cd883c41cbf70c095af783fe018c7ff9a0 | dev | No PR-triggered run | Large Wren anatomy/modular clothing source belongs to the parallel modelling stream. Preserve; no merge here. |
| #5 | a563b16b700131115f7506faf19998b570bdc6b2 | dev | Audio and mode validation passed, run 42159015364 | Audio/menu foundation is already integrated/evolved; Arena remains placeholder. No re-merge. |

Current dev_2 head at this refresh: 374d4a2894e0c118c4a35d075a23ca568ff51209. All PRs above remain open as observed in the live listing; this refresh did not merge or close any PR. The only PR currently targeting dev_2 besides this audit is #121; its base commit predates #125–#127, so a successful older workflow must not be treated as merge approval on the current baseline.


### Final focused workflow exception: fix/ara-review-crash-remove-legacy-wren-build

A direct source comparison of this branch's workflows against current dev_2 resolves the earlier open question:

- Its wren-workshop workflow is 522 lines; current dev_2 is 687 lines and includes additional JavaScript validation, packaging and review safeguards. Both generate Ara assets; the old branch does not contribute a unique current Ara build capability.
- Its godot-web-export workflow is a 131-line early exporter; current dev_2 uses the 329-line combined game/Workshop/props Pages workflow. The branch's exporter is an earlier version of the same lineage as feat/wren-only-pages-two-character-workshop.
- The current workflow contains no separate legacy Wren model build to remove; it already builds/consumes the Ara runtime package. No unique crash fix was identified that is absent from current validation.
- **Disposition revised:** superseded workflow history; preserve the branch, no merge. Do not replace current workflows with its older copies.


## Cross-PR dependency and integration-order map — 12 November 2026

This is the practical dependency map for avoiding duplicate or order-sensitive merges. It distinguishes already recovered code from still-open historical PRs.

| Source PR/branch | Depends on / overlaps | Current integration consequence |
|---|---|---|
| #124 / feature/equipment-gameplay-stat-integration | Current CharacterState, ItemCatalog and CombatRules | Equipment slot/two-handed/helmet rule slice is already merged. Do not re-merge #91. |
| #125 / feature/full-world-port-foundation | Current HexMapData, WorldRoot, Campaign2/world data | Campaign2 data/builders/previews are already merged. Other stale simulation/scene snapshots remain untrusted. |
| #126 / feature/animal-riding-validation | Current CharacterState, WorldSimulation, CreatureActor, save/load and lifecycle APIs | Riding runtime is already merged. Its original PR #110 is not a second integration candidate; only the preview capture remains to decide. |
| #127 / feat/equipment-materials-heraldry | Current equipment definitions and later Ara actor/equipment presentation | Helper/shader/test are already merged. Runtime asset wiring belongs to the separate modelling stream. |
| #121 / integration/opening-cinematic-dev2 | #119 two-storey tavern/building, current HollowTankard scene, Ara animation assets | Visual review only. Refresh against latest dev_2 before merge because its base SHA predates #125–#127. |
| #110 / feature/animal-riding-validation | #126 selectively supersedes simulation payload; preview capture is a separate visual-only candidate | Keep open until preview disposition; do not merge old WorldSimulation/CharacterState snapshots. |
| #99 / feature/farmstead-bear-creature-model | #90 older skill/companion/quest content; current CampaignJournal and canonical companion IDs; #126 animal profile only if reused | Port only Tessa quest-state/encounter service after lifecycle fixes. Do not copy old HollowTankard or quest-content snapshots. |
| #96 / feature/vision-stealth-perception | #122 already supplies spatial VisionRules/LOS; current save/load and campaign map discovery contract | Fog-of-war is still a distinct candidate, but requires a persistence/knowledge design before implementation. |
| #90 / feature/skill-magic-foundation | #99 quest content, companion/NPC progression, current CharacterState/SkillProgression | Preserve as source history. No wholesale merge; spell JSON is not a working casting system. |
| #87 / feature/unified-character-assembly | feature/anatomy-geometry-revision, feature/shared-character-system, feature/modular-character-poc, #8, #25, #29, #73 | Major architecture candidate with conflicting body-profile/schema assumptions. Decide one-base-plus-morphs, migrate all 22 NPCs and validate assets before any selective port. |
| #8 / feature/wren-anatomy-piercings-halter-fit | #25 dress/loading pipeline, #87 assembly schema, active Ara anatomy stream | Parallel modelling/anatomy history only. Preserve; no wholesale merge. |
| #25 / fix/dress-selector-and-loading-review | #8 Wren garment work, #26 incremental pipeline, current Ara actor/creator | Historical pipeline; split browser/deployment from garment/anatomy before any salvage. Visual acceptance required. |
| #26 / ci/incremental-character-pipeline | Stacked directly on #25 | Do not merge as an independent production branch. Reconcile only after #25's useful workflow changes are isolated. |
| #76 / feat/equipment-materials-heraldry | #127 already recovered helper; separate armour/helmet modelling | No second helper merge. Keep remaining modelling changes out of this audit. |
| #73 / feature/ser-aldric-first-companion-model | Current Ara character builder and eventual assembly resolver (#87); companion identity/manifest | No model acceptance: binary GLB path absent. Do not add a parallel companion registry prematurely. |
| #74 / feat/player-morphs-inventory-weapons | Current ItemCatalog, player starting loadout and creator | Test inventory only; do not replace campaign starting gear/loot/shop logic. |
| #77 / feat/tapered-split-dress-v2 | Current garment pipeline and base-body/morph acceptance | Hold for rendered fit review; no default garment replacement based on CI. |
| #34 / chore/consolidate-preview-and-review-workflows | Current independent character, Ara, prop, export and Pages workflows | Workflow cleanup must follow current artifact dependencies; do not apply its historical deletions. |
| #89 / docs/content-census | docs/content-parity-audit and current source content/22-NPC manifest | Reconcile into one current source census; don't merge stale duplicated documents unchanged. |
| #5 / feature/audio-and-mode-select | Current AudioManager/importer and main-menu flow | Already integrated/evolved; no dependency blocker for current gameplay. Arena remains placeholder. |

### Safe integration order already completed

1. #119 building/door foundation → #120 restore test → #122 vision/LOS foundation (historical baseline).
2. #124 equipment gameplay rules → #125 Campaign2 world data/previews → #126 animal/riding simulation → #127 equipment appearance helper. All are now in current dev_2 and their original feature branches remain intact.
3. #121 is the only currently open PR targeting dev_2 that is a gameplay/presentation candidate; keep it isolated for visual acceptance and then refresh/revalidate against current dev_2.

### Deferred recovery order after Stage 1 sign-off

- First resolve architecture and schema direction for #87 and its predecessor branches before importing any NPC/garment assembly code.
- Keep #99 quest and #73 companion work dependent on current canonical quest/companion IDs and the accepted character pipeline.
- Design fog-of-war persistence/knowledge before extracting #96's fog presentation.
- Only then consider remaining 2D mechanics and new features, in accordance with the user's priority order. This dependency map is a preservation/recovery aid, not approval to start those feature ports now.


## Large orphan character, village and mechanics branches — focused review, 12 November 2026

### Opening village and iPhone Ara preview lineage

- `feature/opening-village` compares 194 ahead / 361 behind with 35 paths; `feature/iphone-hollowmere-ara-preview` compares 178 / 361 with 36 paths. They share the same 13-NPC appearance manifest and most of the same Ara/village code lineage. The iPhone branch adds `iphone-hollowmere-ara-preview.yml`, `export_presets.cfg` and `tools/deploy_web.py`; the deploy script targets the old Hugging Face Space (`Thisisausername836/silverhart-saga-3d`).
- Both manifests contain only 13 NPCs: Wren, Garrick, Mira, Oskar, Wick, Dray, Tomlin, Hask, Yvette, Hendra, tavern patron, Elder Marta and Rowan Fletcher. Current `dev_2` has 22 records, including the player and eight later companion/quest characters. Do not replace the current manifest with the older 13-record version.
- Their `scripts/world/hollowmere_village.gd` is an earlier 220m blockout snapshot; current `dev_2` has a 420m village presentation with organic world features, imported tree support, creature actors and later settlement evolution. Their `world_root.gd`, Hollow Tankard, Ara actor and accessory/appearance files are also older architectural snapshots.
- The branch family contains distinct old Blender/GLB assembly and character appearance tooling, but it overlaps `feature/shared-character-system`, `feature/unified-character-assembly` (#87), and the parallel anatomy/modelling stream. It is not a second independent runtime implementation to port.
- **Disposition:** preserve both branches as provenance and historical iPhone preview lineage. No code merge. The old HF deployment script is superseded by the current GitHub Pages pipeline; don't restore it. Reuse any unique modelling/assembly ideas only through the agreed one-male/one-female base plus morph workflow and after visual acceptance.

### Shared character system and modular-character proof of concept

- `feature/shared-character-system` compares 125 / 361 with 18 paths. It is largely the same early Ara character-appearance/accessory-attachment lineage as the opening-village branch; its unique path set is smaller, not a more current alternative.
- `feature/modular-character-poc` compares 51 / 361 with 17 paths. It adds distinct `CharacterAccessoryFactory`, `CharacterAttachmentRig`, `CharacterAppearanceStore`, socket calibration data and a garment shader, plus Blender/TypeScript preparation tools. These are genuine prototype artifacts, but overlap the later unified assembly resolver (#87) and the current separate modelling workstream. They do not establish that their attachment or garment pipeline is the accepted production contract.
- **Disposition:** retain both. No runtime port now. During priority-2 architecture review, compare the modular POC's separation of appearance data, attachment rig and factory with the #87 resolver and current Ara actor; select one coherent design, don't combine duplicate parallel systems. Any shader/asset tool recovery should be a separate, tested change after model/garment compatibility is demonstrated.

### Missing skill runtime port

- `feature/missing-skill-runtime-port` compares 21 / 15 with eight changed paths. `skill_progression.gd`, `character_creation_rules.gd`, `simulation_action_request.gd` and `player_character_creator.gd` are byte-identical to current `dev_2`. Its `combat_rules.gd` is older: current adds equipped-helmet reduction and on-hit StatusEffectRules integration. Its `CharacterState` is an older 402-line snapshot; current is 529 lines and includes persistent status/debuff and animal/mount state. Its `tests/test_simulation.gd` is also an older 1,762-line snapshot versus the current 2,162-line suite.
- The source branch's unique `WorldSimulation` code is an earlier movement-reaction implementation. Current `dev_2` has evolved movement reactions with exclusions, building-floor handling, animal/mount integration, and additional simulation APIs; the branch's lifecycle handler is also older.
- **Disposition:** superseded by current simulation evolution; no cherry-pick or merge. It does not contain a missing skill runtime payload that should be recovered independently. Preserve as historical intermediate port work. The broader missing stealth/spell mechanics are separately tracked gaps, not evidence that this branch should be merged.

### Character inventory panel and arena roster

- `feature/character-inventory-panel` compares 14 / 143 with eight changed paths. Its `scripts/ui/character_panel.gd` is an older 263-line UI snapshot; current `dev_2` panel is 317 lines and adds ItemCatalog integration, `equipment_changed` signalling and scroll-position preservation. Its CharacterState/CombatRules/MovementRules/WorldSimulation/HollowTankard/test snapshots are older than current. No unique UI feature was identified that is missing from the current panel.
- `feature/arena-and-full-character-roster` compares 7 / 108 with seven changed paths. Arena opponent data, legacy enemy roster, named NPC roster, roster validator/tests and roster documentation are already represented in current `dev_2` (same data/test lineage); workflow differences are older validation snapshots. Arena gameplay remains a placeholder, not a missing roster port.
- **Disposition:** no merge for either branch. Preserve as provenance; future Arena gameplay is a separate feature after priority-1 audit and mechanics port planning.

### Active anatomy branches — compare only for audit boundaries

- `feature/anatomy-geometry-revision` is now 206 ahead / 61 behind with 34 changed paths; it includes body-profile/schema changes, resolver, NPC manifest edits, garment library and anatomy validation/review tools. `feature/male-anatomy-skinned-mesh` is 143 / 361 with 21 changed paths and shares the earlier Ara actor/appearance/tooling lineage; `feat/ara-hairstyles-medieval-equipment` is 33 / 106 with 182 paths, including extensive male/female hair GLBs/textures, equipment prop tools and validation workflows.
- These are live parallel modelling/anatomy deliverables. The first branch overlaps #87's character assembly/schema migration, while the latter two include sizeable asset sets that must be reviewed as actual model/texture files, not inferred from filenames. Do not merge, rewrite or prune them during this code-preservation pass. Their binary asset acceptance and body/clothing fit belong to the separate visual review stream.

### Current conclusions from this group

- The early Hollowmere/Ara branches are not a safe source for current NPC manifests or village code: 13 NPCs and a small blockout versus the current 22-NPC manifest and evolved village.
- The modular POC has unique architecture prototypes worth evaluating later, not code to merge before the architecture decision.
- The missing-skill branch is superseded, and the inventory panel/arena roster work is already represented in current `dev_2`.
- No branches in this group were merged or closed; all historical refs remain intact.


## Combat, Ara validation and remaining diagnostic branches — focused review, 12 November 2026

### Animal attributes predecessor

- `feature/animal-attributes` compares 29 / 27 with ten paths and is the direct predecessor to `feature/animal-riding-validation` / PR #110. Its `animal_catalog.gd`, CharacterState and WorldSimulation snapshots are superseded by the selective runtime implementation merged in PR #126. The distinct `riding-preview.yml` and `capture_riding_preview.gd` are the same fixed-offset prototype preview workflow already noted under #110.
- **Disposition:** no merge. Preserve as the earlier source lineage for #126; no separate animal-attribute feature remains to recover.

### Hollowmere shakedown combat

- `feature/hollowmere-shakedown-combat` compares 50 / 131 with eight paths and contains a distinct `scripts/simulation/hollowmere_encounter.gd` plus a focused `_test_hollowmere_encounter()` suite. It stages Garrick, Mira and Oskar as allies against Dray, Tomlin and Hask; it uses current-style WorldSimulation attack resolution and completes the fight choice in the shakedown quest.
- The branch also contains a broad old `HollowTankard` snapshot (1,528 lines) that adds encounter orchestration, combat UI/targeting and soldier movement. Its `CampaignJournal` is byte-identical to current `dev_2`; its campaign-content and ambient-chatter files are not safe to replace without line-level comparison. Its test file is much smaller/older than current (1,115 lines vs 2,162), so it cannot replace the current suite.
- **Known lifecycle concern:** `HollowmereEncounter.start()` marks every registered character dormant, then selectively wakes combatants. `finish()` restores its hard-coded allies/enemies and player-controlled IDs, but does not restore every noncombatant's prior `combat_dormant` and `side` values. The quest wrapper also needs to prove the encounter is safely resumable/serializable and handles player/companion defeat, cancellation and scene exit.
- **Disposition:** preserve as a high-value deferred quest/combat integration candidate, not a ready merge. It depends on the current campaign journal, current CharacterState/WorldSimulation, current 22-NPC manifest and #126 animal/mount changes. After Stage 1, selectively port the encounter state machine and tests; do not copy the old HollowTankard, combat rules, journal or test snapshots wholesale. Fix state restoration and verify target selection/AI before calling the fight branch playable.

### Combat reaction and resolution lineage

- `feature/combat-reaction-triggers` (8 / 149; four paths), `feature/ally-combat-reactions` (7 / 145; four paths), `feature/movement-reactions` (8 / 144; five paths) and `feature/reaction-resolution-turn-safety` (4 / 151; four paths) are older intermediate changes to CharacterState, WorldSimulation, reaction prompt and tests. Current `dev_2` already includes the evolved combat and movement reaction resolver, ally/defender options, sidestep destination validation, reaction prompt and turn-safety/lifecycle handling. Their changed mechanics are represented in the current larger WorldSimulation and test suite; no missing source-only reaction API was identified in this pass.
- `feature/combat-resolution-foundation` (36 / 158; 18 paths) is an older broader combat implementation with old CombatRules/CharacterState/WorldSimulation/test snapshots and historical workflow cleanup. Current combat includes later equipment mitigation, status-effect hooks, animal/mount state, and expanded tests. Its old workflow deletions must not be applied to current CI.
- **Disposition:** no wholesale merge or test replacement. Preserve these branches as development history. If a concrete regression is discovered later, port the isolated rule with a current-head regression test rather than importing an older simulation snapshot.

### Real Hollowmere character-art validators

- `feature/game-real-hollowmere-character-art` compares 6 / 163 with five paths. Its two new validators (`validate_hollowmere_models.py` and `.gd`) check generated GLBs and imported animation tracks, which is a useful type of CI coverage. However, the scripts hard-code a 13-NPC/14-total profile count and `art/characters/hollowmere/<id>.glb` layout, while current `dev_2` uses a 22-character manifest and an Ara runtime artifact workflow. The Python validator additionally requires the player-avatar role to be present in the source manifest, which differs from the older branch's 13-NPC assumptions.
- Its docs/workflow changes are an old 13-character generated-artifact setup and are not a safe fit for current runtime package paths or Pages deployment. The model validation idea remains useful, but must be adapted to the current 22-character manifest and exact artifact package contract.
- **Disposition:** preserve as validation design/source. Do not merge these validators unchanged; if the current Ara artifact pipeline lacks equivalent checks, write a fresh manifest-driven validator against its actual package and test it independently.

### Ara evaluation and pipeline branches

- `feature/ara-character-evaluation` compares 4 / 383 with four paths: adds an Ara evaluation doc and changes the Workshop workflow/site/art pipeline docs. It is older evaluation/documentation lineage; user has explicitly said Cosmo evaluation tooling is unnecessary, but this is Ara character evaluation, so preserve its review criteria as documentation if not duplicated. Do not restore its older Workshop workflow.
- `feature/character-pipeline-foundation` compares 2 / 529 and adds only `docs/CHARACTER_PIPELINE.md`; preserve as design provenance and reconcile any unique requirements into current pipeline docs, no runtime merge.
- `feature/ara-skeleton-animation-validation`, `feature/ara-visual-animation-review` and `feature/terrain-character-grounding-test` have zero commits ahead of current `dev_2`; no code recovery needed.
- `diagnostic/ara-garment-surface-report` and `diagnostic/ara-report-on-character-configure` each have one commit ahead and change only `scripts/presentation/ara_character_actor.gd`. They are narrow diagnostic experiments in the separate modelling stream. Preserve for reference; do not merge debug instrumentation into runtime without a concrete, reproducible need.

### Current disposition from this group

- #126 fully supersedes the animal-attributes predecessor for simulation/riding code.
- The shakedown fight is a meaningful unintegrated quest/combat candidate, but its encounter lifecycle and older scene snapshot need deliberate adaptation.
- Combat reaction/resolution branches are historical intermediate steps superseded by current code.
- The 13-NPC GLB validator is not safe to reuse unchanged; its manifest-driven concept may be adapted later.
- No branches in this group were merged or closed; original branch refs remain intact.


## Remaining campaign, save, equipment and world-system branches — focused review, 12 November 2026

### Action contracts, downed lifecycle and status effects

- `feature/action-contract-downed-lifecycle` compares 10 / 152 with nine paths. It introduced `SimulationActionRequest`, `SimulationActionResult` and `SimulationEvent`, but these contracts are already represented in current `dev_2`; its CharacterState/CombatRules/WorldSimulation/test files are earlier snapshots. No unique current action-contract capability was identified.
- `feature/status-effects-combat-debuffs` compares 10 / 14 with six paths. Its `status_effect_rules.gd` and related combat/status work are already represented in current code, with current tests extended for status effects and lifecycle; its older CharacterState/CombatRules/MovementRules/WorldSimulation/test snapshots must not replace current.
- **Disposition:** no merge. Preserve as implementation lineage; current dev_2 is the source of truth.

### Combat initiative timeline

- `feature/combat-initiative-timeline` compares 36 / 58 with eleven paths. Exact blob checks confirm `combat_initiative_model.gd`, `combat_initiative_timeline.gd` and `hollowmere_encounter.gd` are byte-identical to current `dev_2`. The remaining compare differences are older snapshots of action economy, CharacterState, WorldSimulation, HollowTankard and tests plus an older preview workflow.
- **Disposition:** already integrated/evolved; no re-merge. The original branch is preserved for provenance. Initiative is not a remaining merge candidate.

### Hollowmere items and inventory art

- `feature/hollowmere-items-and-inventory-art` compares 2 / 142 with nine paths. `ItemCatalog` and `art/ui/item_icon_atlas.svg` are byte-identical to current. Its item definitions differ from current, but the current catalogue includes later equipment slot/mitigation changes; its CharacterPanel and HollowTankard snapshots are older. Its `hollowmere_loadouts.json` is an older standalone loadout source, whereas current character definitions/inventory integration have evolved.
- **Disposition:** no merge. Do not replace current item definitions or UI with the old snapshots. If an icon is later found missing in the live UI, compare the SVG atlas content directly; the atlas itself is already present.

### Starting clothing and character creation

- `feature/character-starting-clothing` compares 12 / 67 with six paths, including an old loadout/item-definition snapshot, Ara actor and CharacterCreationRules changes, HollowTankard and a dedicated starting-clothing test. It overlaps the later player-creator, item catalogue and equipment-rule work. Its data/scripts are not a safe current baseline; compare its test intent only if a specific starting-loadout gap is identified.
- `feature/player-custom-avatar-selection` compares 1 / 68 with one HollowTankard change. Current HollowTankard already selects `player_avatar.glb` for a feminine player when available and falls back to the shared Ara female asset. No separate port required.
- `feature/game-start-race-class` and `feature/game-start-race-class-validation` have identical 11 / 141 comparisons and the same old character-creation lineage. Current CharacterCreationRules, player creator, CharacterState and HollowTankard have since evolved; no wholesale merge.
- **Disposition:** preserve these historical sources. Do not reintroduce old player-creation/loadout snapshots; use current code and the agreed base-body/morph direction.

### Campaign map and save/load

- `feature/main-campaign-world-map` compares 12 / 140 with eight paths. The main campaign map UI/data scripts are already represented in current; its WorldRoot/HollowTankard/player-creator snapshots are older. The validated alias has the same head and comparison. No re-merge.
- `feature/save-load-system` compares 26 / 15 with eight paths; `integration/save-load-dev2` compares 10 / 9 with nine paths. Both have `save_manager.gd` byte-identical to current. The old save test differs from current, which has evolved coverage; menu and scene wiring are also represented/evolved. Current system provides manual slots, quicksave and rotating autosaves.
- **Disposition:** save/load is already integrated. Do not replace current tests/menu/scene with old copies. Keep both branches as provenance; no merge needed.

### Buildings, geography, wilderness and seasonal visuals

- `feature/hollowmere-building-port-spec` is the source lineage for the two-storey building/door framework merged by #119. Current `BuildingRegistry` and related runtime files have evolved; no re-merge.
- `feature/organic-hollowmere-geography` compares 17 / 89 with five paths. Its organic-world feature script and village data/presentation have since evolved in current `dev_2`; do not replace current 420m village with its older geography snapshot.
- `feat/wilderness-world-foundation` compares 9 / 126 with six paths. WildernessResourceSystem, chunk streamer and simulation wiring are represented in current; current code has evolved. No re-merge.
- `feat/seasonal-wilderness-visuals` compares 5 / 125 with four paths. Current `SeasonalTreeVisual` is an evolved version supporting imported Kenney Nature Kit assets and procedural fallback. No re-merge.
- **Disposition:** these are already integrated/evolved or superseded; preserve historical refs and don't merge stale copies.

### Cross-check note

The branch compare `ahead/behind` counts describe ancestry, not outstanding work. Exact blob identity and current behavior were checked for the key initiative, item catalogue/icon atlas and save manager files. For files that differ, the current side is the evolved baseline; this group revealed no additional safe code merge. No branch was deleted or closed.


## Audio, Pages/PWA, porting documentation and wilderness-art lineage — focused review, 12 November 2026

### Audio and mode-select branches

- `feature/legacy-audio-menu-dev` (12 / 115; ten paths) and `feature/legacy-audio-menu-dev2` (10 / 111; ten paths) are early versions of the audio/menu work. `scripts/audio/audio_manager.gd` is byte-identical to current `dev_2`; both branches' main-menu/arena scenes and importer are the same integrated lineage, while current main-menu logic and Pages workflow have evolved. `feature/audio-and-mode-select` / PR #5 is the related later source already reviewed.
- **Disposition:** already integrated/evolved; no re-merge. Audio binaries are imported from the legacy source by the importer, not committed as game assets. Arena remains a placeholder; do not mistake the menu/audio foundation for completed Arena gameplay.

### GitHub Pages and iPhone PWA branches

- `feature/ios-game-pwa` compares 12 / 164 with three paths. Exact blob checks confirm both `tools/pwa/package_godot_pwa.py` and `docs/PHONE_TESTING.md` are byte-identical to current `dev_2`. The PWA packaging helper is already used in the evolved Pages pipeline.
- `feature/godot-web-pages-export` (13 / 169; five paths), `feature/hollowmere-github-pages` (5 / 166; four paths), `feature/iphone-web-preview-pipeline` (0 ahead), and older deploy branches are historical iterations of web export/Pages packaging. Current `dev_2` has the more advanced combined 329-line game/Workshop/props artifact workflow. The old HF deploy helper was removed in a later Pages lineage; do not restore it.
- **Important outstanding deployment-source decision:** current `dev_2` workflow triggers/queries artifact sources for `dev`, not `dev_2`. Merging to `dev_2` alone does not deploy the branch. This is an operational baseline decision, not a missing workflow port; do not silently retarget deployment or push gameplay to `dev`. The selected production source must be reconciled explicitly before treating Pages as a current-head visual acceptance loop.
- **Disposition:** no merge from these older branches. PWA code and phone instructions are already integrated. Keep old deploy branches as provenance; the only unresolved item is intentional deployment-source configuration and a successful current-head Pages run from the chosen source.

### Legacy porting matrices and mechanics documentation

- `feature/legacy-porting-matrix` and `feature/legacy-porting-matrix-dev2` both contain the same 9.2 KB older `docs/LEGACY_PORTING_MATRIX.md`; current `dev_2` has a newer ~21 KB version with expanded status and evidence. The two old branches are duplicate documentation lineage, not two separate documents to merge.
- `feature/mechanics-port-foundation` contains only an early `docs/MECHANICS_PORT_REGISTER.md`; current `dev_2` has the evolved mechanics register. `feature/port-action-economy` and `feature/skill-magic-foundation-current-dev` have zero commits ahead.
- **Disposition:** current docs are canonical; no merge. Any unique source-mechanics parity notes should be reconciled into the current register, not restored as stale files.

### Wilderness art and gatherable visuals

- `feat/wilderness-art-and-gatherable-visuals` compares 18 / 123 with eleven paths. Exact blob checks confirm `scripts/presentation/wilderness_resource_visual.gd` and `tests/test_wilderness_resource_visuals.gd` are byte-identical to current `dev_2`. The visual supports fruit/timber trees, ore, stone, herb patches and fishing spots, using the Kenney Nature asset package with procedural fallbacks. The asset-fetch helper and older seasonal/world simulation snapshots are not a reason to merge the branch wholesale.
- **Disposition:** the gatherable visual implementation and its tests are already integrated/evolved. No re-merge. Preserve the branch for its historical asset-fetch/provenance script; current world and seasonal tree code remain canonical.

### Cosmo forest addon and generated assets

- `feature/hollowmere-cosmo-forest` compares 4 / 57 with 178 paths. Its addon/plugin structure is present in current `dev_2` (the plugin configuration blob is identical); the branch also contains a large set of generated GLB tree/bush assets. User has explicitly excluded the Cosmo generator/evaluation tooling from recovery because accepted generated assets are already available in the game tree.
- **Disposition:** no addon/demo/evaluation merge. Keep original branch as provenance. Runtime should consume accepted generated GLBs as assets, not require the generator plugin. If a particular asset is later found missing, recover that exact asset independently after checking its source/licence and whether current seasonal/world visuals use it.

### Current conclusions from this group

- AudioManager, PWA packaging, iPhone testing instructions, wilderness resource visuals/tests and the current legacy/mechanics registers are already represented in current `dev_2`.
- Old Pages workflows are superseded, but the `dev` versus `dev_2` deployment trigger mismatch remains a real decision to resolve deliberately.
- Cosmo tooling remains out of scope by user direction; retain source provenance without merging.
- No branches were merged or closed in this pass.


## Integration and visual-fix branch family — focused review, 12 November 2026

### Already-integrated dev_2 branches

- `integration/two-storey-tankard-dev2` compares 10 / 7 with nine paths and is the source branch for the building/door foundation merged as PR #119. It remains historical provenance; do not merge again.
- `integration/vision-foundation-dev2` compares 3 / 5 with three paths and is the source for the spatial vision/hex LOS foundation merged as PR #122. The separate fog-of-war presentation in the older feature branch is not included in that merge.
- `integration/hollowmere-dev-visual-review`, `integration/hollowmere-npc-visuals`, `integration/hollowmere-world-simulation` and `integration/wren-modular-clothing` have zero commits ahead of current `dev_2`; no code recovery needed.

### Opening cinematic integration branch / PR #121

- `integration/opening-cinematic-dev2` compares 6 / 6 with six paths. It contains `cinematic_director.gd`, animation-matching test and in-engine cutscene design doc, plus actor/HollowTankard integration. This is the current open PR #121 candidate.
- Its earlier Godot validation passed on run `43151102411`, but the PR base SHA predates merged PRs #125–#127. It has not had visual PC acceptance. A headless test can establish that animations load/match, but cannot establish camera framing, actor alignment, cinematic pacing or skip behavior.
- **Disposition:** preserve and hold. User/PC visual review first; then refresh onto current `dev_2` and rerun full Godot validation. No merge now.

### Parallel modelling/anatomy visual-fix branches

These are audited for retention only; they belong to the other active character/clothing stream and must not be edited or merged by this integration pass.

- `fix/anatomy-pelvic-landmark-port` is behind current `dev_2` with zero ahead commits; its work has been superseded/evolved in the current anatomy lineage.
- `fix/male-anatomy-surface-sampling` has one commit ahead changing only `tools/blender/add_male_anatomy.py`; preserve as a narrow experiment, no merge into gameplay baseline.
- `fix/generic-clothing-visibility` (3 / 64) and `fix/keep-body-visible-under-clothing` (2 / 66) change only `ara_character_actor.gd`; preserve both as competing/historical fixes for the transparent-clothing body-visibility issue. Do not choose one by branch age alone; the modelling stream should test actual transparent garments and morphs before accepting a single implementation.
- `fix/modular-outfit-review-material-duplicates` (6 / 165; two paths) changes the Workshop build workflow and modular outfit review renderer; preserve as visual QA tooling lineage. It is not production game code.
- `fix/player-equipment-visuals` (4 / 68; two paths) changes Ara actor and HollowTankard visual integration. Keep with the parallel model/equipment review; don't merge without actual asset/rig review.
- `fix/wren-lace-fishnet-and-anatomy` (19 / 169; six paths) changes Workshop workflow/site, Ara layering patch, adult/male anatomy Blender scripts and outfit renderer. This is a visual/model pipeline candidate; preserve and leave to the parallel stream.
- `fix/dress-selector-and-loading-review` (15 / 164; eight paths) combines older Pages/export workflow changes, clothing/anatomy builder changes and a custom loading shell. It is stacked lineage with `ci/incremental-character-pipeline` and overlaps #8/#25. Preserve; any salvage must split PWA/deploy, UI loading and garment/anatomy concerns into separate changes. Do not merge the branch wholesale.

### Current disposition from this group

- Building/door and vision foundations are already integrated; no re-merge.
- Cinematic PR #121 remains the only current `dev_2` visual integration candidate and needs PC review plus refreshed CI.
- All remaining `fix/*` character visual branches remain preserved for the parallel modelling stream; no gameplay integration action taken.


## Final deployment and creator-branch lineage — focused review, 12 November 2026

### Pages deployment experiments

- `fix/combined-game-workshop-pages-deploy` (4 / 122; four paths), `fix/pages-deploy-artifact-based-v2` (4 / 120; two paths), `fix/pages-deploy-game-and-workshop-artifacts` (9 / 121; four paths), `fix/pages-game-artifact-path` (1 / 118; one path) and `fix/split-game-export-and-pages-deploy` (1 / 119; one path) are successive iterations of the combined Pages workflow. Some add then remove a separate combined workflow; later versions use artifact-based packaging. None supersedes current `dev_2`'s more advanced 329-line workflow, which assembles the game, Ara/Workshop and prop artifacts.
- `maintenance/single-iphone-preview-pipeline` and `feature/iphone-web-preview-pipeline` have zero commits ahead of current; they are historical pipeline snapshots.
- `feat/wren-only-pages-two-character-workshop` (5 / 160; three paths) is an older variant of the current Workshop/Pages pipeline. `fix/workshop-dress-and-game-loading-stages` (4 / 161; three paths) mixes Workshop build, WorldRoot loading and site UI; current workflow/creator code has evolved. `fix/publish-all-male-workshop-previews` (1 / 147; one workflow path) is an older attempt at preview publication.
- `fix/ara-review-crash-remove-legacy-wren-build` was compared directly with current workflows: its Workshop and Godot exporter workflows are older than current; it adds no unique current Ara runtime build capability. It is superseded.
- **Disposition:** preserve all as workflow history. No workflow cherry-pick. Deployment-source mismatch (`dev` trigger/artifact source vs `dev_2` integration baseline) remains an explicit decision before current-head Pages deployment can be used as a trustworthy review loop.

### Cinematic alternative lineage

- `feature/hollowmere-ironbond-opening-cutscene` compares 17 / 58 with four paths and contains a separate `cinematic_director.gd` plus actor/HollowTankard changes and design doc. It overlaps the newer `integration/opening-cinematic-dev2` / PR #121 lineage but is based on older code.
- **Disposition:** preserve as an alternative implementation/provenance source. PR #121 is the current visual-review candidate; do not merge both cinematic branches or mix their scene/actor snapshots. If #121 fails visual acceptance, compare the old director's unique approach before deciding whether to salvage any isolated concept.

### Player character creator lineage

- `feature/player-character-creator` compares 19 / 163 with eleven paths; `feature/player-character-creator-dev` compares 10 / 162 with nine paths. Both are older player-creator implementations and include 13-NPC-era manifest, Ara actor/HollowTankard/WorldRoot snapshots and 13/14-profile validators. Current `PlayerCharacterCreator` is a later 495-line implementation with threaded preview loading/progress and current 22-character manifest. The old validator's 13-NPC assumptions are not compatible with current data.
- **Disposition:** no wholesale merge. Preserve design/interaction history; if a unique creator interaction is missing, recover that isolated behavior against the current creator and current character assembly contract. Do not replace the 22-NPC manifest or current creator.

### Cosmo evaluation branch

- `feature/cosmo-tree-gen-evaluation` compares 23 / 61 with 181 paths and contains the Cosmo addon, a large generated tree collection, gallery scene/script and generator workflow. This is the evaluation tooling the user explicitly said is not required. The game already contains the accepted generated tree collection and current seasonal/resource visuals; the runtime does not need the generator plugin.
- **Disposition:** no merge by explicit user direction. Retain branch as source/provenance; only recover an individually identified missing generated asset if a later asset audit proves it is absent and required.

### Current conclusions from this group

- No remaining deployment branch provides a better production workflow than current `dev_2`; the deployment source choice is the only unresolved operational issue.
- Keep one cinematic implementation candidate (#121) for visual review; preserve the earlier cinematic branch without combining them.
- Player creator branches are superseded by current code and stale manifest assumptions.
- Cosmo evaluation tooling is intentionally excluded; generated assets remain an asset/provenance concern only.
- No branches were merged or closed in this pass.


## Audit-document, CI and repository-maintenance branches — focused review, 12 November 2026

### Skill/spell audit documents

- `audit/skill-effect-branch-cross-reference` (1 / 28) and `audit/skill-effect-parity-update` (3 / 25) modify `docs/SKILL_SPELL_IMPLEMENTATION_AUDIT.md`; `audit/skill-spell-implementation-baseline` is behind current with zero commits ahead. Current `dev_2` already contains a larger, updated version of the skill/spell implementation audit (about 85.9 KB vs 37–45 KB on these branches), so the older copies must not replace it.
- `audit/spell-parity-and-test-findings` adds `docs/SPELL_PARITY_AUDIT.md`; current `dev_2` already has a larger current copy (about 15.8 KB vs 14 KB on the branch), so it is integrated/evolved.
- `docs/content-parity-audit` adds a 29 KB `docs/CONTENT_PARITY_AUDIT.md` which is not currently present in `dev_2`. It is a useful broad 2D-content parity inventory, but its baseline is `dev` at an earlier commit and it is explicitly an initial audit rather than accepted implementation evidence.
- **Disposition:** preserve the current skill/spell and spell-parity docs; no re-merge. Keep the content-parity audit as a unique documentation salvage candidate. Before bringing it into current docs, update its baseline/evidence against `dev_2`, reconcile its status terms with the current porting register and retain its distinction between code presence and tested/accepted gameplay.

### CI and test branches

- `test/save-manager-hardening` has one commit ahead, but its `tests/test_save_manager.gd` is byte-identical to current `dev_2`; no port.
- `test/save-restore-scene` and `test/save-restore-scene-dev2` contain earlier save-restore runner/boot-scene iterations. The current restore integration test was already recovered by PR #120 and passed; do not merge the old runner or HollowTankard diagnostic snapshots.
- `test/additional-skill-effect-coverage` is an older `tests/test_simulation.gd` snapshot. Current tests include the additional racial/movement effect assertions plus newer status, vision, animal, reaction and lifecycle coverage. Do not replace the current suite.
- `ci/enable-dev2-validation` is superseded by the current `godot-validation.yml`, which already triggers for `dev` and `dev_2` and includes the later simulation, save, building, wilderness, creature, map and character checks.
- `ci/incremental-character-pipeline` is a stacked/older character pipeline and cache iteration (30 / 164; ten paths), with anatomy and Workshop changes. Keep it with the separate modelling stream; do not merge workflow or Blender snapshots during this audit.
- `chore/consolidate-preview-and-review-workflows` is an older workflow consolidation proposal, including deletion of review workflows. Current workflow dependencies have evolved; do not apply its deletions wholesale. Its `docs/CI_WORKFLOWS.md` is absent from current and may be useful as a source inventory, but must be refreshed against the actual current workflow graph before inclusion.

### Repository maintenance

- `chore/repository-formatting-rules` adds `.editorconfig` and modifies `.gitattributes`; both files are byte-identical to current `dev_2`. No merge needed. The editor config declares tabs for GDScript/scenes/resources, but current files still contain spaces in many places; configuration presence is not proof of formatting compliance or CI enforcement.
- `chore/remove-huggingface-deployment` removes two old HF workflows. Current Pages deployment has evolved; do not merge historical deletions without checking live workflow paths. HF deployment is no longer the active preview approach.
- `test/chatgpt-session-write-access-20261105` is behind current `dev_2` with zero commits ahead; no recovery needed.

### Current disposition from this group

- Current skill/spell audits and save/CI test coverage are already represented or superseded.
- `docs/CONTENT_PARITY_AUDIT.md` and `docs/CI_WORKFLOWS.md` are the two distinct documentation candidates identified here; preserve their branches and update their evidence before deciding whether to add them to current docs.
- No branch was merged or closed in this pass.


## Low-coverage branch records and exact-blob follow-up — 12 November 2026

- `deploy/wren-workshop-github-pages` compares 1 / 170 with one Workshop workflow change. It is an older Pages deployment iteration; current combined game/Workshop workflow is more advanced. Preserve, no merge.
- `feature/runtime-tattoos` compares 8 / 140 with three paths. Its `docs/WREN_WORKSHOP.md` is byte-identical to current, and the runtime tattoo customization described is in the browser Workshop, not a new Godot actor implementation. Its workflow/site are older snapshots. Preserve, no merge.
- `feat/ara-shields-helmets-hairstyles` is 15 / 106 with seven paths: armour-prop workflows, equipment pipeline doc, asset tests and Blender prop builders. It remains in the separate modelling stream; preserve, no merge here.
- `feat/campaign-loading-feedback` (1 / 105) is an older WorldRoot loading overlay; current WorldRoot adds campaign restore progress. No re-port.
- `feat/character-preview-loading-progress` (3 / 104) is an older creator preview-loading implementation; current creator includes the threaded status/progress behavior and additional body/hair readiness/failure reporting. No re-port.
- `feature/campaign-quest-journal` (5 / 138) is an earlier CampaignJournal/WorldSimulation/test snapshot. Current journal has more extensive faction/NPC knowledge, standing and merchant influence persistence. No wholesale port.
- `feature/hollowmere-dialogue-ambient-chatter` (16 / 137) contains older campaign content and ambient chatter; current content has evolved choice-specific dialogue and reputation state. Its apparent unique lines were compared and are present or superseded; no separate content payload has been identified for recovery.
- `feature/main-campaign-world-map-validated` is the same head and same 12 / 140 comparison as `feature/main-campaign-world-map`; treat as a duplicate validation alias, not a separate implementation.
- `feature/male-anatomy-geometry-review` (5 / 151) changes only the Workshop workflow/site and Blender male-anatomy tool. Parallel anatomy stream; preserve, do not merge.
- `feature/player-character-visual-phase1` (12 / 128) is an older player visual/actor/creator/scene snapshot plus phase doc. Current actor/creator have evolved; preserve unique design criteria for the modelling stream, no code merge.
- `fix/skill-effect-test-rank-fixtures` (1 / 25) is an older simulation test snapshot; current suite contains those cases with updated rank constraints and broader coverage. No re-port.
- `integration/animal-riding-dev2` is the selective source for merged PR #126; `integration/campaign2-world-dev2` is the source for merged PR #125; `integration/equipment-heraldry-dev2` is the source for merged PR #127; and `integration/equipment-rules-dev2` is the source for merged PR #124. These integration branches remain historical recovery branches; no second merge.

### Remaining note on audit completeness

This pass now has explicit comparison/disposition notes for the low-coverage names above. Name coverage remains 134/134. The audit still does not claim exhaustive visual review of all binary assets or in-game acceptance of modelling branches; those are deliberately delegated to the parallel modelling stream. The remaining technical uncertainty is concentrated in (a) the `dev` versus `dev_2` Pages deployment source, (b) PC visual acceptance and refreshed validation for cinematic PR #121, and (c) the exact salvage design for deferred quest/fog/NPC-preview candidates. None of these warrants a merge or branch deletion now.


## Selective recovery playbooks and preservation gates — 12 November 2026

This section turns the deferred candidates into actionable recovery recipes. The recipes intentionally start from the latest `dev_2` and preserve the original source branch. No recipe authorises a wholesale merge of a stale PR.

### 1. Character assembly / NPC canonicalisation — #87

**Source:** `feature/unified-character-assembly`; open draft PR #87 currently targets `dev`, not `dev_2`.

**Preserve now:** the original branch and PR, its resolver implementation, schema/design documents, Blender/ARA build tools, profile catalogue, tests and any generated assets. Do not delete `hollowmere_loadouts.json` or replace the current NPC manifest during preservation.

**Recovery order when the character-model stream is ready:**
1. Agree the runtime contract first: one accepted male base and one accepted female base, per-character morph/appearance recipe, garment fit data and equipment slots. The branch's ten separately exported body/garment profiles are a proposal, not the agreed production model.
2. Create a new integration branch from the then-current `dev_2`; do not retarget or force-push the historical branch.
3. Port/adapt `character_assembly_resolver.gd` as a pure data-to-runtime adapter. It should resolve base body variant plus morph recipe, hairstyle, garment style and equipment references without generating bespoke body assets.
4. Migrate all 22 current NPC definitions before changing schema. Preserve every current ID, quest/companion reference, inventory and equipment item. Add schema migration tests that prove old definitions still load.
5. Prevalidate the complete inventory/equipment payload before mutating CharacterState; reject duplicate item IDs or support stack quantities; make repeated resolver calls idempotent or explicitly reject a second application.
6. Add only the two accepted base body assets and their tested clothing/garment assets. The ten declared profile GLB paths in the source branch are not present as a complete set; catalogue entries alone do not satisfy this gate.
7. Run manifest validation, resolver tests, all current Godot tests, and in-game NPC/player appearance, morph and garment fit review. Keep Blender generation/validation CI separate from the runtime game tests.

**Hard blockers:** 14-vs-22 NPC migration; ten missing profile/garment GLBs; duplicate inventory IDs can overwrite; resolver mutates before all equipment references are validated; deterministic IDs make repeated population non-idempotent; current user direction is two base bodies plus morphs, not ten independently maintained body bases.

**Acceptance:** all 22 existing NPCs resolve; player creator resolves male/female base; inventory ownership and slot validation pass; repeated load/resolve does not duplicate or lose items; representative clothing remains fitted across supported morphs; no accepted model asset is inferred from a path string.

### 2. Fog of war and stealth perception — #96

**Source:** `feature/vision-stealth-perception`; open draft PR #96 targets `dev`. Its `VisionRules` spatial foundation was selectively recovered by PR #122; fog presentation remains branch-only.

**Preserve now:** `scripts/presentation/fog_of_war.gd`, `tests/test_fog_of_war.gd`, `docs/VISION_STEALTH_PORT.md` and the historical PR. Do not merge the old `HollowTankard`, `WorldSimulation`, test-suite or workflow snapshots.

**Recovery order:**
1. Start from current `dev_2` `VisionRules`/`HexMapData` and the #122 LOS tests. Compare the branch fog script against the current village/map geometry and current 420m world layout.
2. Split persistent exploration data from the `Node3D` renderer. Store explored hex IDs per player/party/campaign in stable save data; compute current visible hexes from current observers. MultiMesh, debug panel, cached geometry and actor-node references are disposable presentation state and must be rebuilt after load.
3. Define whether exploration is player-only or party-shared, and how indoor/tavern, unloaded chunks and map transitions are represented. Never serialize MultiMesh instance indices or scene-node paths as world knowledge.
4. Adapt fog rendering to current village/world extents and chunk streaming; avoid hard-coded map radius, 190m bounds and stale geometry assumptions unless they are derived from current map data.
5. Add tests for reveal, loss of live visibility, persistent exploration across save/load, observer movement, multiple observers, map transitions, unloaded cells and deterministic rebuild. Add an in-game visual review for edge clipping, roads/buildings and indoor transitions.
6. Only after fog/exploration is stable should stealth detection, suspicion, observer-specific last-known-position memory and AI search/pursuit be designed as separate simulation state and rules.

**Hard blockers:** current branch fog script couples saved knowledge and presentation caches; old fixed map dimensions/geometry; no campaign persistence contract; no enemy memory/search/suspicion implementation. The `VisionRules` LOS foundation is already in `dev_2`, but stealth bonuses alone are not a stealth system.

**Acceptance:** explored state survives save/load and rebuild; live visibility is recomputed; no renderer object is saved; map edge/indoor tests pass; AI memory remains observer-specific and does not reveal unseen current positions.

### 3. Tessa rescue / dire-wolf quest — #99

**Source:** `feature/farmstead-bear-creature-model`; open draft PR #99 targets `dev` and is based on old quest/world snapshots.

**Preserve now:** Tessa rescue quest content, trail/rescue/encounter beat design, dire-wolf encounter helper, tests and branch history. Do not replace current companion content or current HollowTankard wholesale.

**Recovery order:**
1. Rebase conceptually—not mechanically—onto current `dev_2` quest/campaign state, current 22-NPC definitions, #126 `AnimalCatalog`/mount registration and current `WorldSimulation`.
2. Port quest progression as explicit stable campaign events/states: missing child reported, trail found, Tessa rescued, dire wolf defeated, reward/recruitment outcome. Preserve save/restore between each stage.
3. Reuse the current wolf animal profile and registration rules; do not create a second animal stats implementation. Choose one source of base HP and apply Health skill effects exactly once. #126's double-health correction is the rule to preserve.
4. Snapshot every character's prior `combat_dormant`, `side`, TP and relevant combat state before encounter staging; restore the exact prior values on victory, defeat, cancellation and scene exit. Never set all registered characters dormant and later restore only the party.
5. Add tests for duplicate quest start, missing/dead party members, dire-wolf registration, HP after registration, all encounter outcomes, save/restore at every quest stage and restoration of unrelated bystanders.
6. Run the quest through the actual Hollowmere scene and validate that Tessa, trail markers, encounter trigger and recruitment/reward are reachable and understandable.

**Hard blockers:** old helper gives wolf explicit max HP and adds Health ranks, causing Health to be applied again during registration; global dormancy mutation is not symmetrically restored; old `HollowTankard` and test snapshots conflict with current code.

**Acceptance:** deterministic quest-state transitions and save/restore; one health calculation; unrelated NPC states unchanged after every exit path; no stale scene snapshot.

### 4. Hollowmere shakedown encounter

**Source:** `feature/hollowmere-shakedown-combat` (no current open PR). Unique `HollowmereEncounter` and test are present; current CampaignJournal is identical to `dev_2`, but the branch's broad HollowTankard/test snapshots are stale.

**Preserve now:** `hollowmere_encounter.gd`, the `_test_hollowmere_encounter` test intent, and relevant encounter dialogue/quest design. No merge yet.

**Recovery order:**
1. Port only the encounter state machine and its focused test into a new branch from current `dev_2`.
2. Replace hard-coded roster assumptions with validated current NPC IDs and an explicit encounter roster definition. Validate every participant and every profile before mutating anyone.
3. Snapshot and restore prior side, dormant state, TP, combat flags and any temporary stats/tags for every affected actor; cover victory, party defeat, abort and scene transition.
4. Ensure encounter start/finish is idempotent and save/load policy is explicit (either prohibit saving mid-encounter with a clear result, or serialize the encounter state completely).
5. Use current combat action/reaction/turn scheduler APIs and test actual AI turns, target eligibility, ally defeat, enemy defeat and turn cleanup.
6. Integrate into current HollowTankard via a small encounter controller/event boundary; do not copy the old 1,528-line HollowTankard or 1,115-line test suite.

**Hard blockers:** all-character dormancy/side mutations are not restored for every bystander; temporary ally/enemy stats and tags are applied directly; scene wrapper/quest outcome and interruption handling need validation.

**Acceptance:** no unrelated NPC changes after encounter; repeated start/finish safe; defeat/victory/abort paths close combat cleanly; current simulation suite remains intact and focused encounter tests pass.

### 5. Animal riding preview workflow — #110 after #126

**Source:** `feature/animal-riding-validation`; open non-draft PR #110 targets `dev`. Simulation/riding code was selectively merged as #126; this preview workflow was deliberately not ported.

**Preserve now:** `tests/capture_riding_preview.gd`, `.github/workflows/riding-preview.yml` and the original branch/PR. The current capture hard-codes the rider seat at `(0, 1.35, 0)` and reparents the rider directly to the horse; this is a static composition, not evidence of a production mount socket or animation attachment.

**Recovery order:**
1. Close #110 as superseded only after confirming its remaining diff contains no additional simulation or asset payload beyond the already recovered #126 code and this preview prototype. Keep the branch permanently.
2. Define a mount presentation contract in the current CreatureActor/Ara actor layer: mount socket/bone or calibrated transform, rider facing/scale, animation state and dismount cleanup. Keep it presentation-only; simulation mount links remain authoritative.
3. Rebuild the preview capture against that real contract; capture male/female riders, side/rear views, walk/idle and mount/dismount states where animations exist.
4. Store preview artifacts as CI outputs for review; do not make headless screenshot generation a substitute for visual fit acceptance.
5. Only then add the preview job to the current validation workflow, with paths and branch filters aligned to the selected integration/deployment strategy.

**Acceptance:** preview exercises the same attachment path used in-game, both body variants fit, rider does not detach/fall through during animation, and CI reports the exact tested commit.

### 6. Opening cinematic — #121

**Source:** `integration/opening-cinematic-dev2`; open draft PR #121 already targets `dev_2`.

**Recovery order:**
1. Perform PC visual acceptance before code changes: verify imported GLB animation clips, actor alignment, camera framing, lighting, pacing, skip and return-to-control.
2. If accepted, refresh the branch onto current `dev_2` without deleting its history; resolve conflicts by retaining current actor/HollowTankard architecture and only reapplying cinematic-specific files/wiring.
3. Run full Godot 4.7.2 validation on the refreshed exact head; inspect generated output and rerun visual review after any scene/transform changes.
4. Merge only the cinematic-specific implementation after the visual gate. Keep the alternative `feature/hollowmere-ironbond-opening-cutscene` branch as historical alternative; do not combine two directors.

**Acceptance:** PC review sign-off plus fresh full Godot CI on the exact merge head. The earlier green headless run alone is insufficient.

### 7. Unique documentation salvage candidates

- `docs/content-parity-audit` contains `docs/CONTENT_PARITY_AUDIT.md` not present on `dev_2`. Preserve the branch. Before adding the document, update its source baseline and every file/feature status against current `dev_2`; reconcile statuses with `docs/LEGACY_PORTING_MATRIX.md` and this register. It must distinguish present, partially implemented, tested, visually accepted and playable. Do not copy stale status claims as current facts.
- `chore/consolidate-preview-and-review-workflows` contains `docs/CI_WORKFLOWS.md` not present on `dev_2`, but also proposes deleting old workflows. Preserve only the workflow inventory as a possible documentation extraction; refresh each workflow trigger, artifact dependency, required input and deployment source against current files. Do not merge its workflow deletions.

### Preservation policy and next decision point

- All historical source branches remain intact. Selective recovery branches must be created from the latest `dev_2` and must cite the source branch/commit and the exact paths/commits recovered.
- Open PRs #87, #88, #90, #96, #99 and #110 currently target `dev`; do not merge or retarget them as part of this audit. Their current PR status is evidence of open historical proposals, not a requirement to keep them open forever.
- PR #110 can be closed as superseded after its remaining preview-only diff is confirmed and the #126 merge is referenced. Other old PRs stay open/draft until each has a recorded disposition and any unique work is safely preserved.
- No new gameplay work should begin until the remaining branch-only assets/data/tools and recovery recipes have been inventoried, and the user has reviewed any material trade-off. Character assembly remains coordinated with the separate modelling stream.


## Animal world-registration recovery — PR #128, 12 November 2026

- Further review of PR #110 found that the animal simulation base from #126 was not yet connected to the ten visible exterior village creature actors. Current `CreatureActor` already had `create_simulation_state()`, but current `HollowmereVillage._spawn_creature()` did not set `axial_hex`; there was no village registration method, and current `WorldRoot` did not register the village actors with the tavern's campaign simulation. Thus the animal models remained presentation-only in the live campaign despite the simulation catalogue/riding rules being present.
- Recovered selectively on `integration/animal-world-registration-dev2`, PR [#128](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/128), targeting `dev_2` from base `374d4a2894e0c118c4a35d075a23ca568ff51209`.
- Files changed: `scripts/world/hollowmere_village.gd` (preserve axial hex, add canonical animal-state registration), `scripts/world/world_root.gd` (register exterior animals after tavern simulation initialises), and `tests/test_hollowmere_village.gd` (all ten farm/wilderness actors, actor-to-state references, neutral/dormant/ambient tags and duplicate registration).
- This is the remaining safe integration slice from #110. It does not port the old riding-preview workflow or fixed `(0, 1.35, 0)` rider attachment; those still require a real presentation mount-socket contract and visual validation. Original #110 branch and PR remain untouched pending #128 CI and a final remaining-diff check.
- PR #128 workflow run `43204254123` was in progress at audit update; do not record it as passed until the exact PR head completes all Godot 4.7.2 stages.


### Correction to #110 remaining-diff disposition — mount command and presentation code

A further complete PR-diff inspection shows that #110 is **not preview-only** after #126/#128. Its old `HollowTankard` snapshot also contains a player mount toggle on `R`, nearest-mount selection, rider reparent/attach/detach, camera follow changes, and mounted facing/movement presentation. Current `dev_2` does not yet have these `HollowTankard` methods or the `R` input binding. These are genuine branch-only integration candidates and must be preserved.

- The simulation-side operations (`mount_animal`, `dismount_animal`, mounted movement, reciprocal links, save/load and lifecycle rules) are already in #126 and must not be copied again.
- PR #128 now registers all ten exterior animals, sets each actor's `axial_hex`, and puts each actor in the `creature_actors` group used by mount lookup. A test checks group membership as well as registration.
- The remaining #110 UI/presentation port should be a separate selective PR after #128 passes: add the `R` binding without disturbing current F5/F9 save/load, door/stairs interaction, current input flow or path movement; port/adapt mount selection/status feedback and actor attach/detach/camera follow; synchronize mounted rider/mount facing and movement in current `_on_character_moved`/rotation handling.
- **Do not copy the old `HollowTankard` file.** It predates current save/load diffs, two-storey building/door framework, current WorldRoot integration and later simulation changes. Port only the isolated mount methods and the necessary call sites into current code.
- The current source preview hard-codes rider local position `(0, 1.35, 0)` and rotation zero. Treat this as a provisional seat transform only; do not call it a validated saddle socket or assume the rider animation is compatible. Visual acceptance against the current horse GLB and both male/female base rigs remains required.
- Consequently, do **not** close PR #110 yet. Keep it open until #128 is accepted and the mount UI/presentation code has either been selectively recovered or explicitly dispositioned. Keep the original branch permanently regardless of PR closure.


## Inventory refresh after PR #128 creation — 12 November 2026

- GitHub branch list now returns 135 live branches (the previous 134-name snapshot plus `integration/animal-world-registration-dev2`). All 135 names are represented in this register.
- Open PR count is now 20: three target `dev_2`, 16 target `dev`, and one targets `fix/dress-selector-and-loading-review`. PR #128 is the new `dev_2` animal world-registration recovery; PR #123 remains the audit draft; PR #121 remains the cinematic visual-review candidate.
- PR #128's first full Godot 4.7.2 run (`43204254123`) passed all 28 workflow stages on its initial head. The branch was then tightened to add `creature_actors` group membership and an assertion for mount lookup. Updated head `049d6d4bc2404cffd805b491c2f32d4a32ecbce8` is under a fresh validation run (`43204852927`); only the updated-head result can authorise merge.
- #110 is not ready to close: its mount-toggle, actor attachment/detachment and facing/movement presentation are distinct from the simulation foundation already merged in #126 and village registration being recovered in #128. Preserve this code for a separate selective port; do not import its stale `HollowTankard` snapshot.


## PR #128 merged and save-restore binding correction — 12 November 2026

- PR #128 merged to `dev_2` at `3767ea7ebb62c726c3b0b48ea7d0afb608382dd6`. Updated-head Godot 4.7.2 run `43204852927` completed successfully with all stages green. The ten exterior farm/wilderness animals now have stable axial identity, canonical simulation registration and the `creature_actors` lookup group.
- Post-merge lifecycle review found an ordering edge case: `HollowTankard._ready()` applies pending save data before `WorldRoot` registers the exterior actors. On restore, the simulation may already contain saved animal IDs. A naive registration would report duplicates and leave the presentation actors without `simulation_state` references; it would also fail to restore saved animal position/facing.
- Focused correction is now in PR #129, branch `fix/animal-restore-actor-binding-dev2`, based on `dev_2` head `3767ea7ebb62c726c3b0b48ea7d0afb608382dd6`. It binds matching pre-restored animal states to their actors, restores saved axial position/facing, preserves saved side/dormancy/mount links and makes registration idempotent. Its regression test pre-registers a moved/player-side horse before actor binding. Workflow run `43205739155` was in progress at the time of this note; no pass/merge claim yet.
- The #110 mount-toggle/actor attachment/detachment presentation code remains a separate recovery candidate after this save/restore edge is validated. It must be adapted to current `HollowTankard`; no old scene snapshot.


### Additional mount-presentation acceptance checks discovered in #110

The #110 `HollowTankard` mount code is useful but not ready to copy verbatim:

- It adds `R` as mount/dismount input and shows status feedback through the resource label. Current `dev_2` uses `R` nowhere, so this key is available, but the current F5/F9 quick-save/load, F stairs/doors/NPC interaction, G gathering and movement bindings must remain unchanged.
- It reparents the rider actor under the mount and makes the camera follow the mount. The seat offset is hard-coded to `(0, 1.35, 0)` with zero rotation; no saddle/socket calibration or animation-state retargeting is provided. Treat it as a provisional static preview only.
- Its `_on_character_moved` receives a movement event for the rider and the mount. Because the rider is a child of the mount, independently tweening the rider to the hex centre would destroy the seat offset. Adapt current code to skip presentation movement for a mounted rider and move only the mount actor; retain wilderness spawn checks for a mounted player.
- Add an `animal_forced_dismount` event handler. Simulation already breaks reciprocal links when rider or mount is incapacitated, but the old presentation code only detaches on an explicit R-key dismount. Without a handler, the rider can remain parented to an incapacitated mount after simulation has forced a dismount.
- Add a post-load attachment restoration call after PR #129 has rebound the mount actor to its restored CharacterState. The old code does not reparent a saved mounted rider after load.
- When switching party members, camera follow should target the mount if the newly active character is already mounted. The old branch always targets the rider actor.
- The dynamic wilderness animals spawned inside `HollowTankard` are currently presentation-only; they are not registered with WorldSimulation and do not carry a `simulation_state`/group membership. Do not accidentally make them selectable mounts until they are registered as simulation actors or explicitly excluded.

These are adaptation requirements for a separate mount-presentation PR. They do not invalidate the already merged simulation layer or PR #128 world registration.


## Additional branches discovered in the latest live refresh — 12 November 2026

### Content census / parity documentation

- `docs/content-census` compares 2 / 60 with `dev_2` and adds two substantial documents: `docs/CONTENT_CENSUS.md` (~28.8 KB) and `docs/CONTENT_PARITY_AUDIT.md` (~29.3 KB). Both are based on the older `dev` baseline and dated 10 November. The census contains source-backed inventory counts (98 named NPCs, 35 creature/enemy templates, 63 source equipment definitions vs 76 3D definitions, 186 skill definitions, 15 spells, quest/dialogue catalogue and Arena/world data) and correctly warns that data presence is not equivalent to gameplay/visual acceptance. The parity audit inventories missing/partial 2D content and systems.
- `docs/content-parity-audit` (1 / 59) carries only the parity document; it is an earlier/duplicate documentation lineage. `docs/content-census` is the richer combined candidate.
- **Disposition:** preserve both source branches; no merge of their status claims as-is. Refresh the source-to-port comparisons against `Hex-crpg/main` and current `dev_2`, verify the counts, update the audited ref/date, and reconcile against `LEGACY_PORTING_MATRIX.md`, `MECHANICS_PORT_REGISTER.md` and this recovery register. Keep separate status columns for data ported, runtime implemented, tests passed, persistence, visual acceptance and playable end-to-end. Then create a documentation-only PR from `dev_2`; no runtime files need to move.

### In-game reaction prompt branch

- `feature/in-game-reaction-prompt` compares 2 / 147 with two paths. Its `scripts/ui/reaction_prompt.gd` is an older variation; current `dev_2` has the same modal component with a more useful generic explanation that nearby defenders may react and that each option is paid for by the named character. Its `HollowTankard` is a very early 37.5 KB snapshot, compared with the current ~131 KB evolved script and lacks current save/load, upper floor/door, resource, and later campaign integration.
- **Disposition:** no merge. Reaction prompt UI and integration are already represented/evolved in current. Retain the branch as implementation history; do not replace current scene logic.

### Hollowmere cast validator

- `fix/hollowmere-cast-validator` compares 1 / 15 with one path. Exact blob check confirms `tools/ci/validate_hollowmere_models.py` is byte-identical to current `dev_2`.
- **Disposition:** already integrated/evolved; no merge.

### Current animal integration branches

- `integration/animal-world-registration-dev2` is the source branch for merged PR #128 (merge commit `3767ea7ebb62c726c3b0b48ea7d0afb608382dd6`). Keep it as history; no re-merge.
- `fix/animal-restore-actor-binding-dev2` is the source branch for open PR #129. It is a two-file, focused fix to rebind saved animal states and make exterior actor registration idempotent. Its current workflow run is `43205739155`; the result is pending and must be checked against head `27088d58de36d722d1c4462dc68318e492aa157e` before merge.

### Live inventory count

GitHub now returns 136 live branch names and 20 open PRs. All 136 branch names are represented in this register. The count includes new PR #129's fix branch; merged PR #128 is no longer an open PR. No original feature branch has been deleted.


## Animal save-restore and mount-control recovery — PRs #129 and #130

- PR #129 merged to `dev_2` at `0138f1ebd5cc6b677319a4e007d3b581c3301e97`. Exact-head Godot 4.7.2 run `43205739155` passed all 30 stages. The new village registration path now rebinds restored animal states idempotently, restores saved position/facing and preserves status/mount links.
- PR #130 (`integration/animal-mount-controls-dev2`) is a selective adaptation of the remaining player-facing mount code from #110, based on the current `dev_2` head after #129. It adds R/HUD mount toggle, registered actor lookup, rider reparenting, camera follow, mount facing/movement handling, forced-dismount detachment and post-load reattachment. It deliberately does not copy the old HollowTankard snapshot.
- PR #130 adds an isolated mount presentation test host/actor and tests explicit mount/dismount, seat transform, rider movement event handling, facing, forced dismount and restoration after load. Godot workflow run `43206955005` was in progress at the time of this update; no test pass or merge claim yet.
- The seat remains a provisional fixed `(0, 1.35, 0)` offset from #110. PC visual review against the horse GLB and both accepted male/female rigs remains a merge gate. No saddle socket, animation retargeting or dynamic wilderness creature registration is claimed.
