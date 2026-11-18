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


## Shared casting resolver

`SimulationActionRequest.cast_spell()` is the common entry point for player and NPC casts. `WorldSimulation.submit_action()` enforces the active combat turn, then delegates spell validation, affordability and effect application to `SpellCastingRules`.

The first supported effects are:

- **Firebolt:** hostile target, computed spell range, ranged hit check and prepared magnitude damage.
- **Heal:** friendly living target within one hex; can restore health and revive an unconscious character.

A cast must be unlocked and present in the caster's saved prepared-spell list. The resolver validates target legality, range, mana and Time Points before paying either resource. Unsupported spell families and modifier variants are rejected without cost. NPC combat AI uses this same action for prepared Heal and Firebolt rather than implementing a second effect path.
