# Spellcasting architecture

## Catalogue and preparation

The source-derived catalogue contains all 15 base spells. `PreparedSpell` preserves the base ID, validated modifier choices and stable presentation identifiers. `SpellRules` is the sole source of variant cost, range, radius and magnitude calculations.

## Shared action path

Player controls and combat AI submit `SimulationActionRequest.cast_spell()` or `cast_spell_at_hex()`. `WorldSimulation` validates the learned spell, exact prepared variant, target, range, Time Points, mana and armour/Blood Magic costs before payment. `SpellEffectRules` applies effects only after the validation and payment boundary.

## Executable spell effects

| Spell | Simulation effect |
|---|---|
| Firebolt | Ranged damage, hit check, armour reduction and burst variant |
| Heal | Restore health and revive unconscious allies; burst healing |
| Smite Evil | Damage restricted to undead/demon tags |
| Divine Silence | Persistent damage over elapsed Time Points; broken when target casts |
| Sanctuary | Protects an ally and penalises hostile attacks/spells against them |
| Divine Protection | Penalises hostile attackers' Time Points |
| Summon Animal | Registers a wolf, boar, tiger, eagle or quest-gated unicorn summon |
| Counterspell | Dispel an active target effect or summoned creature |
| Dragon Breath | Hex-radius damage to opponents |
| Entangle | Applies timed movement-cost effects to opponents in a hex radius |
| Wild Fury | Timed bonus to unarmed damage |
| Calm Animal | Calms eligible animal targets; excludes fey and dragons |
| Disguise Self | Stores the selected disguise profile on the caster |
| Temporal Rift | Drains the target's Time Points to zero |
| Feather Fall | Timed self-protection, consumed by the shared fall-damage hook |

Active effects are stored on `CharacterState` and included in save data. Timed effects advance with the world clock. NPC AI uses the same cast action for Heal and Firebolt and will not take turns while calmed.

## Deliberate presentation deferral

Verbal/somatic grammar, spoken audio, hand gestures, casting animation and disguise rendering remain presentation work. The prepared-spell schema retains symbolic hooks for that later layer. No spell is considered complete merely because a visual or audio cue exists; the simulation effect and its tests are the acceptance criteria.

## Remaining verification

The full spell suite covers each catalogue entry, but the complete Godot 4.7.2 headless workflow must pass before this branch is merged. Counterspell can also interrupt an opposing cast through the existing reaction request system. The defender spends 5 TP and the Counterspell mana cost; a countered caster spends the spell mana cost but does not pay the cast TP cost. NPC counterspell decisions use the source game’s 50% response chance.
