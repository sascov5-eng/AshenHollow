# V22 — Hollow Knight–Style Combat Core Design

Date: 2026-09-01
Status: Proposed for implementation after user review
Baseline: V21 stable commit `c8f97734feb50f7ed2884b58260ec06f326ba425`

## 1. Goal

V22 replaces the current prototype combat feel with a skill-based 2D action combat loop inspired by the structural principles of Hollow Knight: spacing, fast readable melee, directional attacks, attacker recoil, enemy knockback, pogo, contact danger, stagger, readable boss patterns, safe punish opportunities created by positioning rather than arbitrary invulnerability, and a resource-driven Focus heal decision.

This is a mechanical inspiration target, not a content/art/audio clone. Ashen Hollow keeps its own characters, visuals, enemy designs, names, timing values, encounters, and progression systems.

The primary success criterion is that combat stops feeling like `stand inside enemy -> trade HP` and instead becomes `read -> position -> strike -> recoil/reset spacing -> choose next action`.

## 2. Non-negotiable V21 baseline constraints

The following confirmed systems must remain stable unless a V22 change explicitly requires a narrow extension:

- landscape presentation;
- existing kinematic player controller;
- no `SKPhysicsBody` on player;
- gravity `-1700`;
- jump `610`;
- jump release `285`;
- run speed `315`;
- ground acceleration `1900`;
- air acceleration `1050`;
- ground deceleration `2400`;
- max fall speed `-900`;
- camera zoom `1.55`;
- V21 six-room architecture;
- multi-enemy support;
- Grunt / Runner / Heavy / Ranged / Ash Warden;
- combat-gated room exits;
- V19 death -> fade -> full level restart -> 5/5 HP;
- PlayerHealth i-frames remain authoritative for accepted damage.

V22 may extend input/combat state in `GameScene`, but must not replace the stable movement/collision solver.

## 3. Root problem in V21

The current boss contract has stages `idle / telegraph / committed / recovery`, but `BossController.applyPlayerHit()` accepts damage in every living state. Therefore `recovery` is only presentation text and does not create a mechanically distinct combat opportunity.

At the same time, simply making Ash Warden invulnerable outside recovery would move the design in the wrong direction. The intended Hollow Knight–style model is:

- bosses are usually damageable whenever the player's weapon can genuinely reach them;
- attack states create danger, not arbitrary immunity;
- recovery creates a safer punish opportunity, not the only legal damage window;
- explicit guard/parry states may block damage, but must be visually readable and exceptional;
- high-skill players can often attack during telegraphs or attacks if their positioning permits it.

## 4. Core combat loop

The V22 loop is:

`READ -> POSITION -> ATTACK -> RECOIL / SEPARATION -> REASSESS -> ATTACK / JUMP / POGO / FOCUS`

The game must reward correct spacing and timing rather than holding ATTACK in overlap range.

### 4.1 Player melee properties

Player melee remains fast and responsive.

Initial target values for tuning:

- attack duration: approximately `0.22 s`;
- damage window remains a subset of the animation;
- attack cooldown target: approximately `0.30–0.34 s`;
- damage: `1` base melee damage;
- per-swing de-duplication remains mandatory per target;
- movement is not globally frozen by attacking;
- facing is locked at attack start for horizontal attack consistency.

Exact timing can be tuned after device testing, but tests should encode the chosen values once implementation begins.

## 5. Directional melee

V22 introduces three melee directions:

1. horizontal attack;
2. upward attack;
3. downward aerial attack.

### 5.1 Horizontal attack

Default ATTACK action.

Hitbox extends in facing direction.

On accepted hit:

- target takes damage;
- player receives attacker recoil away from target;
- normal enemy receives archetype-specific knockback;
- hit feedback is triggered.

### 5.2 Upward attack

Hitbox extends above the player with limited horizontal overlap.

Purpose:

- hit airborne or elevated enemies;
- attack enemies while staying below some attack zones;
- create a vertical combat option without changing player movement physics.

Upward attack does not launch the player.

### 5.3 Downward aerial attack / pogo

Available only while airborne.

Hitbox extends below the player.

If the hitbox connects with a valid enemy/hazard target:

- target takes normal melee damage unless protected by an explicit block rule;
- player receives an immediate upward pogo impulse;
- the pogo impulse is applied through the existing kinematic velocity path, not SpriteKit physics;
- normal enemy hit reaction still applies where appropriate;
- one swing cannot pogo repeatedly from the same target through frame overlap.

Initial pogo vertical velocity target: around `430–500`, to be tuned below the full jump impulse and verified on device.

Pogo must preserve horizontal player velocity unless an explicit recoil component modifies it.

## 6. Mobile input design

V22 must add directional attack intent without cluttering the screen with separate UP-ATTACK and DOWN-ATTACK buttons.

Proposed touch contract:

- tap ATTACK -> horizontal attack;
- drag/flick upward on the ATTACK control before activation threshold -> upward attack;
- while airborne, drag/flick downward on ATTACK -> downward attack / pogo;
- short ambiguous movement around the ATTACK button defaults to horizontal attack;
- JUMP and movement remain independently multi-touch compatible.

The ATTACK gesture only selects attack direction; it must not modify movement input.

Thresholds must be forgiving enough for phone use and tested on device.

A small temporary directional indicator may be used during V22 acceptance testing, then removed or polished later.

## 7. Attacker recoil and separation

This is a core V22 mechanic.

When the player lands a valid horizontal/upward melee hit, the player receives a short horizontal recoil away from the target.

Goals:

- prevent automatic body overlap after a successful hit;
- create a natural rhythm between strikes;
- allow the player to re-engage intentionally;
- reduce guaranteed retaliation from ordinary enemies;
- preserve control rather than create a long stun.

Initial target:

- player recoil displacement/velocity equivalent: roughly `18–28 px` horizontal separation per successful close hit;
- recoil is short and should not cancel vertical velocity;
- recoil cannot push player outside active room bounds;
- recoil must not bypass platform collision.

Implementation should use a narrow kinematic combat impulse path, not direct teleporting through geometry.

## 8. Enemy knockback and hit reaction

Normal enemies keep the V21 hit-stun + knockback concept, but it becomes coordinated with player recoil.

Per-archetype target behavior:

- Grunt: medium knockback, medium hit-stun;
- Runner: strong knockback, slightly longer hit-stun;
- Heavy: low knockback, short hit-stun;
- Ranged: strong knockback, medium hit-stun;
- Boss: negligible positional knockback; no ordinary stun on every hit.

Successful melee hit on a normal enemy:

`damage -> cancel active normal-enemy damage window -> hit-stun -> enemy knockback -> player recoil`

This rule does not apply to already committed boss attacks unless the boss is in an explicit stagger state.

## 9. Contact damage

Enemy bodies remain dangerous where the archetype/encounter requires it.

Contact danger is important because spacing must matter, but V22 must avoid unfair damage chains.

Rules:

- PlayerHealth i-frames apply to contact damage exactly as to attack/projectile damage.
- A successful player strike should generally create enough separation that the player is not guaranteed to eat contact damage on the same exchange.
- Contact damage must use the central `PlayerDamageInbox` rather than bypassing it.
- Dead, staggered, or explicitly harmless states cannot generate contact damage.
- Boss contact damage must be state-aware: e.g. charge body is dangerous; idle/recovery body may use a smaller or disabled contact hurt source depending on acceptance tuning.

## 10. Boss philosophy

Ash Warden is rebuilt around readable danger and positional punish opportunities.

### 10.1 Boss damageability

Default rule:

- idle: damageable;
- telegraph: damageable;
- committed attack: damageable if weapon reaches the boss safely;
- recovery: damageable and safer to punish;
- stagger: damageable and safest to punish;
- explicit parry/guard: blocked;
- defeated: no further damage.

There is no generic `bossCanTakeDamageOnlyDuringRecovery` rule.

### 10.2 Recovery

Recovery is a tactical opening, not a vulnerability switch.

During recovery:

- boss stops dealing attack damage from the completed pattern;
- movement is reduced or stopped;
- core/visual state clearly communicates safety;
- player can choose DPS or Focus heal;
- Phase II shortens recovery but never removes every safe opportunity.

Initial recovery targets:

- Slash Phase I: ~`0.70–0.80 s`;
- Charge Phase I: ~`0.90–1.05 s`;
- Volley Phase I: ~`1.00–1.15 s`;
- Phase II multipliers approximately `0.70–0.78` of Phase I.

These are tuning targets, not immutable Hollow Knight values.

## 11. Ash Warden attack patterns

V22 keeps the three existing pattern identities but rewrites their combat contracts.

### 11.1 Slash

Stages:

`telegraph -> active slash -> recovery`

Properties:

- clear facing tell;
- active hitbox exists only for a short committed window;
- player can jump over, backstep through spacing, or potentially hit from a safe side/vertical angle;
- boss remains damageable;
- recovery is short but reliable.

### 11.2 Charge

Stages:

`telegraph -> committed horizontal charge -> deceleration/recovery`

Properties:

- charge direction locks at commit;
- charge body/dedicated hitbox deals damage once per commit per i-frame rules;
- boss should not instantly reverse mid-charge to track player;
- jumping/pogoing over the charge is a valid high-skill response;
- charge ends in a readable recovery.

### 11.3 Ash Volley

Stages:

`telegraph -> projectile release -> recovery`

Properties:

- projectiles use central damage inbox;
- projectile disappears on player contact even if i-frames reject HP loss;
- projectile arrangement is readable and dodgeable;
- Phase II increases pressure through pattern density/speed, not by removing all recovery.

## 12. Boss stagger system

Ash Warden gains a hit-count stagger meter independent from HP.

Purpose:

- reward sustained successful offense;
- create a predictable large opening;
- support the Focus-heal decision;
- avoid making every individual hit interrupt the boss.

Initial target:

- Phase I stagger threshold: `6` accepted player hits;
- Phase II threshold: `7` accepted player hits;
- stagger duration target: `1.35–1.55 s`;
- entering Phase II resets or explicitly re-bases stagger progress to avoid accidental immediate double-stagger;
- hits during stagger deal damage but do not instantly end stagger;
- after stagger ends, hit counter resets.

Boss committed attacks are not cancelled by normal player hits. Stagger may interrupt the boss only when the threshold is reached, by explicit rule.

## 13. Explicit guard/parry state

V22 may add one short readable Ash Warden guard/parry pattern if implementation scope remains controlled.

Rules if included:

- visually unmistakable guard state;
- melee hit during guard returns `BLOCKED`;
- boss HP does not change;
- a small player recoil may occur;
- guard is an explicit pattern/state, never a hidden immunity flag;
- parry cannot chain continuously without an opening.

This feature is secondary to the main combat loop. If it risks destabilizing core V22, it is deferred to V23 rather than partially implemented.

## 14. Essence resource and Focus healing

V22 adds a combat resource inspired by the risk/reward role of Soul but using Ashen Hollow's own naming and values.

Working name: `ESSENCE`.

### 14.1 Essence gain

Initial economy target:

- successful melee hit on an enemy/boss grants Essence;
- approximately three normal successful hits provide enough Essence for one heal;
- duplicate hit frames from the same swing do not generate duplicate Essence;
- hits on blocked/parried targets do not grant Essence;
- hitting dead targets grants nothing.

Suggested initial numbers:

- Essence capacity: `100`;
- gain per accepted melee hit: `34`;
- Focus heal cost: `100`.

This gives one heal after three accepted hits while leaving clean integer bookkeeping.

### 14.2 Focus heal

Add a dedicated `FOCUS` control near the existing right-side action controls.

Contract:

- Focus must be held continuously;
- player cannot start Focus without enough Essence and missing HP;
- initial channel duration target: `0.95–1.10 s`;
- successful completion restores `1 HP` and consumes the configured Essence cost;
- if player takes accepted damage during channel, Focus cancels and does not heal;
- movement is strongly reduced or disabled during Focus;
- jump/attack cancel Focus;
- interrupted Focus should not consume the full cost unless design testing proves partial-cost behavior is better;
- death overrides Focus immediately.

Focus creates a tactical decision during boss recovery/stagger instead of every opening being pure DPS.

## 15. Hit-stop and impact feedback

V22 adds mechanical hit feedback on accepted melee hits.

Required:

- very short hit-stop/freeze impression;
- target flash;
- slash impact visual;
- player recoil;
- target knockback where applicable;
- small camera impulse/shake;
- stronger feedback on enemy death/boss phase/stagger.

Hit-stop must not globally corrupt timer-based systems.

Preferred architecture:

- do not pause the entire SKScene for normal hit-stop;
- use a combat-specific short presentation/runtime freeze or local timescale/action gating;
- player input buffering should remain predictable;
- projectile and boss timers must not accidentally skip damage windows after hit-stop.

Initial hit-stop target: roughly `35–55 ms` for standard melee, slightly stronger for heavy/boss milestone impacts.

## 16. Damage authority and event flow

V22 should reduce combat coupling by using explicit accepted-hit events/contracts.

Recommended flow:

Player attack intent
-> AttackController directional attack state
-> runtime computes attack hitbox
-> target combat model validates per-swing hit
-> accepted hit event
-> target HP / stagger / hit reaction
-> player recoil / pogo
-> Essence gain
-> impact presentation

Enemy/boss attack
-> active damage source intersects player
-> PlayerDamageInbox
-> PlayerHealth validates i-frames/dedup
-> accepted player damage event
-> HP update / blink / Focus interruption / death pipeline

No visual node alpha alone should be the authoritative source of combat state when a pure model can represent it.

## 17. Architecture changes

Expected new or revised pure components:

- directional attack model / attack direction enum;
- player combat recoil/pogo result model;
- Essence/Focus controller;
- boss stagger state integrated into `BossController` or a dedicated model;
- explicit boss damage response (`accepted`, `blocked`, `defeated`, possibly `staggered`);
- accepted-hit event data shared by runtime presentation.

Expected SpriteKit integration areas:

- `GameScene.swift`: narrow input/attack-direction hooks and safe kinematic combat impulse application only;
- `AttackController.swift`: directional attack state and timing contract;
- `MultiEnemyRuntimeInstaller.swift`: accepted-hit event + player recoil/pogo + Essence gain;
- `BossController.swift`: stagger and explicit state-aware damage response;
- `BossRuntimeInstaller.swift`: rewritten boss pattern/hitbox/presentation loop;
- `PlayerDamageInstaller.swift`: emit accepted-damage signal for Focus interruption;
- `GameView.swift` / runtime bootstrap only if needed for shared combat context;
- new pure `EssenceFocusController.swift` (name may vary);
- new tests for each pure contract.

The existing kinematic collision movement functions are not to be replaced.

## 18. Input and control safety

V22 must preserve simultaneous inputs:

- left/right + jump;
- left/right + attack;
- jump + attack;
- airborne down-attack;
- attack direction gesture must not steal unrelated touches;
- FOCUS uses its own touch identity and cancels correctly on touch end/cancel.

The control layout should remain readable in landscape on current target iPhone dimensions.

## 19. Boss HP tuning

Because V22 allows damage during more boss states and adds stagger/Focus decisions, final Ash Warden HP should be tuned after the mechanical loop works.

Do not mechanically reduce HP before measuring device combat duration.

Starting acceptance build may keep `20 HP` so the new combat loop can be evaluated independently. If the fight is too long, HP is then tuned in a bounded follow-up based on observed number of attack cycles and player DPS.

This supersedes the earlier speculative recommendation to immediately lower boss HP to 14.

## 20. TDD / verification requirements

V22 must use RED -> GREEN tests for pure combat contracts before SpriteKit integration.

Minimum tests:

### Directional attack
- horizontal attack produces horizontal direction;
- up attack produces upward hitbox intent;
- down attack only allowed in air;
- same swing ID cannot hit same target twice;
- facing locks correctly for horizontal swing.

### Recoil / pogo
- horizontal accepted hit creates recoil away from target;
- recoil never zeros vertical velocity;
- downward accepted hit produces upward pogo impulse;
- same down swing cannot pogo multiple times from same target.

### Essence / Focus
- accepted hit grants Essence exactly once;
- blocked hit grants none;
- insufficient Essence cannot start Focus;
- full channel heals 1 HP and consumes cost;
- accepted player damage cancels Focus;
- attack/jump cancels Focus;
- Focus cannot heal above max HP.

### Boss
- normal boss states accept damage;
- explicit guard returns blocked;
- recovery is safe-state metadata, not the only damageable state;
- accepted hits increment stagger counter;
- threshold enters stagger;
- stagger duration and reset work;
- Phase II threshold/profile changes correctly;
- committed attack is not cancelled by ordinary hit below stagger threshold;
- reaching stagger threshold may explicitly interrupt according to contract.

### Regression
All existing V21 tests remain green unless intentionally updated to the new combat contract.

Final acceptance requires:

1. full GitHub Actions suite success on exact final SHA;
2. arm64 iOS compile success;
3. unsigned IPA package/upload success;
4. artifact `workflow_run.head_sha` equals final SHA;
5. downloaded IPA passes ZIP integrity check;
6. user device test before V22 is called stable.

## 21. Device acceptance checklist

User should specifically test:

- horizontal melee no longer causes guaranteed body-trade after every hit;
- player recoil feels short and controllable;
- Grunt/Runner/Heavy/Ranged reactions still feel distinct;
- upward attack is reliable;
- downward pogo works on enemies and does not break jump physics;
- several consecutive pogo attempts cannot double-trigger from one swing;
- Ash Warden can be damaged during telegraph/attack when safely reached;
- recovery clearly feels safer without being an artificial damage switch;
- boss stagger is readable and useful;
- Phase II remains aggressive but fair;
- FOCUS can be used during genuine openings;
- taking damage cancels FOCUS;
- Essence gain does not duplicate per frame;
- run/jump/collision/camera remain stable;
- death/respawn still returns to Room 1 with 5/5 HP;
- all six rooms remain traversable.

## 22. Deferred beyond V22

Not required for V22 acceptance:

- spells using Essence;
- charm/equipment equivalents;
- complex aerial enemies designed around pogo;
- wall-jump/dash mechanics;
- multiple boss phases beyond current two-phase Ash Warden;
- advanced parry system for player;
- final animation/art/audio pass;
- controller support;
- save/progression changes.

## 23. Definition of done

V22 is complete as an acceptance build when:

- combat uses directional attacks;
- accepted melee hits create controlled separation;
- pogo works through the kinematic controller;
- normal enemies retain distinct hit reactions;
- boss is generally damageable and no longer relies on fake recovery-only vulnerability;
- boss attacks have explicit telegraph/active/recovery semantics;
- stagger creates a real large opening;
- Essence/Focus adds a heal-vs-DPS decision;
- hit-stop/impact feedback makes accepted hits mechanically legible;
- all CI/build/artifact checks pass;
- real-device testing confirms the loop feels materially closer to the requested Hollow Knight–style combat philosophy.
