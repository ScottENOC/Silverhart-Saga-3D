# Spellcasting architecture foundation

## Scope of this first implementation

This slice establishes two foundations only:

- `PreparedSpell` records the base spell and the modifier choices that produced a prepared variant.
- `SpellRules` is the single source-derived calculator for variant mana, Time Point cost, magnitude, range, radius and effective type.

It does not yet cast spells, apply spell effects, add a spellbook UI, or give NPCs casting decisions. Those belong in subsequent increments built on this data model.

## Prepared spell data

A prepared spell is serialisable and retains:

- `base_spell_id`
- modifier choices: speed, magnitude, range, radius, extra targets, burst, subtle and touch
- an optional presentation profile and symbolic verbal/somatic component IDs

The presentation fields are intentionally just stable identifiers. There is no invented language, recorded incantation or animation name in gameplay code. A later presentation layer can resolve the base spell and modifier choices through a grammar/gesture catalogue, while character traditions can override the profile or component mapping.

## Authoritative calculation

`SpellRules.compute_variant()` ports the original `Hex-crpg/spellPlanner.js` `computeSpellVariant()` formula. It preserves the distinction between `mana_cost` and `core_mana_cost`, the Arcane-only efficiency skills, the 1-mana floor, and the original speed/range/magnitude/radius/target/burst/subtle/touch arithmetic.

The calculator checks structurally invalid combinations (for example, subtle direct damage and burst on a buff). It does not yet decide whether a character has unlocked each modifier. That belongs in the future spell-building/legality layer, which will consult the character's actual learned skills and school options rather than trusting UI controls.

## AI and shared casting

The intended next layer is a shared simulation cast request and resolver. The player spellbook and NPC decision-maker will both submit the same `PreparedSpell` representation to that resolver. AI may choose different targets, tactical priorities and prepared variants, but must not have separate cost, range, affordability or effect rules.

No caller should directly deduct mana or Time Points before the shared resolver accepts a cast. A rejected cast must not consume either resource.

## Tests

Run with Godot 4.7.2:

```sh
godot --headless --path . --script res://tests/test_spell_rules.gd
```


## First shared casting slice

The first executable cast path is now implemented in `WorldSimulation`:

1. A caller constructs a `PreparedSpell` and submits `SimulationActionRequest.cast_spell()`.
2. The simulation checks the actor, turn ownership (when in combat), learned base spell, target relationship, range, magnitude, Time Points and mana affordability.
3. Only after every check succeeds does the simulation spend Time Points and mana (or the explicitly enabled Blood Magic health shortfall).
4. The resolver applies the effect and emits a `spell_cast` simulation event.

The first resolved effects are:

- **Firebolt** — ranged hostile spell, using the character's spell accuracy, Firebolt hit skill, target passive dodge, valid-tag restrictions and target damage reduction.
- **Heal** — adjacent allied healing, including waking an unconscious character when healing raises health above zero.

Armour casting penalties and the original Blood Magic conversion (two HP per missing mana, leaving at least one HP) are applied centrally. A failed validation spends no resources. The action resolver is the only place that applies cast costs/effects.

## Combat AI

`CombatAI` now uses the same action request and resolver:

- It considers healing itself or a nearby injured ally before choosing an offensive action.
- It can use Firebolt against an opponent outside its melee range but within spell range.
- It reads saved prepared variants when present; otherwise it can use a default variant for a learned base spell.
- It does not implement private AI-only mana, range, damage or healing rules.

This is an initial tactical policy, not a complete spell planner. AI does not yet build variants from its modifier unlocks, approach allies to heal, use Burst/AoE, Counterspell, summons, buffs/debuffs or utility effects.

## Remaining work

- Modifier legality: verify Quickened/Slowed, range, magnitude, radius, extra-target, Burst, Subtle and Touch against actual learned skill unlocks.
- Effect families: area damage/healing, ongoing effects, buffs/debuffs, dispel, summons and utility.
- Counterspell/reaction flow, including the player reaction prompt and AI counter decisions.
- Prepared-spell UI and improved navigation; the UI must submit the same request, never mutate resources itself.
- AI spellbook construction, tactical scoring, mana conservation and safe fallback/replanning.
- Out-of-combat cast timing and presentation. The current action spends TP immediately; the old game's real-time cast wind-up is not yet ported.
- Verbal/somatic grammar and animation remain presentation-layer work, as previously planned.
