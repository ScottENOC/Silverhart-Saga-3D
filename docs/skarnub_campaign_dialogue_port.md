# Chief Skarnub dialogue and trust port

## Source
- `Hex-crpg/campaign2Dialogue.js`: `chief_skarnub`, `offerGoblinFavor`.
- `Hex-crpg/campaign2World.js`: `buildGoblinCamp`, including the 60-gold gift requirement and the original one-time `giftedIn` unlock.

## Implemented in this pass
- Persistent relationship profile for Chief Skarnub, using the existing non-companion relationship store and save/load bridge.
- Source-authored opening greeting and the initial bargain, read-the-chief, threat and leave choices.
- The source's 60-gold gift gate, implemented as a one-time keyed relationship event. It deducts no inventory itself: the runtime caller receives the validated remaining-gold result and must apply the transaction to the player's CharacterState.
- Gift raises persistent trust by 20 and familiarity by 2; these are the initial relationship-system tuning values for the source's boolean `giftedIn` milestone. The keyed event prevents paying repeatedly to farm trust.
- Gift unlocks the source-authored "You don't have to leave. Stay." alliance offer.
- CampaignJournal registration/start for `goblin_threat` when the player opens favour negotiations.
- Source-authored favour menu, including the Hollowmere raid option only at goblin standing 25 or higher.
- Initial post-alliance dialogue for the mine raid and scout-note / Northwatch follow-up.
- `resolve_favour` now applies the source-authored kingdom/goblin reputation changes for scouting, stealing supplies and raiding Emberlode; each favour is keyed in the quest journal to prevent repeat farming. It returns explicit region, reward and Aldric-attitude effect descriptors.
- `resolve_threat` now applies the mutually exclusive diplomacy, permanent-alliance, assault, stealth-succession and betrayal reputation outcomes, completes `goblin_threat`, and returns the source-authored region/XP/Aldric consequence descriptors. Diplomacy requires goblin standing 40; alliance requires the recorded 60-gold gift.

## Remaining work
- Wire the content into the future Skarn-tooth camp interaction and apply the gift transaction to player gold.
- Apply the returned region-stat, XP, gold, Aldric rescue/attitude/departure effect descriptors in the campaign runtime; the content layer deliberately does not mutate scene-owned or CharacterState resources.
- Connect Nix, guards, Grondle, Ser Aldric and the scout note to the resulting campaign state.
- Extend the post-Northwatch war-mission branch after its required siege systems are available.

This is a content/state layer, not a claim that the Skarn-tooth camp is already a playable 3D location.
