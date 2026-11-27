# Campaign quest architecture

## Responsibilities

Campaign quest code is split into four layers:

1. **Quest content modules** own authored quest definitions, dialogue, objective rules, choices and rewards. They should remain independently testable and should not depend on a world scene.
2. **Encounter modules** own quest-specific combat setup, enemy simulation state and encounter resolution. They return results; they do not create scene presentation actors.
3. **Campaign quest services** provide common journal operations and coordinate quest registration/lookup. This is the campaign-facing API used by world scenes and other systems.
4. **World/presentation scenes** connect NPCs, actor visuals, proximity triggers, UI and save restoration to quest services. They should not contain quest rules or hard-code quest registration lists.

## Current implementation

- `scripts/quests/campaign_quest_registry.gd` centralises registration of the existing standalone quest content modules and companion quest definitions.
- `scripts/quests/campaign_quest_service.gd` provides a configured facade for quest state, start, objective progress, completion and failure.
- `HollowTankard` now configures the service once during campaign startup and delegates all campaign quest-definition registration to the registry; it no longer maintains a second registration list.
- Existing content and encounter modules remain in `scripts/simulation/` during this first migration slice. Their paths will be moved only when their callers and tests can be migrated together.
- The registry uses explicit quest IDs and tolerates repeated registration.

## Migration sequence

1. Add and validate the central registry/service (this change).
2. [Complete] Replace direct quest-definition registration in `HollowTankard` with the campaign registry/service.
3. Move quest dialogue-choice resolution into quest content adapters/dispatch so `HollowTankard` handles only presentation effects and world actions.
4. Move quest content and encounter files into `scripts/quests/content/` and `scripts/quests/encounters/`, updating every preload and test in the same change.
5. Integrate The Missing Watch through the same service and actor-presentation boundary.

## Rules for new quests

- Do not add quest definitions, reward calculations or quest-stage rules to `HollowTankard`.
- Keep encounter simulation separate from actor presentation.
- Make registration idempotent.
- Persist quest state in the campaign journal and dynamic actor state through the existing save system.
- Add focused headless tests for state transitions, rewards, failure/retreat and save restoration.
