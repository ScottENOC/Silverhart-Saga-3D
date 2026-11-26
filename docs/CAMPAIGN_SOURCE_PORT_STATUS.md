# Campaign source-port status

**Source:** `ScottENOC/Hex-crpg`, `main`  
**Target:** `ScottENOC/Silverhart-Saga-3D`, `dev` plus isolated campaign feature branches  
**Status date:** 2026-11-23  
**Policy:** Preserve authored campaign behaviour and character-specific writing. A 3D adaptation may change presentation or spatial execution, but must not silently simplify the underlying choice, quest or relationship outcome.

This document distinguishes existing target functionality from the source systems that still need migration. A file existing in the 3D repository is not, by itself, evidence that the complete original feature has been ported.

**Detailed content gap ledger:** [Campaign 2 content gap audit](campaign2_content_gap_audit.md) — pinned source-to-target NPC roster, dialogue-volume and quest-ID reconciliation, with outstanding items and migration checklists (2026-11-26).

## Existing 3D campaign foundations

| Area | Existing target implementation | Current assessment |
|---|---|---|
| Campaign quest state | `scripts/simulation/campaign_journal.gd` | Basic quest lifecycle, objectives, decisions, faction/NPC standings, merchant influence and serialization exist. It is a useful base, not yet a complete event-driven quest engine. |
| Hollowmere opening | `scripts/simulation/hollowmere_campaign_content.gd` | The Ironbond shakedown has opening lines, three response choices, reputation cascades and conditional greetings. The full source dialogue/event chain still needs comparison and migration. |
| Companion first contact | `scripts/simulation/companion_campaign_content.gd` | First-contact and recruitment gates exist for eight companions, with several companion quests. This is not the same as porting their full personal quest chains or relationship stories. |
| Farm quest | `scripts/simulation/farm_wolves_quest.gd` | A 3D wolf/farm quest adaptation exists. |
| NPC identity/presentation | `data/characters/hollowmere_npcs.json`, `data/characters/legacy_named_npcs.json`, character registries and actor factory | Authored identities and visual definitions exist. Persistent campaign identity and world placement still need a shared runtime contract with the map stream. |
| Dialogue UI | `scripts/ui/campaign_dialogue_panel.gd` | A presentation panel exists. Dialogue content/conditions/consequences are still distributed through campaign content scripts. |
| World events | `scripts/simulation/simulation_event.gd` and `world_simulation.gd` | A simulation event pathway exists. The original quest and NPC systems have not all been migrated to consume it. |

## New relationship-state foundation in this branch

Added `scripts/simulation/companion_relationship_state.gd`, based on the original:

- `companionAffinity.js`
- `companionRelationships.js`
- `companionRelationshipProgression.js`
- `companionRomance.js`

It preserves separate axes for approval, familiarity, trust, friendship, romantic bond and attraction. It also carries authored presentation-dependent hard caps, companion-specific relationship styles, explicit agreements and breach responses, relationship interpretation/voice lines, idempotent conversation/event keys, bounded history and save/load support. Wren’s original shakedown, goblin-favour, goblin-resolution, personal-dialogue and parents-search affinity/disposition consequences are also migrated as keyed events.

The six companions with authored affinity/romance profiles in the source are Wren Talbot, Ser Aldric Thorne, Fenn Oakheart, Reyna Fletcher, Mirabel Quill and Brother Alden. The source's other two recruitable companions, Warlord Grukk Ironhide and Snik Fangtooth, do not have equivalent profiles in `companionAffinity.js`; this port does not invent romance profiles for them.

Important source-specific rules retained in the data:

- Wren starts at familiarity 35 and trust 25, and is the anchor companion. Her romantic and attraction caps differ by player gender presentation.
- Aldric's authored romantic/attraction caps are strongly presentation-dependent and his relationship style is exclusive, with a one-time reconciliation rule.
- Fenn, Reyna and Mirabel have open relationship styles and authored casual/FWB/group-relationship support; their attraction/romantic caps differ by character.
- Brother Alden has zero attraction caps but can form romantic bonds. His sexual exclusivity is open while romantic exclusivity is exclusive.
- Attraction, romantic bond, friendship, approval, familiarity and trust are not interchangeable. A threshold or accumulated meter is not consent.
- Relationship agreements record romantic exclusivity and sexual exclusivity separately. Breach handling preserves the different CNM, Aldric, Alden and Wren responses; Wren’s response receives her authored security value from the caller.
- Unique personal-dialogue familiarity and shared-party-day familiarity have separate source-derived caps (60 and 50 respectively).

The companion relationship class is deliberately not yet wired into `CharacterState`, the player save pipeline or dialogue UI. The new non-companion model is also a separate serialisable owner with an explicit approval/reputation synchronisation bridge to `CampaignJournal`; it is not yet attached to the authoritative save owner. These integrations must be coordinated with the map/campaign architecture before altering shared runtime files.

## Source systems still requiring port work

| Original source | Responsibility | Port status |
|---|---|---|
| `campaign2Dialogue.js` | Campaign 2 authored dialogue trees, conditional lines and choices | Partially represented by Hollowmere content and companion first-contact dialogue; full extraction and branch-by-branch parity remain. |
| `campaign2Content.js` | Campaign 2 NPC records, opening content and authored campaign data | NPC data has been partially migrated to JSON; full content audit remains. |
| `companionAffinity.js` | Friendship, romantic bond, attraction, caps and authored story affinity effects | Profile/state foundation added; complete affinity event table and all effects not yet ported. |
| `companionRelationships.js` | Familiarity, trust, conversation memory and clothing-boundary policy | Core relationship axes and unique conversation keys added; clothing-boundary baseline/enforcement remains unported. |
| `companionRelationshipProgression.js` | Unique dialogue, shared time, trust events and Wren-specific story consequences | Only authored starting values and generic idempotent event APIs are in the new foundation. Full progression rules remain. |
| `companionRomance.js` | Relationship interpretation, agreements, breach handling and Wren's love/desire conflict | Agreement data shape and authored voice-line/profile foundations are represented; interpretation, breach responses, reconciliation and Wren's authored conflict scenes remain. |
| `companionQuestChains.js` | Multi-chapter personal quests with authored resolutions and arc changes | All nine authored chapters and their dialogue/resolution data are now in `data/quests/companion_quest_chains.json`. `CompanionQuestChainState` handles prior-chapter gating, party presence, supporting-character consultation, companion-decided resolutions, journal completion, relationship/affinity effects, arc state, personality growth and chapter cooldowns. Runtime UI/event integration, XP application and earlier prerequisite companion arcs remain. |
| `persistentCharacterDialogueHooks.js` | Relationship memory and existing dialogue/quest bridges | Dialogue-tree-to-character mapping, one-time audience memory, Seraphine's familiarity-gated personal question and four relationship-dependent response lines, plus all three Wizard Vendetta relationship outcomes are now represented in `PersistentCharacterDialogueContent`. Actual dialogue UI/tree wiring remains. |
| `companionRelationshipMoments.js` | Contextual authored relationship scenes | Not yet ported. |
| `companionMajorQuestReactivity.js` | Companion responses to major campaign decisions | Not yet ported comprehensively. |
| `companionConversationMemory.js`, `persistentCharacterDialogueHooks.js` | Conversation/event memory and callbacks | Not yet ported comprehensively. |
| `persistentCharacterRelationships.js` | Persistent non-companion relationship depth | A separate state model and tests now cover all nine authored NPC profiles, approval/standing conversion, familiarity, trust, friendship, idempotent conversations/events, history bounds and serialisation. An explicit bridge now synchronises approval changes with `CampaignJournal` NPC standing. Save-owner integration remains. |
| `persistentCharacterCrossReactivity.js`, `ordinaryDialogueConsequences.js` | NPC-to-NPC and ordinary dialogue consequences | Not yet ported comprehensively. |
| `eventDrivenNpcSchedules.js`, `npcRoutineScheduler.js`, `civilianPersistence.js` | Schedules, persistent civilians and event-driven routine changes | Not yet ported comprehensively. |
| `companionContextualBanter.js`, `characterBanter.js`, `ambientChatterRelationships.js` | Party banter and ambient conversation | Not yet ported comprehensively. |
| `companionWorldAgency.js`, `companionDecisionAnticipation.js`, `companionObservedPersonality.js`, `companionPersonalityKnowledge.js`, `companionEvergreenPersonalityClues.js` | Companion autonomy, anticipation and learned knowledge | Not yet ported comprehensively. |

## Port sequence

1. **Complete and test the relationship-state foundation.** Compare every profile and state transition against the source; add migration-safe serialization and integrate it into the authoritative save owner.
2. **Port Wren's opening relationship consequences.** The Ironbond choices must update Wren's approval, trust, friendship, romantic bond and attraction according to the original source tables, independently of faction/NPC reputation.
3. **Port relationship progression and memory.** Unique personal conversations must not farm familiarity; trust changes only on authored reliability events; repeated event delivery/save-load must be idempotent.
4. **Port romance semantics and agreements.** Implement interpretation, explicit consent/choice gates, separate romantic/sexual exclusivity, breach handling, reconciliation and Wren's specific love/desire conflict.
5. **Port persistent non-companion relationships.** Important NPCs retain familiarity, trust, friendship and (only where authored) romantic/attraction dimensions while not spawned. The state model and source roster are now present; next integrate its reputation bridge and serialisation into the authoritative save owner.
6. **Expand campaign dialogue and quest data.** Migrate the source trees branch by branch, preserving conditions, consequences, repeat dialogue and world-state memory.
7. **Port companion quest chains and reactivity.** The nine later personal-quest chapters are now data-backed and have a generic journal/state controller. The earlier chapter quests they depend on, world-event triggers, XP application, UI choices and authored major-quest reactivity still need porting.
8. **Port schedules, banter and autonomous world agency.** Connect these to the agreed world event/location interfaces rather than scene-specific callbacks.

## Integration boundary

Until the map stream confirms its stable location IDs, spawn contract and world-event API:

- Keep campaign state independent of map scene nodes, hex coordinates and actor instances.
- Use stable character IDs (for example `garrick_holt`, `wren_talbot`) and stable quest/event keys.
- Keep new campaign logic in campaign-owned files. Do not modify map-owned world builders or shared movement/door files without agreement.
- Treat actor scenes as presentation of a persistent campaign character, not the owner of their identity or relationship state.


## Map and spatial audit boundary

The companion document [Campaign 2 map gap audit](campaign2_gap_audit.md) owns geography, terrain, routes, settlement/site footprints, building and interior layouts, entrances, physical-object placement and spatial traversal. This campaign status document owns the behaviour/content attached to those places: character identity and persistence, dialogue branches/effects, quest state, relationships, NPC schedules, encounter behaviour and companion/world agency.

A character or quest may appear in both documents only where the distinction is explicit: the map audit records its physical anchor or spatial dependency; this document records the actor/content/runtime behaviour. The two audits should not duplicate each other's outstanding-work lists.
