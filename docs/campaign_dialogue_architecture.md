# Campaign dialogue architecture

## Non-negotiable presentation contract

Every player-visible spoken or narrative text event uses exactly one of two modes:

1. **Ambient** — non-blocking text attached to the speaking character in the world. It expires after a short duration measured in real time. Multi-speaker ambient exchanges remain in this mode.
2. **Interactive** — blocking conversation panel with the current speaker's portrait, contextual text and/or dialogue, and explicit player choices. A choice may simply end the conversation.

There is no third presentation mode. In particular, world-origin floating narration is not permitted. Non-character context belongs in the interactive panel; ambient text must have an identifiable speaker/actor.

NPC-to-NPC banter is ambient. Any NPC-to-player exchange that expects a response is interactive. Player initiation and NPC initiation are different entry points into the same interactive conversation runtime, not separate dialogue systems.

## Current implementation on `dev`

| Component | Current responsibility | Architectural status |
|---|---|---|
| `scripts/presentation/campaign_ambient_dialogue_presenter.gd` | Actor-attached speech, wrapping, duration and real-time expiry; supports sequential multi-speaker exchanges | Canonical ambient presenter |
| `scripts/simulation/campaign_conversation_session.gd` | Validates prompts and owns one active conversation's lifecycle, initiation metadata and choice selection | Canonical interactive session |
| `scripts/presentation/campaign_conversation_controller.gd` | Adapts the shared session to the existing panel, resolves portraits and forwards choices | Canonical interactive controller |
| `scripts/ui/campaign_dialogue_panel.gd` | Renders speaker, context/body, optional actor portrait and choice buttons; emits selected choice data | Retain as the interactive presentation component |
| `scripts/simulation/hollowmere_opening_sequence_controller.gd` | Coordinates the timed Hollowmere opening beat through injected world/presentation callbacks | Reusable sequence controller |
| `scripts/simulation/hollowmere_campaign_content.gd` | Authored Hollowmere opening lines, choices, NPC greetings and ambient exchange data | Retain content separation; migrate incrementally |
| `scripts/simulation/camp_companion_dialogue_service.gd` | Builds ambient companion exchanges | Retain as an ambient content/service precedent |
| `scripts/simulation/companion_campaign_dialogue_service.gd` | Packages companion chapter prompts and routes chapter operations | Domain-specific dialogue service, not a second runtime |
| `scripts/simulation/persistent_character_dialogue_content.gd` | Builds state-aware persistent-character dialogue | Retain as content, not presentation/runtime |
| `scripts/quests/campaign_ambassador_dialogue_service.gd` | Routes Brokk, Toren, Cassia, Marta, Nella and Baron tribute choices through their existing quest content modules; returns dialogue/status/close data | Domain choice coordinator; no UI or scene dependency |
| `scripts/quests/campaign_local_quest_dialogue_service.gd` | Routes Old Mac farm wolves, Dray missing courier and Petra toll-taker choices through their existing quest content modules; returns dialogue/status/world-action flags | Domain choice coordinator; actor spawning remains in the world adapter |
| `scripts/simulation/companion_campaign_dialogue_service.gd` | Routes companion chapter start/resolution and Wren character-arc choices; packages returned dialogue and XP outcomes | Companion domain service; no UI or scene-node dependency |
| `scripts/world/campaign_npc_interaction_service.gd` | Resolves nearby NPCs and their actors | Retain as world interaction lookup |
| `scripts/world/hollow_tankard.gd` | Composes the world, resolves local actors, starts the shared opening sequence, supplies presentation adapters and handles remaining camp/abandoned-house/encounter handoffs | World adapter; domain choice resolution is delegated to the relevant services |

## Remaining architectural gaps

- `HollowTankard._select_dialogue_choice()` remains a scene-owned dispatcher for several unrelated campaign systems. Ambassador/elder/innkeeper/baron tribute choices are routed by `CampaignAmbassadorDialogueService`; farm wolves, missing courier and toll-taker choices are routed by `CampaignLocalQuestDialogueService`; companion chapter and Wren character-arc choices are routed by `CompanionCampaignDialogueService`. Remaining camp, dwelling and encounter branches still need bounded domain extractions.
- `HollowTankard._interact_with_character()` still selects the relevant domain dialogue service for local NPCs. It should ultimately become a thin world-interaction adapter that asks those services for prompts.
- The opening sequence is extracted. The scene supplies callbacks for quest start, actor speech, soldier movement, resolved-state checks and the final interactive handoff; it no longer owns the timing loop.
- `HollowTankard._show_speech_bubble()` now delegates to the shared ambient presenter. It does not create labels or timers itself.
- The world-origin narration helper has been removed. The tavern entrance/stage direction is supplied as context in Dray's interactive prompt, while character lines remain ambient.
- The shared controller accepts both `player` and `npc` initiation sources. The Hollowmere opening uses the NPC-initiated path; ordinary player Talk interactions use the player-initiated path.

## Target responsibilities

### Authored content
Dedicated simulation/content resources provide dialogue prompts, speaker IDs, body/context, portrait/expression hints, choices, conditions and typed effects. They do not create UI or mutate scene nodes.

### Interactive conversation runtime
The shared session owns the active conversation lifecycle and validates prompt/choice data. The controller renders each prompt and forwards selected choices to the owning domain service. Domain consequences remain outside the session, controller and panel.

### Ambient dialogue service/presenter
The shared presenter owns actor-attached text creation, wrapping, duration calculation and real-time expiry. The simulation/content side chooses eligible ambient exchanges and speakers; scene adapters only provide actor resolution/presentation roots.

### Presentation
`CampaignDialoguePanel` remains the interactive panel. It receives state through `CampaignConversationController` and emits choice selections; it must not own campaign rules.

### World/scene adapters
Scene-specific scripts may resolve local actors, provide the scene tree/presentation root, and connect shared service signals. They must not own dialogue content, branching, conversation orchestration, choice routing or UI construction.

## Migration status

1. **Shared ambient presenter — implemented.** Actor-attached text and real-time expiry are centralized; sequential exchanges are supported.
2. **Hollowmere opening sequence — implemented.** Timing is in a simulation controller; stage context is interactive and character speech is ambient.
3. **Shared interactive session/controller — implemented.** Existing panel retained; prompt presentation, session lifecycle, portraits and choice selection use one shared path.
4. **Player/NPC initiation — shared path implemented.** Both sources use the same session/controller. More NPC-initiated campaign events can adopt the same entry point as they are ported.
5. **Choice/domain extraction — outstanding.** Move the legacy choice dispatcher into domain-specific services in small, tested groups. Do not turn the controller into a campaign rules engine.
6. **Cross-project presentation audit — ongoing.** Keep regression coverage for actor-attached real-time ambient speech, interactive context/portrait/choices, both initiation sources, and removal of any third presentation mode.

## Scope guardrails

- Do not create a second normal dialogue engine.
- Do not put dialogue content, rules, orchestration, response dispatch or presentation construction in `hollow_tankard.gd` or another scene-specific script.
- Do not move domain consequences into the UI panel or conversation controller.
- Do not treat every existing scene-specific branch as a generic effect without preserving its domain service and tests.
- Keep each extraction independently testable and validate against the current `dev` head before merging.
