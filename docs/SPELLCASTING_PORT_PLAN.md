# Spellcasting Port Plan

**Reference baseline:** Hex-crpg main, reviewed 18 November 2026  
**3D baseline:** current dev after PR #154  
**Purpose:** turn the 15-entry base spell catalogue into a tested, usable spellcasting system without treating catalogue data or mana fields as completed gameplay.

## Source-of-truth modules

| Original source | Responsibility to preserve |
|---|---|
| `spells.js` | 15 base definitions, spell schools/types, target tags, self-target rules, durations and summon choices |
| `spellPlanner.js` | Prepared spell construction, school-specific metamagic, spell-slot limits, deterministic NPC spellbooks and idle auto-heal policy |
| `gameEngine.js` | Cast timing, mana/armour costs, Blood Magic affordability, Counterspell reactions, active effects, upkeep/expiry and effect resolution |
| `ui.js` | Player spell builder, spell stats/cost preview, spellbook, target selection and cast feedback |
| `skills.js` | Learn-spell gates, school capacity/efficiency/range/magnitude/speed/expand/targets/burst/touch/regen skills, subtle casting and armour-ease skills |

Current 3D data is `data/magic/base_spells.json`. Current character state already stores mana, school caps, spell-slot capacity and unlocked base-spell IDs, but has no prepared-spell or active-spell model.

## Required architecture

1. **Spell catalogue and validation**
   - Load and validate the 15 base definitions using the same data-driven pattern as SkillCatalog.
   - Reject unknown IDs, invalid schools/types, malformed tags and invalid numeric fields.
   - Keep catalogue metadata separate from runtime spell instances.

2. **Spell builder / prepared spell model**
   - Reproduce the original cost formula for default, quickened and slowed casting.
   - Support school-specific range/magnitude efficiency, magnitude/range/radius/target dials, burst, touch and subtle options only when the relevant skills unlock them.
   - Apply mana caps and armour penalties consistently.
   - Persist prepared spells and spell-slot usage; keep deterministic NPC auto-build separate from player-authored spell construction.
   - Preserve summon-specific animal choices and their additional mana costs.

3. **Shared cast action contract**
   - Add spell casting to SimulationActionRequest / WorldSimulation rather than letting UI mutate CharacterState directly.
   - Validate caster availability, learned/prepared spell, target or clicked hex, range, line of sight where required, side/tag restrictions, mana affordability and TP.
   - Ensure failed casts do not spend mana or TP.
   - Support exploration casting delay and combat turn costs through one rules contract.

4. **Active spell lifecycle**
   - Represent active effects by stable IDs, caster/target IDs, base spell ID, effect parameters, upkeep cost and remaining duration/expiry rule.
   - Persist effects in WorldSimulation save/load and clean them up when caster/target/entity is removed or an effect is dispelled.
   - Implement ongoing mana upkeep and timed expiry in the world tick pipeline.
   - Keep trigger-ended effects (e.g. Sanctuary) distinct from timed effects (e.g. Wild Fury / Feather Fall).

5. **Effect families**
   - Direct damage/healing and area damage/healing.
   - Buffs/debuffs and tag-restricted effects.
   - Area ground effects, dispel, Counterspell and Time Point manipulation.
   - Summoning with legal placement, creature templates, summon lifecycle and permanent animal-companion exception.
   - Special disguise and Feather Fall integration with the character/world systems.

6. **Player and NPC experience**
   - Spellbook and spell-builder UI with live cost/cap preview.
   - Target selection for entity and hex-targeted spells, clear rejection feedback and cast result feedback.
   - Counterspell reaction prompt using the existing reaction framework.
   - NPC spell preparation and AI cast selection; idle auto-heal only after the cast path is reliable.

## Recommended implementation order

1. Catalogue validation, prepared-spell data model and exact cost calculator with unit tests.
2. Single-target Firebolt and Heal through the shared cast action, including range/side/target validation, mana/TP costs and save/load.
3. Spellbook and target-selection UI for those tested casts.
4. Remaining direct damage/heal and area families.
5. Persistent buffs/debuffs, duration/upkeep, dispel and Sanctuary interactions.
6. Counterspell reactions and Blood Magic.
7. Summoning, disguise, Feather Fall and Temporal Rift.
8. NPC spell planner/AI and exploration auto-heal.
9. Source-by-source acceptance against all 15 base spells and every unlocked metamagic skill.

## Acceptance rules

- No spell is marked complete because it exists in JSON or appears in the spellbook.
- Every cast path has tests for success, invalid target, out-of-range, insufficient mana/TP, school cap, and failed-cast non-mutation.
- Every persistent effect has lifecycle, expiry/upkeep, dispel and save/load tests as applicable.
- UI and AI call the same simulation cast API.
- Any deliberate deviation from the 2D behaviour is recorded with a reason.
