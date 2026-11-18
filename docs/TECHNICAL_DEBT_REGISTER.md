# Technical Debt Register

**Baseline:** `dev` at `91a14a17bfb3031e3360072ac8d663f80aee55eb` (18 November 2026)
**Stable branch:** `main`
**Active development and test branch:** `dev`
**Legacy branch:** `dev_2` (historical reference only; no new work)
**Status:** Refreshed against the current `dev` tree; remaining priorities are based on current file sizes, CI evidence and known unfinished refactors.

This register tracks structural improvements without treating file length alone as a defect. The objective is to make systems independently understandable, testable and reusable, while preserving gameplay behaviour.

## 1. Branch and validation baseline

The current branch strategy is:

- `main`: stable build; promote only after review and validation.
- `dev`: active development and play-testing branch; all new work targets this branch.
- `dev_2`: legacy historical reference; do not target it for new work.
- `backup/*-before-promotion-2026-11-13`: exact pre-promotion refs.

Do not change `main` or `dev_2` as part of routine development. Preserve `dev` history; use focused feature branches and PRs.

### Automated baseline

The current `dev` baseline is recorded above; a successful full validation run against this exact SHA has not yet been recorded. The main Godot workflow now runs the split character/progression, campaign, equipment, world/movement, combat/reaction and animal/riding suites, plus building, UI, save/restore, appearance, world and scene checks. A separate combat-preview workflow still referenced the retired monolithic `tests/test_simulation.gd`; that stale reference is being corrected in this refresh.

A recent PR #151 validation run passed the hex-grid and split domain suites but failed when loading `hollow_tankard.gd` because the PR introduced mixed tabs/spaces at line 254. Its separate character pipeline job also failed on the pre-existing roster entry `tam_wells_human_male`. These are recorded as outstanding validation issues, not evidence that the current `dev` baseline itself failed.

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
| TD-001 | P0 | Baseline and validation | Current `dev` SHA recorded; full validation against this exact SHA and hands-on review are not yet recorded | Preserve baseline SHA, run the correct current test suites and record failures before each refactor | In progress |
| TD-002 | P0 | Simulation test organisation | The former monolithic suite has been split into independently runnable character/progression, campaign, equipment, world/movement, combat/reaction and animal/riding suites | Keep CI references aligned with the split suites; retain independent testability | Complete; CI reference cleanup in progress |
| TD-003 | P1 | Hollow Tankard location God Object | `scripts/world/hollow_tankard.gd` is 2,552 lines / 123,261 bytes; it still combines construction, actors, UI, input/camera, narrative, combat, resources and persistence | Extract cohesive vertical slices into reusable systems and location data; leave a thin composition entry point | Planned |
| TD-004 | P1 | WorldSimulation cohesion | `scripts/simulation/world_simulation.gd` is 1,332 lines / 68,079 bytes; coordinates registration, movement, combat/actions, reactions, animal/riding and lifecycle | Extract cohesive domain services while retaining one authoritative state/coordinator and stable action/event contracts | Planned |
| TD-005 | P1 | Hollowmere village construction | `scripts/world/hollowmere_village.gd` is 644 lines / 31,999 bytes and constructs environment, buildings, vegetation, fields/fences and creatures | One shared world vegetation generator must own placement and asset selection across all locations; continue separating reusable construction from Hollowmere content | In progress — PR #151 is stale against current `dev` and requires reconciliation/validation |
| TD-006 | P2 | Character presentation actor | `scripts/presentation/ara_character_actor.gd` is 714 lines / 33,276 bytes | Separate model/rig loading, equipment/appearance application, animation and actor lifecycle only at stable boundaries | Planned; defer until Ara pipeline stabilises |
| TD-007 | P2 | Character creator UI | `scripts/ui/player_character_creator.gd` is 489 lines / 26,040 bytes | Separate UI flow from character-creation rules, data validation and preview/presentation | Planned |
| TD-008 | P2 | NPC skill spending | `scripts/simulation/npc_skill_spending.gd` is 543 lines / 28,884 bytes | Audit rule ownership, data inputs and decision boundaries before deciding whether extraction is warranted | Audit needed |
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

**Complete.** The monolithic simulation test file has been replaced by independently runnable domain suites covering character/progression, campaign content, items/equipment, world/movement, combat/reactions and animals/riding. The current Godot validation workflow invokes these suites individually. The remaining CI cleanup is to remove stale references to the deleted monolithic runner from secondary workflows.

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

- One focused PR/change set at a time, targeting `dev`.
- Never force-push or rewrite `main` or `dev`.
- Preserve a known-good commit before each substantial refactor.
- Run the narrow tests during development and the full Godot validation workflow before merging.
- Do not merge a refactor merely because it compiles; inspect test coverage and relevant scene behaviour.
- Keep `dev_2` as a historical branch; do not promote it or create new work from it.
- Keep the parked fog/vision work out of the current sequence.
- Character assembly work that depends on the finalised body model remains gated by that model; do not refactor it prematurely.

## 6. Immediate next tasks

1. Reconcile the shared vegetation generator with the latest `dev` state, fix the mixed-indentation parse error, and ensure tavern resource placements remain intact.
2. Update all CI workflows to invoke the split test suites; verify the full Godot workflow against the resulting feature head.
3. Recover the useful nearby-interaction panel extraction from PR #149 onto a branch based on `dev`; do not merge its `dev_2`-based branch.
4. Begin HollowTankard decomposition with one tested vertical slice at a time, then map WorldSimulation ownership before extracting services.
5. Audit character-pipeline roster status and generation idempotency separately from the world refactors.

Keep fog/vision parked. Defer Ara actor/creator decomposition until the current character-generation workflow stabilises.
