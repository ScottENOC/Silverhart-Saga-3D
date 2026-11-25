# Silverhart Saga 3D implementation roadmap

**Status date:** 2026-11-23  
**Working target:** `dev`  
**Source project:** `ScottENOC/Hex-crpg`  
**Purpose:** Keep the active work, dependencies and deferred features visible so parallel development does not duplicate systems or destabilise the shared world architecture.

This is a prioritised work register, not a claim that every item is currently being implemented. Work should move from the active queue to the next item only when its dependencies and validation are clear.

## Immediate priority: bring the campaign to life

### 1. Stabilise and integrate the campaign source-port foundation
**Status: In progress — PR #240, draft, not merged**

- [x] Port six authored companion relationship profiles and core relationship state.
- [x] Port nine persistent non-companion NPC relationship profiles.
- [x] Port persistent NPC dialogue hooks, including Seraphine's familiarity-gated personal question and Wizard Vendetta outcomes.
- [x] Port the nine later companion personal-quest chapters and their authored dialogue, choices and consequences.
- [x] Add focused tests for relationship state, NPC dialogue and companion quest-chain rules.
- [ ] Resolve all Godot 4.7.2 CI failures and rerun the complete validation workflow.
- [ ] Integrate relationship dimensions with the authoritative `CharacterState` / save path; do not leave competing persistent state owners.
- [ ] Connect the new dialogue content and quest choices to the existing `CampaignDialoguePanel` and campaign event flow.
- [ ] Apply quest XP to the authoritative player progression state.
- [ ] Connect quest/relationship consequences to agreed simulation events, not UI callbacks.
- [ ] Review the complete diff and merge only after tests and architecture integration are sound.

PR: https://github.com/ScottENOC/Silverhart-Saga-3D/pull/240

### 2. Port the missing prerequisite companion quests
**Status: Next campaign-content task**

The nine later personal-quest chapters depend on five earlier arcs that are not yet implemented in the 3D campaign:

- [ ] Aldric — `aldric_measure_of_oath`
- [ ] Mirabel — `mirabel_unquiet_concordance`
- [ ] Fenn — `fenn_living_boundary`
- [ ] Reyna — `reyna_empty_blind`
- [ ] Alden — `alden_uncounted`

Audit each complete source quest before implementation. Preserve authored dialogue, conditions, objectives, decisions, consequences, rewards, failure/alternative paths and prerequisites. Reuse `CampaignJournal`, the relationship state and the existing quest-chain controller; do not add a parallel quest framework.

### 3. Continue the Hex-crpg dialogue and campaign-content migration
**Status: High priority; broad source audit and port work required**

- [ ] Compare the complete `campaign2Dialogue.js` trees against current 3D campaign dialogue, branch by branch.
- [ ] Port missing NPC dialogue trees, conditional/repeat lines, player choices and consequence handlers.
- [ ] Audit `campaign2Content.js` for opening scenes, NPC records, quest definitions, world-state flags and authored campaign data not yet represented.
- [ ] Finish Hollowmere opening dialogue and the Ironbond shakedown consequence chain, preserving all existing choices and reputation effects.
- [ ] Connect persistent NPC dialogue memory and relationship-dependent lines to the actual dialogue runtime.
- [ ] Port contextual companion relationship moments and major-quest reactivity after the core dialogue/event integration is stable.
- [ ] Add regression tests for choice branches, repeated conversations, save/load and event idempotency.

Prioritise self-contained dialogue and quest content that can become playable early. Keep authored writing and outcomes intact; presentation can be adapted to 3D.

## World and map foundation

**Status: Active parallel work; coordinate shared interfaces before editing**

- [ ] Validate terrain elevation, ridges, rivers, roads, vegetation density and chunk boundaries in the actual streamed 3D game.
- [ ] Fix remaining legacy geometrically generated trees beside the starting tavern so the village consistently uses the approved GLB tree assets.
- [ ] Confirm the streamed regional world uses the existing player movement/pathfinding controller and shared `WorldSimulation`, not a preview-only camera.
- [ ] Complete the Hollowmere opening area and verify NPC/building placements against stable IDs.
- [ ] Continue reusable building interiors, floors, doors and traversal using the existing `BuildingRegistry`, `BuildingDoorState` and shared simulation.
- [ ] Ensure entering/exiting interiors, door state, NPC interaction, pickups and combat publish agreed authoritative simulation events.
- [ ] Test chunk unload/reload without losing campaign character identity, state or world changes.

Architecture contract: `WorldRoot` owns the shared `WorldSimulation`; campaign identity and persistent state remain outside presentation chunks. Campaign and map streams must coordinate changes to shared files such as `WorldSimulation`, `SimulationEvent`, `WorldRoot` and `Campaign2LocationLoader`.

## Creature model and animation production

**Status: Tracked separately in the creature asset register**

- [ ] Build, rig, animate and integrate the missing source enemy roster.
- [ ] Audit the actual animation clips in the existing Quaternius animal assets.
- [ ] Prioritise the Skarnak's Hold troll encounter, then goblin/orc campaign enemies.

See [CREATURE_ASSET_AND_ANIMATION_REGISTER.md](CREATURE_ASSET_AND_ANIMATION_REGISTER.md) for the 35-entry source roster, existing model inventory, animation acceptance checklists and per-asset tracking template.

## Character presentation and model integration

**Status: Active parallel work; accepted assets should be reused, not recreated**

- [ ] Connect the already accepted companion builds to the game so Wren and other named companions do not fall back to generic/default appearances.
- [ ] Verify the main character, companions and named NPCs all resolve the correct stable character IDs and appearance assets through the existing actor factory/presentation pipeline.
- [ ] Verify modular anatomy and clothing assets are used consistently in live campaign scenes, not only in the workshop.
- [ ] Fix remaining appearance/equipment issues, including body visibility under transparent garments and correct clothing-slot asset selection.
- [ ] Continue the Ara-based reusable character workflow for NPCs, companions and player customisation.
- [ ] Develop/validate the male presentation option and its compatible base assets.
- [ ] Ensure character appearance survives save/load and actor/chunk recreation.

Do not restart the abandoned bespoke Wren-from-scratch workflow. Recover and integrate the accepted companion builds.

## Audio and campaign presentation

**Status: Queued after the immediate dialogue/quest foundation**

- [ ] Audit the original Character Voice Maker Studio dialogue audio and GarageBand music assets.
- [ ] Establish a game-mode start flow that distinguishes campaign from arena.
- [ ] Connect campaign dialogue voice/audio and ambient music to the appropriate scenes and states.
- [ ] Preserve existing arena audio while adding campaign-specific presentation.
- [ ] Test audio transitions, interruption and mobile/desktop playback.

## Deferred: fatigue, resting and companion camp life

**Status: Deliberately deferred — GitHub issue #243**

Do not start the camp implementation while the immediate campaign dialogue/quest port is underway. Keep the issue and source audit as the specification for later.

When resumed, the work includes:

- [ ] Verify and port time-based mana regeneration independently of sleeping.
- [ ] Add persistent awake-time/fatigue state using the existing `WorldClock`, `CharacterState` and save path.
- [ ] Port fatigue, sleep quality, thermal comfort, watch and rest interruption rules.
- [ ] Add autonomous camp planning and task allocation using existing world/resource interfaces.
- [ ] Add physical camp setup, armour removal/helping animations, night clothing, bathing and sleeping arrangements.
- [ ] Add ambient companion banter, authored camp conversations, relationship-aware scenes and persistent memories.
- [ ] Make cosmetic activities individually skippable/speed-adjustable without skipping critical decisions or consequences.
- [ ] Test danger interruption, save/load and chunk unload/reload.

Issue: https://github.com/ScottENOC/Silverhart-Saga-3D/issues/243

## Working rules and validation

1. **One authoritative owner:** Reuse existing campaign state, world simulation, clock, character and save systems. Do not create competing registries, clocks, quest engines, dialogue frameworks or resource simulations.
2. **Campaign/world boundary:** Campaign owns identity, relationships, quest rules, dialogue and decisions. World owns spatial presentation, terrain, physical props and movement.
3. **Stable IDs and events:** Use stable character/quest/building IDs and agreed `SimulationEvent` contracts. Important consequences must not exist only in UI callbacks.
4. **Preserve source behaviour:** Adapt presentation where necessary, but do not silently remove authored branches, dialogue, consequences or relationship distinctions.
5. **Small isolated branches:** Keep campaign-content, world/map and character-pipeline changes separate where practical. Coordinate shared-file changes explicitly.
6. **Godot conventions:** Use Godot 4.7.2 standard GDScript, tabs for indentation, and focused headless tests. A successful import alone is not a passing test suite.
7. **Honest status:** Mark work complete only when the implementation is present and the relevant tests/scene checks have passed. A draft PR or a green subset of CI is not a merged, integrated feature.
