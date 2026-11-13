# Technical Debt Register

**Baseline:** `dev_2` at `a8b5987ebdc12b016d99e2550349f17a8fd62645` (13 November 2026)
**Working branch:** `tech-debt/register-and-test-split`
**Integration target:** `dev_2`
**Status:** Initial inventory; priorities are provisional until dependency and runtime audits are complete.

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
| TD-002 | P0 | Simulation test organisation | `tests/test_simulation.gd` is 2,172 lines and contains broad campaign, character, movement, combat, reaction and animal/riding coverage | Split into cohesive domain suites; retain assertions and coverage; no gameplay changes | Planned |
| TD-003 | P1 | Hollow Tankard location God Object | `scripts/world/hollow_tankard.gd` is 2,836 lines; it combines construction, actors, UI, input/camera, narrative, combat, resources and persistence responsibilities | Replace bespoke location implementation with reusable systems and location data; leave at most a thin composition entry point | Planned |
| TD-004 | P1 | WorldSimulation cohesion | `scripts/simulation/world_simulation.gd` is 1,211 lines; owns broad registration, movement, combat/action, reactions, animal/riding and persistence coordination | Separate cohesive domain services while retaining one authoritative state/coordinator and stable action/event contracts | Planned |
| TD-005 | P1 | Hollowmere village construction | `scripts/world/hollowmere_village.gd` is 645 lines and constructs environment, buildings, vegetation, fields/fences and creatures | Move reusable construction/presentation into generic builders; retain Hollowmere-specific layout/content as data | Planned |
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
