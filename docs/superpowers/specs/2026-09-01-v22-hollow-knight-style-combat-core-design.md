# V22 — Hollow Knight–Style Combat Core Design

Date: 2026-09-01  
Status: Proposed for implementation after user review  
Baseline: V21 stable commit `c8f97734feb50f7ed2884b58260ec06f326ba425`

## 1. Goal

V22 replaces the prototype combat feel with a skill-based 2D action loop inspired by the structural principles of Hollow Knight: spacing, fast readable melee, directional attacks, attacker recoil, enemy knockback, pogo, contact danger, stagger, readable boss patterns, safe punish opportunities created by positioning, and a resource-driven Focus heal decision.

This is a mechanical inspiration target, not a content/art/audio clone. Ashen Hollow keeps its own characters, visuals, names, enemy designs, encounters, timings, progression, and presentation.

Primary success criterion:

`stand inside enemy -> trade HP`

must become:

`read -> position -> strike -> recoil/reset spacing -> choose next action`.

## 2. V21 baseline constraints

The following confirmed systems remain stable unless V22 explicitly adds a narrow combat hook:

- landscape only;
- kinematic player controller remains authoritative;
- no `SKPhysicsBody` on player;
- gravity `-1700`;
- jump `610`;
- jump release `285`;
- run `315`;
- ground acceleration `1900`;
- air acceleration `1050`;
- ground deceleration `2400`;
- max fall `-900`;
- camera zoom `1.55`;
- six-room V21 level architecture;
- multi-enemy runtime;
- Grunt / Runner / Heavy / Ranged / Ash Warden;
- combat-gated exits;
- V19 death -> fade -> fresh level restart -> 5/5 HP;
- PlayerHealth i-frames remain authoritative for accepted damage.

The existing movement/collision solver is not replaced.

## 3. Root problem in V21

The current Ash Warden state machine already has `idle / telegraph / committed / recovery`, but `BossController.applyPlayerHit()` accepts damage in every living state. Therefore recovery is currently presentation-only.

However, making the boss invulnerable outside recovery would also be wrong for the requested combat style.

V22 rule:

- bosses are usually damageable whenever the player's weapon genuinely reaches them;
- telegraph/attack states create danger, not generic immunity;
- recovery is a safer punish opportunity, not the only legal damage window;
- explicit guard/parry may block damage, but must be exceptional and visually obvious;
- skilled players may damage the boss during telegraph/committed states if their positioning is safe.

## 4. Core combat loop

`READ -> POSITION -> ATTACK -> RECOIL / SEPARATION -> REASSESS -> ATTACK / JUMP / POGO / FOCUS`

Combat must reward spacing and timing rather than ATTACK spam while bodies overlap.

## 5. Directional melee

V22 introduces three attack directions:

- horizontal;
- upward;
- downward aerial.

Base melee remains `1` damage and preserves per-swing target deduplication.

Initial timing targets:

- attack duration around `0.22 s`;
- cooldown around `0.30–0.34 s`;
- damage window remains shorter than full animation;
- movement is not globally frozen by attacking;
- horizontal facing locks at attack start.

### 5.1 Horizontal

Default attack. Hitbox extends in facing direction.

Accepted hit:

`damage -> target reaction -> player recoil -> Essence gain -> impact feedback`.

### 5.2 Upward

Hitbox extends above player with limited horizontal overlap.

Purpose:

- aerial/elevated targets;
- attack from below;
- vertical combat without changing movement physics.

No upward launch is applied to player.

### 5.3 Downward aerial / pogo

Only available while airborne.

Hitbox extends below player.

Accepted hit:

- target takes normal melee damage unless explicitly blocked;
- player receives a kinematic upward pogo impulse;
- horizontal velocity is preserved unless a separate recoil component modifies it;
- same swing cannot pogo repeatedly from the same target through frame overlap.

Initial pogo target: vertical velocity around `430–500`, tuned below full jump impulse on device.

## 6. Mobile attack-direction input

The screen should not gain separate UP-ATTACK and DOWN-ATTACK buttons.

V22 changes the ATTACK control into a directional touch control with a very short intent-resolution window:

- normal tap / no meaningful vertical displacement -> horizontal;
- upward displacement past threshold -> upward attack;
- downward displacement past threshold while airborne -> down attack/pogo;
- downward intent while grounded falls back to horizontal;
- ambiguous movement defaults to horizontal;
- movement/jump touches remain independent and multi-touch compatible.

To preserve responsiveness, attack intent resolution must be short and deterministic. Initial target:

- vertical displacement threshold about `22–28 pt`;
- maximum intent-resolution delay about `45–60 ms` before defaulting to horizontal.

This is a starting mobile UX contract, not final tuning. A temporary direction indicator may be used in acceptance builds.

## 7. Player combat impulse interface

V22 requires recoil and pogo, but `GameScene.velocity` is currently private and must remain under the kinematic controller's authority.

Therefore V22 adds a narrow combat-only interface on GameScene rather than moving or duplicating movement state.

Conceptual API:

- apply horizontal combat recoil away from source;
- apply upward pogo impulse;
- optionally expose grounded/airborne state required by attack selection.

Requirements:

- recoil/pogo update the existing kinematic velocity/state;
- never create `SKPhysicsBody`;
- never directly teleport through platforms;
- recoil never zeroes vertical velocity;
- pogo preserves horizontal velocity;
- room/world bounds and collision logic remain authoritative on subsequent integration.

Initial player horizontal recoil should produce roughly `18–28 px` of separation in normal close hits without feeling like a long stun.

## 8. Normal enemy reaction

V21 hit-stun/knockback remains, coordinated with player recoil.

- Grunt: medium knockback / medium hit-stun;
- Runner: strong knockback / slightly longer hit-stun;
- Heavy: low knockback / short hit-stun;
- Ranged: strong knockback / medium hit-stun;
- Boss: negligible positional knockback / no ordinary per-hit stun.

Normal enemy accepted hit:

`damage -> cancel active normal-enemy damage window -> hit-stun -> enemy knockback -> player recoil`.

Boss committed attacks are not cancelled by ordinary hits unless an explicit stagger threshold is reached.

## 9. Contact damage

Bodies remain dangerous where the archetype/state requires it, because spacing must matter.

Rules:

- all contact damage goes through `PlayerDamageInbox`;
- PlayerHealth i-frames apply normally;
- successful player strikes should generally create enough separation to prevent guaranteed same-exchange body damage;
- dead/staggered/harmless states cannot deal contact damage;
- boss contact danger is state-aware: charge body is dangerous; idle/recovery may use reduced or disabled body danger depending on device tuning.

## 10. Ash Warden damageability

Default:

- idle -> damageable;
- telegraph -> damageable;
- committed attack -> damageable if safely reachable;
- recovery -> damageable and safer to punish;
- stagger -> damageable and safest to punish;
- explicit guard/parry -> blocked;
- defeated -> no damage.

There is no global `damage only during recovery` flag.

## 11. Recovery semantics

Recovery is a tactical opening, not a vulnerability switch.

During recovery:

- previous attack's damage source is off;
- boss movement is reduced/stopped;
- visual state clearly communicates an opening;
- player may choose DPS or Focus;
- Phase II shortens recovery but never removes every safe opportunity.

Initial targets:

- Slash P1: `0.70–0.80 s`;
- Charge P1: `0.90–1.05 s`;
- Volley P1: `1.00–1.15 s`;
- Phase II around `70–78%` of Phase I recovery duration.

These are Ashen Hollow tuning values, not copied constants.

## 12. Ash Warden patterns

### Slash

`telegraph -> active slash -> recovery`

- clear facing tell;
- short active damage window;
- jump/spacing/vertical attack can create counters;
- boss remains damageable throughout;
- recovery is short but reliable.

### Charge

`telegraph -> locked horizontal charge -> deceleration/recovery`

- direction locks at commit;
- no instant mid-charge retarget;
- dedicated charge/body damage source;
- jumping or pogoing over charge is valid;
- readable recovery follows.

### Ash Volley

`telegraph -> projectile release -> recovery`

- projectiles use central damage inbox;
- projectile disappears on player contact even if i-frames reject HP loss;
- pattern is readable/dodgeable;
- Phase II adds pressure through density/speed, not removal of recovery.

## 13. Boss stagger

Ash Warden gains a hit-count stagger meter independent from HP.

Initial targets:

- Phase I threshold: `6` accepted hits;
- Phase II threshold: `7` accepted hits;
- stagger duration: `1.35–1.55 s`;
- entering Phase II resets/rebases stagger progress so phase transition does not accidentally trigger an immediate second stagger;
- hits during stagger still deal damage but do not end stagger immediately;
- after stagger, counter resets.

Normal accepted hits below threshold do not cancel committed attacks.

Reaching stagger threshold may explicitly interrupt the current boss action.

## 14. Explicit guard/parry

Optional within V22 only if core implementation remains stable.

If included:

- unmistakable visual guard;
- melee returns `BLOCKED`;
- no HP loss;
- no Essence gain;
- small player recoil may occur;
- guard cannot chain continuously.

If this risks V22 core stability, it is deferred rather than partially implemented.

## 15. Essence and Focus healing

Working resource name: `ESSENCE`.

Initial economy:

- max Essence: `100`;
- accepted melee hit: `+34`;
- heal cost: `100`;
- blocked/dead/duplicate hits grant `0`.

This yields one heal after three accepted hits.

### Focus

A dedicated `FOCUS` button is added near the right-side action controls.

Rules:

- hold continuously to channel;
- requires missing HP and enough Essence;
- target channel around `0.95–1.10 s`;
- successful completion heals `1 HP` and consumes cost;
- accepted incoming damage cancels Focus;
- attack/jump cancel Focus;
- movement is strongly reduced or disabled during Focus;
- interrupted Focus does not consume full cost in V22;
- death cancels Focus immediately.

## 16. Shared PlayerHealth authority

V21 currently keeps `PlayerHealth` privately inside `PlayerDamageInstaller`. That is incompatible with Focus healing because two independent health copies would be incorrect.

V22 therefore moves the authoritative `PlayerHealth` instance into the shared runtime context (or an equivalent single owner) used by both damage and Focus systems.

Required authority rules:

- exactly one PlayerHealth instance per live scene;
- PlayerDamageInstaller reads/writes that instance;
- Focus completion heals that same instance;
- HUD reads that same instance;
- accepted-damage notification from that authority interrupts Focus;
- respawn creates a fresh context with 5/5 HP and empty/reset combat state according to V22 rules.

No duplicate shadow HP state is allowed.

## 17. Essence/Focus pure controller

Add a pure model responsible for:

- Essence amount/capacity;
- per-hit gain;
- Focus eligibility;
- channel state/time;
- cancel reasons;
- cost consumption only on completion;
- heal-completion event.

The controller does not directly mutate SpriteKit nodes.

## 18. Hit-stop and impact feedback

Accepted melee hits require:

- short hit-stop impression;
- target flash;
- slash impact visual;
- player recoil;
- enemy knockback where applicable;
- small camera impulse;
- stronger feedback for death/stagger/phase milestones.

Initial standard hit-stop target: `35–55 ms`.

Do not pause the entire SKScene for ordinary hits if that would corrupt attack/projectile/timer windows. Prefer combat-local gating/presentation freeze with deterministic timer behavior.

## 19. Damage/event flow

Player:

`attack intent -> directional AttackController state -> computed hitbox -> target model validates swing -> accepted/blocked result -> HP/stagger/reaction -> recoil/pogo -> Essence -> presentation`.

Enemy/boss:

`active source intersects player -> PlayerDamageInbox -> authoritative PlayerHealth validates -> accepted damage event -> HP/HUD/blink -> Focus interruption -> death pipeline`.

Visual alpha is not authoritative combat state when a pure state can represent it.

## 20. Expected code architecture

Likely revised/new pure components:

- `AttackDirection` / directional attack contract;
- combat impulse result model;
- `EssenceFocusController`;
- boss stagger logic;
- explicit boss hit result: accepted / blocked / defeated / staggered;
- accepted damage event/sequence token if needed.

Likely SpriteKit integration:

- `GameScene.swift`: narrow directional-input and kinematic combat-impulse hooks only;
- `AttackController.swift`: directional attack state/timing;
- `V21RuntimeContext.swift` or V22 successor: single PlayerHealth + Essence/Focus authority;
- `MultiEnemyRuntimeInstaller.swift`: directional hurtboxes, recoil/pogo, Essence gain;
- `BossController.swift`: stagger + explicit hit result;
- `BossRuntimeInstaller.swift`: rewritten pattern/hitbox/recovery/stagger loop;
- `PlayerDamageInstaller.swift`: use shared health and emit accepted-damage interruption signal;
- HUD/bootstrap files only as required.

The movement collision functions remain intact.

## 21. Input safety

Must preserve:

- left/right + jump;
- left/right + attack;
- jump + attack;
- airborne down attack;
- attack touch must not steal movement/jump touches;
- Focus touch has independent identity and cancels correctly on touch end/cancel.

## 22. Boss HP tuning

Do not reduce Ash Warden HP pre-emptively.

V22 acceptance build may keep `20 HP` so combat mechanics can be evaluated independently. After real-device testing, HP is tuned based on observed fight duration and attack cycles.

This supersedes the earlier speculative `14 HP` recommendation.

## 23. TDD requirements

RED -> GREEN pure tests before SpriteKit integration.

### Directional attack

- horizontal direction;
- up direction;
- down only while airborne;
- facing locks correctly;
- same swing cannot damage same target twice.

### Recoil/pogo

- recoil points away from target;
- recoil does not zero vertical velocity;
- down hit produces upward pogo impulse;
- same down swing cannot pogo repeatedly from same target.

### Essence/Focus

- accepted hit grants exactly once;
- blocked hit grants none;
- insufficient Essence cannot Focus;
- completed channel requests exactly 1 HP heal and consumes cost;
- accepted incoming damage cancels;
- attack/jump cancel;
- max HP cannot be exceeded.

### Boss

- normal states accept damage;
- explicit guard blocks;
- recovery is metadata/opening, not sole damage state;
- hits increment stagger;
- threshold enters stagger;
- stagger resets correctly;
- Phase II threshold/profile updates;
- committed attack survives normal hit below threshold;
- threshold hit may explicitly interrupt into stagger.

### Shared health

- damage and Focus operate on same health authority;
- damage during Focus cancels before completion;
- respawn creates fresh 5/5 authority.

### Regression

All existing V21 tests remain green unless intentionally updated to match the new contract.

## 24. Device acceptance checklist

- horizontal hits no longer force guaranteed body-trade;
- recoil is short/control-preserving;
- Grunt/Runner/Heavy/Ranged remain distinct;
- up attack is reliable;
- down attack/pogo is reliable;
- one swing cannot multi-pogo from frame overlap;
- Ash Warden can be hit during telegraph/attack when safely reached;
- recovery feels safer without being an immunity switch;
- boss stagger is readable/useful;
- Phase II is aggressive but fair;
- Focus works in genuine openings;
- accepted damage cancels Focus;
- Essence cannot duplicate per frame;
- run/jump/collision/camera remain stable;
- death/respawn returns to Room 1 at 5/5;
- all six rooms remain traversable.

## 25. Deferred beyond V22

- offensive Essence spells;
- charm/equipment equivalent;
- advanced player parry;
- dash/wall-jump;
- final art/audio pass;
- save/progression changes;
- controller support;
- new boss beyond Ash Warden.

## 26. Definition of done

V22 acceptance build is complete when:

- directional melee works;
- accepted melee creates controlled separation;
- pogo works through existing kinematic velocity;
- normal enemies retain distinct reactions;
- boss is generally damageable and uses readable attack/recovery semantics;
- stagger creates a real large opening;
- Essence/Focus creates a heal-vs-DPS decision;
- hit-stop/impact feedback makes hits legible;
- one PlayerHealth authority is shared by damage/heal/HUD;
- full CI passes on exact final SHA;
- arm64 iOS compile/package/upload succeeds;
- artifact SHA matches final commit;
- downloaded IPA passes integrity check;
- user device test is required before V22 is called stable.
