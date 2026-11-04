# Browser game migration map

The existing `ScottENOC/Hex-crpg` repository is the behavioural and content reference.
It remains independently playable and is not a dependency of this project.

| Existing area | New destination | Migration approach |
|---|---|---|
| `entities.js` | CharacterState, party state, presentation actor | Separate logical state from visual interpolation and scene nodes |
| `hexMap.js` | HexGrid, map data, world presentation, camera/input | Rebuild; do not port Canvas renderer |
| `terrain.js` | Terrain definitions and movement/combat resolvers | Convert rules into data and tested resolvers |
| `gameEngine.js` | Movement, action, combat, AI and interaction services | Decompose by domain; do not port wholesale. First increments: ActionEconomy, WorldClock, CombatTurnScheduler, MovementRules and weighted HexPathfinder. |
| `campaign2World.js` | Authored world data + world bootstrap | Extract data and scene setup; avoid browser globals |
| `regions.js`, `worldPulse.js` | Regional simulation and event scheduler | Preserve persistent regional state and time-based events |
| `persistence.js` | Versioned save/load service | New schema, stable IDs; no legacy compatibility initially |
| `humanoidRenderer.js` | Character rigs, equipment sockets and animation | Rebuild in 3D; preserve equipment identity and visual rules |
| `ui.js` | Godot UI scenes | Rebuild around game state/events |
| `campaign2Dialogue.js` | Dialogue definitions and interaction actions | Data-driven dialogue; effects resolved through simulation commands |
| `campaign2Content.js` and content data | Data resources / definitions | Preserve IDs; replace embedded executable functions with explicit effect definitions |

## Important behaviour to preserve

- Real-time world simulation and action/time-point tactical combat.
- Movement, attack costs, reactions, interruptions and AI decision-making. The first movement pass shares terrain-aware TP costs between keyboard stepping and mouse-click A* routes; advanced climbing, occupancy exceptions, road preferences, reactions and AI pathing remain outstanding.
- Multiple relationship dimensions; do not flatten into one reputation number.
- Party members, followers, formations, mounts and shared inventory.
- Equipment, skills, spells, crafting and resource gathering.
- Buildings with doors, floors, stairs, elevation and fall handling.
- Local hex map and wider regional/world map as distinct scales.
- NPC schedules, sleep/wake, caravans, shops, regional conditions and autonomous events.
- Persistent consequences, faction standings, rumours and campaign political developments.
- Stable identity for NPCs even when their 3D presentation is unloaded.

## First content slice

The standard non-greenskin Campaign 2 opening at the Hollow Tankard is the first
authentic vertical slice. The greenskin openings must remain possible in the eventual
architecture, but they are not part of the first playable slice.

The first slice should preserve the original scene's characters, dialogue, branch
outcomes, reputation/faction effects and follow-up state. The new rectangular inn
architecture replaces the old trapezoidal tile footprint; gameplay positions and paths
are remapped to the new physical layout.
