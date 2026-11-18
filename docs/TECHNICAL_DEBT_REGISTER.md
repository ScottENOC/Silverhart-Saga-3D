# Technical Debt Register

**Historical baseline:** `dev_2` at `a8b5987ebdc12b016d99e2550349f17a8fd62645` (13 November 2026)
**Current audit snapshot:** `dev` at `56d3e21a63fcdfae1a3ebbc8a1aa4902d8c0471b` (18 November 2026)
**Working branch:** `tech-debt/current-ownership-audit`
**Integration target:** `dev`
**Status:** Updated after a current-branch ownership review; implementation priorities remain subject to runtime and dependency verification.

This register tracks structural improvements without treating file length alone as a defect. The objective is to make systems independently understandable, testable and reusable, while preserving gameplay behaviour.

## 1. Branch and validation baseline

The branch promotion on 13 November 2026 established:

- `main`: historical development baseline.
- `dev`: current script-tested candidate for the user's hands-on gameplay review.
- `dev_2`: active technical-debt and refactoring line.
- `backup/*-before-promotion-2026-11-13`: exact pre-promotion refs.

Do not merge this work into `dev` until the user has reviewed the candidate and the relevant changes have passed validation.

### Automated baseline

The GitHub Actions workflow **Godot validation** completed successfully on commit `a8b5987ebdc12b016d99e2550349f17a8fd62645` (run [43310423179](https://github.com/ScottENOC/Silverhart-Saga-3D/actions/runs/43310423179), 12 November 2026).

The workflow currently covers Godot 4.7.2 import, the hex-grid and simulation suites, building/door tests, save/restore, tavern script loading, NPC pass-through, character/equipment appearance, seasonal trees, wilderness resources, Hollowmere, Campaign 2 geography/roads/settlement layouts, JSON validation and scene smoke tests.

This is evidence that the automated pipeline passed at the baseline commit. It is not a substitute for a human playing the game, and it does not prove that every gameplay path or visual presentation is correct.

## 2. Target architectural principles

1. **Location content is not a game system.** A location describes what is present; reusable systems construct and operate it.
2. **Building content is data-driven.** Building dimensions, room/floor layout, doors, furniture, materials, decoration and spawn/interaction points should be authored as definitions wherever practical.
3. **Simulation owns authoritative rules and state.** Presentation requests actions and displays results; it does not decide whether gameplay actions are legal.
4. **One owner per responsibility.** Avoid duplicated state, parallel catalogues and hidden cross-script mutation.
5. **Dependencies are explicit.** Prefer injected references and clear interfaces over broad scene-tree searches and implicit global access.
6. **Refactors preserve behaviour.** Establish tests before moving code; keep gameplay changes out of structural refactor commits unless explicitly intended and separately tested.
7. **Do not split for line count alone.** A module should represent a cohesive responsibility with a clear interface, not merely be a smaller file.

### Location-script end state

The desired end state for `scripts/world/hollow_tankard.gd` is to remove its location-specific implementation responsibilities, not simply redistribute its 2,836 lines into a collection of tightly coupled scripts. Ideally, the tavern is assembled from reusable building/world systems plus authored building and campaign content. A tiny scene composition/entry script is acceptable only if the scene genuinely needs one.

Apply the same principle to `hollowmere_village.gd`: village-specific content should describe the village, while reusable world presentation/building systems implement it.

## 3. Prioritised debt register

| ID | Priority | Area | Baseline evidence | Intended outcome | Status |
|---|---|---|---|---|---|
| TD-001 | P0 | Baseline and validation | CI passed at baseline commit; user has not yet performed hands-on review of this candidate | Preserve baseline SHA, know which automated checks run, record any failures before each refactor | Recorded |
| TD-002 | P0 | Simulation test organisation | The original 2,172-line `tests/test_simulation.gd` is absent from current `dev`; its domains now have separate suites and explicit CI steps | Confirm assertion parity and suite independence; retain the split suites | Implemented; parity audit pending |
| TD-003 | P1 | Hollow Tankard location God Object | Current `scripts/world/hollow_tankard.gd` is 2,604 lines; it still combines building geometry, map registration, actor spawning, story/dialogue, encounter orchestration, HUD, camera/input, movement presentation, resources and persistence | Reduce to location composition and authored content; move reusable responsibilities to their owning systems | Active audit; extraction not started |
| TD-004 | P1 | WorldSimulation cohesion | Current `scripts/simulation/world_simulation.gd` is 1,724 lines; one authoritative state owner coordinates character/party lifecycle, mounts, movement, combat/reactions, spell casting, resources, clock and persistence | Extract cohesive domain services without creating competing state owners or changing action/event contracts | Audit required; preserve single state owner |
| TD-005 | P1 | Hollowmere village construction | Current `scripts/world/hollowmere_village.gd` is 579 lines; vegetation now delegates to `WorldVegetationGenerator`, but buildings, farm, fields/fences, creatures and biome selection remain in the location script | Keep Hollowmere layout/content local; extract genuinely reusable building/farm/creature presentation | Partially improved; building ownership audit required |
| TD-006 | P2 | Character presentation actor | `scripts/presentation/ara_character_actor.gd` is 26,429 bytes | Separate model/rig loading, equipment/appearance application, animation and actor lifecycle where boundaries are cohesive | Planned |
| TD-007 | P2 | Character creator UI | `scripts/ui/player_character_creator.gd` is 26,234 bytes | Separate UI flow from character-creation rules, data validation and preview/presentation | Planned |
| TD-008 | P2 | NPC skill spending | `scripts/simulation/npc_skill_spending.gd` is 28,884 bytes | Audit rule ownership, data inputs and decision boundaries; reduce duplicated progression logic | Planned |
| TD-009 | P2 | Content/data ownership and generated outputs | Existing architecture uses canonical character/item data and generated pipeline outputs; prior work identified possible duplicated or stale generated configuration | Identify each source of truth; make generation deterministic/idempotent; validate outputs and avoid hand-editing generated files | Audit needed |
| TD-010 | P2 | Asset/build pipeline reliability | Ara garment extraction/build pipeline has had identifier/slot mismatches and patch/cache idempotency concerns | Make stages reproducible, cache-safe, explicit about accepted identifiers and fail with actionable diagnostics | Audit needed |
| TD-011 | P3 | Vision/fog systems | Previous fog/vision feature branch is stale relative to current architecture | Keep parked; later recover only the useful presentation/gameplay requirements, not the old implementation wholesale | Parked |

File sizes/line counts are measurements of the baseline snapshot, not automatic evidence that a file must be split. For example, the character actor and creator are audit candidates, not approved refactor designs.

## 4. Execution sequence and acceptance criteria

### Phase 0 — Baseline (recorded; repeat before structural changes)

- [x] Record the baseline commit.
- [x] Confirm the latest Godot validation workflow passed on that exact commit.
- [ ] Record local/editor/runtime issues when the user can play the candidate.
- [ ] For each subsequent refactor, compare its test results with this baseline.

### Phase 1 — Split the simulation test suite

First inspect the complete test inventory and dependencies. Group tests by cohesive domain (likely character/progression, campaign/dialogue, movement/world time, combat/actions/reactions, items/equipment, animals/riding and lifecycle/persistence). The final grouping must follow actual setup/helpers and shared fixtures, not this provisional list.

Acceptance criteria:

- Every existing test assertion is retained or explicitly justified.
- Test cases remain independently runnable through Godot headless.
- Shared fixtures/helpers have clear ownership and do not introduce order-dependent state.
- CI runs the new suites and reports failures clearly.
- The old monolithic runner is removed only after equivalent coverage is demonstrated.
- No gameplay scripts or gameplay rules are changed in this phase.

### Phase 2 — Hollow Tankard decomposition

Before moving code, map all responsibilities, state, signals, node ownership, external callers and scene dependencies. Choose one vertical slice at a time. The intended direction is:

- Generic building/world construction and furniture systems.
- Location/building definitions for the tavern layout and appearance.
- Generic character placement/spawning driven by location data.
- Campaign/event/dialogue content separate from reusable interaction systems.
- Combat and gathering owned by simulation/gameplay systems.
- UI, camera and input owned by presentation/player-control systems.
- Persistence owned by SaveManager/world persistence contracts.

Do not create generic abstractions without a second real use case or a clear reusable contract. Test the existing tavern as the first consumer of each extracted capability.

Acceptance criteria: the tavern still loads and behaves the same; no location-specific logic leaks into generic systems; the scene can be composed from reusable capabilities and authored content; automated tests and smoke tests pass.

### Phase 3 — WorldSimulation decomposition

Map state ownership and all callers before extraction. Keep the public action request/result/event contract stable. Extract only cohesive responsibilities, likely movement/pathing coordination, combat action resolution, reaction resolution and animal/riding lifecycle. Avoid creating multiple competing owners of world state.

Acceptance criteria: deterministic tests for existing action and reaction behaviour pass; registration, movement, combat, riding and save/restore lifecycle remain consistent; no presentation code gains authority over gameplay rules.

### Phase 4 — Village, character actor and creator

Refactor each independently. Prefer data-driven world/building content and clear presentation boundaries. Avoid coupling character model import/assembly to simulation rules or UI state.

### Phase 5 — Cross-cutting reliability

Audit duplicated sources of truth, stale generated files, pipeline idempotency/cache invalidation, error handling and implicit dependencies. Address only issues demonstrated by the audit.

## 5. Working rules

- One focused PR/change set at a time, targeting `dev_2`.
- Never force-push or rewrite the protected candidate branch.
- Preserve a known-good commit before each substantial refactor.
- Run the narrow tests during development and the full Godot validation workflow before merging.
- Do not merge a refactor merely because it compiles; inspect test coverage and relevant scene behaviour.
- If the technical-debt line becomes unhealthy, create a fresh `dev_3` from the untouched `dev` candidate and recover only reviewed changes.
- Keep the parked fog/vision work out of the current sequence.
- Character assembly work that depends on the finalised body model remains gated by that model; do not refactor it prematurely.

## 6. Immediate next task

Start TD-002: inspect the complete `tests/test_simulation.gd` test/helper inventory, identify shared setup and order dependencies, then propose the exact file split. Do not edit or move test code until that inventory is complete. The first implementation PR should be test-only and behaviour-preserving.


## 6. Immediate next task

Complete the ownership map for HollowTankard and the overlapping building-presentation implementations before extracting code. The test-suite split is already present on the current branch; do not recreate it.

## 7. Current-branch audit — 18 November 2026

This section supersedes stale status assumptions in the original 13 November inventory. Measurements below are from the named current snapshot, not from the historical baseline.

### Branch and validation position

- dev is a descendant of dev_2; the comparison at this audit found dev 265 commits ahead and zero commits behind dev_2.
- The current audit branch was created from dev at commit 56d3e21a63fcdfae1a3ebbc8a1aa4902d8c0471b. Changes here remain isolated until reviewed.
- The current Godot validation workflow explicitly runs the split character, campaign, items, movement, combat/reaction and animal/riding suites. It also runs the building framework, campaign UI, save/restore, character appearance, vegetation and world-content suites.
- The most recent Godot validation run found for dev was cancelled (run [44237510473](https://github.com/ScottENOC/Silverhart-Saga-3D/actions/runs/44237510473), commit d20fa886). The current snapshot therefore needs a fresh successful Godot validation run before structural changes can be accepted. Character-pipeline jobs are separate and must not be treated as Godot validation.

### TD-002 — test split is already implemented

The old tests/test_simulation.gd no longer exists on current dev. The current workflow invokes separate suites including:

- tests/test_character_systems.gd
- tests/test_campaign_content.gd
- tests/test_items_and_equipment.gd
- tests/test_world_movement.gd
- tests/test_combat_and_reactions.gd
- tests/test_animals_and_riding.gd

The split is real and wired into CI. What remains unverified by this audit is exact assertion parity against the removed monolith and whether any shared fixtures rely on execution order. Do not re-split these suites without evidence of a cohesion or isolation problem.

### TD-003 — HollowTankard responsibility map

Current scripts/world/hollow_tankard.gd is 2,604 lines. Its responsibilities include:

1. Location map-cell registration and building/door layout registration.
2. Tavern building, upper floor, furniture, materials and primitive mesh construction.
3. Authored grove and resource placement.
4. Character and creature actor spawning and placement.
5. Hollowmere story progression, dialogue, companion recruitment and ambient chatter.
6. Encounter lifecycle and player-facing combat orchestration.
7. HUD/panels, camera, keyboard/mouse input, path queue and movement presentation.
8. Save/load snapshot creation and restoration.
9. Resource visual refresh and spell visual-effect dispatch.

Important boundary distinction: the tavern currently calls WorldSimulation for authoritative movement, attacks, harvesting and spell actions, and delegates enemy turns to CombatAI. This is not evidence that it duplicates all combat rules. The debt is that the location script still owns too much orchestration, input/presentation and scenario-specific spawning alongside scene construction.

WorldRoot is already the campaign composition root: it creates and owns the shared WorldSimulation, registers initial campaign quest definitions, creates HollowmereVillage and HollowTankard, then registers village animal actors. Preserve this boundary. HollowTankard's location-specific map-cell and building-layout registration is legitimate location assembly; the reusable registration mechanics belong in the existing building framework.

Candidate extraction order, after dependency tracing:

- Player input and route-presentation controller (keep path legality and movement authority in WorldSimulation).
- Location/encounter composition for wolf and shakedown scenarios (keep quest content and encounter rules in their existing simulation/content owners).
- Save/load orchestration boundary (keep serialization ownership in SaveManager / persistence contracts).
- Tavern visual construction into authored building data plus reusable presentation builders.

Do not extract all of these in one PR. Each slice needs a named owner, explicit inputs/signals and a regression test.

### TD-005 / vegetation — shared generator now exists

Current scripts/world/world_vegetation_generator.gd is a 148-line shared generator. Both HollowTankard and HollowmereVillage use it:

- HollowTankard passes four authored tree placements to generate_authored_placements().
- HollowmereVillage passes local terrain/biome predicates and family-selection callbacks to generate_hex_grid().
- Candidate filtering and biome choice remain location-specific; deterministic placement, asset catalogue loading and model instancing are shared.

This resolves the previously identified duplicate tree-generation implementation on current dev. Preserve the useful separation: locations supply content rules, the generator owns reusable placement/instancing.

### New finding — building presentation has three overlapping owners

Current dev contains at least three independent procedural building-rendering paths:

- scripts/world/hollow_tankard.gd: _create_building(), _create_upper_floor_rooms(), _create_furniture(), wall/window/box helpers.
- scripts/world/hollowmere_village.gd: _create_cottage(), _create_farmstead(), door-wall and box helpers, farm buildings and fences.
- scripts/world/campaign2_settlement_builder.gd: _build_building(), wall and box helpers for generated settlements.

BuildingRegistry and BuildingLayoutRegistrar currently own logical building/door registration and walkability, not the shared visual construction contract. They do not eliminate this presentation duplication.

Add TD-012 (P1): define a reusable building-visual composition contract for common primitives (walls, openings, roofs, doors, foundations and material assignment), while allowing each location/settlement to supply authored geometry/layout data. Do not force unique tavern furniture or bespoke landmark details into a generic builder. First compare the three builders' inputs, outputs and scene assumptions; then extract only the common stable subset.

### Open work that must not be mistaken for completed work

- PR [#149](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/149), nearby interaction panel extraction, remains open and targets dev_2; its new panel file is not present on current dev. It is not counted as integrated.
- PR #130 remains draft/in progress and must be left untouched.
- PR #87 remains gated on acceptance of the final character model and must be left untouched.
- Vision/fog remains parked.

### Updated execution order

1. Refresh and pass Godot validation on the current dev snapshot.
2. Audit TD-002 assertion parity only; do not repeat the already completed split.
3. Finish the TD-003 dependency/ownership map, including node ownership, external callers, signals and scene assumptions.
4. Resolve TD-012's shared building-visual contract before extracting more location-specific mesh code.
5. Extract one small HollowTankard vertical slice at a time, with behaviour-preserving tests.
6. Revisit WorldSimulation domain extraction only after mapping its callers and preserving one authoritative state owner.

Every extraction must be a separate focused change. Avoid combining feature work, character pipeline changes or gameplay-rule changes with structural refactors.
