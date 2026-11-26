# Ara animation and posing audit

Baseline: `dev` at `6d44b26a` (2026-11-26). The original investigation was prepared against `252d4922`; the relevant actor and retargeter implementation was rechecked against current `dev` before this PR. Scope: current Ara animation architecture, clip availability, and safe integration of the separate procedural posing slice. This is an investigation only: no production code, animation assets, looping settings, face data, or posing tests are changed.

## Evidence tags and limits

- **[run]** Observed by running Godot 4.7.2 headless against a default import of the committed carrier GLB in a minimal project.
- **[data]** Read from committed GLB files by `tools/review/audit_ara_animations.py`.
- **[code]** Established by reading current GDScript; not executed.
- **[doc]** Stated in a repository document, not independently verified.
- **[unverified]** Inference or expectation.

The [run] checks were not performed in the running game scene. The current campaign code was rechecked: the combat controller orchestrates simulation and HUD but does not issue character animation calls; camp activity hints still fall back to the available carrier clips. The camp documentation describes a larger 259-clip Ara export, but those additional clips are not present in the committed carrier/player GLBs audited here.

---

## 1. Existing architecture

```
ara_person_benchmark.glb (hidden carrier: 69 bones, 77 clips) [data]
  AnimationPlayer -> carrier Skeleton3D ("AraAnimationSource")
                         | read every modifier pass
                         v
visible character GLB (own Skeleton3D + skin)
  AraSkeletonRetargeter (SkeletonModifier3D child of target skeleton)
  garments/hair skinned to target skeleton; equipment attached to hand/head bones
  AraCharacterActor exposes set_moving() and play_camp_activity()
```

The visible character keeps its own mesh, skin and skeleton. The carrier is the animation source; the retargeter transfers pose deltas to the visible rig by matching bone name and parent name.

| Concern | Current implementation |
|---|---|
| Carrier and assembly | `scripts/presentation/ara_character_actor.gd`: loads `ara_person_benchmark.glb`, hides carrier meshes, creates the retargeter under the visible character skeleton; requires at least 20 mapped bones or uses the native rig. |
| Retargeter | `scripts/presentation/ara_skeleton_retargeter.gd`: a `SkeletonModifier3D`; maps matching bone and parent names; writes pose transforms for every mapped bone on every modifier pass. Translation delta uses the target/source motion-scale ratio; scale is not transferred. |
| Locomotion | `set_moving()` selects a clip by token (`walk`/ `locomotion`/ `run`, or `idle`/ `stand`) and plays with a 0.12 s blend. |
| Camp routines | `play_camp_activity()` selects existing clips. Gather/fetch use pickup then carry; cook/repair/study use `Use / press`; train uses crouch/jump; socialise uses talk/idle; watch uses idle; sleep uses lie-down/sleep. These are approximations, not bespoke performances. |
| Exploration movement | `HexActorPresentation` moves the actor by tween and calls `set_moving()`. |
| Camp social exchanges | `CampPartyActivityDirector` temporarily plays the socialise hint for both speakers, then restores their assigned activity. |
| Dialogue | Dialogue UI changes the portrait expression; player-initiated world dialogue does not play a world-actor talk animation. |
| Portrait | `CharacterPortraitRenderer` duplicates the model into a SubViewport, uses the duplicate's own idle where available, adds sway/blink and static blend-shape expressions. The duplicate retargeter's behaviour was not tested. |
| Actor sources | Player bodies: `ara_player_female_body.glb` / `ara_player_male_body.glb`; companions under `art/characters/companions`; NPCs under `art/characters/hollowmere`. |
| Equipment | `BoneAttachment3D` sockets on hand/head bones; no per-weapon grip offsets or stance. |

No `AnimationTree`, blend space/state machine, root-motion system, weapon-specific stance, or runtime loop-mode assignment was found in the relevant scripts/scenes. The only project `SkeletonModifier3D` is the retargeter. The male-anatomy helper writes the unmapped `AnatomyRoot` bone; that exception is not a safe pattern for mapped bones. [code]

## 2. Animation inventory

[Data] The carrier has **77 clips**; each player body has **216** (the 77 plus **139** player-only clips); the three companions have **0** clips of their own. The player-only clips are unreachable through `AraCharacterActor`, which animates from the carrier whenever retargeting succeeds.

Only **9 carrier clips are referenced by gameplay code**: `Idle`, `Walk`, `Talk`, `Pick up (ground)`, `Carry idle`, `Use / press`, `Crouch idle`, `Sleep`, and `Lie down`. `Run` is not selected because the current token search finds `Walk` first. Some other carrier clips are exercised by review captures; most are not used.

The carrier inventory covers:
- everyday idle, walking/running, turns and jumps;
- sword/unarmed combat, chair sitting, lying down and sleep;
- talk, social gestures, object interaction, injury/death reactions;
- mounts/small boats and a large set of modern vehicle, firearm and aircraft clips that do not fit the medieval-fantasy setting.

No committed clip was found for eating, drinking, dressing/undressing, weapon draw/sheath, kneeling, ground/bench/log sitting, dedicated cooking/chopping/hammering, item handover, hugging, handshake, nodding, shrugging, stretching, yawning, praying, reading or writing. There are no committed axe, spear, mace, dagger, bow-draw/release or shield-combat performances. The clip named `Bow` is a courtesy bow, not archery. [data]

The camp documentation describes `squat`, `push_up`, `talk_gestures`, `look_around` and loop-suffixed exports, and refers to a 259-clip source list [doc]. Those names/exports are not present in the committed carrier GLB; the current actor code explicitly falls back to crouch, talk and idle for these activities. The "259" count has not been independently verified.

## 3. Technical limitations

| ID | Finding | Evidence |
|---|---|---|
| L1 | **Almost no clips loop.** 75/77 carrier clips import as `LOOP_NONE`; only Ride bicycle and Ride motorcycle loop. [run] Idle stops after 3.2 s and Walk after about 1.07 s. No code assigns loop mode; locomotion is only replayed on state changes. [run/code] |
| L2 | **Face animation is authored but not retargeted.** Carrier clips contain morph-weight channels; Godot import exposes 34 blend-shape tracks (blink, brows, jaw, mouth and visemes). The retargeter copies bones only. Talk contains blink/brow/viseme keys, but world characters do not receive them. [data/run/code] |
| L3 | **139 player-only clips are unreachable.** The actor uses the carrier's 77 clips, not the player body's own AnimationPlayer. [data/code] |
| L4 | **Retargeter owns every mapped bone each pass**, including fingers and face bones that a particular clip may not animate. A later modifier must own procedural writes. [run/code] |
| L5 | **No state machine.** Transitions use string matching and short blends; one-shot replay is polling/caller-driven. [code] |
| L6 | **Movement and stride are unsynchronised.** Hex movement is tween-driven; there is no root motion, velocity sync, turn-in-place or foot locking. [code/doc] |
| L7 | **Combat has no character animation wiring.** The current combat controller handles turns, attacks, reactions and HUD state, but does not call the actor animation API. [code] |
| L8 | **Player-initiated dialogue does not animate the world speaker.** Camp banter does use the socialise hint; the portrait is a separate duplicate. [code] |
| L9 | **Weapons have no grip data or weapon-specific idle.** They are attached to hand bones. [code] |
| L10 | **Visible proportions may diverge from bone lengths.** Body sliders can use blend shapes; where a height shape is absent, the actor can scale the model vertically. The size of any solver/mesh mismatch is unmeasured. [code/unverified] |
| L11 | **Portrait duplicate behaviour is unknown.** Duplicating the model also duplicates its retargeter node; whether it remains inert in the portrait copy was not tested. [code/unverified] |

---

## 4. Procedural posing integration

### 4.1 Modifier-order probe

`tools/review/ara_layering_probe/probe.gd` uses two real carrier instances, the real `AraSkeletonRetargeter`, a test override modifier and a recorder modifier. It pauses the source animation at a fixed pose to remove frame-timing uncertainty. The harness validates itself with an identical-rig case.

The supplied probe reports seven checks: the self-check plus the following cases. [run, as reported by the source investigation; rerun in this repository's CI before treating as confirmed here.]

| Case | Expected observation | Consequence |
|---|---|---|
| B: override after retargeter | Override wins | Procedural modifier must be a later child of the target skeleton. |
| C: override before retargeter | Retargeter overwrites it | Modifier order is decisive. |
| D: override influence 0.5 | Halfway quaternion slerp | `SkeletonModifier3D.influence` provides a blend weight. |
| E: ordinary bone write outside modifier pass | Retargeter overwrites it | Do not write mapped bones from `_process`, Tween or signal. |
| F: modifier disabled | Animation pose returns without residue | Layer can be faded/disabled. |

### 4.2 Proposed architecture

1. Add a `ProceduralPoseLayer` as a `SkeletonModifier3D` **after** `AraSkeletonRetargeter` under the visible character skeleton. It edits only bones it claims.
2. Write mapped bones only inside `_process_modification_with_delta`; ordinary writes are overwritten by the retargeter.
3. Use one layer per body region (right arm, left arm, later head) so each region has independent influence and ordering.
4. A per-actor coordinator owns goals and region claims. Disjoint goals can run together; conflicts need explicit priority/weighting. A two-handed prop is one goal claiming both arms.
5. Build the rig from each target character's own skeleton and bone lengths. Express targets as character-relative landmarks/offsets, not fixed world metres. Seed elbow swivel from the animated pose to avoid popping.
6. The authored animation continues on bones the procedural layer does not claim. Re-read moving targets each modifier pass.

### 4.3 Still to verify before building the layer

- The posing slice's `PoseApplier` uses global-pose setters/readback; its behaviour inside a modifier pass has not been proven. Compare with computing local rotations directly.
- Carrier AnimationPlayer versus target skeleton modifier timing in a live actor scene (possible one-frame lag).
- Whether BoneAttachment3D equipment sockets follow bones changed by a late modifier.
- Behaviour on real Ara proportions, including Aldric and the 66-bone `tavern_patron`.

---

## 5. Missing coverage, prioritised

**P0 — use what already exists:** fix looping for idle/walk/run/talk/sleep/carry/crouch/sit; retarget blink/brow/viseme tracks; play Talk during player dialogue; wire existing sword/hit/death clips into combat; decide whether player-only clips should be included in a canonical carrier export.

**P1 — procedural:** look at a speaker/player; touch face, point, place a hand on a table/door, hold/grip props, eat/drink, draw/sheath a weapon, hand over/receive items, nod/shake head, and improve camp hand paths over generic `Use / press`.

**P2 — authored:** kneel; sit on ground/bench/log; chop/hammer/dig and other rhythmic chores; axe/spear/mace/dagger/bow/shield combat sets; wounded idle/limp/kneeling; mood/idles; paired hug/handshake.

**P3 — low priority/out of setting:** dressing/undressing gestures, stairs/ramps, and modern vehicle/firearm/aircraft/parachute clips.

## 6. Proposed implementation sequence

0. Land the procedural posing core and validate it on real Ara skeletons.
1. Decide carrier policy: canonical export, loop naming and whether to merge the 139 player-only clips.
2. Make looping changes only after owner approval; test Idle and Walk still playing after 10 seconds.
3. Verify PoseApplier inside a modifier pass and test attachment/timing behaviour.
4. Build the procedural pose layer/coordinator without gameplay wiring; test nose-poke while Idle/Walk/Talk play, preserving unclaimed bones, across Wren, Aldric and tavern_patron.
5. Retarget face channels; test non-zero jaw/viseme and blink on a visible character mesh.
6. Wire dialogue/combat to existing clips.
7. Add procedural P1 interactions one at a time.
8. Request authored P2 clips with duration and loop requirements.

## 7. Verification status

**Reported by the source investigation:** Godot 4.7.2 headless import checks on the carrier; 77 clips, 90 tracks on each of seven inspected clips (1 Hips position, 55 rotation, 34 blend-shape); 75 non-looping/2 looping clips; Idle/Walk stop times; modifier-order/influence/plain-write/no-residue probe results.

**Verified from GLB data by the supplied script:** clip names/counts, skeleton counts, retargeter mapping by bone+parent name, player-only clip set.

**Rechecked against current dev code for this PR:** actor carrier path and retargeter behaviour; camp activity fallbacks; combat controller does not call actor animation APIs.

**Not verified:** behaviour in the running game scene; player-body clip payload quality; visual retargeting on non-Ara proportions; mesh-versus-bone mismatch; portrait duplicate behaviour; carrier/target timing; equipment sockets after a late modifier; the 259-clip documentation count; suitability of a built-in look-at modifier.

Reproduce the GLB inventory with `python3 tools/review/audit_ara_animations.py`. Run the Godot probe after importing the carrier, through `tools/ci/run_godot_checked.sh` because Godot script errors do not necessarily change the process exit code.
