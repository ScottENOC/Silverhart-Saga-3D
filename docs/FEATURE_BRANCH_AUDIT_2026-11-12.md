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


## Second-pass file-level findings (in progress)

### #91 equipment gameplay/stat integration

The actual changes are small and useful: validate item type against its equipment slot, reject two-handed/offhand conflicts without destroying inventory, and include the equipped helmet's reduction in combat mitigation.

However, the branch's versions of `character_state.gd`, `combat_rules.gd` and `test_simulation.gd` are substantially older than the current `dev_2` files (349 vs 445 lines, 125 vs 189, and 1,183 vs 1,928 respectively). The passing workflow therefore validates the old branch snapshot, not the code as it would integrate today.

**Port recommendation:** transplant the two focused rule changes and their regression tests onto current `dev_2`; do not merge the old files. Current item definitions confirm `nasal_helm` is a helmet in the `helmet` slot, and spear/bow are two-handed while dagger/sword support offhand use. Run the complete current Godot suite after the port.

### #110 animal simulation and riding

The animal catalogue and riding work is genuinely new, but the current branch has no Actions run for its current head. The code review found a concrete health calculation defect:

- Horse profile declares 50 health and 4 `health` skill ranks.
- Wolf profile declares 20 health and 1 `health` rank.
- `register_character()` calls `CharacterState.sync_skill_effects()`, which adds 10 max/current HP per unapplied `health` rank.
- Consequently, registering these profiles increases the horse from approximately 50 to 90 HP and the wolf from approximately 20 to 30 HP. The current tests check the values immediately after `AnimalCatalog.create_state()`, before registration, so they miss the defect.

The source-compatible interpretation is 10 base HP plus four/one Health ranks. Correct the profile base values and apply the skill effect exactly once (while retaining the intended individual variance), then assert health after registration and save/load.

The happy-path riding tests cover mounting, shared occupancy, movement TP, initiative exclusion, dismounting and save/load. They do not yet cover a mount or rider dying/becoming unconscious while mounted, broken reciprocal links, or size compatibility beyond a hard-coded minimum mount size. In particular, `dismount_animal()` currently requires the mount to be able to act, which can strand a rider on an incapacitated mount. Add an explicit forced/emergency dismount or lifecycle cleanup rule and tests.

**Port recommendation:** fix these issues on a clean `dev_2` integration branch, add current-head CI, and review the rider screenshots. Do not merge the stale `world_simulation.gd` or `hollow_tankard.gd` wholesale.

### #90 skill, progression, companion and farmstead branch

A direct content comparison against current `dev_2` shows that several files highlighted by the PR are already identical to the baseline:
- `data/skills/skill_definitions.json`
- `scripts/simulation/skill_catalog.gd`
- `scripts/simulation/npc_skill_spending.gd`
- `data/characters/hollowmere_npcs.json`
- `data/characters/hollowmere_loadouts.json`
- `data/magic/base_spells.json`

The current branch's `character_state.gd`, `world_simulation.gd` and `hollow_tankard.gd` are older snapshots than `dev_2`; they omit later status-effect, building, save/load and other integration work. Its companion dialogue code also lacks the canonical companion-ID normalization now present in `dev_2`.

**Port recommendation:** do not merge PR #90 as a 70-commit feature. Its skill catalogue, skill metadata and NPC spending foundation are already present. Audit only the remaining farmstead visuals, dialogue/quest additions and any genuinely missing skill-effect behaviour. Reconcile the bear quest with #99's dire-wolf/Tessa rescue design before adding either to the campaign.

### `feature/missing-skill-runtime-port` orphan branch

A preliminary content comparison found its character-creation rules, skill-progression implementation, player-creator code and simulation action-request contract identical to current `dev_2`. Its character/combat/world files are older and omit current status-effect and building integrations; its test file is also an older subset of the current suite.

**Provisional disposition:** likely superseded/archival rather than a merge candidate. Complete a final file-by-file check for any isolated skill-effect code not represented in current `StatusEffectRules` or `CombatRules` before closing it out.

### Repository style rule reconciliation

The style mismatch is broader than `vision_rules.gd`: current GDScript files such as `character_state.gd` also use spaces while `.editorconfig` specifies tabs. The repository needs one agreed GDScript indentation convention and an automated check. Do not apply a repository-wide formatting churn until that convention is decided.


### #99 farmstead rescue / dire-wolf quest

The branch contains a genuinely distinct campaign beat: Reyna's recruitment is moved from the simple grain-raiding bear quest to a three-stage missing-child rescue (find Tessa's trail, rescue her, defeat the dire wolf). The new `FarmsteadDireWolfEncounter` service and scene staging are not present in current `dev_2`.

The branch's `hollow_tankard.gd` and test files are older snapshots, so this is not a safe whole-file merge. Its companion-content change replaces `reyna_bear_hunt` with `reyna_dire_wolf_hunt`; that is a campaign design/content decision to carry forward deliberately, not a mechanical merge conflict to resolve automatically.

The new dire-wolf helper repeats two issues seen in the current bear helper:
- It sets a large explicit max health and also adds `health` skill ranks, which `register_character()` applies again through `sync_skill_effects()`.
- It marks every character in the simulation dormant at encounter start, but only restores the party members at finish.

**Port recommendation:** retain the Tessa rescue as a distinct quest improvement, but port its quest-state and scene logic onto current `dev_2`. Make the encounter use the shared animal profile/registration path if #110 is accepted, avoid double-applying health skills, and make encounter participation restore each character's prior dormant/side state.

### Existing `dev_2` farmstead bear issues

The current `scripts/simulation/farmstead_bear_encounter.gd` has the same health calculation problem: it sets the bear to 180 HP and assigns four `health` ranks, then `WorldSimulation.register_character()` calls `sync_skill_effects()`, adding another 40 HP. The registered bear therefore has 220 HP, not the declared 180.

The encounter also sets every simulation character's `combat_dormant` flag to true and does not restore the previous values for non-party characters in `finish()`. This is already in the integration baseline and should be fixed independently of whether #99 is ported.

### #87 canonical character assembly schema

The schema migration is valuable, but the current branch's schema-v2 `hollowmere_npcs.json` contains 14 records while current `dev_2` schema-v1 contains 22. The eight records missing from the branch are:
- Ser Aldric Thorne
- Nix Sharpear
- Warlord Grukk Ironhide
- Reyna Fletcher
- Mirabel Quill
- Fenn Oakheart
- Brother Alden
- Snik Fangtooth

The branch also deletes `hollowmere_loadouts.json` and moves inventory/equipment into the character definitions. That is a sensible canonical-source direction, but it must migrate all 22 current records and preserve current quest/companion additions. Do not apply the schema-v2 JSON as-is.

The branch adds a new `CharacterAssemblyResolver` and substantial Blender/Ara tooling. Its current-head CI evidence is only the average-body anatomy review; the Godot validation and local Blender/in-game acceptance gates remain open.

### #88 strict Godot validation runner

The latest #88 Godot workflow failed in `tests/test_character_appearance.gd:73`: the synthetic bra material's applied tint did not equal `appearance.bra_tint`. A later assertion also emitted `Parameter "material" is null`. The test script subsequently printed a success message, but the new `tools/ci/run_godot_checked.sh` correctly converted the emitted script/material errors into a failing workflow.

The hex-grid and simulation tests passed in that same run. The strict runner is a useful CI improvement to port to current `dev_2` (after reviewing its detection patterns), while the appearance test/material defect must be fixed rather than weakening the runner.


## Permanent feature-branch preservation policy

Feature branches are retained as permanent development history by default. Consolidation is about integrating the useful work into `dev_2`, not deleting the original branch.

- **Merged:** retain the branch; close the PR when appropriate and record the merge commit / replacement integration.
- **Superseded:** retain the branch and record the successor branch or PR.
- **Deferred/incomplete:** retain the branch for future work; do not close merely because it is not currently mergeable.
- **Duplicate:** retain both histories initially and mark one as canonical. Do not delete either as part of this audit.
- **Abandoned:** retain unless the repository owner explicitly authorises deletion.
- Do not reuse old branch names for new work. Create fresh branches from `dev_2` for new integration or follow-up changes.

Closing a pull request is a review-queue decision, not a branch deletion instruction. A closed PR's branch may still be checked out, compared, and used as the source for a later port.


## Second-pass: combat, actions and reaction branches

### Current integration baseline already contains much of this cluster

The following files on old feature branches are already present in `dev_2`:

- `scripts/simulation/status_effect_rules.gd` from `feature/status-effects-combat-debuffs` is byte-for-byte identical to `dev_2`.
- `scripts/ui/combat_initiative_timeline.gd` from `feature/combat-initiative-timeline` is byte-for-byte identical to `dev_2`.
- `scripts/ui/reaction_prompt.gd` from `feature/in-game-reaction-prompt` exists in `dev_2`; the only difference in the inspected file is that the current UI description correctly explains that nearby defenders may react and each option is paid for by its named character.
- `SimulationActionRequest`, `SimulationActionResult` and `SimulationEvent` are already in `dev_2`. The old `feature/action-contract-downed-lifecycle` request enum predates the current FEINT action, and its `world_simulation.gd` is only 250 lines versus the current 1,012-line implementation. Do not transplant its old world simulation or request type over the current implementation.
- `CombatRules` exists in `dev_2` and is materially more developed than the old `feature/combat-resolution-foundation` version (189 lines versus 117 in the inspected version). The old branch lacks current weapon-family mapping and skill-rank option resolution. Its old combat resolver must not replace the current one.

The current `WorldSimulation` owns pending reaction state, request IDs, eligibility validation, TP payment, resolution/cancellation, pending attack resumption, movement-reaction sequencing and lifecycle interruption. The old `feature/ally-combat-reactions`, `feature/combat-reaction-triggers`, `feature/movement-reactions` and `feature/reaction-resolution-turn-safety` branches are all far behind `dev_2`; they should be treated as historical source branches, not as merge candidates.

### Status-effect integration is present and tested

The current baseline:
- applies status effects on successful attacks;
- advances poison/withering using actual gained TP;
- applies hamstring as a movement-cost multiplier;
- persists poison, withering, sunder and hamstring state through CharacterState serialization;
- has focused tests for proc behaviour, rank caps, ranged exclusions, tick durations, lethal poison, save/load and movement costs.

The implementation is integrated through `WorldSimulation`, `MovementRules` and `CharacterState`; it is not just an unused catalogue/helper. No new merge is required from `feature/status-effects-combat-debuffs`.

### Initiative timeline and reaction prompt

The initiative timeline branch's UI script is already byte-identical to current `dev_2`. The prompt is also integrated, with a small current-baseline improvement to explain multi-character reaction ownership. These branches should be marked **integrated; retain original branch** rather than merged again.

### Branch-by-branch provisional disposition

| Branch | Comparison to dev_2 | Disposition |
|---|---|---|
| `feature/action-contract-downed-lifecycle` | 10 commits ahead / 148 behind; request/result/event contracts are present but old request enum lacks FEINT and world simulation is an obsolete snapshot. | **Superseded/integrated in evolved form.** Preserve history; do not merge. |
| `feature/ally-combat-reactions` | 7 ahead / 141 behind; old world simulation is far behind current reaction coordinator. | **Superseded/integrated in evolved form.** Preserve history; do not merge. |
| `feature/combat-initiative-timeline` | 36 ahead / 54 behind; timeline UI is byte-identical to current `dev_2`. | **Integrated.** Preserve history; no re-merge. |
| `feature/combat-reaction-triggers` | 8 ahead / 145 behind; old world-simulation implementation is superseded by the current reaction lifecycle. | **Superseded/integrated in evolved form.** Preserve history; do not merge. |
| `feature/combat-resolution-foundation` | 36 ahead / 154 behind; old CombatRules lacks later skill/equipment integration and is not a safe replacement. | **Superseded in evolved form.** Preserve history; inspect only for any isolated missing rule not represented in current tests. |
| `feature/in-game-reaction-prompt` | 2 ahead / 142 behind; UI exists in current baseline with improved multi-reactor explanation. | **Integrated.** Preserve history; no re-merge. |
| `feature/movement-reactions` | 8 ahead / 140 behind; current WorldSimulation owns movement reaction flow and pending movement context. | **Superseded/integrated in evolved form.** Preserve history; do not merge. |
| `feature/reaction-resolution-turn-safety` | 4 ahead / 147 behind; current baseline resolves/cancels pending reactions on lifecycle and combat transitions. | **Superseded/integrated in evolved form.** Preserve history; do not merge. |
| `feature/status-effects-combat-debuffs` | 10 ahead / 10 behind; status rules file is byte-identical and covered by current simulation tests. | **Integrated.** Preserve history; no re-merge. |
| `test/additional-skill-effect-coverage` | 3 ahead / 23 behind; test-only branch. | **Compare test assertions against current suite; port only missing cases.** |
| `test/save-manager-hardening` | 1 ahead / 4 behind; one focused save-manager test change. | **Review the single test delta against current SaveManager and test suite; likely a small port candidate.** |

### Architecture and maintainability checks still required

The presence of these systems in `dev_2` is not a full architectural sign-off. The follow-up review should verify:
- simulation remains authoritative and emits stable, typed events for presentation;
- reaction requests cannot leave an active turn or pending attack permanently stranded when a reactor dies, becomes incapacitated, combat ends, or a request is cancelled;
- pending reaction / pending attack / pending movement context are either serialized or explicitly disallowed at save boundaries;
- reaction option IDs are unique within a request and every option's reactor is validated at resolution;
- status-effect stacking, source attribution, expiry, lethal poison and save/load semantics are explicitly documented;
- status effects are not applied twice when an attack is resumed after a reaction;
- the UI prompt handles a stale request ID safely and cannot resolve a newer reaction with an old button press.

These are review/test requirements, not claims that a defect has already been demonstrated.


### Additional save/reaction boundary verification

The save boundary is deliberately explicit in the current baseline:
- `HollowTankard` blocks manual, quick and autosaves during combat, dialogue, pending reactions and the opening confrontation.
- `WorldSimulation.to_dict()` persists world clock, combat flag, party, characters, resources and buildings, but does not serialise a pending reaction, pending attack context or active scheduler turn.
- `WorldSimulation.load_dict()` clears pending reactions and resets the reaction request counter and turn scheduler; the saved active combat flag is subsequently cleared by the campaign scene restore path.
- Autosaves are only triggered outside combat, pending reactions, dialogue and the opening confrontation.

This is a coherent “save only at safe campaign boundaries” design. The test and documentation should preserve that invariant; do not attempt to serialize half-finished reaction prompts as part of the current save format.

### Test-only branch findings

- `test/save-manager-hardening`'s `tests/test_save_manager.gd` is byte-for-byte identical to the current `dev_2` file. Its single unique commit is already represented in the baseline; no port is required.
- `test/additional-skill-effect-coverage` is an older test-suite snapshot. Its inspected assertions for Fast Movement, Goblin Opportunist and parry TP cost are all present in current `tests/test_simulation.gd`. Current tests also include newer weapon-skill, status-effect, feint and vision coverage. Do not merge the older test file over the current suite.

Both branches should be retained and marked **integrated**.


## Second-pass: Hollowmere, campaign content, world map and wilderness branches

### Work already represented in dev_2

- `feature/hollowmere-building-port-spec` is the historical source for the building/door framework now integrated through PR #119. Its branch is 39 ahead / 54 behind, but must not be merged over the current two-storey tavern implementation.
- `feature/main-campaign-world-map-validated` has its `main_campaign_world_map.gd` and `main_campaign_world_map_data.gd` files byte-for-byte identical to current `dev_2`. The branch's unique history is already represented in the baseline.
- `feat/wilderness-art-and-gatherable-visuals` has `wilderness_resource_visual.gd` byte-for-byte identical to current `dev_2`; its resource visual work is integrated.
- `feature/hollowmere-shakedown-combat` has its `hollowmere_campaign_content.gd` byte-for-byte identical to current `dev_2`. The current `hollowmere_encounter.gd` differs in two lines: it sets participants to `ActionEconomy.COMBAT_TURN_READY_TP` rather than `max_time_points`, so the old branch must not overwrite the current turn-readiness rule.
- `feature/organic-hollowmere-geography` contains the organic world feature helper and village-data work already represented in current `dev_2`; its older village scene is substantially shorter (442 lines versus 601) and predates the current imported Cosmo tree assets, creature actors and later village presentation work. Its helper differs only in a small compatibility expression using `back()` versus explicit final-index access.
- `feature/campaign-quest-journal` is an older journal implementation. Current `CampaignJournal` is more extensive, with NPC/faction standing, knowledge and merchant influence state; do not replace it with the 211-line branch snapshot.
- `feature/hollowmere-dialogue-ambient-chatter` is superseded by current campaign content. Its ambient chatter lacks the current shakedown-choice gate, and its campaign content is an older subset of the current file.
- `feature/hollowmere-items-and-inventory-art` is an older 63-item catalogue; current `item_definitions.json` has 76 items including later underwear/garment definitions. Do not replace current item data with the older catalogue.
- `feat/seasonal-wilderness-visuals` contains an older procedural-only tree implementation. Current `seasonal_tree_visual.gd` uses imported Kenney Nature Kit GLBs with procedural winter fallback; preserve the current asset-backed implementation.
- `feature/legacy-porting-matrix` and `feature/mechanics-port-foundation` are documentation-only source branches. Their registers predate many merged systems; use the current audit and current baseline as the source of truth rather than copying their old status tables.
- `feature/hollowmere-ironbond-opening-cutscene` is a source branch for the opening cinematic. The current integration work is tracked separately in PR #121; compare the actual integration branch and its reviewed code rather than merging this source branch independently.

### Provisional dispositions

| Branch | Comparison / evidence | Disposition |
|---|---|---|
| `feature/organic-hollowmere-geography` | 17 ahead / 85 behind; helper/data content is represented, scene is an older subset. | **Integrated/superseded.** Preserve history; no wholesale merge. |
| `feature/hollowmere-building-port-spec` | 39 ahead / 54 behind; its framework is now PR #119. | **Integrated via #119.** Preserve history; no re-merge. |
| `feature/main-campaign-world-map-validated` | 12 ahead / 136 behind; map UI and data files are byte-identical to current. | **Integrated.** Preserve history; no re-merge. |
| `feature/wilderness-world-foundation` | Branch comparison returned 404; branch was in the earlier inventory but is not currently resolvable by GitHub. | **Unresolved reference.** Do not infer deletion or recreate it; verify branch existence through the live branch list. |
| `feat/wilderness-art-and-gatherable-visuals` | 18 ahead / 119 behind; resource visual script is byte-identical to current. | **Integrated.** Preserve history; no re-merge. |
| `feature/hollowmere-cosmo-forest` | 4 ahead / 53 behind; very large Cosmo add-on, generated assets and demo tree. Current village references Cosmo-generated trees. | **Integrated asset source; review licensing/provenance and generated runtime assets only if a specific missing variant is identified.** Preserve history. |
| `feat/seasonal-wilderness-visuals` | 5 ahead / 121 behind; older procedural tree script predates current Kenney GLB implementation. | **Superseded.** Preserve history; do not merge. |
| `feature/hollowmere-dialogue-ambient-chatter` | 16 ahead / 133 behind; older campaign content and chatter implementation. | **Superseded by richer current campaign content.** Preserve history; do not merge. |
| `feature/hollowmere-items-and-inventory-art` | 2 ahead / 138 behind; older 63-item catalogue versus current 76-item catalogue. | **Integrated/evolved.** Preserve history; do not replace current data. |
| `feature/hollowmere-shakedown-combat` | 50 ahead / 127 behind; campaign content file identical; encounter differs only in old max-TP initialisation. | **Integrated with later correction.** Preserve history; no re-merge. |
| `feature/campaign-quest-journal` | 5 ahead / 134 behind; old 211-line journal versus current 331-line reputation-aware implementation. | **Integrated/evolved.** Preserve history; no re-merge. |
| `feature/legacy-porting-matrix` | 2 ahead / 111 behind; documentation-only and stale. | **Superseded by current audit/register.** Preserve history. |
| `feature/mechanics-port-foundation` | 1 ahead / 154 behind; documentation-only and stale. | **Superseded by current audit/register.** Preserve history. |
| `feat/campaign-loading-feedback` | 1 ahead / 101 behind; one focused `world_root.gd` change. | **Inspect the isolated loading-feedback delta against current scene loading before deciding whether to port.** |
| `feature/campaign-loading-feedback` | Branch comparison returned 404; only `feat/campaign-loading-feedback` was resolvable. | **Unresolved historical name; do not assume it exists.** |
| `feature/hollowmere-ironbond-opening-cutscene` | 17 ahead / 54 behind; source implementation overlaps current PR #121 integration branch. | **Source branch retained; PR #121 remains the integration candidate and still needs visual acceptance.** |
| `feature/game-real-hollowmere-character-art` | 6 ahead / 159 behind; adds model validation tooling and web-export workflow changes. | **Audit tooling separately; avoid merging stale workflow changes.** |

### World-content review notes

The current Hollowmere scene is materially ahead of several source branches. The 3D village scene now includes imported tree variants, creature actor integration and later presentation code; old village snapshots should be treated as source references, not replacements. The world-map UI/data are already in the current baseline, while a truly traversable campaign map, inter-settlement travel and broader world simulation remain separate gameplay milestones and must not be marked complete merely because the map widget exists.


## Second-pass: CI, Pages deployment, iPhone preview and audio branches

### Current deployment architecture and a significant integration boundary

The current `dev_2` workflow inventory contains 12 workflows. The production GitHub Pages workflows are still explicitly wired to `dev`:

- `godot-web-export.yml` triggers on pushes and upstream character workflow completions on `dev`, explicitly checks out `ref: dev`, and queries supporting character/workshop artifacts from `dev`.
- `wren-workshop.yml` builds on `dev` and selected character-fix branches; its Pages upload/deploy steps are gated on `github.ref_name == 'dev'`.
- The old `combined-pages-deploy.yml` is not present in current `dev_2`.

**Consequence:** a manual dispatch of the current game export workflow from `dev_2` still checks out `dev` and retrieves `dev` artifacts. It is not a valid preview of the `dev_2` game. A push to `dev_2` does not trigger the production Pages workflow. Do not change the production deploy to `dev_2` implicitly: first decide whether we want a separate dev_2 preview deployment or to keep Pages as a dev-only release channel. This is a concrete blocker to using the current Pages URL as visual acceptance of unmerged `dev_2` work.

### Character/workshop pipeline branches

- `chore/consolidate-preview-and-review-workflows` deletes three dedicated workflows (iPhone preview, male anatomy, Wren modular review) and retains/updates only selected ones. Do not apply its historical deletions wholesale; current pipeline has multiple independent asset build/review stages.
- `ci/incremental-character-pipeline` is a large stale workflow/Blender stack (30 ahead / 160 behind) that removes the male anatomy workflow and changes web export, Wren Workshop, anatomy generators and loading shell. It must be split into cache improvements, generator changes and deployment changes.
- `fix/ara-review-crash-remove-legacy-wren-build` modifies several workflows and Wren docs; inspect against current Ara pipeline before porting.
- `fix/hollowmere-cast-validator` is a focused validator change (1 ahead / 10 behind); review its stricter cast validation against the current validator and retain only useful test coverage.
- `feature/iphone-web-preview-pipeline` compares as zero commits ahead of `dev_2` and has no unique merge content.

### Godot web export / Pages branch family

The following branches are historical iterations of the game export and Pages workflow:
- `feature/godot-web-pages-export`
- `feature/hollowmere-github-pages`
- `fix/combined-game-workshop-pages-deploy`
- `fix/pages-deploy-artifact-based-v2`
- `fix/pages-deploy-game-and-workshop-artifacts`
- `fix/pages-game-artifact-path`
- `fix/split-game-export-and-pages-deploy`
- `fix/workshop-dress-and-game-loading-stages`
- `deploy/wren-workshop-github-pages`

These branches are all substantially behind current `dev_2` and change overlapping workflow files. Some introduced a combined Pages deploy, while later iterations removed it and returned to separate artifact flows. The current `godot-web-export.yml` is a much later 329-line workflow that fetches successful supporting artifacts and publishes the game. Do not merge old workflow files over it. If the dev_2 preview requirement is accepted, implement a small dedicated preview workflow using the dev_2 SHA and isolated artifact/deployment path; do not resurrect an old combined deployment design by default.

### Audio and mode-selection branch family

- `feature/legacy-audio-menu-dev2` has `audio_manager.gd`, `main_menu.gd` and `main_menu.tscn` byte-for-byte identical to current `dev_2`.
- Current `project.godot` autoloads AudioManager and starts at the Campaign/Arena main menu. The arena scene remains a placeholder.
- `feature/ios-game-pwa` has its PWA packaging tool and phone-testing instructions byte-for-byte identical to current `dev_2`.
- `feature/audio-and-mode-select` / PR #5 is historical source work; current mode/audio scripts are already integrated.
- Legacy audio binaries are not stored in the repository. `tools/import_legacy_audio.py` downloads the pinned original `Hex-crpg` audio assets and converts them with FFmpeg. The current audio validation workflow performs that import before Godot smoke tests.
- `audio-mode-validation.yml` is currently triggered for PRs/pushes to `dev`, not `dev_2`; manual dispatch can be used for a selected branch. Do not assume a `dev_2` PR automatically runs this workflow.

### Provisional dispositions

| Branch | Comparison / evidence | Disposition |
|---|---|---|
| `chore/consolidate-preview-and-review-workflows` | 7 ahead / 154 behind; removes three dedicated workflows. | **Do not merge wholesale.** Salvage documentation only after reconciliation with current workflow inventory. |
| `ci/enable-dev2-validation` | 1 ahead / 6 behind; focused Godot validation trigger change. | **Review against current workflow; likely already superseded by dev_2 PR CI.** |
| `ci/incremental-character-pipeline` | 30 ahead / 160 behind; broad stale pipeline/generator/web-shell changes. | **Split and salvage only specific cache or generator improvements.** |
| `feature/godot-web-pages-export` | 13 ahead / 165 behind; early web export workflow. | **Superseded by current 329-line export workflow.** Preserve history. |
| `feature/hollowmere-github-pages` | 5 ahead / 162 behind; early Pages workflow iteration. | **Superseded.** Preserve history. |
| `feature/ios-game-pwa` | 12 ahead / 160 behind; PWA tool and phone guide are byte-identical to current. | **Integrated.** Preserve history; no re-merge. |
| `feature/iphone-web-preview-pipeline` | 0 ahead / 352 behind. | **No unique commits.** Retain as historical branch. |
| `deploy/wren-workshop-github-pages` | 1 ahead / 166 behind; old workshop Pages changes. | **Superseded by current Wren workflow.** Preserve history. |
| `fix/combined-game-workshop-pages-deploy` | 4 ahead / 118 behind; adds combined deploy file absent from current. | **Do not restore without an explicit architecture decision.** |
| `fix/pages-deploy-artifact-based-v2` | 4 ahead / 116 behind; earlier artifact workflow. | **Superseded by current export workflow.** |
| `fix/pages-deploy-game-and-workshop-artifacts` | 9 ahead / 117 behind; removes combined deploy and changes artifact handling. | **Historical iteration; current workflow supersedes.** |
| `fix/pages-game-artifact-path` | 1 ahead / 114 behind; small path fix on old workflow. | **Check whether current workflow already handles this path; no wholesale merge.** |
| `fix/split-game-export-and-pages-deploy` | 1 ahead / 115 behind; old export workflow change. | **Superseded unless a specific regression is found.** |
| `fix/workshop-dress-and-game-loading-stages` | 4 ahead / 157 behind; mixes workshop pipeline and game loading screen changes. | **Split by responsibility; compare loading changes against current `world_root.gd`.** |
| `fix/hollowmere-cast-validator` | 1 ahead / 10 behind; focused validator. | **Small salvage candidate after checking current validator.** |
| `fix/ara-review-crash-remove-legacy-wren-build` | 4 ahead / 155 behind; workflow/docs changes. | **Review isolated fixes only; preserve current independent build stages.** |
| `chore/remove-huggingface-deployment` | 2 ahead / 163 behind; removes old HF audit/reset workflows. | **Historical deployment cleanup; current Pages architecture already supersedes HF.** |
| `feature/legacy-audio-menu-dev2` | 10 ahead / 107 behind; audio manager, main menu and scene are byte-identical to current. | **Integrated.** Preserve history; no re-merge. |

### Deployment decision required before the next visual review cycle

Keep production Pages deployment on `dev` unless intentionally changing release policy. If `dev_2` needs a phone-review URL before promotion, create a separate preview workflow and URL that:
1. checks out the exact `dev_2` commit (not hard-coded `dev`);
2. builds its own game artifact and required character/workshop assets from that same SHA or pinned compatible artifacts;
3. publishes to an isolated preview path or separate Pages environment;
4. never overwrites the production `dev` build;
5. reports the source commit in the preview page so screenshots can be tied to a known revision.


## Second-pass: Ara character, clothing, anatomy and workshop branches

### Character foundation and starting clothing

- `feature/character-pipeline-foundation` is documentation-only against current `dev_2` (2 ahead / 525 behind). Current `docs/CHARACTER_PIPELINE.md` and workflow structure have moved on substantially; use current docs as the baseline.
- `feature/character-starting-clothing` has its `tests/test_starting_clothing.gd` byte-for-byte identical to current `dev_2`. Its actor, item data and creation rules are older snapshots; current starting-clothing behaviour is already present and the actor has since evolved. No merge required.
- `feature/player-character-visual-phase1` has its phase-one design document identical to current; its 419-line creator script is older than current `dev_2` (495 lines). It explicitly describes height/build as whole-model scaling, not true anatomical morphs, and garment selection as saved state rather than mesh swapping. The current creator has since evolved; preserve the doc as a scope boundary, not a code merge.
- `feature/player-custom-avatar-selection` is a three-line scene integration change on an old base. Check whether its specific selection behaviour is present in current `HollowTankard` before any port.
- `feature/character-inventory-panel` and `feat/player-morphs-inventory-weapons` are older UI/test inventory work; do not ship the all-items inventory as campaign starting equipment. Use test fixtures for exhaustive catalogue coverage.

### Character assembly, Ara assets and NPC workshop

- `feature/unified-character-assembly` remains a major salvage candidate, not a merge candidate. The branch's schema-v2 NPC file has 14 records versus 22 current schema-v1 records, and deletes the separate loadout file. Any adoption must migrate all 22 current NPCs and preserve their quest/companion state.
- `feat/ara-hairstyles-medieval-equipment` has its 2,341-line runtime hair manifest byte-for-byte identical to current `dev_2`; the current build tool for medieval armour props has since evolved slightly. Its asset/manifest work is represented, but any missing GLB or material variant should be identified by manifest/path before adding duplicate assets.
- `feature/reusable-npc-workshop` contains `build_npc_previews.py` and `npc_profiles.json`, neither of which exists in current `dev_2`. This is potentially useful tooling for a 100+ NPC roster, but it is built on a very stale character assembler (5 ahead / 357 behind). Treat as a deferred tooling salvage candidate; first align it to the current character definition/resolver schema.
- `feature/ara-character-evaluation` is a documentation/workshop workflow branch on a very old base. Use its evaluation findings only where they still describe the current Ara assets; do not replace current workflow files.
- `feature/runtime-tattoos` has the live tattoo controls and implementation in `site/index.html`; current `dev_2` contains the same tattoo UI and runtime code. The remaining differences in the page are later unrelated workshop improvements, so no merge is needed.

### Clothing visibility and outfit pipeline fixes

The body-visible-under-clothing safety rule is present in current `AraCharacterActor`: the current implementation hides only surfaces positively identified as known garment surfaces; unknown surfaces remain visible rather than risking holes in the skin. The current path also normalises garment labels and includes the later surface-report diagnostics.

The old fixes:
- `fix/generic-clothing-visibility`
- `fix/keep-body-visible-under-clothing`
- `fix/player-equipment-visuals`

are earlier versions of this logic and are materially shorter than current `ara_character_actor.gd` (523–551 lines versus 574). They must not be merged over the current actor. This code-level guard does not prove visual acceptance: transparent fabric, surface naming, skin visibility, clipping and body/garment fit still require the current workshop render and in-game checks.

`fix/wren-lace-fishnet-and-anatomy` is also an older patch-layering version (208 lines versus 233 current) and predates later idempotency/source-contract handling. Current pipeline code already has the underTop/underBottom, lace/fishnet and opacity work. Do not apply the old patch over the current script. `fix/modular-outfit-review-material-duplicates` is an earlier render script version (187 lines versus 188 current); inspect only if a specific missing material label or duplicate-render regression is reported.

### Anatomy geometry branch family — do not merge before visual acceptance

The geometry branches remain active work, not completed integration candidates:
- `feature/anatomy-geometry-revision` (200 ahead / 57 behind; 34 changed files, ~5,558 changed lines) is the current broad anatomy workstream. Its latest Average-body anatomy review run #43173981591 was still in progress at this audit pass (commit `e2d1c4c361058da8f0042359f8dc369c567c8ffa`).
- `feature/male-anatomy-skinned-mesh` (143 ahead / 357 behind) is an older skinned-mesh implementation. Its latest Male anatomy blockout run #42186638804 passed on 6 November, but the geometry-revision branch is newer; do not resurrect older mesh geometry without comparing outputs.
- `feature/male-anatomy-geometry-review` and `fix/male-anatomy-surface-sampling` are older generator/review iterations. Their latest character-pipeline validation runs passed, but their Blender generator files are behind the current 463-line `add_male_anatomy.py`.
- `fix/anatomy-pelvic-landmark-port` had no Actions runs found for the branch.
- `feature/wren-anatomy-piercings-halter-fit` has failed Wren Workshop and modular garment review runs on its latest listed head (8 November). It overlaps current Ara base anatomy/clothing work and should not be merged wholesale.

The immediate acceptance criterion is not simply a green generator workflow: inspect the current male and female body renders, then validate the actual skinned meshes in Godot. The base-body shape, anatomy colour/material, deformation and clothing fit must be accepted before treating the anatomy/assembly branches as production-ready.

### Provisional dispositions

| Branch | Comparison / evidence | Disposition |
|---|---|---|
| `feature/character-pipeline-foundation` | 2 ahead / 525 behind; docs-only. | **Superseded documentation.** Preserve history. |
| `feature/character-starting-clothing` | 12 ahead / 63 behind; starting-clothing test is byte-identical to current. | **Integrated/evolved.** Preserve history; no re-merge. |
| `feature/male-anatomy-geometry-review` | 5 ahead / 147 behind; older generator branch, CI passed on 7 November. | **Superseded by current anatomy geometry work.** Preserve history. |
| `feature/player-character-visual-phase1` | 12 ahead / 124 behind; phase-one doc identical, creator script older. | **Integrated/evolved.** Preserve history; no re-merge. |
| `feature/player-custom-avatar-selection` | 1 ahead / 64 behind; three-line scene change. | **Check for a missing behaviour only; otherwise superseded.** |
| `feature/reusable-npc-workshop` | 5 ahead / 357 behind; two new tooling files absent from current. | **Deferred salvage candidate after schema alignment.** |
| `feature/runtime-tattoos` | 8 ahead / 136 behind; tattoo UI/code already present in current page. | **Integrated.** Preserve history; no re-merge. |
| `fix/generic-clothing-visibility` | 3 ahead / 60 behind; earlier body/garment visibility logic. | **Superseded by current AraCharacterActor.** |
| `fix/keep-body-visible-under-clothing` | 2 ahead / 62 behind; earlier garment-only surface hiding. | **Superseded by current AraCharacterActor.** |
| `fix/player-equipment-visuals` | 4 ahead / 64 behind; earlier equipment visual changes. | **Superseded/evolved.** |
| `fix/male-anatomy-surface-sampling` | 1 ahead / 144 behind; earlier male geometry sampling generator. | **Superseded by current generator; preserve history.** |
| `fix/wren-lace-fishnet-and-anatomy` | 19 ahead / 165 behind; older layering patch and anatomy generator changes. | **Superseded by current patching pipeline; salvage only missing asset results.** |
| `fix/modular-outfit-review-material-duplicates` | 6 ahead / 161 behind; earlier render review script. | **Superseded/evolved.** |
| `fix/publish-all-male-workshop-previews` | 1 ahead / 143 behind; small Wren workflow change. | **Check current artifact publication; no wholesale merge.** |
| `diagnostic/ara-garment-surface-report` | 1 ahead / 59 behind; earlier actor diagnostics. | **Integrated/evolved in current diagnostics; retain.** |
| `diagnostic/ara-report-on-character-configure` | 1 ahead / 58 behind; earlier actor diagnostics. | **Integrated/evolved in current diagnostics; retain.** |
| `feature/ara-character-evaluation` | 4 ahead / 379 behind; evaluation doc/workflow changes. | **Retain findings; current workflow supersedes old branch.** |
| `feature/ara-shields-helmets-hairstyles` | Branch comparison returned 404. | **Unresolved historical name; verify via live branch list.** |
| `feat/ara-hairstyles-medieval-equipment` | 33 ahead / 102 behind; hair manifest byte-identical to current, extensive assets. | **Integrated asset set; retain history and only add proven missing variants.** |
| `feat/player-morphs-inventory-weapons` | 7 ahead / 102 behind; old inventory fixture/creator/catalogue changes. | **Do not ship test inventory; compare only missing test cases.** |
