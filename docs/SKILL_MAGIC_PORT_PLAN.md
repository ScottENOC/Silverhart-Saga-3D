# Skill, progression and magic port plan

## Source of truth
The original `ScottENOC/Hex-crpg` `main` branch is authoritative. Adjacent JSON files are source-derived static catalogues, not proof that effects are implemented. Source has 186 directly declared skill definitions plus 71 unique entries expanded by generateWeaponSkills() and generateMagicSkills(), for 257 runtime skill IDs, plus 15 base spells.

## One progression model for every character
The main character, companions, named NPCs, generated humanoid NPCs and combatant enemies use the same rules for attribute pools, skill budgets, prerequisites, rank caps and effects. They differ in who chooses the spend and when.

- **Player/main character:** race + ordered class levels generate attribute pools. The player explicitly spends points in the skill UI. Unspent points persist through save/load.
- **Companions at recruitment:** when a companion first joins the party, automatically allocate all skill points accumulated through their current level. Use their race, class/level history, role, equipment and authored build preferences to create a legal, coherent build. This is a one-time recruitment initialisation, not a recurring auto-build policy.
- **Companions after recruitment:** from the moment they join, all newly earned skill points remain unspent until the user allocates them. Do not automatically spend companion points on level-up. The UI should make each companion's available points visible and allow the user to choose their skills.
- **Companion departure/rejoin:** preserve the companion's existing ranks, spent-point ledger, unspent points and recruitment-initialisation marker. Rejoining must not rebuild them or grant/spend the same points again. A genuinely new companion instance should be initialised once when first recruited.
- **Named NPCs who are not party companions:** use authored race, class levels, preferred picks, equipment and archetype. Validate picks in purchase order. Invalid or over-budget picks become warnings, never silent free grants. If one becomes a party companion, apply the one-time recruitment rule only to any valid unspent budget; preserve authored ranks and spending.
- **Generated humanoid NPCs who are not party companions:** deterministic seeded race/class packages and fully legal point spending. Build should fit role, equipment and faction.
- **Civilians:** explicit zero-class/zero-skill progression mode.
- **Non-humanoid creatures:** innate/template abilities and creature-specific policies; do not force humanoid class rules.

## Skill-point accounting
Preserve original calculation: race bonuses + bonuses from each class level produce attribute pools. Each purchase consumes one point from its own tree; wildcard points may substitute only where original rules permit. Track:
- generated/earned points by pool;
- spent points by skill and pool;
- remaining points by pool;
- explicitly free/innate ranks exempt from spending;
- authored intent, unmet picks, progression mode and deterministic seed;
- for companions, whether one-time recruitment allocation has occurred and the point-balance snapshot at recruitment.

For every pool, spent + remaining must reconcile to earned budget. Prevent level-up, reload, respawn or companion rejoin from awarding points twice. Recruitment allocation may spend only the companion's then-current unspent budget; it must not overwrite prior authored or earned ranks.

## NPC skill-spending policy
Port the original layers as behavioural reference for non-party NPCs and for the one-time companion recruitment build:
- `npcProgression.js`: race profiles, class packages, legal spending, equipment requirements and priorities.
- `npcProgressionPolicy.js`: deterministic weighted package choice, legacy reconciliation and equipment legality.
- `namedNpcProgression.js`: stable authored named builds.
- `npcProgressionModes.js`: authored / population / civilian separation and invariant checks.
- `companionProgression.js`: stable companion identities and preferred builds.
- `npcBuilder.js` and `campaign2Content.js`: authored skill-pick examples.

Automatic allocation order:
1. Make equipped weapon, armour, shield and mount legal.
2. Buy prerequisites in valid order.
3. Meet archetype/class must-haves.
4. Prefer skills the character can actually use (no shield reaction without shield, no bow mastery without bow).
5. Spend remaining eligible points via deterministic weighted priorities.
6. Avoid mutually exclusive/unusable duplicates; report legitimate leftovers.

**Important boundary:** the automatic allocator must not run on a party companion's ordinary level-up after recruitment. At that point it is only a recommendation/reference for the player, not an authority that spends points.

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

NPCs need both knowledge and a valid built spell variant, plus an AI policy for when to cast. Player-created spells remain player-authored and must never be overwritten by NPC generation. Party companions' newly earned skill points remain player-controlled as described above; spell learning/unlocking must respect that same ownership boundary rather than silently spending their points.

## Proposed 3D architecture
1. `data/skills/skill_definitions.json` — source metadata, tree, prerequisites, rank limits and effect identifiers.
2. `data/magic/base_spells.json` — spell definitions and targeting/effect metadata.
3. `scripts/simulation/skill_catalog.gd` — loading, validation and lookup.
4. `scripts/simulation/skill_progression.gd` — budget calculation, legal purchase, rank checks, respec and reconciliation.
5. `scripts/simulation/npc_skill_spending.gd` — deterministic role/equipment-aware build generation, with a recruitment-only entry point for companions.
6. `scripts/simulation/spell_catalog.gd` + `spell_builder.gd` — spell definitions and variant/cost generation.
7. `scripts/simulation/spell_casting.gd` — cast validation and effects.
8. `scripts/simulation/npc_spell_planner.gd` — NPC spellbook construction and tactical choice.
9. Extend `CharacterState` save/load with budgets, spent ranks, free ranks, unlocks, spell variants and progression provenance, including companion recruitment state.

Do not create a second parallel skills dictionary. Existing reads in `world_simulation.gd` and `combat_rules.gd` should be migrated incrementally to the shared model without regressing their current behaviour.

## Existing 3D foundations observed on dev
- `CharacterState` stores `skills`, `free_skill_ranks`, mana, mana caps, spell slots and unlocked base spells.
- `CombatRules` reads selected ranks for weapon damage, racial damage bonuses and shield reduction.
- `WorldSimulation` contains Parry/Protector, Spear Intercept, Spear Halt and Sidestep reaction paths.
- Character creation currently seeds a basic Health rank.
- No complete skill catalogue, point-purchase service, spell builder/caster or NPC skill-spending service was found in dev. The feature branch now adds a validated catalogue loader, a shared purchase/accounting service, persistent pool ledgers and one-time grant IDs. Runtime skill effects, NPC policies, companion recruitment integration, and UI are still outstanding.

## Acceptance tests
- Every original runtime skill ID—including programmatically generated weapon and magic skills—and base-spell ID represented exactly once.
- Race + class budgets match source calculations for every playable race/class.
- Purchases validate pool, wildcard, prerequisite, rank cap, mutually exclusive choices and point availability.
- Player, companion, authored NPC, generated NPC and civilian fixtures reconcile budget = spent + remaining (free ranks separately tracked).
- Companion recruitment auto-allocates the accumulated budget exactly once; ordinary post-recruitment level-ups add unspent points and never trigger automatic spending.
- Companion departure/rejoin preserves ranks and balances without rebuilding or duplication.
- NPC builds deterministic for fixed seed; every purchase legal and equipment legal without free proficiency.
- Level-up grants points once; save/load and respawn do not duplicate them.
- Existing 3D combat mechanics retain behaviour after integration.
- Spell variants match source cost formula; unaffordable/illegal casts rejected.
- NPCs only generate spells learned and affordable, then choose contextually sensible casts.
- Regression fixtures cover player, newly recruited companions, established companions levelling up, rejoining companions, named NPCs, generic humanoids, civilians and monsters.

## Implementation order
1. Add source-derived catalogues, including generated weapon and magic skill definitions (this PR).
2. Implement point budget and purchase validator; wire player UI and save/load.
3. Port deterministic NPC spending for non-party NPCs and one-time companion recruitment; ensure party companion level-ups remain player-controlled.
4. Port spell builder/casting; verify combat integration.
5. Port NPC spellbook generation and tactical casting, respecting player control of party companions.
6. Port remaining effects by family with regression tests.


## Canonical campaign companions staged in Hollowmere
- The original `companionProgression.js` defines eight canonical recruitable builds: Ser Aldric Thorne, Nix Sharpear, Warlord Grukk Ironhide, Reyna Fletcher, Mirabel Quill, Fenn Oakheart, Brother Alden and Snik Fangtooth.
- Their race, gender, ordered class history, preferred skill picks, equipment, extra inventory and source dialogue IDs are now represented in the Hollowmere character manifest/loadouts. The Hollowmere spawn path builds their authored skill progression through `NPCSkillSpending.build_authored` before registration.
- They are represented as neutral world NPCs, not automatically recruited. Their current placements are temporary staging positions; future region-by-region world work will replace them with canonical campaign locations.
- Temporary presentation: they use the shared Ara runtime male/female base bodies with distinct appearance parameters and hair, rather than bespoke companion GLBs. Goblin/orc racial appearance is not yet represented; individual models and proper racial bodies remain art work.
- The strategic campaign map already has a Hollowmere POI and map-data foundation, but the full explorable campaign world and companion quest locations are not yet built. Hollowmere placement is a temporary staging arrangement.


## Companion dialogue and recruitment gates
- Hollowmere routes all eight canonical companion NPCs through source-derived first-contact dialogue, separate from their post-recruitment companion conversation IDs. The dialogue profile now accepts the canonical character IDs and the actual `game_id` values in the NPC manifest.
- The UI provides a **Nearby People** list with a separate Talk button for each person in range. This avoids silently choosing the wrong person when several NPCs are standing together; F remains a shortcut to the nearest person. Hostile quest targets appear as explicit Engage choices.
- Recruitment remains gated by the original campaign outcomes: Aldric freed from goblin captivity; Nix only after the peaceful goblin alliance; Grukk after the troll quest and 40+ orc faction standing; Reyna after the farmstead rescue and dire-wolf hunt; Mirabel after the ruin's spider nest is cleared; Fenn after delivering three herbs; Alden after Northwatch is defended; Snik after the greenskin Star Fort outcome.
- Quest state and branch decisions are stored in `CampaignJournal`; the dialogue/recruitment helper exposes `complete_objective` and `complete_with_decision` for world/combat event integration. Fenn's herb turn-in consumes three actual inventory bundles.
- **Reyna's farmstead recruitment is a separate, staged story alongside Old Mac's ordinary wolf-pack quest.** After accepting, the player follows a visible scrap of Tessa's blue cloak and small footprints to an abandoned shepherd's shelter. Tessa, Old Mac's young niece, is found alive inside while the dire wolf prowls outside. The player speaks to her and escorts her back to the farm; only then can the dire wolf be engaged. Defeating it completes Reyna's quest and unlocks recruitment. The ordinary wolf-pack quest and its three-wolf den encounter remain independent. The rescue and hunt share the existing Hollowmere map and combat systems; combatants start at the source 100 TP baseline.
- Successful recruitment calls `WorldSimulation.recruit_companion`, preserving the authored NPC build and applying the one-time companion progression boundary. The companion joins the party and stops ambient NPC chatter.
- Remaining companion quest locations/encounters still to port: goblin camp and Aldric rescue; Skarnak's Hold/troll; spider ruin; Emberwood herb patches; Northwatch siege; Star Fort. Their quest gates and dialogue exist, but these events must call the quest-completion helpers before recruitment becomes available.


## Farmstead creature encounter note
- Reyna's dire wolf reuses the generic Quaternius wolf model at enlarged scale and its existing animation set. The dire wolf has its own identity and tougher combat statistics; Old Mac's separate pasture-pack quest continues to use ordinary wolves.
