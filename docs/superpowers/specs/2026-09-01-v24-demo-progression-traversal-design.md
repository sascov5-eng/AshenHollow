# Ashen Hollow V24 — 10+ Minute Demo Progression & Traversal Design

Date: 2026-09-01
Status: Design approved in chat; implementation not started

## 1. Goal

V24 turns the current combat/platforming prototype into a deliberate vertical-slice demo with a minimum of 10 minutes of real gameplay on a normal first playthrough.

The target is 12–15 minutes for a typical first-time player so that even a fast player should still spend roughly 10–11 minutes before completion.

The demo must feel like a small connected metroidvania rather than a horizontal test level. Progression is linear in required events, but room geometry and travel direction may go right, left, down, and up.

The demo must spend its runtime on gameplay: platforming, combat, learning traversal abilities, revisiting connected spaces, and the Ash Warden boss. Empty corridors, forced waiting, artificial timers, and repeated filler encounters must not be used simply to inflate duration.

## 2. Existing Systems That Must Remain Stable

V24 builds on the current custom kinematic player controller. The player must remain free of `SKPhysicsBody`.

Existing stable behavior to preserve unless explicitly changed by this design:

- player visual: 42×64
- player collider: 36×60
- gravity: -1700
- jump velocity: 610
- jump release velocity: 285
- run speed: 315
- ground acceleration: 1900
- air acceleration: 1050
- ground deceleration: 2400
- max fall speed: -900
- coyote time and jump buffering
- existing melee combat, pogo, player health, enemy damage, Essence/Focus, death/respawn, room combat clearing, camera, and boss state machine
- camera zoom remains 1.55 unless a later separately-approved design changes it

Dash and wall traversal are additions to the kinematic movement model, not a replacement for it.

## 3. Ability Progression Model

Create a dedicated player progression state rather than storing unrelated ability booleans directly throughout `GameScene`.

Required abilities for the demo:

1. `dash`
2. `wallTraversal` — one unlock that enables both Wall Cling and Wall Jump

Each ability is either locked or unlocked.

Unlocks persist through:

- room changes
- player death
- respawn
- app termination and relaunch
- Continue

Unlocks are cleared only by starting a New Game.

The runtime scene consumes the progression state; it does not own the durable save data.

## 4. Ability Acquisition — Shrines

Abilities are obtained from dedicated shrine/artifact objects in the world rather than being silently granted on room entry.

On first activation of a shrine:

1. temporarily block player movement/combat input;
2. play a short acquisition presentation;
3. show the ability name;
4. mark the ability unlocked in progression state;
5. persist the save immediately;
6. mark that shrine as consumed;
7. restore control;
8. place the player directly into a safe teaching section that requires the new ability.

A consumed shrine remains consumed after death and after relaunch. Returning to it must not replay the unlock or grant anything again.

The acquisition sequence must be short. It is a punctuation beat, not a long cutscene.

## 5. Dash

### 5.1 Input

Dash uses a dedicated `DASH` touch button on the right side of the HUD.

The current right-side control cluster therefore becomes:

- FOCUS
- ATTACK
- JUMP
- DASH

The visual layout and hit testing must continue using the shared HUD geometry system introduced by `HUDControlLayout`; no independent magic coordinates may be reintroduced.

### 5.2 Availability

Dash is disabled until the `dash` progression unlock is acquired.

Dash does not consume Essence or any other resource.

Dash has no invulnerability frames.

### 5.3 Core Behavior

Target behavior:

- horizontal burst based on current directional input; if no horizontal input is held, use current facing;
- short dash duration;
- target cooldown approximately 0.6 seconds;
- gravity is suppressed during the brief dash window and restored immediately afterward;
- a ground dash may be reused after cooldown;
- in the air, only one dash is available until aerial dash is restored;
- the dash must remain deterministic inside the existing kinematic/substep collision system;
- dash must never tunnel through solid room geometry.

Exact speed and duration are tuning constants to be finalized during implementation using tests and device playtesting. The functional contract above is fixed.

### 5.4 Air-Dash Restoration

The aerial dash becomes available again after any of these events:

- landing on the ground;
- entering valid wall cling / completing a wall jump;
- successful pogo bounce.

Repeated airborne button presses without a restore event must not create additional air dashes.

## 6. Wall Cling / Wall Jump

Wall traversal is a passive ability and has no dedicated HUD button.

It is disabled until the `wallTraversal` unlock is acquired.

### 6.1 Wall Cling

A wall cling is valid when:

- the player is airborne;
- the player's collider is touching a solid wall on the relevant side;
- the player is holding movement toward that wall;
- wall traversal has been unlocked.

While clinging:

- downward velocity is capped to a much slower slide speed;
- ordinary gravity may continue to act but cannot accelerate the player beyond the wall-slide cap;
- releasing direction toward the wall ends the cling and returns to ordinary falling.

Ground contact takes priority over wall cling.

### 6.2 Wall Jump

Pressing JUMP during a valid wall cling produces a jump impulse away from the wall.

The wall jump must:

- push horizontally away from the contacted wall;
- apply an upward impulse;
- temporarily prevent immediate reattachment to the same wall long enough for the jump to read correctly;
- return to normal air control after the short launch window;
- allow chained jumps between opposing walls.

Wall jumping restores the player's aerial dash.

## 7. Death, Checkpoints, Continue, and New Game

### 7.1 Checkpoints

The demo has persistent checkpoints.

Activating a checkpoint records at minimum:

- checkpoint identifier;
- room identifier;
- respawn position appropriate to that checkpoint;
- current unlocked abilities;
- consumed ability shrines;
- enough demo-progression state to prevent invalid replay of already-completed acquisition events.

### 7.2 Death

Death keeps the existing death presentation and player-state reset semantics.

On respawn:

- player returns to the latest activated checkpoint;
- HP returns according to the existing respawn contract;
- unlocked abilities remain unlocked;
- consumed shrines remain consumed;
- the player does not repeat ability acquisition sequences.

Enemy/room encounter reset behavior should remain consistent with the existing room system unless a room-specific requirement is defined during implementation.

### 7.3 App Relaunch / Continue

`Continue` loads the latest saved checkpoint and durable progression.

The player resumes from that checkpoint, not from the start of the demo.

If no valid save exists, Continue must not attempt to load invalid state; New Game is the valid entry path.

### 7.4 New Game

`New Game` clears the demo save and starts from the initial Approach checkpoint with:

- no traversal abilities unlocked;
- all ability shrines unconsumed;
- demo progression reset;
- initial room/player state restored.

## 8. Demo World Structure

The world is spatially connected. Required progression is linear, but travel direction is deliberately varied.

The implementation may use room-local coordinates and transitions, but the player's perceived route must include horizontal and vertical movement rather than ten rooms arranged in a straight row.

Proposed progression map:

```text
                         [9] Warden Gate
                              │
                              ↑
                     [8] Ashen Ascent
                              ↑
                              │
[6] Watcher Hall ←──── [7] Hollow Shaft
       ↑                     │
       │                     ↓
[5] Furnace Passage ← [4] Dash Shrine
       ↑                     ↑
       │                     │
[3] Broken Gallery ←── [2] Lower Hall
                              ↑
                              │
                        [1] Approach

                         ↓ after Gate

                    [10] Warden Chamber
                         ASH WARDEN
```

This diagram defines progression intent, not exact world-space coordinates. Final room origins must support the intended transitions without overlap or camera/collision ambiguity.

## 9. Room-by-Room Pacing

### 9.1 Approach — target 1–1.5 min

Purpose:

- starting checkpoint;
- basic movement and jump reacclimation;
- one simple combat beat;
- visually tease at least one route that is currently inaccessible without a later traversal ability.

No traversal ability is available yet.

### 9.2 Lower Hall — target 1–1.5 min

Purpose:

- first proper combat room;
- reinforce core melee, movement, and Focus loop;
- begin moving the route away from a simple left-to-right corridor.

### 9.3 Broken Gallery — target ~1 min

Purpose:

- platforming plus a faster enemy such as Runner;
- show a vertical/high path the player cannot yet use effectively;
- guide the player toward the Dash shrine route.

### 9.4 Dash Shrine — target ~1 min

Purpose:

- acquire Dash;
- short acquisition presentation;
- immediately teach Dash in a safe environment;
- require at least one gap that cannot be crossed with an ordinary jump alone;
- then introduce a short sequence of multiple dash uses without combat pressure.

Checkpoint #2 activates after Dash acquisition/teaching.

### 9.5 Furnace Passage — target 1–1.5 min

Purpose:

- combine Dash with normal platforming;
- use gaps/positioning that reward Dash;
- introduce combat where Dash is useful for repositioning but not mandatory for dealing damage.

### 9.6 Watcher Hall — target 1–1.5 min

Purpose:

- ranged-pressure encounter using the current rebalanced Ranged enemy plus supporting enemy pressure;
- Dash is the primary movement tool for safely closing distance and repositioning;
- lead the player toward the lower/vertical route to the second shrine.

### 9.7 Hollow Shaft — target ~1 min

Purpose:

- descend into a vertical space;
- acquire Wall Cling / Wall Jump at the lower shrine;
- teach the passive ability by making the exit route upward;
- the player must escape the shaft using the new wall traversal mechanic.

Checkpoint #3 activates after Wall Traversal acquisition/teaching.

### 9.8 Ashen Ascent — target 1–1.5 min

Purpose:

- primary vertical traversal showcase;
- require combinations such as wall jump → dash → wall cling → jump → dash;
- place enemies on selected ledges so traversal and combat interact;
- avoid making every jump pixel-perfect.

The room should reward mastery but remain clear enough for a first-time mobile player.

### 9.9 Warden Gate — target 1–2 min

Purpose:

- final non-boss test;
- combine both traversal abilities with stronger enemy pressure such as Heavy/Ranged compositions;
- include one meaningful connected-world shortcut or route payoff;
- provide a short calm approach after completion.

Checkpoint #4 activates immediately before entering Warden Chamber.

### 9.10 Warden Chamber — target 2–4 min

Purpose:

- Ash Warden remains the demo climax;
- boss design assumes Dash is available and useful;
- Wall Jump is an optional mobility advantage in the arena, not a hidden mandatory execution check;
- dying to the boss respawns at Checkpoint #4, not several rooms earlier;
- completing the boss ends the vertical slice and leads to a demo-complete state/screen.

V24 does not redesign the existing boss state machine from scratch. Only changes required to make the arena and attacks coexist correctly with the new traversal abilities are in scope.

## 10. Connected-World Payoffs

The demo should contain one or two short shortcuts or revisits enabled by newly unlocked traversal abilities.

Examples of valid payoffs:

- a high passage seen earlier becomes reachable after Wall Jump;
- a gap seen from the opposite side becomes crossable after Dash;
- a reopened route reduces travel through an already-cleared area.

These are used to make the world feel connected. They must not turn the 10–15 minute demo into a maze or require extensive backtracking.

## 11. Minimum Runtime Acceptance Requirement

Runtime is a product requirement, not a vague target.

Acceptance requires device playtesting after implementation:

- normal first-time playthrough target: 12–15 minutes;
- fast but legitimate first playthrough target: at least 10 minutes;
- boss time counts as gameplay;
- death/retry time is not required to reach the minimum; a clean run should still satisfy the intended duration closely enough that the demo is not dependent on failure to feel substantial.

If testing shows the route completes in under 10 minutes for a competent player, increase meaningful gameplay density or room traversal complexity. Do not solve the problem with idle waits, excessively slow movement, inflated enemy HP, or empty distance.

## 12. Architecture Boundaries

Implementation should keep responsibilities separated.

### Player progression / save state

Owns:

- ability unlocks;
- consumed shrines;
- latest checkpoint;
- durable serialization/deserialization;
- New Game reset.

It must be testable independently of SpriteKit rendering.

### Traversal ability controllers

Own:

- Dash state/cooldowns/air-use state;
- Wall Cling/Wall Jump state and timing;
- pure or near-pure state transitions where practical.

`GameScene` integrates their outputs with the existing kinematic velocity/collision loop rather than embedding every rule inline.

### Room definitions

Own:

- spatial topology;
- platforms/collision geometry;
- exits in all required directions;
- enemy spawns;
- shrine placement;
- checkpoint placement;
- teaching gates/shortcuts.

### HUD

Owns:

- rendering and hit targets for DASH in the existing shared layout system;
- locked/unlocked presentation where appropriate.

HUD hit testing must use the same geometry used to draw buttons.

## 13. Failure and Edge Cases

Implementation must explicitly handle:

- pressing DASH before the ability is unlocked;
- pressing DASH during cooldown;
- repeated airborne DASH attempts before restore;
- dashing into a wall without tunnelling or entering geometry;
- wall cling at floor/wall corners;
- wall jump followed by immediate same-wall reattachment;
- death during or immediately after an acquisition sequence;
- app termination immediately after acquiring an ability;
- loading a save whose checkpoint is valid but current room encounter state is transient;
- New Game after a fully progressed save;
- Continue when no valid save exists;
- touchscreen multitouch with D-pad + DASH/JUMP/ATTACK/FOCUS combinations.

## 14. Testing Strategy

V24 is implemented test-first where the logic permits it.

Minimum automated coverage:

- ability unlock state and New Game reset;
- persistence round trip for abilities, consumed shrines, and checkpoint;
- Dash cooldown and one-air-dash rule;
- Dash restoration on landing, wall traversal, and pogo;
- Dash unavailable while locked;
- Wall Cling eligibility and slide cap;
- Wall Jump direction/launch state;
- same-wall reattachment suppression;
- room exits in left/right/up/down topology;
- shrine single-consumption behavior;
- checkpoint respawn selection;
- HUD DASH target drawing/hit-test consistency;
- existing combat/movement regression tests remain green.

CI acceptance still requires all existing tests plus arm64 iOS compilation and IPA packaging.

CI success does not prove device feel or runtime. V24 is considered device-stable only after a real-device test confirms controls, traversal feel, room progression, save/Continue behavior, and playthrough duration.

## 15. Out of Scope for V24

Do not expand this milestone into a full metroidvania system.

Out of scope unless separately approved:

- double jump;
- Crystal Heart / super dash analogue;
- Shade Cloak / invulnerable dash;
- dash resource cost;
- additional spells;
- large nonlinear map or map UI;
- complex inventory;
- full-game save-slot system;
- redesigning all enemy archetypes;
- replacing the Ash Warden architecture;
- procedural rooms;
- artificial runtime padding.

## 16. Definition of Done

V24 is complete only when all of the following are true:

1. Dash is obtained from its shrine and behaves according to this design.
2. Wall Cling/Wall Jump is obtained later and behaves as a passive traversal unlock.
3. Both abilities survive death and app relaunch.
4. New Game resets them and Continue restores the latest checkpoint.
5. Four checkpoint stages work: start, post-Dash, post-Wall Traversal, pre-boss.
6. The playable route uses left/right/up/down room progression rather than a straight horizontal chain.
7. At least one meaningful traversal-enabled shortcut/revisit exists.
8. The route culminates in Ash Warden.
9. Existing stable combat/controller behavior is not regressed.
10. CI passes all regression/new tests, arm64 compilation, and IPA packaging.
11. A real-device clean first playthrough demonstrates a minimum of approximately 10 minutes, with 12–15 minutes as the normal target.
12. Real-device testing confirms the new HUD, Dash, Wall Traversal, checkpoints, Continue, and New Game are usable and reliable.
