# Silverhart Saga 3D — shared TODO index

**Last reviewed:** 2026-11-25  
**Integration branch:** `dev`  
**Source of truth:** this file is the short, cross-chat work queue. Detailed requirements remain in the linked GitHub issues and design/status documents.

This is a prioritised index, not a claim that every item is currently being implemented. Keep it current as work starts, passes validation, merges, or is deliberately deferred. Do not create duplicate systems to satisfy a TODO: follow the architecture contracts in the linked documents.

## How we use this list

- Every project chat should check this file and the linked open PRs before starting overlapping work.
- Substantial work gets a GitHub issue; implementation happens on a feature branch and is merged to `dev` only after current-base Godot 4.7.2 validation passes.
- Update this index when a task materially changes. Mark completed only after tests **and** any required in-game/visual acceptance.
- The detailed porting matrices are authoritative for feature-by-feature parity; this file is the navigation page and near-term queue.

## Immediate queue

- [ ] **Finish the shared encounter/combat runtime migration.** Follow [ADR 0003](adr/0003-shared-encounter-runtime.md) and [issue #401](https://github.com/ScottENOC/Silverhart-Saga-3D/issues/401). The shared controller now owns the active roster and combat loop; Ironbond, abandoned-house, farm-wolf, dire-wolf and camp night-wolf encounters use it. Camp night-watch results now spawn a wolf ambush, present a detected alarm, and apply an explicit 20 TP surprise penalty when undetected. Remaining: stable encounter identity, active-combat save/load, and more presentation/integration coverage. Location scripts must not regain generic combat or encounter-kind resolution logic.

- [ ] **Keep the current integration queue healthy.** Resolve the Godot 4.7.2 test/type-inference failure tracked by [PR #388](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/388), then validate active PRs against the latest `dev`. Merge only after exact-head checks pass.
- [ ] **Finish the current campaign dialogue/quest slices.** Review and validate [PR #384](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/384) (Ironbond courier), [PR #385](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/385) (quest-dialogue service), and [PR #387](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/387) (Hollowmere NPC and ambient dialogue). Preserve the original source choices and consequences.
- [ ] **Complete the morning camp routine integration.** Validate [PR #386](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/386). Follow up on actual armour removal/re-equipping, dedicated morning animations, visible fire extinguishing, and physical camp-prop cleanup; these are not all implemented by the first staged routine.
- [ ] **Validate exploration group movement in-game.** [PR #379](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/379) needs visual review for spacing, crowded routes, stairs and floor transitions, in addition to automated tests.
- [ ] **Finish the canonical Campaign 2 site registry pass.** Validate [PR #381](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/381) and ensure map presenters consume the canonical site definitions.
- [ ] **Populate the source-authored companion sites.** Work through [issue #252](https://github.com/ScottENOC/Silverhart-Saga-3D/issues/252): Reyna at Old Mac's Farmstead, Mirabel and the spider ruin near Reddale, and Elder Nessa/Fenn at Emberwood Grove. Preserve unique persistent character identities and source-relative placement.
- [ ] **Continue the full companion camp-life system.** [Issue #243](https://github.com/ScottENOC/Silverhart-Saga-3D/issues/243) is broader than the first morning/evening presentation: fatigue, rest quality, camp planning, weather/comfort, watch, social activity, persistence and interruption rules remain to be completed without adding a second simulation or time system.
- [ ] **Implement actual night watch and camp encounters.** [Issue #393](https://github.com/ScottENOC/Silverhart-Saga-3D/issues/393) covers watch rotation, threat detection, deterministic ambush resolution, alarm/combat hand-off and save/load. The first integration slice now rolls and persists the deterministic result, then hands attacks to the shared combat runtime as a two-wolf encounter. Detected attacks raise an alarm; undetected attacks apply a 20 TP initiative penalty. Remaining: pause/resume sleep at the actual attack time, active-combat save/load, and visual acceptance of the wolf approach.
- [ ] **Build the Skarn-tooth camp and Aldric rescue encounter.** Track against [issue #72](https://github.com/ScottENOC/Silverhart-Saga-3D/issues/72), keeping the camp's map geometry, encounter logic, dialogue, recruitment choice and save state distinct acceptance steps.

## Major workstreams

### World map and authored locations

- [ ] Continue the source-faithful Campaign 2 world port: geography, roads, terrain, settlement footprints, buildings, interiors, doors, props and chunk persistence.
- [ ] Review each site's **physical map** separately from its NPC, quest and service completeness. A built map does not mean its encounter is playable.
- [ ] Complete visual and traversal acceptance for the existing Hollowmere, Millbrook, Emberlode, Reddale and other authored locations; continue the remaining wilderness and northern sites from the source manifest.
- [ ] Keep source-relative anchors and stable IDs; do not invent coordinates or duplicate world/door/movement systems.

References: [Campaign 2 world status](campaign2_world_port_status.md), [full-world 2D-to-3D port plan](full_world_2d_to_3d_port_plan.md), [world-building architecture](WORLD_BUILDING_ARCHITECTURE.md), [map/source gap audit](source_to_3d_world_gap_audit.md), [issue #65](https://github.com/ScottENOC/Silverhart-Saga-3D/issues/65).

### Campaign, dialogue and quests

- [ ] Continue comparing the complete original `campaign2Dialogue.js` and `campaign2Content.js` against the 3D runtime; port missing conversations, branches, choices, conditions, consequences and repeat behaviour.
- [ ] Complete the prerequisite companion quest arcs and connect later personal chapters to authoritative journal, relationship, progression and save state.
- [ ] Ensure quest/domain logic lives in quest or campaign services; location controllers should handle proximity and presentation, not own quest rules.
- [ ] Add end-to-end tests for dialogue choices, idempotent consequences, save/load and chunk unload/reload.

References: [implementation roadmap](IMPLEMENTATION_ROADMAP.md), [campaign dialogue index](campaign2_npc_dialogue_index.md), [issue #252](https://github.com/ScottENOC/Silverhart-Saga-3D/issues/252), [PR #317](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/317), [PR #316](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/316).

### Character models, animation and equipment

- [ ] Establish and maintain the canonical reusable Ara-based human character pipeline for player, companions and generated NPCs; keep model generation reproducible and versioned.
- [ ] Finish reliable shared body visibility, character-creator preview/equipment separation, body-shape handling and modular clothing fit. Preserve the existing safety checks in mesh fitting; do not hide deformation errors by relaxing tolerances.
- [ ] Continue distinct male/female base presentation and the male option in the character workshop; verify that clothing, equipment, tattoos, hair and animations work on both.
- [ ] Review generated GLBs from front, side, rear and three-quarter views and in Godot before treating them as accepted assets.
- [ ] Complete the named NPC and enemy model roster with stable model IDs, compatible rigs, animation coverage and LOD/performance checks.

References: [issue #71](https://github.com/ScottENOC/Silverhart-Saga-3D/issues/71), [Ara animation integration](ARA_ANIMATION_INTEGRATION.md), [Ara equipment pipeline](ARA_EQUIPMENT_PIPELINE.md), [open character pipeline PRs](https://github.com/ScottENOC/Silverhart-Saga-3D/pulls).

### Combat, skills, magic, Arena and audio

- [ ] Finish source-parity combat rules and a complete deterministic encounter lifecycle: facing/flanking, ranged line of sight/cover, reactions, status effects, enemy decisions, defeat and rewards.
- [ ] Connect skills, checks, progression and spell effects to actual gameplay rather than leaving catalogue/data-only coverage.
- [ ] Restore Arena as a real mode using shared campaign character, combat, inventory and progression systems.
- [ ] Audit and integrate original music, voices, ambience and sound effects through the shared AudioManager with mode-scoped buses and independent volume controls.

References: [issue #65](https://github.com/ScottENOC/Silverhart-Saga-3D/issues/65), [legacy porting matrix](LEGACY_PORTING_MATRIX.md), [skill and magic port plan](SKILL_MAGIC_PORT_PLAN.md), [PR #294](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/294), [PR #169](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/169).

### Platform, UI and release readiness

- [ ] Keep the PC/Godot 4.7.2 workflow reliable and ensure tests run against the exact PR head and current integration base.
- [ ] Review the browser/Pages build and make sure deployment uses the intended branch/artifacts; a successful workflow is not proof that the correct game build was published.
- [ ] Continue the iOS export foundation after core gameplay and asset loading are stable; validate touch controls, memory, loading and performance on-device.
- [ ] Keep mobile UI readable and prevent clipped/off-screen controls; diagnostics should not dominate normal play.

Reference: [iOS export foundation PR #202](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/202).

## Active PR watchlist (snapshot 2026-11-25)

These are pointers, not merge approvals. Check their live state and exact-head CI before acting.

| PR | Work | Next gate |
|---|---|---|
| [#388](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/388) | Campaign dwelling test type inference | Godot validation |
| [#387](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/387) | Hollowmere NPC and ambient dialogue | Dialogue tests and full validation |
| [#386](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/386) | Staged morning camp routine | Godot validation and visual limitations follow-up |
| [#385](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/385) | Quest-giver dialogue service | Godot validation |
| [#384](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/384) | Ironbond courier encounter | Quest/save/dialogue validation |
| [#381](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/381) | Campaign 2 canonical sites | Godot validation and registry integration |
| [#379](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/379) | Toggleable group movement | Automated tests and in-game visual review |
| [#375](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/375) | Remove temporary retargeter diagnostics | Godot validation |
| [#348](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/348), [#347](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/347), [#344](https://github.com/ScottENOC/Silverhart-Saga-3D/pull/344) | MakeHuman/morph-aware garment-fit investigations | Inspect reports/renders; do not treat prototypes as accepted production assets |

## Detailed registers and plans

- [Implementation roadmap](IMPLEMENTATION_ROADMAP.md) — sequencing, dependencies and active campaign tasks.
- [Legacy porting matrix](LEGACY_PORTING_MATRIX.md) — mechanic-by-mechanic source parity status.
- [Mechanics port register](MECHANICS_PORT_REGISTER.md) — system-level mechanics inventory.
- [Campaign 2 world port status](campaign2_world_port_status.md) — physical site/map status versus playable content.
- [Full-world 2D-to-3D port plan](full_world_2d_to_3d_port_plan.md) — fidelity contract and world implementation plan.
- [Camp system](camp_system.md) — camp simulation and presentation contract.
- [Feature branch recovery register](BRANCH_RECOVERY_REGISTER.md) — preservation and selective recovery decisions.

---

**Maintenance note:** when a PR merges, update the active watchlist and the relevant detailed register. Do not mark an entire workstream complete merely because one PR or one location's geometry is finished.
