# Technical Debt Register

**Historical baseline:** `dev_2` at `a8b5987ebdc12b016d99e2550349f17a8fd62645` (13 November 2026)
**Current audited baseline:** `dev` at `a70421b41001bea4224bb08190ee3b184fe195aa` (20 November 2026)
**Current audit branch:** `tech-debt/hollow-tankard-current-audit`
**Integration target:** `dev`
**Status:** Historical inventory retained; current ownership findings are recorded in Section 7 and supersede stale branch/status assumptions above.

This register tracks structural improvements without treating file length alone as a defect. The objective is to make systems independently understandable, testable and reusable, while preserving gameplay behaviour.

## 1. Historical branch and validation baseline (13 November 2026)

The branch promotion on 13 November 2026 historically established the following. These branch roles have since changed; Section 7 is the current source of truth:

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

## 3. Historical prioritised debt register (13 November baseline; superseded by Section 7)

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

## 4. Historical execution sequence and acceptance criteria (superseded by Section 7)

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

## 5. Historical working rules (superseded by Section 7)

- One focused PR/change set at a time, targeting the current `dev` branch.
- Never force-push or rewrite the protected candidate branch.
- Preserve a known-good commit before each substantial refactor.
- Run the narrow tests during development and the full Godot validation workflow before merging.
- Do not merge a refactor merely because it compiles; inspect test coverage and relevant scene behaviour.
- Do not revive the old `dev_2` / `dev_3` branching plan without a fresh branch comparison; recover only reviewed changes onto current `dev`.
- Keep the parked fog/vision work out of the current sequence.
- Character assembly work that depends on the finalised body model remains gated by that model; do not refactor it prematurely.

## 6. Historical immediate task (superseded)

The original instruction to split `tests/test_simulation.gd` is complete on current `dev`; the monolithic runner has been replaced by domain-specific suites. Do not restart that task without evidence of missing assertions or suite coupling. The current technical-debt work is the ownership audit and execution sequence in Section 7.


## 7. Current `dev` ownership audit — 20 November 2026

**Audited commit:** `a70421b41001bea4224bb08190ee3b184fe195aa`

This audit follows the architectural objective: reduce duplicate implementations and contradictory ownership, not merely reduce file length. No gameplay source was changed during this audit.

### 7.1 Current file sizes and ownership map

| File / system | Current size | Observed responsibility and boundary |
|---|---:|---|
| `scripts/world/hollow_tankard.gd` | 2,604 lines | Still combines location composition, map registration, actor spawning, story flow, three encounter lifecycles, HUD, command dispatch, route execution, resource presentation and campaign snapshot/restore. |
| `scripts/world/hollowmere_village.gd` | 579 lines | Predominantly authored village presentation: terrain, roads, cottages, farm, fields/fences, animals, bridge, signpost and vegetation. It also bridges its presentation animal actors to simulation registration. |
| `scripts/simulation/world_simulation.gd` | 1,724 lines | Authoritative character/occupancy/party state, clock, movement/pathfinding, actions/spells, combat/reactions, animal/riding lifecycle and persistence-facing state restore. Keep it the sole state authority while auditing internal cohesion. |
| `scripts/world/world_root.gd` | 177 lines | Campaign composition root: creates WorldSimulation, registers campaign quest definitions, creates both locations, passes profile/save data and registers village animal actors. This is the correct high-level composition boundary. |
| `scripts/save/save_manager.gd` | 160 lines | Save-slot storage, envelope validation, safe writes/rotation, load and pending-load handoff. It is not currently duplicating the campaign snapshot schema. |
| `scripts/simulation/hollowmere_campaign_content.gd` | 296 lines | Opening dialogue, ambient content, social standings and shakedown decision rules. |
| `scripts/simulation/farm_wolves_quest.gd` | 94 lines | Farm quest definition, greeting, acceptance, objective progress and reward. It does not own wolf combatant creation or encounter lifecycle. |
| `scripts/simulation/hollowmere_encounter.gd` | 80-ish lines | Shakedown encounter roster setup, reset and outcome predicates. |
| `scripts/simulation/farmstead_dire_wolf_encounter.gd` | 76 lines | Dire-wolf setup, participant snapshot/restore and outcome predicates. |
| `scripts/simulation/combat_ai.gd` | 239 lines | Tactical decisions for non-player combatants; submits actions to WorldSimulation for validation/resolution. |
| `scripts/ui/campaign_dialogue_panel.gd` | 70 lines | Dialogue presentation only; emits selected choice data without applying campaign rules. |
| `scripts/world/building_registry.gd` / `building_door_state.gd` | 86 / 99 lines | Authoritative building and door state. Location presentation responds to door-state changes and mirrors passability into map data. |
| `scripts/world/world_vegetation_generator.gd` | Shared | Both village and tavern delegate vegetation placement/instancing to this shared generator. |

The village is not currently a second god object of the same severity as HollowTankard. Most of its length is authored geometry and placement. Do not split its cottage, chapel, bridge, barn or farm layout merely to reduce line count. Its animal-registration bridge is a narrow integration seam, not evidence that it owns animal simulation rules.

### 7.2 HollowTankard: responsibilities and correct existing owners

The following boundaries are already present and should be preserved:

- **Simulation rules:** movement/pathfinding, movement cost, occupancy, attacks, spell casting, reactions, combat turn scheduling and resource harvesting are requested from `WorldSimulation`. Do not reimplement these in a controller.
- **Tactical AI:** `CombatAI.take_turn()` chooses NPC actions; WorldSimulation resolves them.
- **Dialogue rendering:** `CampaignDialoguePanel` renders and emits choices.
- **Campaign content/rules:** `HollowmereCampaignContent`, `CompanionCampaignContent` and `FarmWolvesQuest` already own substantial authored dialogue, quest and reward logic.
- **Encounter setup:** `HollowmereEncounter` and `FarmsteadDireWolfEncounter` already demonstrate scenario-specific encounter helpers.
- **Persistence storage:** `SaveManager` owns slots, file format envelope, validation, backups and safe writes.
- **Building state:** `BuildingRegistry` / `BuildingDoorState` own door condition; the tavern owns its hinge/mesh presentation.
- **Vegetation:** `WorldVegetationGenerator` owns reusable placement/instancing; locations supply their own placement rules.

The debt is the amount of orchestration still concentrated in HollowTankard, plus several places where it writes simulation state directly.

### 7.3 Confirmed ownership leaks and duplicated implementations

**TD-003A — Encounter lifecycle is inconsistent across scenarios (high priority).**

Three scenario paths currently use three different levels of extraction:

1. The Ironbond shakedown calls `HollowmereEncounter.start/finish`, but HollowTankard still owns turn dispatch, party/enemy lists, outcome handling and quest completion.
2. The dire-wolf hunt calls `FarmsteadDireWolfEncounter.start/finish`, which snapshots and restores prior `side` and `combat_dormant` values.
3. The farm-wolf quest is still largely implemented inside HollowTankard. `_start_farm_wolf_encounter()` creates/registers wolf CharacterState records, directly changes combat participation and TP for the whole roster, and starts combat. `_check_farm_wolf_resolution()` separately repeats defeat checks and restores participant state.

This is the clearest contradictory implementation. Farm wolves should receive a scenario-specific encounter helper following the tested contract of the dire-wolf helper; the location should create/bind creature presentation actors and display results, not own the simulation roster transition. Do not create a generic encounter framework until the three real scenarios have been compared and their shared contract is explicit.

There are also repeated party-defeat predicates in HollowTankard, HollowmereEncounter and FarmsteadDireWolfEncounter. Consolidate only if the resulting owner is clear (prefer a small WorldSimulation query or a shared encounter utility), rather than copying another predicate into a fourth helper.

**TD-003B — Direct writes into authoritative CharacterState (high priority).**

HollowTankard directly assigns `side`, `combat_dormant` and `time_points` while starting/finishing encounters and directly assigns `facing_direction` during rotation. It also registers the farm-wolf CharacterState records itself. These writes bypass an explicit WorldSimulation operation and make it harder to know which layer owns valid state transitions.

Introduce narrow simulation operations for encounter participant activation/restoration and character facing, or route these through a scenario helper with an explicit simulation-owned contract. Do not expose a second state store and do not move combat legality into presentation code.

**TD-003C — Campaign save snapshot and restore live in the location (high priority).**

HollowTankard builds and applies a campaign-wide snapshot containing character diffs, appearance diffs, party membership, clock, campaign journal, wilderness resources, building state, story flags and camera state. SaveManager correctly owns storage, not this schema. The snapshot is broader than a tavern and should move to a campaign save adapter/coordinator invoked by WorldRoot (or a dedicated campaign runtime owner). Keep SaveManager focused on slot/file mechanics. Preserve the legacy party-list migration logic during extraction.

**TD-003D — Input dispatch and route execution are coupled to unrelated commands (medium-high priority).**

`_unhandled_input()` dispatches save/load, attack, end-turn, gathering, interaction, party switching, UI panels, roof visibility, facing and movement. Route state and path-marker presentation are also stored in HollowTankard. The route controller depends on simulation path/movement APIs, camera projection, the active floor and the tavern-specific upper-floor coordinate transform.

Extract route execution/presentation behind explicit simulation and coordinate-transform dependencies. Keep a separate player-command router for non-movement commands; do not move the entire input handler into a generic movement controller. WorldSimulation remains the authority for pathfinding and committed movement.

**TD-003E — Runtime scheduling mixes unrelated update loops (medium priority).**

`_process()` currently schedules autosave, ambient chatter, Reyna story proximity, farm-wolf proximity, combat updates, combat HUD refresh, nearby-interaction refresh and route stepping. These are distinct lifecycles. After the encounter and route seams are testable, delegate these updates to cohesive controllers and leave only thin orchestration in the location/root.

**TD-003F — Story flow is split between content owners and the location (medium priority).**

HollowmereCampaignContent and CompanionCampaignContent own content and several rules, but HollowTankard still handles choice routing, Reyna's clue/proximity/rescue sequence, child spawning, quest objective writes, companion interaction and ambient display scheduling. Keep authored dialogue/quest rules in their current content owners; move the Reyna scenario flow into a focused location-story controller that calls those owners and WorldSimulation. Do not put story-specific content into generic dialogue UI.

**TD-003G — Shared geometry primitives are still duplicated on current dev (medium priority).**

The current `dev` branch still has equivalent `_add_box()` implementations in HollowTankard, HollowmereVillage and Campaign2SettlementBuilder. Their `_material()` helpers also overlap but have different defaults: HollowTankard and Hollowmere use two-sided materials, while Campaign2's helper uses the default back-face culling. A shared primitive factory is justified, but it must preserve caller-specific roughness, metallic and culling settings.

PR #164 contains a `WorldGeometryFactory` and a focused test, but that file is absent from current `dev`. PR #164 is not safe to merge as-is: its branch is 17 commits ahead and 28 behind current `dev`, and GitHub reports it as not mergeable. Rebase/rebuild this small extraction against current `dev`, preserve the factory test and material behaviour, then run current validation. Do not treat the PR branch's factory as already integrated.

### 7.4 HollowmereVillage assessment

HollowmereVillage currently creates authored visual content and uses the shared vegetation generator. Its `register_animals_with_simulation()` method creates or rebinds simulation state for its already-created animal actors; WorldRoot calls it after both locations are created. This is an explicit integration seam. It can remain while the village is the only owner of those actor nodes; consider moving it to a world-actor registrar only if another location needs the same operation.

HollowmereVillageData is the shared source for Hollowmere bounds, terrain, roads, river, building footprints and farm coordinates. Both location presentation and tavern map registration consume it. Preserve this shared data owner; do not duplicate its geometry/terrain predicates in either location.

### 7.5 Recommended implementation order

1. **Reconcile the primitive factory from PR #164 onto current dev.** This is small, evidenced duplication across three real consumers, and already has a focused test. Treat it as a standalone refactor; preserve each caller's material settings.
2. **Extract FarmWolvesEncounter.** Move wolf CharacterState creation, participant activation/restoration, defeat predicates and encounter result data out of HollowTankard. Keep actor creation/presentation and dialogue in the location. Add tests for victory, party defeat/retreat, retry and saved/restored encounter state.
3. **Extract the campaign save adapter.** Move snapshot creation, baseline diffs and restore orchestration out of HollowTankard while retaining SaveManager's storage responsibility. Add round-trip and legacy-save tests.
4. **Extract the route controller and separate command dispatch.** Add focused tests for click-to-move, movement-point waiting, route replanning, combat turn gating, reactions and upstairs/downstairs coordinate projection.
5. **Extract Reyna's story flow and separate runtime update scheduling.** Keep campaign text/rules in existing content owners.
6. **Reassess HollowTankard's remaining scene composition and HUD wiring.** Only extract modules with explicit owners and more than one coherent responsibility.
7. **Leave HollowmereVillage largely intact** unless a concrete second consumer justifies extracting a reusable world-presentation capability.
8. **Audit WorldSimulation separately.** Its size is not permission to split blindly; map its state, public contracts and existing collaborating rule classes before extracting anything.

### 7.6 Validation and branch hygiene

- The exact current `dev` commit audited above has no confirmed green Godot-validation result recorded by this audit. Run the full Godot validation workflow on the current baseline before accepting structural changes.
- PR #164's earlier validation was inconclusive/cancelled and its separate combat-preview workflow needed correction. Do not infer a green result from those runs.
- Work from current `dev`; do not merge the stale `tech-debt/current-ownership-audit` branch wholesale.
- One responsibility per PR/change set. Each extraction must state its owner, inputs, outputs/signals and tests.
- No gameplay changes, model/GLB work, spell redesign or unrelated feature changes in these refactor slices.
