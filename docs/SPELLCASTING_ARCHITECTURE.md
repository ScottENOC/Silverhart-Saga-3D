# Spellcasting architecture

## Catalogue and preparation

The player-facing catalogue contains the official 12 base spells: Firebolt, Counterspell, Feather Fall, Disguise Self, Heal, Divine Protection, Divine Strength, Curse, Summon Animal, Entangle, Calm Animal and Wild Fury. `PreparedSpell` preserves the base ID, validated modifier choices and stable presentation identifiers. `SpellRules` is the sole source of variant cost, range, radius and magnitude calculations.

## Shared action path

Player controls and combat AI submit `SimulationActionRequest.cast_spell()` or `cast_spell_at_hex()`. `WorldSimulation` validates the learned spell, exact prepared variant, target, range, Time Points, mana and armour/Blood Magic costs before payment. `SpellEffectRules` applies effects only after the validation and payment boundary. The simulation remains authoritative; the UI cannot bypass legality or resource payment.

## Executable spell effects

| Spell | Simulation effect |
|---|---|
| Firebolt | Ranged damage, hit check, armour reduction and supported burst variant |
| Counterspell | Dispel an active target effect or summoned creature; can interrupt a pending opposing cast through the reaction system |
| Feather Fall | Timed self-protection, consumed by the shared fall-damage hook |
| Disguise Self | Stores a selected appearance profile on the caster |
| Heal | Restore health and revive eligible unconscious allies; supports burst healing |
| Divine Protection | Applies a protective effect that penalises hostile attackers |
| Divine Strength | Grants an ally a timed damage bonus |
| Curse | Applies timed hostile-action penalties and its supported cleric skill hooks |
| Summon Animal | Registers a wolf, boar, tiger, eagle or quest-gated unicorn summon |
| Entangle | Applies timed movement-cost effects to opponents in a hex radius |
| Calm Animal | Calms eligible animal targets; excludes fey and dragons |
| Wild Fury | Grants a timed bonus to unarmed damage |

Active character effects are stored on `CharacterState` and included in character save data. Timed effects advance with the simulation clock. Spell terrain effects are serialized by `WorldSimulation` and contributed to campaign snapshots through the SaveManager snapshot-extension interface.

## Campaign and presentation ownership

- `SpellbookPanel` owns spell preparation, targeting UI and player-facing cast requests.
- `CampaignSpellcastingController` is created by `WorldRoot`, the campaign composition root. It coordinates the spellbook, target-click input, Disguise Self appearance editing, summoned-animal actors and spell-terrain save/restore.
- `SpellVfxController` is presentation-only; successful simulation events drive its effects.
- The Hollow Tankard location controller is not the owner of spellbook UI, targeting, disguise editing, summon actor lifecycle or spell-terrain persistence. Those campaign-level responsibilities live outside `hollow_tankard.gd`.

## Deliberate presentation deferral

Verbal/somatic grammar, spoken audio, hand gestures and casting animation remain presentation work. The prepared-spell schema retains symbolic hooks for that later layer. No spell is considered complete merely because a visual or audio cue exists; the simulation effect and its tests are the acceptance criteria.

## Verification

The Godot 4.7.2 workflow runs the spell construction/cost, casting/AI, effect and visual-effect suites alongside the wider campaign regression suite. Counterspell's reaction path charges the defender 5 TP and the Counterspell mana cost; a countered caster pays the spell mana cost but not the cast TP cost. NPC counterspell decisions use the source game's 50% response chance.
