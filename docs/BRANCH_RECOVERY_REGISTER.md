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

