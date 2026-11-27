# Campaign architecture

## Ownership

The campaign is composed independently of any location scene.

- **WorldRoot** owns application/scene startup and constructs the shared simulation and campaign coordinator.
- **CampaignCoordinator** is the campaign composition root. It configures campaign-wide services, registers campaign content and exposes campaign-facing operations.
- **WorldSimulation** remains the authoritative owner of mutable world and campaign state.
- **Campaign services** own focused workflows such as quest access, companion chapter progression, household routines and camp lifecycle.
- **Location scenes** own only location-specific presentation and interaction surfaces. They must not register campaign quests, seed campaign rules or become the owner of campaign-wide workflows.

## Existing services to reuse

- `scripts/quests/campaign_quest_service.gd` — common journal operations and central quest registry.
- `scripts/quests/campaign_quest_registry.gd` — explicit catalogue of quest definition modules.
- `scripts/simulation/companion_campaign_dialogue_service.gd` — companion chapter dialogue and resolution.
- `scripts/world/campaign_household_world_service.gd` — household actor and routine behaviour.
- `scripts/world/rowan_fletcher_world_service.gd` — Rowan's camp interactions.
- `scripts/world/camp_lifecycle_controller.gd` — camp lifecycle and presentation coordination.
- `scripts/world/campaign_npc_interaction_service.gd` — shared NPC proximity and actor lookup.

Do not create competing replacements for these services. Extend or compose them behind the campaign coordinator where appropriate.

## Current migration

1. `CampaignCoordinator` now owns initial campaign setup, including the opening clock, quest-service configuration, central quest registration and starting social standings.
2. `CampaignQuestRegistry` now includes the opening Hollowmere shakedown, Farm Wolves, Elder Marta's locket and Aldenreach message definitions alongside its existing catalogue.
3. `WorldRoot` delegates campaign initialisation to the coordinator rather than importing and registering individual quest content itself.
4. The existing `HollowTankard` script is not the target for new campaign orchestration. Its remaining responsibilities must be extracted behind focused services before it can become a thin location adapter.

## Next extraction slices

- Move standalone quest dialogue routing and NPC greeting selection into campaign dialogue dispatchers, called by the coordinator/service layer rather than by a location-owned rules script.
- Extract quest-specific encounter orchestration from location scripts; keep only actor creation and world presentation callbacks at the location boundary.
- Move Wren/companion chapter interaction routing into the existing companion dialogue service.
- Integrate The Missing Watch through the central registry and dialogue/encounter boundaries after its preload/validation failure is resolved.
- Audit save/load restoration so the coordinator rehydrates services without moving authoritative state out of `WorldSimulation`.

## Rules

- Never add quest definitions, reward calculations, quest-stage rules or campaign-wide registration lists to a location scene.
- Keep encounter simulation separate from actor presentation.
- Keep registration idempotent and test it through the campaign registry, not by manually registering definitions in individual tests.
- Persist campaign state in the existing journal/simulation/save system; coordinators and services should be reconstructible.
