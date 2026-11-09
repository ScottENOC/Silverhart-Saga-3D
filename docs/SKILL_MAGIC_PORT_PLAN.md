# Skill, progression and magic port plan

## Source of truth
The original `ScottENOC/Hex-crpg` `main` branch is authoritative. Adjacent JSON files are source-derived static catalogues, not proof that effects are implemented. Source currently defines 186 skill entries and 15 base spells.

## One progression model for every character
The main character, companions, named NPCs, generated humanoid NPCs and combatant enemies use the same rules for attribute pools, skill budgets, prerequisites, rank caps and effects. They differ only in who chooses the spend.

- **Player:** race + ordered class levels generate attribute pools. Player explicitly spends points in the skill UI. Unspent points persist through save/load.
- **Companions:** same purchase validator; authored build preferences guide automatic allocation. Identity/class build remains stable. Level-ups allocate only newly earned points.
- **Named NPCs:** authored race, class levels, preferred picks, equipment and archetype. Validate picks in purchase order. Invalid or over-budget picks become warnings, never silent free grants.
- **Generated humanoids:** deterministic seeded race/class packages and fully legal point spending. Build should fit role, equipment and faction.
- **Civilians:** explicit zero-class/zero-skill progression mode.
- **Non-humanoid creatures:** innate/template abilities and creature-specific policies; do not force humanoid class rules.

## Skill-point accounting
Preserve original calculation: race bonuses + bonuses from each class level produce attribute pools. Each purchase consumes one point from its own tree; wildcard points may substitute only where original rules permit. Track:
- generated/earned points by pool;
- spent points by skill and pool;
- remaining points by pool;
- explicitly free/innate ranks exempt from spending;
- authored intent, unmet picks, progression mode and deterministic seed.

For every pool, spent + remaining must reconcile to earned budget. Prevent level-up, reload, respawn or companion rejoin from awarding points twice.

## NPC skill-spending policy
Port the original layers as behavioural reference:
- `npcProgression.js`: race profiles, class packages, legal spending, equipment requirements and priorities.
- `npcProgressionPolicy.js`: deterministic weighted package choice, legacy reconciliation and equipment legality.
- `namedNpcProgression.js`: stable authored named builds.
- `npcProgressionModes.js`: authored / population / civilian separation and invariant checks.
- `companionProgression.js`: stable companion identities and preferred builds.
- `npcBuilder.js` and `campaign2Content.js`: authored skill-pick examples.

AI spending order:
1. Make equipped weapon, armour, shield and mount legal.
2. Buy prerequisites in valid order.
3. Meet archetype/class must-haves.
4. Prefer skills the NPC can actually use (no shield reaction without shield, no bow mastery without bow).
5. Spend remaining points via deterministic weighted priorities.
6. Avoid mutually exclusive/unusable duplicates; report legitimate leftovers.

## Magic
Port base spells and learn/unlock skills together:
- spell learning prerequisites and unlock state;
- arcane/divine/nature mana pools, caps, regeneration and spell slots;
- original spell-builder cost formula and dials (magnitude, range, radius, target count, speed);
- burst, touch, subtle, quickened/slowed and school-specific efficiency;
- target legality, tags, self-targeting, hit checks, duration and ongoing effects;
- summon restrictions and permanent-companion interactions;
- NPC spellbooks containing only learned, valid and affordable variants;
- tactical AI selection based on target, expected effect, mana, TP, role and friendly-fire risk.

NPCs need both knowledge and a valid built spell variant, plus an AI policy for when to cast. Player-created spells remain player-authored and must never be overwritten by NPC generation.

## Proposed 3D architecture
1. `data/skills/skill_definitions.json` — source metadata, tree, prerequisites, rank limits and effect identifiers.
2. `data/magic/base_spells.json` — spell definitions and targeting/effect metadata.
3. `scripts/simulation/skill_catalog.gd` — loading, validation and lookup.
4. `scripts/simulation/skill_progression.gd` — budget calculation, legal purchase, rank checks, respec and reconciliation.
5. `scripts/simulation/npc_skill_spending.gd` — deterministic role/equipment-aware build generation.
6. `scripts/simulation/spell_catalog.gd` + `spell_builder.gd` — spell definitions and variant/cost generation.
7. `scripts/simulation/spell_casting.gd` — cast validation and effects.
8. `scripts/simulation/npc_spell_planner.gd` — NPC spellbook construction and tactical choice.
9. Extend `CharacterState` save/load with budgets, spent ranks, free ranks, unlocks, spell variants and progression provenance.

Do not create a second parallel skills dictionary. Existing reads in `world_simulation.gd` and `combat_rules.gd` should be migrated incrementally to the shared model without regressing their current behaviour.

## Existing 3D foundations observed on dev
- `CharacterState` stores `skills`, `free_skill_ranks`, mana, mana caps, spell slots and unlocked base spells.
- `CombatRules` reads selected ranks for weapon damage, racial damage bonuses and shield reduction.
- `WorldSimulation` contains Parry/Protector, Spear Intercept, Spear Halt and Sidestep reaction paths.
- Character creation currently seeds a basic Health rank.
- No complete skill catalogue, point-purchase service, spell builder/caster or NPC skill-spending service was found in dev.

## Acceptance tests
- Every original skill and base-spell ID represented exactly once.
- Race + class budgets match source calculations for every playable race/class.
- Purchases validate pool, wildcard, prerequisite, rank cap, mutually exclusive choices and point availability.
- Player, companion, authored NPC, generated NPC and civilian fixtures reconcile budget = spent + remaining (free ranks separately tracked).
- NPC builds deterministic for fixed seed; every purchase legal and equipment legal without free proficiency.
- Level-up grants points once; save/load and respawn do not duplicate them.
- Existing 3D combat mechanics retain behaviour after integration.
- Spell variants match source cost formula; unaffordable/illegal casts rejected.
- NPCs only generate spells learned and affordable, then choose contextually sensible casts.
- Regression fixtures cover player, companions, named NPCs, generic humanoids, civilians and monsters.

## Implementation order
1. Add source-derived catalogues (this PR).
2. Implement point budget and purchase validator; wire player UI and save/load.
3. Port deterministic NPC spending; migrate authored NPCs and companions.
4. Port spell builder/casting; verify combat integration.
5. Port NPC spellbook generation and tactical casting.
6. Port remaining effects by family with regression tests.
