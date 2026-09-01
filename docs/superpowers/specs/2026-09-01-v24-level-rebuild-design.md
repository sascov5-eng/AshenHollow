# Ashen Hollow V24 — Full Level Rebuild Design

Date: 2026-09-01
Status: Approved in chat; supersedes the room-geometry, encounter-placement, and onboarding details of the earlier V24 progression/traversal spec. The original V24 scope, progression order, abilities, persistence, checkpoints, and Ash Warden milestone remain in force.

## 1. Scope and Goal

Rebuild all ten V24 demo rooms so the demo feels like a small connected metroidvania rather than ten unrelated test screens.

This rebuild stays strictly inside the already-approved V24 milestone:

- ten rooms only;
- Dash and Wall Traversal only;
- four checkpoint stages;
- one meaningful traversal-enabled shortcut/revisit;
- existing enemy archetypes only;
- existing Ash Warden architecture;
- 10+ minutes required, 12–15 minutes target for a normal first playthrough;
- no map UI, double jump, super dash, invulnerable dash, extra spells, procedural rooms, or full-game systems.

The rebuild changes:

- room blockout and platform geometry;
- how room exits are physically reached;
- enemy placement inside rooms;
- short environmental teaching sequences;
- beginning tutorial prompts;
- world-state presentation for shrines/checkpoints/gates/shortcut;
- automated traversal validation.

It does not replace the existing kinematic controller.

## 2. Design Principles

The level-design pass follows these rules:

1. **Blockout before decoration.** Geometry is validated first using the real player controller/tuning. Enemy placement comes after traversal works.
2. **Rooms have one primary job.** A room may combine systems, but one purpose must dominate: onboarding, combat, Dash teaching, ranged pressure, Wall teaching, combined traversal, final combat, or boss.
3. **Teach before testing.** The first use of a newly unlocked ability must be forgiving and combat-free.
4. **Mandatory traversal is not precision platforming.** Required jumps have approximately 20–25% execution margin relative to the player’s practical limit.
5. **Optional shortcuts may be tighter.** Optional routes may use roughly 10–15% margin, but may not be required to finish the demo.
6. **World geometry communicates locks.** Gaps, height, walls, and shafts should explain why a route is inaccessible instead of relying on arbitrary “ABILITY LOCKED” walls wherever avoidable.
7. **Enemies belong to space.** Ranged enemies require line-of-sight space and cover/reposition options; Heavy enemies guard ground routes; Runner enemies receive horizontal room to accelerate; tutorial traversal stays enemy-free.
8. **Quiet rooms are allowed.** Not every room needs combat.
9. **State changes are visible.** Consumed shrines, activated checkpoints, cleared combat gates, opened shortcut, and post-boss exit must visibly change state.
10. **No important gameplay object under mobile HUD.** Shrines, landing targets, hazards, and first-read enemies are kept out of the persistent control clusters.

## 3. Authoritative Player Movement Tuning

The rebuild uses the current player movement values as the design source of truth:

- visual body: 42×64 pt;
- collision body: 36×60 pt;
- gravity: 1700 pt/s² downward;
- full jump initial vertical speed: 610 pt/s;
- released-jump vertical cap: 285 pt/s;
- run speed: 315 pt/s;
- ground acceleration: 1900 pt/s²;
- air acceleration: 1050 pt/s²;
- max fall speed: 900 pt/s downward;
- coyote time: 0.12 s;
- jump buffer: 0.12 s;
- motion collision substep cap: 5 pt;
- Dash speed: 720 pt/s;
- Dash duration: 0.16 s;
- Dash cooldown: 0.60 s;
- Wall Jump launch: 360 pt/s horizontally away from wall, 560 pt/s vertically;
- Wall slide cap: 180 pt/s downward;
- same-wall reattachment lock: 0.12 s.

Derived theoretical reference values:

- full-jump apex time: approximately 0.359 s;
- full-jump apex rise from launch point: approximately 109 pt;
- theoretical full-flight horizontal travel at already-achieved 315 pt/s: approximately 226 pt;
- pure Dash displacement while unobstructed: approximately 115 pt.

These are **reference maxima, not level-design targets**. Required geometry is built below these limits.

## 4. Shared Movement Tuning and Traversal Validation

Current movement constants must no longer exist only as private magic values inside `GameScene` if level geometry depends on them.

Introduce one shared `PlayerMovementTuning` value/type consumed by both `GameScene` and traversal tests. The goal is to make a future movement-tuning change automatically invalidate stale level assumptions.

Add a pure traversal-validation layer, independent of SpriteKit rendering. It must verify room blockout against the same tuning.

Minimum validation contracts:

### 4.1 Ordinary mandatory jump

For a required jump without Dash or Wall Traversal:

- vertical rise from takeoff surface to landing surface should normally be 0–80 pt;
- 80 pt is the ordinary mandatory ceiling unless a specific test proves a larger step remains comfortably reachable;
- horizontal clear gap should normally be no more than 150–170 pt for first-pass mobile traversal;
- the receiving platform should normally be at least 180 pt wide, with 220+ pt preferred for tutorial or post-combat landings.

A mandatory jump must be validated from a realistic takeoff zone, not from a single perfect pixel at the source edge.

### 4.2 Dash teaching gap

The first Dash gate must:

- be wider than the conservative ordinary-jump envelope;
- remain comfortably inside jump-plus-Dash reach;
- target approximately a 230–255 pt clear gap between safe surfaces;
- use a receiving platform at least 260 pt wide;
- place the landing top at equal or lower elevation than the takeoff top unless testing explicitly proves another arrangement safe;
- provide a safe recovery surface if the player undershoots during the first tutorial.

### 4.3 Vertical stair sequences

Mandatory stair-step traversal must not stack repeated near-apex jumps.

- ordinary vertical increments target 55–75 pt;
- hard mandatory increment ceiling: 80 pt;
- after a larger horizontal transfer, the next step must include a stable landing zone before another required jump;
- no receiving platform may be positioned so the expected arc reaches its vertical side before the player collider can clear the platform top.

### 4.4 Wall-jump shaft

The first Wall Traversal shaft must:

- keep the shrine itself walk-accessible before the ability unlock;
- use opposing inner wall gap of approximately 170–200 pt;
- include a broad first cling surface;
- provide a safe upper ledge at least 220 pt wide;
- require Wall Traversal for the intended exit without requiring frame-perfect alternation.

### 4.5 Combined traversal

Later rooms may require combinations such as wall jump → Dash → landing or wall jump → cling → jump.

For the mandatory route:

- each combo is separated by a stable landing or cling opportunity;
- the player is not required to chain more than two precision-sensitive actions without a recovery state;
- first-time mobile execution remains the target, not speedrun execution.

### 4.6 Collision-side safety

The validator must reject mandatory platform transfers where the expected player trajectory collides with the receiving platform’s vertical side before reaching a valid landing height.

This specifically prevents the current failure mode: the player reaches the platform horizontally, embeds/halts against its side, loses vertical momentum, and falls.

Validation should account for the 36×60 collider, not just the player center point.

## 5. Onboarding Tutorial — Approach

The beginning gains a short contextual tutorial lasting roughly 30–60 seconds. It uses the real HUD controls; no duplicate fake control layout is introduced.

Tutorial sequence:

1. **Movement**
   - briefly highlight the real LEFT/RIGHT controls;
   - show a small `MOVE`/localized movement prompt;
   - complete after the player travels a modest horizontal distance.
2. **Jump**
   - place one low, wide, safe obstacle/ledge;
   - highlight the real JUMP button;
   - complete after the first successful grounded jump/landing.
3. **Attack**
   - introduce one isolated Grunt only after movement/jump are demonstrated;
   - highlight ATTACK;
   - complete after the first successful player hit, not merely button press.
4. **Focus**
   - do not block progression or ask the player to Focus at full HP;
   - when the player first has both missing HP and enough Essence, show `HOLD FOCUS TO HEAL` and highlight the actual FOCUS control;
   - dismiss after successful healing or permanently after the player leaves the onboarding phase if the condition never arises.
5. **Dash/Wall Jump**
   - not explained at game start;
   - Dash is taught after Dash Shrine;
   - Wall Traversal is taught after Hollow Shaft shrine.

Tutorial prompts are contextual, short, and do not repeat on every death. New Game resets tutorial completion; ordinary checkpoint respawn does not.

## 6. World Structure

The required progression remains exactly the approved V24 order:

`Approach --DOWN--> Lower Hall --LEFT--> Broken Gallery --DOWN--> Dash Shrine --LEFT--> Furnace Passage --UP--> Watcher Hall --LEFT--> Hollow Shaft --UP--> Ashen Ascent --LEFT--> Warden Gate --DOWN--> Warden Chamber`

The implementation may use room-local coordinates, but transition direction, spawn side, and exit side must make spatial sense to the player.

The ten rooms remain the complete required demo route.

## 7. Room Rebuild

### 7.1 Approach — onboarding / 1–1.5 min

Primary job: movement onboarding and first simple combat.

Blockout:

- broad safe starting floor;
- low onboarding ledge within the conservative jump envelope;
- one simple route downward toward Lower Hall;
- one visually readable high/vertical route teaser that cannot be completed yet without Wall Traversal.

Enemies:

- exactly one early Grunt for ATTACK teaching;
- it must not aggro before the player has had space to learn movement/jump.

World reaction:

- tutorial highlights disappear as actions are demonstrated;
- later Wall Traversal may make the teased route readable as a real shortcut payoff.

### 7.2 Lower Hall — basic combat / 1–1.5 min

Primary job: first real combat room.

Blockout:

- two broad floor elevations plus one wide central ledge;
- no staircase of near-maximal jumps;
- ample flat ground for melee spacing and Focus use.

Enemies:

- two Grunts separated so they do not necessarily engage simultaneously on spawn;
- second enemy becomes relevant as the player advances through the room.

World reaction:

- required combat gate opens after the encounter clear.

### 7.3 Broken Gallery — branching teaser / ~1 min

Primary job: show that the world contains routes the player cannot yet use.

Blockout:

- safe main traversal toward the Dash Shrine route;
- one high Wall-Traversal-gated exit/shortcut visibly present early;
- ordinary route remains obvious and does not require guessing.

Enemies:

- one Grunt in a stable ground section;
- one Runner on a long horizontal lane where its speed can be read and reacted to.

World reaction:

- after Wall Traversal is acquired, the high route becomes physically usable and visibly reads as `SHORTCUT`, reducing repeated travel without becoming mandatory.

### 7.4 Dash Shrine — acquisition + pure Dash teaching / ~1 min

Primary job: grant and teach Dash safely.

Before shrine:

- shrine is walk-accessible;
- no combat pressure;
- shrine placement stays clear of left-side HUD.

After acquisition:

1. checkpoint #2 is activated;
2. shrine becomes consumed/visually dormant;
3. first mandatory Dash gap is presented immediately;
4. first receiving platform is broad and forgiving;
5. a safe recovery ledge/floor prevents a single undershoot from becoming a long fall/replay;
6. one short, easy ascent follows using 55–75 pt vertical steps and broad surfaces;
7. exit leads LEFT toward Furnace Passage.

No enemy is introduced until Dash has been demonstrated successfully.

### 7.5 Furnace Passage — Dash application / 1–1.5 min

Primary job: apply Dash in ordinary traversal and combat.

Blockout:

- mix normal jump and one or two Dash-favored transfers;
- receiving surfaces remain broad enough for first-play mobile control;
- no enemy is placed directly on a mandatory landing point;
- route climbs toward the UP transition to Watcher Hall.

Enemies:

- Grunt occupies stable ground;
- Runner receives a clear lane;
- Dash helps reposition but is not required to damage either enemy.

### 7.6 Watcher Hall — ranged-pressure room / 1–1.5 min

Primary job: teach how Dash changes engagement with Ranged enemies.

Blockout:

- player enters with immediate cover or vertical interruption, not a direct unavoidable firing lane;
- Ranged enemy occupies a readable elevated/distant firing position;
- at least one safe approach lane lets the player close distance using Dash;
- a Grunt pressures the approach without overlapping the first projectile timing unfairly.

Enemies:

- one Ranged;
- one Grunt support enemy;
- no additional enemy type is added.

World reaction:

- clear opens the route LEFT toward Hollow Shaft.

### 7.7 Hollow Shaft — Wall Traversal acquisition / ~1 min

Primary job: grant and teach Wall Cling/Wall Jump.

Before shrine:

- player can descend/walk to the shrine without already needing Wall Traversal;
- no combat pressure.

After acquisition:

1. checkpoint #3 activates;
2. shrine becomes consumed;
3. player is faced with an upward route between opposing walls;
4. first wall-jump section uses a 170–200 pt inner gap;
5. broad walls and ledges create readable cling targets;
6. top recovery platform is at least 220 pt wide;
7. exit goes UP into Ashen Ascent.

No enemy is used inside the teaching shaft.

### 7.8 Ashen Ascent — combined traversal / 1–1.5 min

Primary job: combine learned movement systems.

Blockout progression:

- simple Wall Jump start;
- stable landing;
- Wall Jump + Dash transfer;
- stable landing;
- Wall Cling/Jump continuation;
- final wide approach to the LEFT exit.

The mandatory route never requires more than two precision-sensitive actions before a recovery state.

Enemies:

- Runner only on a stable ledge/ground lane;
- Ranged only from a platform where projectiles pressure movement without covering a required blind landing;
- enemy placements are introduced after the player has already demonstrated the combined traversal pattern once without combat.

### 7.9 Warden Gate — final systems test / 1–2 min

Primary job: final non-boss challenge and calm pre-boss reset.

Blockout:

- broad combat floor with traversal options rather than a precision platform ladder;
- optional height/Wall route gives positional advantage;
- post-encounter calm section leads to checkpoint #4;
- checkpoint is before Warden Chamber and cannot be activated while already trapped in boss combat.

Enemies:

- Heavy acts as a ground-route guard;
- Ranged occupies a separated firing position;
- their attack zones should overlap enough to create a deliberate challenge but not produce unavoidable spawn pressure.

World reaction:

- clear opens the boss approach;
- pre-Warden checkpoint visibly activates.

### 7.10 Warden Chamber — boss arena / 2–4 min

Primary job: Ash Warden climax.

Blockout:

- broad central floor;
- side walls support Wall Traversal as an optional evasive tool;
- no small incidental platforms that catch the player collider during boss movement;
- Dash provides useful horizontal repositioning;
- Wall Jump is beneficial but never mandatory to survive a standard boss pattern.

World reaction:

- defeating Ash Warden changes the arena/exit state and exposes the demo-complete route/screen.

The Ash Warden state machine itself is not redesigned from scratch.

## 8. Enemy Placement Rules

Enemy placement occurs only after traversal blockout is GREEN.

Required placement rules:

- do not spawn a hostile enemy directly on the player spawn or mandatory landing target;
- avoid unavoidable first-frame ranged fire after room transition;
- Ranged enemies need readable line of sight and at least one player response option: cover, elevation change, or Dash approach;
- Runner enemies require sufficient horizontal lane length to express patrol/chase speed;
- Heavy enemies guard routes/rewards rather than appearing in narrow traversal shafts;
- tutorial rooms for a newly acquired ability remain enemy-free until the ability has been demonstrated at least once;
- combat rooms provide enough stable ground for Attack, recoil, knockback, Focus, and enemy hit-stun to work without constant accidental falls.

## 9. World Reaction and Persistent Presentation

Within V24 scope, the world visibly reacts to the player:

- Dash Shrine changes from active to consumed/dormant after acquisition;
- Wall Shrine does the same;
- checkpoint markers visibly activate and remain activated after Continue;
- combat gates change from closed to open after their encounter clear;
- the Broken Gallery shortcut changes from an unreadable/unusable high route to an open usable shortcut after Wall Traversal;
- post-boss arena/exit state changes after Ash Warden is defeated.

Durable state follows the existing V24 save/progression contract. Transient room enemies may reset according to the existing room reset rules unless otherwise required by the base spec.

## 10. Tutorial/Traversal State

Add a small tutorial-progression state separate from ability ownership.

Minimum flags/events:

- movement demonstrated;
- jump demonstrated;
- first successful attack demonstrated;
- Focus tutorial shown/completed;
- Dash teaching gap completed;
- Wall teaching shaft completed.

The first four tutorial flags support onboarding presentation. Dash/Wall completion flags are used for one-time contextual prompts and should not change ability ownership.

Tutorial presentation must not block Continue into later checkpoints.

## 11. Automated Geometry Acceptance

The rebuild is not accepted because coordinates “look reasonable.”

Automated tests must cover at least:

1. every mandatory ordinary transfer against conservative horizontal/vertical limits;
2. every mandatory landing platform width;
3. Dash Shrine first gap is too wide for conservative ordinary jump but comfortably valid with Dash;
4. Dash Shrine receiving platform/trajectory does not create side-collision before landing;
5. Dash Shrine ascent increments stay within the mandatory vertical envelope;
6. Hollow Shaft shrine is reachable before Wall Traversal;
7. Hollow Shaft wall gap is within the approved 170–200 pt range;
8. Hollow Shaft exit requires and supports Wall Traversal;
9. Ashen Ascent mandatory combo route includes recovery states between combos;
10. no mandatory transition spawns the player intersecting solid geometry;
11. no important shrine/checkpoint/spawn/mandatory landing target occupies the persistent HUD exclusion zones on the reference mobile viewport;
12. the existing V24 topology order remains intact;
13. all pre-existing combat, Dash, Wall, save, HUD, and boss tests remain green.

Prefer a deterministic kinematic traversal simulator using the shared tuning and collider dimensions. If a full search simulator is excessive, use conservative analytic/envelope tests plus targeted collision-trajectory simulations for each mandatory transfer. The key requirement is that tests fail when movement tuning or platform coordinates make the required route invalid.

## 12. Device Acceptance

CI proves structural validity, not feel.

After automated validation and arm64 build pass, device testing must verify:

- the beginning tutorial is understandable without covering play space;
- mandatory jumps do not require perfect edge takeoff;
- the player lands on top of receiving platforms instead of hitting their vertical sides;
- the first Dash gap is obvious and forgiving;
- the Dash Shrine recovery route prevents repeated long falls;
- Hollow Shaft teaches Wall Traversal without combat interference;
- Ashen Ascent is challenging but consistently readable on touch controls;
- enemy placements feel intentional rather than randomly stacked;
- room transitions make spatial sense;
- Continue/checkpoints still work after the rebuild;
- clean first-play runtime remains at least approximately 10 minutes, with 12–15 minutes the target.

If any mandatory transfer repeatedly fails on device despite automated acceptance, geometry is adjusted; movement physics are not weakened merely to fit a bad platform layout unless separately approved.

## 13. Files / Component Boundaries

Expected implementation areas:

- `Sources/PlayerMovementTuning.swift` — shared movement constants used by runtime and tests;
- `Sources/GameScene.swift` — consume shared tuning; expose only minimal traversal state needed by runtime;
- `Sources/RoomController.swift` — rebuilt ten-room blockout and enemy placement;
- `Sources/DemoTutorialController.swift` or equivalent pure state component — contextual onboarding state;
- `Sources/TraversalValidation.swift` or equivalent pure helper — deterministic geometry checks/simulation;
- `Sources/V21RuntimeInstaller.swift` / runtime installer files — render tutorial/world-state presentation as needed;
- `Tests/*` — traversal envelope, tutorial state, topology, spawn, HUD-exclusion and regression tests.

Do not fold all of these responsibilities into `GameScene`.

## 14. Out of Scope

This redesign does not add:

- more than ten required rooms;
- map UI;
- fast travel;
- new enemy archetypes;
- additional bosses;
- double jump;
- super dash;
- invulnerable dash;
- new spells;
- new resource economy;
- complex world-state simulation;
- procedural layout;
- full Hollow Knight-style nonlinear progression.

The Hollow Knight analysis informs room flow, environmental teaching, encounter placement, shortcuts, and world response. It does not expand V24 into a clone or a full game.

## 15. Definition of Done

The level rebuild is complete only when:

1. all ten approved rooms are rebuilt under this design;
2. Approach contains the contextual Move → Jump → Attack onboarding flow;
3. Focus tutorial appears only when healing is actually possible;
4. Dash Shrine and Hollow Shaft teach their abilities before testing them under pressure;
5. mandatory geometry passes automated movement/collision validation from shared runtime tuning;
6. no mandatory landing depends on near-apex, pixel-perfect, or platform-side collision behavior;
7. enemy placement follows the room-role rules;
8. world-state changes are visually readable for shrines, checkpoints, gates, shortcut, and boss completion;
9. the existing V24 progression, saves, abilities, checkpoints, shortcut, and Ash Warden remain functional;
10. all automated tests and arm64 IPA build pass;
11. real-device testing confirms the route is consistently traversable with touch controls;
12. a clean legitimate playthrough remains at least approximately 10 minutes, with 12–15 minutes the normal target.
