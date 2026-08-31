# V21 — Combat Vertical Slice Design

## Status

Approved design direction for the first full combat-focused vertical slice on top of the user-confirmed V20 room architecture.

V20 remains the stable baseline for player movement/jump, camera follow, melee input/timing, player HP/i-frames/death/respawn, and room-local coordinates/world origins/transitions/camera clamping.

V21 expands enemy/combat/content architecture without intentionally changing the feel of the confirmed player controller.

---

## Goal

Build the first complete playable level that demonstrates:
- multiple simultaneous enemies;
- four reusable normal enemy archetypes;
- repeated and mixed enemy compositions across rooms;
- ranged projectiles;
- enemy hit reaction with hit-stun and knockback;
- one multi-pattern boss with a second phase;
- a boss health bar;
- six-room linear level progression;
- combat-gated exits;
- a final exit that unlocks only after the boss dies;
- full compatibility with V19/V20 player death and level restart.

The purpose of V21 is not final content polish. It is to create a reusable combat architecture capable of supporting future levels and enemy variations.

---

## Chosen Architecture

### Enemy model

Replace the single `testEnemy` runtime with a reusable multi-enemy system.

Use one common enemy entity/runtime plus data-driven archetype definitions instead of separate unrelated enemy classes.

Core concepts:
- `EnemyArchetype`
- `EnemyDefinition`
- `EnemySpawn`
- `EnemyRuntime`
- `EnemyCombatState`
- `EnemyHitReaction`

Each live enemy instance owns independent:
- unique instance ID;
- archetype;
- current HP;
- AI/controller state;
- current attack ID;
- attack cooldown/timing;
- facing;
- hit-stun timer;
- knockback state;
- death state;
- SpriteKit node/presentation state.

Room definitions own arrays of enemy spawns rather than one optional enemy spawn.

### Why this architecture

Rejected alternatives:

1. Duplicate the current `testEnemy` node manually for each mob.
   - Fast initially.
   - Produces duplicated HP/AI/damage code and room-specific conditionals.
   - Does not scale to mixed groups or bosses.

2. Separate independent classes for every enemy type.
   - More isolation.
   - Too much duplication while the four normal archetypes still share most locomotion/combat lifecycle behavior.

3. Shared enemy runtime + archetype data — chosen.
   - Normal enemies reuse one lifecycle.
   - Archetypes vary stats and AI parameters.
   - Boss reuses common health/damage/hurt-reaction contracts while owning a dedicated pattern controller.

---

## Player Combat Contract

The existing player melee attack remains the player's only offensive action in V21.

A player attack has one global `playerAttackID`.

For every active enemy intersected by the player melee hitbox:
- that enemy may accept damage at most once for that `playerAttackID`;
- another enemy may also accept damage from the same swing if its hurtbox also intersects;
- repeated frames of the same active melee window may not apply duplicate damage to the same enemy.

This preserves the V16 anti-double-hit contract while extending it to multiple targets.

---

## Enemy Hit Reaction — Required V21 Mechanic

The current V20 behavior allows an enemy to often complete its attack even when the player clearly hits first. V21 changes this.

On an accepted player melee hit against a normal enemy:

1. Apply player damage to the enemy.
2. Immediately cancel that enemy's currently active melee damage window.
3. Enter a short hit-stun state.
4. Apply horizontal knockback away from the player.
5. Suspend normal chase/patrol/new-attack decisions during hit-stun.
6. Resume AI when hit-stun ends if the enemy is still alive.

This means a successful first hit can interrupt an ordinary enemy instead of forcing a guaranteed damage trade.

### Archetype hit reactions

Approximate initial tuning:

| Archetype | Hit-stun | Knockback | Notes |
|---|---:|---:|---|
| Grunt | 0.16 s | medium | baseline reaction |
| Runner | 0.18 s | strong | light enemy, displaced easily |
| Heavy | 0.10 s | weak | high poise / mass |
| Ranged | 0.16 s | strong | easy to displace once reached |
| Boss | 0.06 s | very weak | feedback only; not a normal interrupt loop |

Exact pixel velocities/distances are implementation tuning values and may be adjusted during real-device testing while preserving the relative ordering above.

### Normal-enemy hit-stun rules

During hit-stun, a normal enemy:
- cannot start a new attack;
- cannot deal damage from a melee hitbox that was active before the player's accepted hit;
- does not run normal patrol/chase movement;
- may still be damaged by a later distinct player attack after normal player attack cooldown permits;
- remains subject to room boundaries.

### Boss poise / interruption rule

The boss is intentionally different from normal mobs.

A player hit on Ash Warden:
- always applies valid player damage;
- always gives a brief visual/physical reaction;
- may apply the very short boss hit-stun value;
- does **not** cancel a boss attack once that attack has entered its committed phase.

Examples:
- a Slash still in early telegraph may be briefly flinched before commitment if the pattern controller explicitly allows it;
- a committed Slash damage window is not deleted by every player tap;
- a committed Charge continues to its recovery/end condition;
- an already-fired Volley projectile remains independent of later boss hit reactions.

This prevents the boss from being permanently interrupted by the player's normal melee cadence while still making hits feel responsive.

### Knockback rules

Enemy knockback:
- is horizontal for V21;
- points away from the player at hit time;
- is clamped to the active room's legal horizontal bounds;
- may not push an enemy through a room exit or outside the active room;
- does not require introducing `SKPhysicsBody` to the player or enemy controller.

The implementation should use explicit kinematic state rather than reintroducing SpriteKit's physics solver into the confirmed player movement architecture.

---

## Normal Enemy Archetypes

### 1. Grunt

Purpose: baseline melee enemy.

Initial stats/behavior:
- HP: 3
- damage: 1 player HP
- medium movement speed
- medium detection range
- medium patrol range
- standard melee attack range
- standard melee cooldown
- medium hit-stun/knockback

The existing V17 AI behavior is the conceptual baseline for Grunt.

### 2. Runner

Purpose: fast pressure enemy.

Initial stats/behavior:
- HP: 2
- damage: 1 player HP
- faster chase speed than Grunt
- wider detection range
- shorter time to close distance
- melee range similar to Grunt
- aggressive cadence
- strong knockback when hit

Runner should feel dangerous because of movement speed, not raw durability.

### 3. Heavy

Purpose: slow durable anchor enemy.

Initial stats/behavior:
- HP: 6
- damage: 2 player HP
- slow movement
- slower attack cadence
- visibly longer wind-up/telegraph than Grunt
- larger body/hurtbox than normal enemies
- weak knockback response
- short hit-stun compared with lighter enemies

Heavy must not deliver an unreadable 2-HP attack. Its higher damage is paired with a clearer telegraph and recovery window.

### 4. Ranged

Purpose: force movement and target prioritization.

Initial stats/behavior:
- HP: 3
- projectile damage: 1 player HP
- prefers a working distance from the player
- does not intentionally rush into melee when it has space
- pauses briefly before firing
- fires a simple horizontal projectile toward the player's side
- strong knockback when the player reaches it

Ranged may reposition horizontally to avoid standing point-blank, but V21 does not require sophisticated pathfinding.

---

## Projectile System

V21 introduces a reusable projectile runtime primarily for Ranged and the boss.

A projectile owns:
- unique projectile ID;
- owner enemy instance ID;
- position;
- horizontal velocity;
- damage;
- lifetime;
- active/alive state;
- room ID or room-bound context.

Projectile rules:
- travels horizontally in V21;
- does not home after spawning;
- checks collision against the player's damage rectangle;
- if player i-frames allow damage, applies its configured damage through the same central player-health authority;
- on **any physical collision with the player**, the projectile is consumed even if player i-frames reject the damage;
- is removed when lifetime expires;
- is removed when it leaves the active room bounds;
- is removed during room transitions and full death/respawn reset;
- cannot damage its owner or other enemies.

Consuming the projectile on contact prevents a projectile from sitting inside an invulnerable player and dealing delayed damage when i-frames expire.

The system should be reusable by the boss Volley pattern.

---

## Multi-Enemy Damage to Player

Each enemy has an independent attack ID sequence.

Player i-frames remain authoritative across all enemy sources.

Therefore:
- two enemies can both attack during the same period;
- only attacks whose damage window intersects the player are candidates;
- after one accepted hit, normal player i-frames prevent instant multi-hit deletion from overlapping enemy attacks/projectiles;
- after i-frames expire, a later valid attack from any source may deal damage.

Existing V18/V19 player HP semantics remain the baseline.

---

## Boss — Ash Warden

`Ash Warden` is the working V21 boss name and may be renamed later without changing architecture.

### Core boss stats

Initial target:
- HP: 20
- larger visual/hurtbox than Heavy
- dedicated boss HP bar at the top of the camera HUD
- very weak knockback response
- very short hit-stun reaction
- committed attacks resist interruption
- cannot be stun-locked by normal player melee cadence

### Boss arena rule

The final level exit is locked while Ash Warden is alive.

After boss death:
1. boss damage sources are cancelled;
2. boss health UI enters defeated state/disappears;
3. final exit becomes active/visible;
4. player can enter it;
5. show `LEVEL COMPLETE` state.

### Boss Pattern A — Heavy Slash

Sequence:
- approach/face player at valid melee distance;
- clear telegraph/wind-up;
- enter committed state;
- wide melee damage window;
- 2 player HP damage;
- recovery period.

The player must have time to disengage after recognizing the telegraph.

### Boss Pattern B — Charge

Sequence:
- short preparation/telegraph;
- lock charge direction and enter committed state;
- horizontal charge through a meaningful portion of the arena;
- attack/contact window during charge;
- recovery after charge ends or reaches arena constraint.

Charge direction is locked at commitment rather than perfectly tracking the player throughout the charge.

### Boss Pattern C — Ash Volley

Sequence:
- stop/telegraph;
- enter committed firing state;
- fire multiple horizontal projectiles through the shared projectile runtime;
- recover before choosing another pattern.

The initial V21 volley should be readable and avoid unavoidable projectile overlap.

### Boss Phase 2

Phase 2 begins at `HP <= 10` (50% or lower).

Phase 2 changes:
- shorter recovery/cooldowns;
- faster pattern cadence;
- denser Ash Volley pattern;
- visible presentation change such as stronger glow/color shift.

Phase transition does not restore HP.

The boss remains one entity; Phase 2 is a state change, not a new boss spawn.

---

## Room / Level Composition

V21 uses six linear rooms built on the V20 local-coordinate/world-origin room architecture.

Normal enemy archetypes intentionally repeat across rooms in different combinations.

### Room 1 — Approach

Purpose:
- establish level entry;
- basic movement/platforming;
- no combat pressure.

Enemies:
- none.

### Room 2 — Lower Hall

Purpose:
- first simultaneous multi-enemy fight.

Enemies:
- 2 × Grunt.

Acceptance focus:
- independent HP;
- independent AI;
- both can be hit by one swing if physically overlapping the player's hitbox;
- hit-stun/knockback can create space.

### Room 3 — Broken Gallery

Purpose:
- combine platform traversal and asymmetric enemy speed.

Enemies:
- 1 × Grunt
- 1 × Runner

### Room 4 — Furnace Passage

Purpose:
- introduce durability and high-damage telegraph.

Enemies:
- 1 × Heavy
- 1 × Grunt

### Room 5 — Watcher Hall

Purpose:
- mixed target-priority fight.

Enemies:
- 1 × Runner
- 1 × Ranged
- 1 × Grunt

The room layout must give the Ranged enemy meaningful firing space without making its shots unavoidable.

### Room 6 — Warden Chamber

Purpose:
- boss fight and level conclusion.

Enemies:
- Ash Warden only.

After boss death:
- final exit unlocks;
- entering final exit shows `LEVEL COMPLETE`.

---

## Room Transition Rules

Normal room exits in V21 are gated by combat status when the room contains required enemies.

V21 rule:
- traversal-only Room 1 exit is immediately usable;
- combat-room exit is locked while any required enemy instance in that room remains alive;
- when all required enemies die, exit becomes active;
- final boss-room exit is locked until Ash Warden dies.

This prevents the player from simply sprinting through combat rooms without engaging the V21 systems.

If an exit is locked, it is visibly different from an active exit.

---

## Enemy Persistence and Room Lifecycle

V21 does not require persistent cleared-room state across player death.

During a normal forward room transition:
- old room enemy nodes/actions/projectiles are removed/deactivated;
- next room's enemy instances are spawned fresh from its `EnemySpawn` data;
- player HP is preserved;
- player controller state is neutralized in the same deterministic way V20 already uses for room entry.

During player death:
- V19 full scene replacement remains authoritative;
- level restarts at Room 1;
- player returns at 5/5 HP;
- all room enemies/boss/progression reset.

Current-room checkpoints are deferred.

---

## Visual Communication in Temporary Art

V21 still uses temporary procedural SpriteKit shapes, but enemy archetypes must be visually distinguishable even without final art.

Minimum differentiation:
- Grunt: baseline size/color;
- Runner: smaller/lighter silhouette;
- Heavy: larger/wider silhouette;
- Ranged: distinct color plus visible ranged-attack tell;
- Boss: substantially larger silhouette and dedicated boss UI.

Hit reaction must have visible feedback in addition to movement:
- short flash, scale/pulse, or equivalent;
- boss Phase 2 visibly changes presentation.

The exact final art style is out of scope.

---

## Compatibility Constraints

Do not intentionally regress the user-confirmed V20 baseline.

Keep:
- landscape orientation;
- camera zoom `1.55` unless a later explicit design changes it;
- player gravity/jump/run/controller constants;
- custom kinematic player collision model;
- no `SKPhysicsBody` on the player;
- horizontal movement never zeroes vertical velocity;
- V18 player i-frame semantics;
- V19 death fade/full-scene respawn behavior;
- V20 room-local coordinates and world-origin architecture.

Prefer new isolated combat/runtime files over rewriting the stable player controller.

---

## Suggested Code Boundaries

Likely V21 production files:

- `Sources/EnemyArchetype.swift`
  - normal archetype stats/configuration.

- `Sources/EnemyRuntimeModel.swift`
  - pure enemy HP/hit-dedup/hit-stun/knockback state contracts where practical.

- `Sources/EnemyAIController.swift`
  - evolve the current AI to accept archetype parameters rather than fixed constants.

- `Sources/MultiEnemyRuntimeInstaller.swift`
  - SpriteKit creation/update/removal of normal enemy instances.

- `Sources/ProjectileController.swift`
  - pure projectile lifetime/movement/contact contract.

- `Sources/ProjectileRuntimeInstaller.swift`
  - SpriteKit projectile presentation/collision integration.

- `Sources/BossController.swift`
  - pure Ash Warden pattern/phase/commit decisions where practical.

- `Sources/BossRuntimeInstaller.swift`
  - SpriteKit boss presentation, boss HP HUD, attacks and phase presentation.

- `Sources/RoomController.swift`
  - evolve `RoomDefinition` from one `enemySpawn` to `[EnemySpawn]`; add combat gating/final exit metadata.

- `Sources/RoomRuntimeInstaller.swift`
  - spawn/despawn groups, lock/unlock exits, level progression.

- `Sources/PlayerDamageInstaller.swift`
  - consume damage events from multiple melee/projectile/boss sources while preserving one central PlayerHealth/i-frame authority.

The exact split may be adjusted during implementation if a smaller boundary is clearer, but V21 must not collapse the entire multi-enemy system into `GameScene.swift`.

---

## TDD / Verification Strategy

V21 preserves all existing tests and adds focused pure tests before production implementation.

Minimum new coverage:

### Enemy archetypes
- Grunt HP/damage/speed family;
- Runner HP and faster movement intent;
- Heavy 6 HP and 2 damage;
- Ranged 3 HP/projectile attack type.

### Independent multi-enemy health
- two enemies maintain separate HP;
- one player attack ID may hit different enemies once each;
- one player attack ID cannot damage the same enemy twice.

### Hit reaction
- accepted player hit starts archetype hit-stun;
- current normal-enemy attack damage window is cancelled on accepted hit;
- hit-stun blocks starting a new normal attack;
- knockback direction is away from player;
- Heavy knockback is weaker than Grunt;
- Runner/Ranged knockback is stronger than Grunt;
- boss committed pattern is not cancelled by ordinary melee hit reaction;
- boss hit reaction does not create long stun-lock windows.

### Projectile contract
- projectile advances horizontally;
- projectile expires after lifetime;
- projectile is consumed on player contact whether or not i-frames accept damage;
- projectile deactivates outside room bounds.

### Boss
- starts in Phase 1;
- transitions to Phase 2 at HP <= 10;
- phase transition does not heal;
- committed attack state survives ordinary boss hit reaction;
- boss death is detectable;
- final exit unlock condition requires boss dead.

### Room compositions
- six rooms exist in correct order;
- Room 2 contains two Grunts;
- Room 3 contains Grunt + Runner;
- Room 4 contains Heavy + Grunt;
- Room 5 contains Runner + Ranged + Grunt;
- Room 6 contains Ash Warden;
- combat-room exits remain locked while required enemies are alive.

### Regression
Existing tests continue to cover:
- player attack controller;
- player health/i-frames;
- player respawn sequence;
- room coordinate/camera contracts;
- existing AI behavior where retained/reused.

Final CI must run all unit tests, full arm64 iOS 15 compile, unsigned IPA packaging, and artifact upload.

Final artifact must be verified against exact final HEAD and pass ZIP integrity checks before device testing.

---

## Real-Device Acceptance Criteria

V21 becomes stable only after device confirmation that:

1. V20 movement/jump/camera still feel unchanged.
2. Room 2 can display and run two Grunts simultaneously.
3. Enemies have independent HP/death states.
4. Player melee can hit multiple enemies when geometry genuinely overlaps.
5. A successful first player hit visibly interrupts ordinary enemy offense through hit-stun/knockback.
6. Runner feels materially faster than Grunt.
7. Heavy survives more hits, is harder to knock back, and its 2-HP attack is readable.
8. Ranged fires working projectiles and can be pressured/knocked back in melee.
9. Projectiles do not linger on an invulnerable player after contact.
10. Mixed Room 5 combat functions without instant multi-hit deletion through overlapping damage sources.
11. Boss HP bar works.
12. Ash Warden uses Slash, Charge and Volley patterns.
13. Boss visibly enters Phase 2 at half HP.
14. Boss cannot be permanently stun-locked or have every committed attack cancelled by normal player melee.
15. Boss death unlocks the final exit.
16. Final exit produces `LEVEL COMPLETE`.
17. Player death anywhere in the level still performs the V19 fade/respawn cycle and restarts at Room 1 with 5/5 HP.

---

## Explicitly Deferred After V21

- final character/enemy art;
- animation sprite sheets;
- loot and drops;
- XP/leveling;
- inventory;
- checkpoints;
- persistent cleared rooms after death;
- multiple levels/map selection;
- advanced navigation/pathfinding;
- jumping/flying enemies;
- status effects;
- parry/block/dodge systems;
- player weapon variety;
- save system;
- final VFX/SFX/haptics polish.

These can be layered onto the V21 enemy/room architecture later without being required for the first combat vertical slice.
