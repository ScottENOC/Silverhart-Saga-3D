# Spell Parity Audit — 2D source vs 3D dev

**Audit date:** 2026-11-11  
**3D baseline:** `dev` at `6b33dac76bfa44d5e87740d665922dbef9697359`  
**2D source:** `ScottENOC/Hex-crpg` `main`  
**Scope:** all 15 entries in `data/magic/base_spells.json`, compared with the original `spells.js`, `gameEngine.js`, `spellPlanner.js` and spell-builder UI in `ui.js`. This is an implementation audit, not a proposal to redesign spell behaviour.

## Executive finding

The 3D port currently has the **spell catalogue and character-state placeholders, not a working spellcasting system**.

Confirmed on 3D `dev`:
- `data/magic/base_spells.json` contains all 15 base spell IDs and source-derived fields.
- `CharacterState` stores `current_mana`, `max_mana`, school mana caps, `max_spell_slots` and `unlocked_base_spells`, and serialises/deserialises those values.
- The reviewed `SimulationActionRequest` and `WorldSimulation` contain no spell/magic/mana/cast path.
- The current `scripts/simulation/` tree has no `spell_catalog.gd`, `spell_builder.gd`, `spell_casting.gd` or `npc_spell_planner.gd`.
- The existing `docs/SKILL_MAGIC_PORT_PLAN.md` explicitly lists those systems as future implementation steps.

Consequently, **none of the 15 spells is currently verified as castable or effect-resolving in 3D**. The data definitions should not be mistaken for partial gameplay implementations. The JSON catalogue is broadly faithful to the 2D base definitions; the missing work is the runtime system and its integrations.

## Per-spell parity matrix

| Spell ID | Original 2D behaviour (source of truth) | 3D dev evidence | Audit result |
|---|---|---|---|
| `firebolt` | Single-target arcane damage; hit check; spell accuracy and Firebolt skill bonus; target cover affects hit chance; can ignite an unlit fireplace or detonate an oil barrel when aimed at the tile. | Base damage/range/mana/hit-check data only. No cast or world-object interaction path found. | **DATA ONLY — runtime missing** |
| `heal` | Restores target HP up to maximum; revives an unconscious target when HP becomes positive. Can be converted to an area burst by the Divine Burst skill. AI can select healing casts. | Base heal data only; no effect resolver, target validation or AI spell use. | **DATA ONLY — runtime missing** |
| `smite_evil` | Divine damage with a hit check; only valid against targets tagged `undead` or `demon`. | Tags, damage and hit-check metadata only. No target-tag enforcement at runtime. | **DATA ONLY — runtime missing** |
| `divine_silence` | Ongoing target effect. Casting while silenced breaks the silence; its ongoing penalty is processed during ticks and can trigger the cleric's configured divine-drain penalty. | Ongoing/debuff metadata only; no active-effect lifecycle or tick processing. | **DATA ONLY — runtime missing** |
| `sanctuary` | Ongoing protection. Opponents are hindered by a TP penalty when attacking or casting at the protected target; offensive action by the protected character ends the sanctuary. Can trigger cleric retaliation effects. | Buff/debuff metadata only; no attack/cast hooks or expiry/cancellation handling. | **DATA ONLY — runtime missing** |
| `divine_protection` | Ongoing defensive protection. An attacker loses TP when making a melee attack against the protected target. | Buff metadata only; no combat integration. | **DATA ONLY — runtime missing** |
| `summon_animal` | Summons a selected creature at a clicked hex, with occupancy, bounds and terrain checks (including multi-hex placement). Wolf, boar, tiger and eagle are ordinary options. Unicorn is not an ordinary temporary summon: it is a permanent companion gated by the druid-grove unlock, Animal Companion skill and having no existing companion. | Summon list metadata only. No summon placement, creature creation or permanent-companion interaction. | **DATA ONLY — runtime missing** |
| `counterspell` | Reaction to an opposing cast when the countering caster has a prepared Counterspell, sufficient mana and TP, and is within range of the caster or target. Player can choose the reaction; AI counter attempts use a chance roll. Counterspell spends TP/mana and negates the incoming spell. | Spell definition only; no cast reaction or reaction integration. | **DATA ONLY — runtime missing** |
| `dragon_breath` | Immediate area damage centred on a clicked hex, radius 1, range 4; affects opposing entities in the burst without an individual hit check. | AOE data only; no hex-area resolution or damage application. | **DATA ONLY — runtime missing** |
| `entangle` | Area debuff centred on a clicked hex, radius 1, range 8. Affected hexes are changed to Swamp and recorded as an active spell/hex effect, which can be dispelled. | AOE/debuff metadata only; no terrain mutation, active hex effect or dispel. | **DATA ONLY — runtime missing** |
| `wild_fury` | Buffs only the caster or that caster's own animal companion (not another ally); increases unarmed damage by the spell magnitude; expires after 200 world ticks. | Buff, magnitude and duration metadata only; no target restriction, combat modifier or timed expiry. | **DATA ONLY — runtime missing** |
| `calm_animal` | Ongoing debuff restricted to genuine animal-tagged creatures, excluding fey and dragons. Casting at a rider redirects the effect to the mount. Cast-time mode is Stay, Come or Chase; an attacked/calmed animal can break free. | Tag and exclusion metadata only; no target resolver, mount redirection, mode or AI behaviour. | **DATA ONLY — runtime missing** |
| `disguise_self` | Self-only spell. Applies a player-configured disguise profile through the disguise system and tracks it as an active effect; recasting replaces the previous disguise. | Self-target flag only; no disguise profile UI, appearance application or effect lifecycle. | **DATA ONLY — runtime missing** |
| `temporal_rift` | Sets the selected target's current TP to zero, pushing its next turn back until TP regenerates. | Type/range/mana data only; no TP effect. | **DATA ONLY — runtime missing** |
| `feather_fall` | Self-only timed protection lasting 30 world ticks. It is checked when a character is knocked from a height and prevents the fall consequence; recasting replaces the previous effect. | Self-target, duration and debuff metadata only; no fall-event integration or timed effect. | **DATA ONLY — runtime missing** |

## Shared 2D systems that must be ported

The source behaviour is broader than the 15 individual effect handlers. These shared systems are prerequisites for faithful parity.

### 1. Learning, spell construction and preparation
- A spell is learned through its corresponding `learn_<spell_id>` skill, subject to the original progression rules. Creature/template exceptions exist for monster-only spells.
- The player builds named spell variants from unlocked base spells and saves them to the prepared spell list, subject to school mana caps and spell-slot limits.
- The builder exposes magnitude, range, radius, additional targets, speed (default/quickened/slowed), burst, touch and subtle options where the character's skills permit them.
- Burst converts single-target damage/healing into an area effect. Touch trades range for lower mana cost. Subtle casting preserves stealth for eligible non-damaging spells.
- AI spellbooks are generated from spells the NPC has actually learned, with valid and affordable variants; the player-authored spellbook must remain player-controlled.

### 2. Cost, action economy and mana
- The source builder calculates mana cost from the base spell and selected options, with school-specific skill efficiencies/caps.
- Quickened casts use 5 TP and a mana surcharge; slowed casts use 20 TP and reduce mana cost. Other dials add their source-defined mana costs.
- Armour adds a spellcasting mana penalty (light/medium/heavy: +1/+2/+3); Divine and Nature armour-ease skills reduce the relevant school penalty.
- Blood Magic is an explicit toggle: a mana shortfall can be paid at 2 HP per missing mana, but the caster must remain above zero HP.
- Outside combat, casting is delayed according to TP cost and proceeds through a pending-cast/cooldown path. In combat, TP is spent as part of the action.
- Ongoing spells have mana upkeep: 2.5% of core mana cost per TP gained. Insufficient mana ends the effect. Timed effects count down by world ticks.

### 3. Targeting, reactions and lifecycle
- Validate range, target side/type/tags, self-target rules, clicked-hex effects, area radius and summon placement before applying an effect.
- Counterspell is a reaction, not an ordinary target effect. Sanctuary and Divine Silence also modify the casting pipeline.
- Maintain active effects with target/entity/hex association, cancellation, dispel, duration, upkeep, save/load and UI state.
- Integrate with existing 3D combat, terrain, elevation/fall handling, creature/mount state, disguise/appearance and AI. These cannot be implemented faithfully as isolated catalogue lookups.

### 4. NPC behaviour
- The original AI constructs spellbooks only from known spells and valid variants, then chooses casts based on range, mana, TP, expected value, role and target clusters.
- Healing AI selects eligible allies, accounts for overheal and mana efficiency, and can approach within a bounded path distance outside combat.
- Summoning and attack spell use have distinct tactical conditions. A generic “NPC knows spell” flag is insufficient.

## Source references inspected

- Original definitions: [`spells.js`](https://github.com/ScottENOC/Hex-crpg/blob/main/spells.js)
- Original cast validation, cost payment, Counterspell, spell effects and active-effect processing: [`gameEngine.js`](https://github.com/ScottENOC/Hex-crpg/blob/main/gameEngine.js) (notably `tryCastSpell`, `resolveSpell`, `cancelSpell`, combat effect hooks and tick processing)
- Original player spell builder and targeting UI: [`ui.js`](https://github.com/ScottENOC/Hex-crpg/blob/main/ui.js) (spell screen, variant calculation, save and target selection)
- Original NPC spellbook generation and idle healing: [`spellPlanner.js`](https://github.com/ScottENOC/Hex-crpg/blob/main/spellPlanner.js)
- 3D definitions: [`base_spells.json`](https://github.com/ScottENOC/Silverhart-Saga-3D/blob/dev/data/magic/base_spells.json)
- 3D character persistence: [`character_state.gd`](https://github.com/ScottENOC/Silverhart-Saga-3D/blob/dev/scripts/simulation/character_state.gd)
- 3D port plan: [`SKILL_MAGIC_PORT_PLAN.md`](https://github.com/ScottENOC/Silverhart-Saga-3D/blob/dev/docs/SKILL_MAGIC_PORT_PLAN.md)

## Audit conclusion and implementation order

**Current 3D parity: 0/15 spells verified as castable.** This is a runtime-system gap, not evidence that the base spell catalogue itself is wrong.

Recommended order, following the existing port plan:
1. Spell catalogue loader/validator and canonical learn/unlock mapping.
2. Spell builder/variant calculator, including exact source cost formulas and school limits.
3. Cast request, target validation, affordability/payment and TP/cooldown handling.
4. Shared active-effect lifecycle, upkeep, duration, cancellation and save/load.
5. Individual spell effect handlers and their integrations (combat, terrain, creatures, mounts, disguise and falling).
6. Counterspell/Sanctuary/Divine Silence reaction and cast-pipeline interactions.
7. NPC spellbook construction and tactical spell selection.
8. Deterministic tests for each spell and cross-cutting interaction, with source-derived fixtures.

No spell implementation is included in this audit. Do not mark a spell complete until the relevant cast path and effect are exercised by tests.


## Additional source inconsistency: 19 orphan spell-unlock skills

The original `skills.js` contains **19 additional `learn_*` definitions** that push spell IDs into `unlockedBaseSpells`, but those IDs are not among the 15 entries in the original `spells.js` `baseSpells` registry:

| School | Skill IDs | Unlocked IDs |
|---|---|---|
| Arcane | `learn_blink`, `learn_slow`, `learn_force_push`, `learn_haste`, `learn_chain_lightning`, `learn_energy_shield`, `learn_gravity_well` | `blink`, `slow`, `force_push`, `haste`, `chain_lightning`, `energy_shield`, `gravity_well` |
| Divine | `learn_curse`, `learn_command`, `learn_mark_of_guilt`, `learn_divine_wrath`, `learn_excommunicate`, `learn_condemn` | `curse`, `command`, `mark_of_guilt`, `divine_wrath`, `excommunicate`, `condemn` |
| Nature | `learn_root`, `learn_barkskin_spell`, `learn_natures_vigor`, `learn_spore_cloud`, `learn_call_of_the_wild`, `learn_camouflage` | `root`, `barkskin_spell`, `natures_vigor`, `spore_cloud`, `call_of_the_wild`, `camouflage` |

The descriptions in `skills.js` specify intended costs and effects (for example Blink teleports within 4 hexes; Chain Lightning deals 3/2/1 damage across successive enemies; Energy Shield absorbs 6 damage for 20 ticks; Root prevents movement for 5 TP ticks). However, these IDs are not defined in the original `baseSpells` object, and a targeted scan of the original `gameEngine.js` found no corresponding spell-effect handlers for them. The original player spell builder also obtains its spell name/configuration from `baseSpells[id]`.

**Treatment:** mark these 19 as **ORPHAN SOURCE UNLOCKS — described by a skill, but no corresponding base spell definition/effect path established**. Do not silently add them to the 3D spell catalogue or claim they were fully working in the 2D game. They are a source-project inconsistency / unfinished feature set that needs a deliberate product decision before any port. `learn_temporal_rift` is not part of this orphan group because `temporal_rift` is one of the 15 registered base spells.

This also means the 3D port should keep two counts distinct:
- **15 registered base spells** — real original definitions, all currently data-only in 3D.
- **19 orphan unlock definitions** — descriptions in the original skill tree, but no registered base spell/effect implementation confirmed in the original source.


## Follow-up: learning skills are not wired to spell unlock state

A further check of 3D `SkillProgression.purchase()` confirms that purchasing a
skill increments the rank in `CharacterState.skills` and updates point
accounting; it does not apply an unlock effect. In particular, no mapping was
found from `learn_<spell_id>` ranks to
`CharacterState.unlocked_base_spells`. NPC skill allocation likewise stores
skill ranks but does not construct an unlocked spell list.

The `unlocked_base_spells` and `max_spell_slots` fields in
`CharacterState` are persisted, but the reviewed 3D simulation scripts do not
consume them in a casting/preparation flow. This means that even the 15
registered spells' `learn_*` skills are not yet demonstrated to unlock their
corresponding spell IDs on 3D dev. Spell-learning integration is therefore
missing before the spell builder/casting work even begins.

## Follow-up: orphan source unlock cross-check

The 19 orphan IDs listed above were also searched in the original 2D
`spells.js`, `ui.js` and `spellPlanner.js`, in addition to
`gameEngine.js`. No corresponding base-spell definitions or effect handlers
were found in those magic files. The few string matches for `slow` are spell
speed/variant controls, not a registered Slow spell; `command` matches are
unrelated command/UI code. The classification remains **described by a skill,
but not registered as a base spell and not implemented in the inspected 2D
magic pipeline**.

One source comment in `spellPlanner.js` says that both Dragon Breath and
Temporal Rift have no `learn_*` skill, but the current `skills.js` does
contain `learn_temporal_rift`. Treat that comment as stale; Temporal Rift is
one of the 15 registered spells and is not an orphan unlock.
