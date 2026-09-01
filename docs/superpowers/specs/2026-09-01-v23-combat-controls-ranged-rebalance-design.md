# V23 — Combat Controls + Focus Reliability + Ranged Rebalance Design

Date: 2026-09-01  
Status: Proposed for implementation after user review  
Baseline: V22 acceptance commit `3793b7cf7249294ca26cfa26e0866e48fbf06afa`

## 1. Goal

Make combat inputs immediate and predictable on touch devices, eliminate the Focus completion race that can make healing appear to hang, and rebalance the Ranged archetype so it creates pressure without becoming an unavoidable HP tax.

The target feel remains Hollow Knight-inspired: directional attacks are selected by held movement direction, attack input is immediate, healing is a deliberate channel, and ranged enemies create readable spacing problems with clear punish windows.

## 2. Problems confirmed in V22

### 2.1 Horizontal ATTACK is delayed

Current V22 stores the ATTACK touch in `touchesBegan`, but a normal horizontal attack only starts from `touchesEnded`. Up/down swipe attacks may start earlier when the movement threshold is crossed. This makes the basic attack feel softer and less responsive than directional attacks.

### 2.2 Focus completion can be lost on release

`EssenceFocusController` defers a completed heal by arming a confirmation frame. Releasing FOCUS calls `cancelFocus()`, which clears `completedHealPending`. If release lands between channel completion and confirmation consumption, the pending heal is discarded. This is the source of the intermittent “healing hangs / button does not work” symptom.

### 2.3 Ranged pressure has too little counterplay

Current Ranged values and runtime behavior combine:
- detection range 390;
- attack range 310;
- attack cooldown 1.05 s;
- aim delay about 0.18 s;
- projectile speed 325;
- evasive retreat when player gets within 145;
- Watcher Hall also contains Runner + Grunt.

The result is sustained zoning while the player is simultaneously pressured by melee enemies, with little time to close distance and convert that approach into damage.

## 3. Considered control approaches

### A. Keep ATTACK swipe gestures

Pros: preserves V22 implementation.  
Cons: basic attack remains delayed or requires gesture heuristics; direction selection competes with the same finger used to attack; poor fit for rapid touch combat.

Rejected.

### B. Separate up/down attack buttons

Pros: deterministic.  
Cons: adds too many right-side buttons and increases thumb travel; does not match the desired Hollow Knight-style “direction + attack” mental model.

Rejected.

### C. Left D-pad / directional pad + immediate ATTACK

Pros: attack direction is deterministic, basic ATTACK can fire on touch-down, pogo becomes `DOWN + ATTACK` in air, and the right thumb only handles action buttons. This most closely matches a controller-style action platformer while remaining practical on mobile.

Selected.

## 4. Input architecture

### 4.1 Left-side directional controls

Replace the current two-button left/right input surface with a four-direction D-pad-style control model:

- LEFT: horizontal movement left;
- RIGHT: horizontal movement right;
- UP: no player translation; acts as attack direction modifier;
- DOWN: no player translation; acts as attack direction modifier.

Horizontal movement behavior and all existing kinematic constants remain unchanged.

### 4.2 Attack selection

ATTACK starts on `touchesBegan`, never on release.

At the instant ATTACK begins:

1. If UP is currently held, attack direction = `.up`.
2. Else if DOWN is held and player is airborne, attack direction = `.down`.
3. Else attack direction = `.horizontal`.

Direction is locked for the entire swing.

DOWN while grounded does not create a down-attack; it falls back to horizontal ATTACK.

If both UP and DOWN somehow become held at once, UP wins deterministically.

### 4.3 Removed gesture dependency

`AttackGestureResolver` is no longer authoritative for player combat input. It can be removed or retired after tests are migrated.

No swipe is required for any attack.

### 4.4 Right-side actions

Keep three action controls:

- FOCUS;
- ATTACK;
- JUMP.

ATTACK must be the easiest and most immediate button to reach. FOCUS should be sufficiently separated from ATTACK/JUMP so accidental touch reassignment is unlikely.

## 5. Focus reliability redesign

### 5.1 State ownership

`EssenceFocusController` remains the pure state machine. `PlayerVitalState` remains the single HP authority.

### 5.2 Completion rule

A Focus heal completes atomically when channel time reaches zero.

There is no extra “confirmation frame” after reaching 100%.

On the frame the channel completes:

1. verify Focus has not already been cancelled by accepted damage;
2. spend the Essence cost;
3. emit exactly one completed-heal event;
4. apply exactly one HP through `PlayerVitalState`;
5. end Focus.

Releasing the button after completion cannot erase an already completed heal.

### 5.3 Cancellation rule

Before completion, Focus is cancelled by:

- accepted player damage;
- ATTACK;
- JUMP;
- releasing/leaving the FOCUS touch area.

Cancelled Focus spends no Essence and heals nothing.

### 5.4 Input ownership rule

A touch that started on FOCUS remains owned by FOCUS until release/cancel. Sliding slightly inside an expanded tolerance zone does not reclassify it as another button. This avoids “button stopped working” caused by finger drift.

## 6. Ranged enemy rebalance

The Ranged enemy should be dangerous because it changes spacing, not because it fires too often while permanently retreating.

### 6.1 Initial balance targets

Use these initial targets for the next acceptance build:

- max HP: 3 (unchanged);
- projectile damage: 1 (unchanged);
- detection range: reduce from 390 to about 340;
- preferred attack range: reduce from 310 to about 270;
- attack cooldown: increase from 1.05 s to about 1.45 s;
- aim/telegraph delay: increase from ~0.18 s to about 0.42 s;
- projectile speed: reduce from 325 to about 285;
- retreat trigger: reduce from 145 to about 105;
- retreat must have a finite short duration/cooldown rather than being available continuously.

Exact tuning remains data-driven and can be adjusted after device testing, but these values define the first V23 acceptance target.

### 6.2 Read → shot → recovery loop

Ranged attack loop becomes:

`TRACK / POSITION → AIM TELEGRAPH → FIRE ONCE → RECOVERY → TRACK / POSITION`

During AIM:
- enemy does not retreat;
- facing/shot direction locks late enough to remain readable;
- visible telegraph is stronger than V22.

During RECOVERY:
- enemy cannot fire;
- enemy cannot immediately re-enter evade;
- player gets a real opportunity to close distance and punish.

### 6.3 Retreat limits

Retreat is only a spacing correction, not a permanent escape mode.

Rules:
- triggers only when player breaches the close-distance threshold;
- runs for a short fixed burst;
- then enters a retreat cooldown;
- Ranged can still be cornered and hit;
- room bounds continue to clamp movement.

### 6.4 Watcher Hall composition

Keep the concept of a mixed room, but lower simultaneous pressure for acceptance testing.

Preferred V23 composition:
- 1 × Ranged;
- 1 × Grunt.

Remove Runner from Watcher Hall for this iteration. Runner + Ranged + Grunt makes it difficult to evaluate whether Ranged itself is balanced because three pressure profiles overlap.

After Ranged is proven fair on-device, harder mixed compositions can return later.

## 7. Combat feel preserved from V22

V23 keeps:

- horizontal/up/down melee;
- pogo;
- player recoil on accepted hits;
- enemy knockback/hit-stun;
- contact damage + player i-frames;
- Essence gain only on accepted melee hits;
- Focus healing economy;
- Ash Warden damageability during telegraph/attack/recovery;
- boss stagger;
- hit-stop/impact feedback;
- V21 six-room architecture;
- V19 full respawn to Room 1.

V23 does not redesign the boss again unless a regression is discovered during implementation.

## 8. Kinematic safety constraints

Do not reintroduce `SKPhysicsBody` for the player.

Do not change:
- gravity `-1700`;
- jump `610`;
- jump release `285`;
- run speed `315`;
- ground acceleration `1900`;
- air acceleration `1050`;
- ground deceleration `2400`;
- max fall speed `-900`;
- camera zoom `1.55`.

Recoil and pogo continue through the existing kinematic combat impulse queue.

## 9. Test strategy

### 9.1 Directional input pure tests

Add a pure D-pad attack direction resolver contract:

- no vertical direction held → horizontal;
- UP held → up;
- DOWN held + airborne → down;
- DOWN held + grounded → horizontal;
- UP + DOWN → up.

### 9.2 Immediate attack integration contract

Verify ATTACK starts on press rather than release and direction is locked for the swing.

### 9.3 Focus race regression tests

Pure tests must reproduce the V22 failure:

- channel reaches completion;
- user releases immediately after completion;
- heal event still exists exactly once;
- Essence is spent exactly once.

Also verify:
- release before completion cancels with no spend;
- accepted damage before completion cancels;
- accepted damage after completion cannot erase a completed heal.

### 9.4 Ranged behavior pure tests

Extract or extend a pure Ranged combat state model so CI can verify:

- AIM duration before fire;
- one projectile per attack cycle;
- recovery prevents immediate second shot;
- retreat burst is finite;
- retreat cooldown prevents permanent kiting.

### 9.5 Regression suite

All existing V22 pure tests remain required plus arm64 iOS compile/package.

## 10. Device acceptance criteria

V23 is not stable until the user confirms on iPhone:

1. tapping ATTACK produces an immediate horizontal strike;
2. holding UP + tapping ATTACK gives reliable up-slash;
3. airborne DOWN + ATTACK gives reliable down-slash/pogo;
4. no attack requires a swipe;
5. movement remains identical to the stable controller;
6. FOCUS starts reliably when pressed;
7. completing Focus then releasing cannot lose the heal;
8. interrupted Focus does not spend Essence;
9. Ranged shots are readable before launch;
10. Ranged has a real recovery/punish window;
11. Ranged cannot permanently run away at close range;
12. Watcher Hall can be cleared without losing most HP by default;
13. boss combat and V22 stagger behavior still work;
14. death/respawn still resets to Room 1 at 5/5 HP and 0 Essence.

## 11. Scope exclusions

Not in V23:

- spells;
- dash;
- parry;
- controller hardware support;
- final UI art;
- final enemy sprites;
- additional Ranged projectile patterns;
- additional boss redesign.
