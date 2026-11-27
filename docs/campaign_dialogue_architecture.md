# Campaign dialogue architecture

## Non-negotiable presentation contract

Every player-visible spoken or narrative text event uses exactly one of two modes:

1. **Ambient** — non-blocking text attached to the speaking character in the world. It expires after a short duration measured in real time. Multi-speaker ambient exchanges remain in this mode.
2. **Interactive** — blocking conversation panel with the current speaker's portrait, contextual text and/or dialogue, and explicit player choices. A choice may simply end the conversation.

There is no third presentation mode. In particular, world-origin floating narration is not permitted. Non-character context belongs in the interactive panel; ambient text must have an identifiable speaker/actor.

NPC-to-NPC banter is ambient. Any NPC-to-player exchange that expects a response is interactive. Player initiation and NPC initiation are different entry points into the same interactive conversation runtime, not separate dialogue systems.

## Existing implementation found on `dev`

| Component | Current responsibility | Architectural status |
|---|---|---|
| `scripts/ui/campaign_dialogue_panel.gd` | Renders speaker, body, optional actor portrait and choice buttons; emits `choice_selected` | Retain as the interactive presentation component |
| `scripts/simulation/hollowmere_campaign_content.gd` | Authored Hollowmere opening lines, choices, NPC greetings and ambient exchange data | Retain content separation; migrate content incrementally |
| `scripts/simulation/camp_companion_dialogue_service.gd` | Builds ambient companion exchanges | Retain as an ambient content/service precedent |
| `scripts/simulation/companion_campaign_dialogue_service.gd` | Packages companion chapter prompts and routes chapter operations | Reuse where applicable; it is not a general conversation runtime |
| `scripts/simulation/persistent_character_dialogue_content.gd` | Builds state-aware persistent-character dialogue | Retain as content, not presentation/runtime |
| `scripts/world/campaign_npc_interaction_service.gd` | Resolves nearby NPCs and their actors | Retain as world interaction lookup |
| `scripts/world/hollow_tankard.gd` | Owns panel construction, portrait lookup, choice dispatch, NPC routing, opening sequence and floating text construction | Must be reduced to world composition/adapters |

## Confirmed architectural gaps

- There is no general interactive conversation session/runtime in the dialogue-named scripts. The panel only renders a supplied prompt and forwards a selected dictionary.
- `HollowTankard._select_dialogue_choice()` is a large scene-owned dispatcher for unrelated campaign systems and dialogue branches.
- `HollowTankard._interact_with_character()` owns character-specific conversation routing.
- `HollowTankard._run_opening_sequence()` owns the opening sequence and calls presentation helpers directly.
- `HollowTankard._show_speech_bubble()` creates actor-attached ambient text and a timer in the scene script.
- `HollowTankard._show_world_narration()` creates a separate world-origin floating text presentation. This violates the two-mode contract.
- The opening narrator line is actually stage/context text (the tavern door opening and armed men entering), not spoken dialogue. It should become context in the interactive panel, not be attributed to a fictitious speaker.
- NPC interaction and opening dialogue both call the same panel helper, but that alone does not make their conversation flow a shared runtime.

## Target responsibilities

### Authored content
Dedicated simulation/content resources provide dialogue nodes, speaker IDs, body/context, portrait/expression hints, choices, conditions and typed effects. They do not create UI or mutate scene nodes.

### Interactive conversation runtime
A shared runtime owns the active conversation session and its progression: current speaker/node, response selection, speaker changes, completion/cancellation, and dispatch of typed campaign effects through services. It must accept both player-initiated and NPC-initiated starts.

### Ambient dialogue service/presenter
A shared presenter owns actor-attached text creation, wrapping, duration calculation and real-time expiry. The simulation/content side chooses eligible ambient exchanges and speakers; scene adapters only provide actor resolution/presentation roots.

### Presentation
`CampaignDialoguePanel` remains the interactive panel. It should receive presentation state from the shared runtime/controller and emit choice selections; it must not own campaign rules.

### World/scene adapters
Scene-specific scripts may resolve local actors, provide the scene tree/presentation root, and connect shared service signals. They must not own dialogue content, branching, conversation orchestration, choice routing or UI construction.

## Migration sequence

1. Add and test the shared ambient presenter; route all ambient text through it and remove the world-origin narration helper.
2. Extract the opening sequence into a reusable campaign sequence/controller. Keep its stage/context text in the interactive panel and its character speech in ambient mode.
3. Introduce the shared interactive conversation session/runtime around the existing panel. Preserve the current panel and existing content APIs while moving response routing out of `HollowTankard`.
4. Route player interactions and NPC-initiated prompts through the same runtime; initiation source is metadata, not a second engine.
5. Migrate existing scene-specific choice handlers into domain services/effect handlers in small, tested groups. Do not make a large one-shot rewrite.
6. Add regression tests asserting that every dialogue presentation is ambient or interactive, that ambient text is actor-attached and expires in real time, and that both interactive initiation paths use the same runtime.

## Scope guardrails

- Do not create a second normal dialogue engine.
- Do not put dialogue content, rules, orchestration, response dispatch or presentation construction in `hollow_tankard.gd` or another scene-specific script.
- Do not move domain consequences into the UI panel.
- Do not treat every existing scene-specific branch as a generic effect without preserving its domain service and tests.
- Keep each extraction independently testable and validate against the current `dev` head before merging.
