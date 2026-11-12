# Feature branch consolidation audit — 12 November 2026

## Purpose and scope

This is the first repository-wide inventory and triage pass for the consolidation of `ScottENOC/Silverhart-Saga-3D` into `dev_2`. It records what is known to remain on branches, what is already integrated, what is duplicated, and what needs a deeper code review.

**Integration baseline:** `dev_2`  
**Baseline commit at audit start:** `143e1b02e87a795a00794f0eb291fe4db50e0175`  
**Repository snapshot:** 129 branches across the first two branch-list pages; 19 open pull requests.

This is not a claim that every line of every orphan branch has been reviewed. It is an inventory, ancestry comparison and first-pass disposition. Branches marked for salvage still require file-level diff review and validation before code is ported.

## Rules for this audit

1. `dev_2` is the integration baseline. Do not merge into `dev` or `main` as part of this work.
2. A branch being ahead of `dev_2` does not prove its work is missing. Squash merges create new commit IDs; check merged PRs and actual file content before porting.
3. A green workflow is evidence for the tested commit and tested scope only. It is not visual acceptance or proof of maintainability.
4. Do not bulk-merge stale branches. Prefer small ports with explicit dependencies, tests and review.
5. Preserve original branches until their useful work has been accounted for. Do not delete branches as part of this audit.
6. Keep simulation authoritative, presentation disposable, stable IDs for persistent state, explicit commands/events for mutations, and headless tests for simulation rules.
7. Follow `.editorconfig`: GDScript, scenes and resources use tabs; JSON uses two spaces. CI currently does not appear to enforce every formatting rule.

## Recently integrated work — do not re-merge

| PR | Work | Result |
|---|---|---|
| #119 | Two-storey Hollow Tankard / reusable building and door framework | Merged to `dev_2`; building/door, SaveManager round-trip and regression CI passed. |
| #120 | Campaign save/restore scene integration test | Merged to `dev_2`; full Godot workflow passed. |
| #122 | Spatial vision and hex LOS foundation | Merged to `dev_2`; Godot 4.7.2 workflow #667 passed all 21 stages. |

The corresponding historical branches may still compare as ahead because these PRs were squash-merged. In particular, `integration/two-storey-tankard-dev2`, `integration/save-load-dev2`, `test/save-restore-scene-dev2` and `integration/vision-foundation-dev2` are not fresh merge candidates. Their integrated content must be checked against the merged PRs, not re-applied.

## Open pull request register

The table is a first-pass disposition, not approval to merge. “CI” refers to the latest workflow evidence available for the current PR head at audit time.

| PR | Branch / subject | Current evidence | Initial disposition |
|---|---|---|---|
| #121 | `integration/opening-cinematic-dev2` — Hollowmere opening cinematic | Godot workflow #43151102411 passed. Requires actual in-game review of GLB animation availability, actor alignment, framing and skip behaviour. Base is `dev_2`; GitHub reports mergeable. | **Hold for visual acceptance.** Do not merge until the cinematic is inspected in-game. |
| #110 | `feature/animal-riding-validation` — animal profiles and riding | 30 commits; based on old `dev`; no workflow run found for the current head SHA. The `feature/animal-attributes` branch is its direct predecessor; riding branch is one commit ahead. | **Revalidate and port to dev_2.** Run current-head tests and inspect rider screenshots before merge. Animal autonomous AI and broader mounted combat remain out of scope. |
| #99 | `feature/farmstead-bear-creature-model` — Tessa rescue / dire wolf quest | 27 commits; Godot workflow #42987629965 passed on current head. Based on old `dev`; overlaps the skill/companion and farm quest work in #90. | **Reconcile dependencies and port selectively.** Confirm quest state, recruitment gates, scene integration and avoid duplicate bear/dire-wolf encounter services. |
| #96 | `feature/vision-stealth-perception` — fog of war and vision profiling | 27 commits; latest Godot workflow #43131614222 failed. Its spatial LOS foundation has been replaced by the tested, merged #122 foundation. | **Do not merge wholesale.** Salvage fog presentation only after designing explored-state persistence, scene lifecycle and the separation of visibility, detection, character memory and AI knowledge. |
| #91 | `feature/equipment-gameplay-stat-integration` — equipment stat rules | 5 commits; Godot workflow #42738211492 passed on current head. Based on old `dev`; changes are relatively focused. | **High-priority selective port.** Review against current item/equipment and combat APIs, then rebase/port and rerun tests on `dev_2`. |
| #90 | `feature/skill-magic-foundation` — skill catalogue, progression, NPC builds and quest follow-up | 70 commits; current head has no matching workflow run. Latest branch workflow evidence found was for an earlier SHA. Overlaps #99, animal/companion work, and the separate missing-skill runtime branch. | **Do not merge as one unit.** Audit and split into skill catalogue/progression core, NPC build policy, companion persistence, and farm quest/UI work. Validate each slice against the current character-state architecture. |
| #89 | `docs/content-census` — source content census | 2 commits; documentation-only; no workflow required. Based on old `dev`. | **Port/update documentation.** Reconcile its counts and findings against current `dev_2` before adding it to the current docs. |
| #88 | `feature/full-world-port-foundation` — Campaign 2 world foundation | 47 commits; character/audio/combat auxiliary workflows passed, but Godot workflow #42994727983 failed. Based on old `dev`. Large preview/data slice, not a traversable campaign. | **Fix and stage.** Review failure logs, validate geography and scene integration, then port a playable Hollowmere–Millbrook slice rather than the whole world dump. |
| #87 | `feature/unified-character-assembly` — canonical character definitions and Ara assembly | 197 commits; latest average-body anatomy review passed, but no Godot validation run was found for the current head. Local Blender build and visual inspection remain required. | **Major salvage candidate; no wholesale merge.** Review schema migration, resolver, equipment slots, anatomy pipeline, exporter and generated assets as separate deliverables. |
| #77 | `feat/tapered-split-dress-v2` — alternate split dress | 8 commits; character-pipeline validation passed. Visual review remains outstanding. | **Low-risk visual port after render review.** Keep original dress as default until accepted. |
| #76 | `feat/equipment-materials-heraldry` — PBR finishes and shield heraldry | 14 commits; character-pipeline and Godot workflows passed. Shield/helmet exports still require rebuilding and visual review. | **Selective port after asset review.** Keep shader/material constraints and tests; do not count generator output as production runtime assets until rebuilt and installed. |
| #74 | `feat/player-morphs-inventory-weapons` — seed player inventory with every item | 7 commits; character pipeline passed, Godot run was cancelled. Description explicitly calls this a development/test inventory. | **Do not ship as campaign behaviour.** Retain tests or convert to a development fixture; normal starting gear, loot and shops should determine inventory. |
| #73 | `feature/ser-aldric-first-companion-model` — Aldric companion model | 7 commits; character pipeline and Godot passed, but Ara character build failed. Visual/rig/armour acceptance is outstanding. | **Hold as an asset candidate.** Fix the asset workflow and inspect the model; do not introduce the model as accepted runtime content yet. |
| #34 | `chore/consolidate-preview-and-review-workflows` — CI workflow consolidation | Hollowmere, Godot/Blender and screenshot workflows passed on its branch. Based on old `dev`; its changes remove/retire several workflows. | **Re-audit current workflows before porting.** Preserve useful separation and documentation, but do not apply historical deletions blindly. |
| #29 | `feature/player-character-creator` — first-run creator | 19 commits; no current-head workflow evidence. Depends on old PR #28 and stores many appearance values without rendering them on the player placeholder. | **Likely superseded in part by #87.** Salvage any useful creator UI/identity choices after checking the current Ara player path. |
| #26 | `ci/incremental-character-pipeline` — build caching | 15 commits stacked on #25; no current-head workflow evidence. It changes pipeline workflows/docs rather than merging character assets itself. | **Port after workflow consolidation.** Re-key caches against the current production pipeline and verify cache invalidation; do not merge the stale stack unchanged. |
| #25 | `fix/dress-selector-and-loading-review` — anatomy, clothing and browser loading | 15 commits; its latest listed Hollowmere, Godot/Blender, screenshot and male-anatomy workflows passed. Based on old `dev`; visual correctness is not established by CI. | **Salvage selectively.** Compare with #8 and #87, inspect current generated renders, then separate browser shell/deployment fixes from anatomy and garment changes. |
| #8 | `feature/wren-anatomy-piercings-halter-fit` — Wren anatomy and modular clothing | 179 commits; latest Wren Workshop and modular garment review workflows failed. Based on old `dev`; substantial overlap with #25 and #87. | **Do not merge wholesale.** Preserve as source history; extract only still-needed anatomy/garment changes after comparing with the current Ara pipeline and reviewed outputs. |
| #5 | `feature/audio-and-mode-select` — Campaign/Arena selector and AudioManager | 16 commits; Godot audio/mode workflow passed. Arena remains a placeholder and imported binary audio assets are not committed. Based on a very stale `dev`. | **Port audio/mode foundation selectively.** Validate buses and routing on `dev_2`; track Arena gameplay and asset import as separate incomplete work. |

## Branches with no unique commits against dev_2

The following branches compared as zero commits ahead of `dev_2` at the time of the audit. They are not merge candidates unless a new commit is added. Keep them until their historical purpose is accounted for; archival/cleanup can be a later, explicit operation.

- `audit/skill-spell-implementation-baseline`
- `feature/ara-skeleton-animation-validation`
- `feature/ara-visual-animation-review`
- `feature/iphone-web-preview-pipeline`
- `feature/port-action-economy`
- `feature/skill-magic-foundation-current-dev`
- `feature/terrain-character-grounding-test`
- `fix/anatomy-pelvic-landmark-port`
- `integration/hollowmere-dev-visual-review`
- `integration/hollowmere-npc-visuals`
- `integration/hollowmere-world-simulation`
- `integration/wren-modular-clothing`
- `maintenance/single-iphone-preview-pipeline`
- `test/chatgpt-session-write-access-20261105`
- `dev`

## Duplicate or closely related branch pairs

| Branches | Finding | Disposition |
|---|---|---|
| `feature/game-start-race-class` / `feature/game-start-race-class-validation` | Identical commit history and tree. | Keep one canonical reference; do not merge twice. |
| `feature/main-campaign-world-map` / `feature/main-campaign-world-map-validated` | Identical commit history and tree. | Keep one canonical reference; do not merge twice. |
| `feature/animal-attributes` / `feature/animal-riding-validation` | Riding branch is one commit ahead of animal-attributes. | Treat #110 as the continuation; review the one-commit delta. |
| `integration/two-storey-tankard-dev2`, `integration/save-load-dev2`, `test/save-restore-scene-dev2`, `integration/vision-foundation-dev2` | Their intended integration work is represented by merged PRs #119, #120 and #122. | Do not re-port without identifying genuinely new changes. |

## Large orphan branches requiring dedicated salvage review

These branches have meaningful unique histories relative to `dev_2`, but are too large, stale or overlapping to merge without a file-level audit:

| Branch | Ahead / behind dev_2 | Diff footprint | Initial interpretation |
|---|---:|---:|---|
| `feature/anatomy-geometry-revision` | 200 / 57 | 34 files, ~5,558 changed lines | Recent anatomy geometry/review work. Compare against #87 and current Blender pipeline; preserve accepted geometry changes and review renders. |
| `feature/male-anatomy-skinned-mesh` | 143 / 357 | 21 files, ~2,843 changed lines | Older male skinned-mesh work; compare with latest male anatomy work and avoid resurrecting superseded geometry. |
| `feature/shared-character-system` | 125 / 357 | 18 files, ~2,469 changed lines | Earlier shared character foundation; substantial overlap with #87 and Wren branches. |
| `feature/opening-village` | 194 / 357 | 35 files, ~4,929 changed lines | Earlier Hollowmere village implementation; compare with current `dev_2` and world branches before recovering any content. |
| `feature/iphone-hollowmere-ara-preview` | 178 / 357 | 36 files, ~4,981 changed lines | Old iPhone build/deployment path; likely superseded by current Pages pipeline. Audit only for missing deployment logic. |
| `feat/ara-hairstyles-medieval-equipment` | 33 / 102 | 182 files, ~6,949 changed lines | Large asset/model generation branch. Inventory generated assets versus source generators and current Ara library. |
| `feature/cosmo-tree-gen-evaluation` | 23 / 57 | 181 files, ~7,856 changed lines | Large vegetation asset evaluation; distinguish reusable production assets from evaluation outputs. |
| `feature/modular-character-poc` | 51 / 357 | 17 files, ~1,291 changed lines | Earlier modular character proof of concept; compare with current assembly pipeline. |
| `feature/missing-skill-runtime-port` | 21 / 11 | 8 files, ~331 changed lines | Focused runtime skill-effect work; overlaps skill progression branch and should be reconciled before either is ported. |
| `feature/farm-wildlife-creatures` | 22 / 54 | 9 files, ~593 changed lines | Animal/creature work; compare with #99 and #110 rather than duplicating creature state. |
| `feature/character-inventory-panel` | 14 / 139 | 8 files, ~457 changed lines | Older UI/equipment work; compare against current inventory and canonical character definitions. |
| `feature/arena-and-full-character-roster` | 7 / 104 | 7 files, ~1,936 changed lines | Roster/Arena content; compare with #5 and current shared character state before porting. |

## Initial codebase consistency findings

### Architecture boundaries

The current `docs/ARCHITECTURE.md` and `docs/MECHANICS_PORT_REGISTER.md` describe several systems as absent or not yet tested even though later merged work now includes:
- reusable building/door state and a two-storey tavern;
- SaveManager slots, quicksave/autosaves and campaign save/restore integration coverage;
- a reusable spatial vision/LOS foundation.

The architecture and porting documents need a fact-checked refresh after branch disposition. Do not update them by simply changing every status to “complete”: known save/load limitations, unimplemented stealth/AI, and missing gameplay integrations remain.

### Style enforcement

`.editorconfig` requires tabs in GDScript. The newly merged `scripts/simulation/vision_rules.gd` uses spaces for indentation. This is a concrete style-rule inconsistency and indicates that the current CI does not enforce the repository's formatting rules. Add a formatter/lint check or normalize changed GDScript consistently; do not reformat the entire repository as an incidental side effect.

### Test evidence versus acceptance

Headless Godot tests are useful but do not establish:
- correct 3D model/garment fit or animation deformation;
- correct camera framing and cinematic blocking;
- actual browser deployment and mobile interaction;
- visual occlusion/clipping or lighting quality.

Keep these as explicit visual acceptance gates rather than treating CI success as a substitute.

## Recommended consolidation order

1. Finish this audit with file-level review of all open PRs and unique orphan-branch diffs.
2. Revalidate small, focused gameplay candidates (#91 first; #110 after current-head tests; #76/#77 after asset review).
3. Split large systems (#90 skills, #87 character assembly, #88 world foundation) into independently reviewable slices.
4. Resolve overlaps among #8/#25/#87 and the anatomy/garment orphan branches before importing further character work.
5. Reconcile #99 farm quests with #90 companion/quest state and #110 animal simulation.
6. Port #5 audio/mode selection and #34/#26 workflow improvements only after checking current workflow ownership and deployment boundaries.
7. Update architecture/porting documentation from verified current behaviour.
8. Run the full Godot 4.7.2 suite after each integration batch; perform PC visual acceptance for asset/scene work.
9. Promote from `dev_2` only after the integrated baseline is coherent and stable.

## Complete branch-name inventory (129 branches)

```text
audit/skill-effect-branch-cross-reference
audit/skill-effect-parity-update
audit/skill-spell-implementation-baseline
audit/spell-parity-and-test-findings
chore/consolidate-preview-and-review-workflows
chore/remove-huggingface-deployment
chore/repository-formatting-rules
ci/enable-dev2-validation
ci/incremental-character-pipeline
deploy/wren-workshop-github-pages
dev
dev_2
diagnostic/ara-garment-surface-report
diagnostic/ara-report-on-character-configure
docs/content-census
docs/content-parity-audit
feat/ara-hairstyles-medieval-equipment
feat/ara-shields-helmets-hairstyles
feat/campaign-loading-feedback
feat/character-preview-loading-progress
feat/equipment-materials-heraldry
feat/player-morphs-inventory-weapons
feat/seasonal-wilderness-visuals
feat/tapered-split-dress-v2
feat/wilderness-art-and-gatherable-visuals
feat/wilderness-world-foundation
feature/action-contract-downed-lifecycle
feature/ally-combat-reactions
feature/anatomy-geometry-revision
feature/animal-attributes
feature/animal-riding-validation
feature/ara-character-evaluation
feature/ara-skeleton-animation-validation
feature/ara-visual-animation-review
feature/arena-and-full-character-roster
feature/audio-and-mode-select
feature/campaign-quest-journal
feature/character-inventory-panel
feature/character-pipeline-foundation
feature/character-starting-clothing
feature/combat-initiative-timeline
feature/combat-reaction-triggers
feature/combat-resolution-foundation
feature/cosmo-tree-gen-evaluation
feature/equipment-gameplay-stat-integration
feature/farm-wildlife-creatures
feature/farmstead-bear-creature-model
feature/full-world-port-foundation
feature/game-real-hollowmere-character-art
feature/game-start-race-class
feature/game-start-race-class-validation
feature/godot-web-pages-export
feature/hollowmere-building-port-spec
feature/hollowmere-cosmo-forest
feature/hollowmere-dialogue-ambient-chatter
feature/hollowmere-github-pages
feature/hollowmere-ironbond-opening-cutscene
feature/hollowmere-items-and-inventory-art
feature/hollowmere-shakedown-combat
feature/in-game-reaction-prompt
feature/ios-game-pwa
feature/iphone-hollowmere-ara-preview
feature/iphone-web-preview-pipeline
feature/legacy-audio-menu-dev
feature/legacy-audio-menu-dev2
feature/legacy-porting-matrix
feature/legacy-porting-matrix-dev2
feature/main-campaign-world-map
feature/main-campaign-world-map-validated
feature/male-anatomy-geometry-review
feature/male-anatomy-skinned-mesh
feature/mechanics-port-foundation
feature/missing-skill-runtime-port
feature/modular-character-poc
feature/movement-reactions
feature/opening-village
feature/organic-hollowmere-geography
feature/player-character-creator
feature/player-character-creator-dev
feature/player-character-visual-phase1
feature/player-custom-avatar-selection
feature/port-action-economy
feature/reaction-resolution-turn-safety
feature/reusable-npc-workshop
feature/runtime-tattoos
feature/save-load-system
feature/ser-aldric-first-companion-model
feature/shared-character-system
feature/skill-magic-foundation
feature/skill-magic-foundation-current-dev
feature/status-effects-combat-debuffs
feature/terrain-character-grounding-test
feature/unified-character-assembly
feature/vision-stealth-perception
feature/wren-anatomy-piercings-halter-fit
fix/anatomy-pelvic-landmark-port
fix/ara-review-crash-remove-legacy-wren-build
fix/combined-game-workshop-pages-deploy
fix/dress-selector-and-loading-review
fix/generic-clothing-visibility
fix/hollowmere-cast-validator
fix/keep-body-visible-under-clothing
fix/male-anatomy-surface-sampling
fix/modular-outfit-review-material-duplicates
fix/pages-deploy-artifact-based-v2
fix/pages-deploy-game-and-workshop-artifacts
fix/pages-game-artifact-path
fix/player-equipment-visuals
fix/publish-all-male-workshop-previews
fix/skill-effect-test-rank-fixtures
fix/split-game-export-and-pages-deploy
fix/workshop-dress-and-game-loading-stages
fix/wren-lace-fishnet-and-anatomy
integration/hollowmere-dev-visual-review
integration/hollowmere-npc-visuals
integration/hollowmere-world-simulation
integration/opening-cinematic-dev2
integration/save-load-dev2
integration/two-storey-tankard-dev2
integration/vision-foundation-dev2
integration/wren-modular-clothing
main
maintenance/single-iphone-preview-pipeline
test/additional-skill-effect-coverage
test/chatgpt-session-write-access-20261105
test/save-manager-hardening
test/save-restore-scene
test/save-restore-scene-dev2
```

## Next audit pass

The next pass should inspect the actual changed files and commit histories for the unique branches, beginning with:
1. #91 equipment rules and #110 animal/riding;
2. #90 skills versus `feature/missing-skill-runtime-port`;
3. #87 unified assembly versus #8/#25 and the anatomy branches;
4. #88 world foundation versus the opening-village and geography branches;
5. the orphaned combat/action/reaction branches and their overlap with the current simulation kernel.

For each, record: files changed, already-integrated hunks, unique reusable hunks, API/data conflicts, missing tests, latest CI status, visual acceptance needs, and a final merge/port/defer/archive recommendation.
