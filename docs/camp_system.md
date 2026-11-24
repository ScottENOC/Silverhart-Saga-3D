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
| Gather wood | Pick up (ground) | Generic ground pickup; no dedicated chopping clip is documented |
| Set up tents | Pick up (ground) | Generic lifting gesture; tent assembly itself is not animated yet |
| Fetch water | Head-load idle, Carry idle, Pick up (ground) | The basin prop must be exported/attached for a convincing head-load |
| Cook | Use / press | Generic interaction gesture; no dedicated cooking clip is documented |
| Repair gear | Use / press | Generic interaction gesture |
| Study map | Sit idle | No map prop/hand interaction yet |
| Train | Squat, Push-ups | Fitness clips are loops |
| Socialise | Talk with gestures | Background conversational loop |
| Watch | Look around | Background look-around loop |
| Sleep | Sleep, Lie down | Sleep is available; bedding alignment remains a separate task |

The runtime tries these preferences in order and falls back gracefully when an imported character asset does not contain a clip. Looping clips remain active; one-shot clips are replayed after completion while the character remains assigned.

## Deliberate limitations

- Ara's published clip list does not include dedicated chopping, cooking, map-reading, tent-pitching or equipment-repair performances. Current mappings are visual approximations, not claims that those tasks have bespoke animation.
- Ara's two-person Handshake is documented for two characters of similar height at a precise relative position. It should not be treated as a general-purpose hug, romance or contact animation.
- Character-specific height, body proportions and rig differences should be respected by the Ara animation carrier and any future interaction placement. Paired contact scenes need their own contact validation before being considered complete.
- The current camp director moves companions to a station and keeps them there. Resource gathering, carried prop state, inventory consumption and chore outcomes still need simulation integration.
