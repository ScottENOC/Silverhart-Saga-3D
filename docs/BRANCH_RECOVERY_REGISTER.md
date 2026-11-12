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
- **Disposition:** genuine selective-salvage candidate. Preserve all branch work. Recover helper, shader, tests and doc as a separate integration branch only after confirming stable surface identifiers, wiring into runtime equipment presentation, tests against actual exported assets and visual acceptance.

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
- **Disposition:** high-value deferred recovery candidate. Preserve all source data, docs, preview tools and tests. First review the source fidelity and schema against current world/map data, inspect the strict runner's error-detection behaviour, then port geography data, preview/builders and tests in separate steps. This is priority-4 world/mechanics work, so do not let it interrupt completion of the current priority-1 branch register.

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
- **Disposition:** preserve both branches and treat riding as the continuation. After priority-1 audit completion, create a fresh integration branch from current `dev_2`, recover the catalogue and tests, and port simulation changes by function. Hard gates remain the double-applied Health ranks, atomic rider/mount lifecycle cleanup on death/incapacitation, occupancy transfer and save/load after forced dismount. No current-head workflow evidence was found in the previous audit snapshot; rerun validation on the exact candidate commit before merge.

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

### Animal riding — selective integration PR in validation

- New branch `integration/animal-riding-dev2`, PR **#126**, targets `dev_2`; current head after lifecycle-fixture correction is `3b57f9c7ac862bab97d07b5a7ce70ac9847ef6f0`.
- Ported animal catalogue and persistent animal/mount state into the current CharacterState/WorldSimulation architecture; retained current building, status-effect, save, reaction and progression code rather than copying stale snapshots.
- Corrected the source branch's double-applied Health issue: horse/wolf use 10 base HP plus their innate Health ranks once (nominal 50/20 HP).
- Added mount/dismount, mount-profile movement/TP use, reciprocal save/load links, turn-end TP capping, and forced detachment when either rider or mount is incapacitated. Added regression tests for those paths.
- PR #126 is ready for review; current-head Godot 4.7.2 workflow is running. Do not merge until the exact latest head passes and any failures are resolved.
- This port is simulation/runtime foundation only; player-facing riding controls and final mount visual/animation attachment remain separate work.

### Equipment appearance/heraldry — isolated recovery candidate

- `EquipmentAppearance`, shield heraldry shader, tests and documentation remain unique to `feat/equipment-materials-heraldry`.
- The helper is not yet proven to be wired into the current Ara actor/equipment presentation path. It is separate from generating equipment meshes, but the user has another workstream handling equipment modelling. Keep this isolated; only merge the helper/test slice after checking for conflicts and confirming the intended runtime integration point. Do not import the branch's armour-prop generator or other modelling workflow changes as part of this audit.

### Combat initiative — already integrated

- Initiative model, timeline UI and capture test are byte-identical to `dev_2`; current `HollowTankard` preloads and wires the timeline. No additional port.

### Explicitly out of scope

- Cosmo Tree Generator evaluation/gallery/regeneration tooling: user confirms the generator was only used to produce assets that have already been accepted. Current generated tree assets are present; no need to recover the evaluation tools.
- Separate character, clothing, hair and equipment modelling workstream: do not duplicate its work in this integration sequence.



### Animal riding — merge completed

- PR **#126** passed the full current-head Godot 4.7.2 workflow (run `43187949002`) and merged into `dev_2` at `69a0f715a9b01efca3aec017cc703fc62e317ffb`.
- Confirmed green steps included engine import, hex grid, the full simulation/movement/combat/animal/riding test suite, building/door, SaveManager, campaign restore, character appearance, wilderness/creature tests, all Campaign 2 tests and all scene smoke tests.
- The old `feature/animal-riding-validation` branch and PR #110 remain intact pending the broader audit of its preview-capture workflow and any remaining branch-only material. Do not delete the branch or blindly merge the old PR.

### Equipment appearance — refresh on current baseline

- PR **#127** has been refreshed after #126 merged. Its integration branch is now based on the latest `dev_2` commit and its compare against `dev_2` contains only the four helper/shader/test/doc files plus the one CI test step.
- New current-head Godot validation is running. The earlier pre-refresh run passed, but the refreshed head must pass before merge.


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

- `feature/hollowmere-dialogue-ambient-chatter` compares 16 ahead / 137 behind with six changed paths. Its ambient chatter script is an older version of the current script. Its campaign-content file is also an older snapshot, but contains some distinct shakedown NPC-standing deltas and greeting/chatter lines not present verbatim in current content. These are content candidates, not a reason to replace current campaign content.
  - **Disposition:** preserve. Before final archival classification, compare the branch's unique dialogue/standing outcomes with the current quest/journal design and the separate shakedown encounter. Recover only specific missing authored content with current canonical NPC IDs and tests.
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
