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

The authored banter service currently covers Wren, Aldric, Nix, Grukk, Reyna, Mirabel, Fenn, Brother Alden and Snik. Four recurring subjects (the road, camp work, home and danger) give each character a distinct voice. A listener's response is guarded when familiarity is low and becomes warmer when that listener's trust and friendship with the speaker are established.

Each completed exchange records directional familiarity/trust/friendship changes and improves both companions' camp social satisfaction. Event keys make those effects idempotent. Conversations are not gated on a character having the socialise assignment: companions can talk while taking a break from another camp duty. The player remains directly controlled and is not inserted as a participant in these autonomous exchanges.

This is an initial ambient-dialogue layer, not yet a full branching conversation UI between NPCs. It does not infer romance or consent from friendship, and it does not yet create a relationship agreement. The authored exchange content is data-driven so further pair-specific history, quest references and conflict reactions can be added without changing the camp movement system.
