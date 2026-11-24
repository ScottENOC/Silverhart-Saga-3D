# In-world camp system

## Time and interaction rules

- Camp is established in the current world; it does not load a separate camp map.
- Evening activities use the ordinary exploration clock (5 game seconds per real second).
- Social contact, flirting and intimacy are not restricted to a camp phase or a dedicated social activity. The interaction system resolves the event and supplies its actual relationship changes.
- Sleep is an explicit eight-hour skip to morning, not eight hours of accelerated real-time simulation. It advances the authoritative world clock and applies overnight recovery in bulk.
- Night watch is assigned when sleep begins, not during evening chores.
- Combat and pending reactions take priority over autonomous companion movement.

## Companion routine presentation

Companions receive a camp station based on their simulation assignment. They path to that station through the existing hex movement system; the player remains directly controlled. When a companion reaches the station, the actor is asked to play the matching Ara animation.

Ara's documented Godot workflow is a rigged, animated GLB with looping clips marked in the export panel so Godot imports names such as `Walk-loop`. The game uses the existing shared Ara animation carrier, so camp routines do not need a separate skeleton or per-character animation set.

Current animation mapping:

| Camp activity | Ara clip preference | Notes |
| --- | --- | --- |
| Gather wood | `pick_up` → `carry_idle` | Generic ground pickup followed by a two-hand carry pose; no dedicated chopping clip is documented |
| Set up tents | `pick_up` → `use_press` | Generic lifting and interaction gestures; tent assembly itself is not animated yet |
| Fetch water | `pick_up` → `carry_idle` | Generic two-hand carry pose; no water container prop is attached yet |
| Cook | `use_press` | Generic interaction gesture; no dedicated cooking clip is documented |
| Repair gear | `use_press` | Generic interaction gesture |
| Study map | `use_press` | Standing interaction gesture avoids sitting without a chair; no map prop is attached yet |
| Train | `squat`, `push_up` | Fitness clips are loops |
| Socialise | `talk_gestures` | Background conversational loop |
| Watch | `look_around` | Background look-around loop |
| Sleep | `lie_down` → `sleep` | Uses the authored transition into the looping sleep pose; bedding alignment remains a separate task |

The runtime uses Ara's canonical clip IDs (rather than display labels), tries preferences in order and falls back gracefully when an imported character asset does not contain a clip. Looping clips remain active; one-shot clips are replayed or chained into a carry/interaction pose while the character remains assigned.

### Dwelling-aware routine staging

The camp activity director now reads the active dwelling layout ID from the camp lodging profile. It uses layout-specific station anchors around the dwelling's world hex when routing companions: hearth for cooking, workshop for repairs, study for map work, common room for socialising, threshold for watch, and yard for outdoor tasks. A one-room cottage routes study to its shared common area; a three-room country house has a separate study and workshop; the restored roadside house and fortified manor use their own distinct anchor patterns.

These are currently hex-map staging positions, not navigable indoor room interiors. If a preferred station hex is absent, blocked or occupied, the director chooses the nearest available walkable hex to that station's intended position, then falls back to the ordinary camp radius. It still reserves one destination per companion and uses normal pathfinding and movement. Wilderness camps retain the terrain-based station selection.

When the ambient topic is home, the conversation service also receives the active dwelling layout and adds a short observation appropriate to that property. This is deliberately limited to the home topic; it does not pretend that the companions have access to rooms or facilities that are not yet represented in the world.

Regression tests cover the different study/cooking station placements and cottage-versus-manor home dialogue. The next presentation step is to build actual property geometry and usable room stations, then let routine schedules react to weather, danger, injuries and party needs.

## Ara export requirements

Ara documents 259 animation clips and exports each selected clip into the rigged GLB. The gameplay animation carrier must therefore be exported with the camp clips included; a rigged-only export is not sufficient. Mark looping clips in their names so Godot imports them with the `-loop` suffix. Keep root motion disabled for these stationary camp actions because world locomotion is already controlled by the hex movement system. Retain the shared 65-bone game rig and matching bind pose used by the existing animation carrier.

Ara GLBs use metres, +Y up, and face +Z. The current gameplay actor wrapper already applies its 180-degree model-forward correction, so new body exports should not add a second manual rotation.

## Deliberate limitations

- Ara's published clip list does not include dedicated chopping, cooking, map-reading, tent-pitching or equipment-repair performances. Current mappings are visual approximations, not claims that those tasks have bespoke animation.
- Ara's two-person Handshake is documented for two characters of similar height at a precise relative position. It should not be treated as a general-purpose hug, romance or contact animation.
- Character-specific height, body proportions and rig differences should be respected by the Ara animation carrier and any future interaction placement. Paired contact scenes need their own contact validation before being considered complete.
- The current camp director moves companions to a station and keeps them there. Resource gathering, carried prop state, inventory consumption and chore outcomes still need simulation integration.

## Companion-to-companion camp dialogue

Camp now schedules autonomous companion exchanges rather than waiting for the player to speak to someone. Every 22 real seconds during the evening, the director selects a pair from the recruited companions (excluding the player), cycles through all possible pairs, and starts a short two-turn conversation. The speakers receive the Ara talk-gesture animation and each line appears as a speech bubble above its speaker.

The authored banter service currently covers Wren, Aldric, Nix, Grukk, Reyna, Mirabel, Fenn, Brother Alden, Snik and Dagna. Four recurring subjects (the road, camp work, home and danger) give each character a distinct voice. Dagna's initial ambient lines reflect her upbringing in a religious community and her growing questions about how its teachings are interpreted, while deliberately leaving her deity, doctrine and eventual direction undefined. A listener's response is guarded when familiarity is low and becomes warmer when that listener's trust and friendship with the speaker are established.

Each completed exchange records directional familiarity/trust/friendship changes and improves both companions' camp social satisfaction. Event keys make those effects idempotent. Conversations are not gated on a character having the socialise assignment: companions can talk while taking a break from another camp duty. The player remains directly controlled and is not inserted as a participant in these autonomous exchanges.

This is an initial ambient-dialogue layer, not yet a full branching conversation UI between NPCs. It does not infer romance or consent from friendship, and it does not yet create a relationship agreement. The authored exchange content is data-driven so further pair-specific history, quest references and conflict reactions can be added without changing the camp movement system.


## Campaign-aware party conversations

Ambient camp dialogue now checks the authoritative companion quest-chain state before choosing a generic topic. When either participant has completed a personal chapter or a companion-specific prerequisite quest, the pair can discuss the most recently completed authored quest that belongs to one of them. The conversation uses the recorded resolution (including the effective resolution when the companion chose for themselves) and the authored reason from that chapter's data. An unresolved or merely offered chapter is never described as completed.

The responding companion has an authored outlook across a small set of decision themes represented by the existing quest content: shared responsibility, self-reliance, restraint, bold inquiry, institutional trust, independence, tradition, stewardship, personal dignity and pragmatism. A compatible outlook produces support; a conflicting outlook produces an explicit but civil disagreement; an unaligned outlook asks the companion to reflect. Existing directional companion bonds temper how openly the response is delivered.

These memory conversations are recorded against the pair and chapter outcome, so the same completed decision is not repeated every time that pair talks at camp. Agreement and disagreement also have different relationship effects: support can deepen friendship, while disagreement can build familiarity and trust without automatically awarding friendship. The ordinary ambient topics continue after a campaign memory has been discussed.

This pass uses the existing CompanionQuestChainState and CampaignJournal as the source of truth. It does not invent quest outcomes, infer a companion's decision from the player's choice, or make every companion agree with the player. Current authored decision stances cover the Fenn prerequisite quest and completed companion chapters for Aldric, Mirabel, Fenn, Reyna and Brother Alden; other companions continue to use their ordinary camp banter until their own authored quest outcomes are available.


## Player-owned dwellings and sheltered camps

The legacy housing routes remain distinct campaign actions rather than a generic property shop:

| Action | Gate | Payment | Layout and camp capacity |
| --- | --- | --- | --- |
| Build crossroads cottage | Surveyed starting plot; no reputation or quest gate in the source | No charge in the original MVP | One-room cottage; one indoor sleeping place |
| Expand to country house | Own the crossroads cottage | 6 wood + 6 stone, or 90 gold | Larger three-room layout; three indoor sleeping places |
| Restore abandoned roadside house | Complete the abandoned-house clearing quest | 8 wood + 8 stone; no gold substitute | Restored roadside layout; two indoor sleeping places |
| Claim Silverhart manor | Silverhart Kingdom standing of at least 60 | Royal grant; no purchase price | Ruined manor until fortified |
| Fortify Silverhart manor | Own the royal grant | 10 wood + 10 stone; no gold substitute | Livable multi-room manor; eight indoor sleeping places |

The manor's reputation threshold is a distinct high-standing reward, not a single-quest reward. The abandoned house requires its clearing quest before materials can be spent. The cottage expansion accepts either gathered materials or the original gold alternative. The adjoining-field purchase remains a separate homestead feature.

Campaign dwelling state owns the action gates, payments, ownership and improvement state. It validates requirements before consuming inventory or gold and is included in world and location save snapshots. Each action also identifies its intended layout and sheltered-camp profile.

When a camp is explicitly established at an owned, livable dwelling, indoor beds are assigned before tents or open-air sleeping. Indoor sleepers receive that property's warmth, security and comfort bonuses; companions beyond its indoor capacity still use ordinary tent and sleeping-bag rules. The camp site must supply its dwelling ID, so owning a house does not shelter a party camping elsewhere.

This pass defines layout IDs and connects dwelling shelter to camp simulation. It does not yet build all four property interiors as explorable 3D locations, add a builder interaction UI, or port the abandoned-house clearing encounter. The required quest-state ID for that encounter is abandoned_house_cleared; until the quest port completes it, the restoration action correctly remains unavailable.


### Changing evening routines

Camp time now moves through three routine stages using the ordinary exploration clock: initial setup, the main evening, and late-evening wind-down. The first transition resolves gathered firewood, water and meal preparation once, before companions move on to personal activities. Player-directed assignments remain protected until their normal override expires.

Routine selection considers persistent fatigue, injury inferred from current health/hobbling, class role, explicitly authored personality tags, available supplies, nearby water/wood, weather severity and whether the camp has a livable dwelling. Fatigued or injured companions avoid strenuous work; scholarly and methodical companions favour map study; practical/craft-oriented companions can take repair work when kits exist. The late routine becomes quieter rather than repeatedly cycling through chores.

The dwelling distinction is functional rather than merely cosmetic: a livable house allows indoor-oriented late activities and shelter from severe weather, while a wilderness camp remains exposed and continues to prioritise essential water/fire needs. No personality is invented where the character has no matching authored tag; those companions use neutral defaults. Routine stage, profiles and preparation completion are saved with camp state.


The routine-stage thresholds are measured in world seconds: 120 seconds (24 seconds of ordinary real-time exploration) begins the main evening, and 360 seconds (72 seconds of ordinary real-time exploration) begins the wind-down. Indoor sleeping capacity is considered before tent setup, so a manor with enough beds is not treated like a wilderness camp with redundant tents.
