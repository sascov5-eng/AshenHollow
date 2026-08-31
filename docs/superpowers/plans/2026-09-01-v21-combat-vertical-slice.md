# V21 Combat Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single V20 test enemy with a reusable multi-enemy combat system, four normal archetypes, ranged projectiles, interrupt/knockback reactions, a six-room level, and the Ash Warden boss while preserving the user-confirmed player controller, HP, death/respawn, and camera behavior.

**Architecture:** Keep `GameScene` as the authoritative player movement/melee scene and add only narrow internal combat/level hooks. Move enemy instances, projectiles, boss patterns, room combat state, and level composition into focused V21 runtime/model files. Use one central player damage inbox consumed by `PlayerDamageInstaller` so all enemy melee/projectile/boss sources still obey the existing `PlayerHealth` i-frame authority.

**Tech Stack:** Swift 5, SpriteKit, UIKit, SwiftUI, standalone `swiftc` pure-model tests, GitHub Actions macOS 15 arm64 iOS 15 compilation, unsigned IPA packaging.

**Spec:** `docs/superpowers/specs/2026-09-01-v21-combat-vertical-slice-design.md`

## Global Constraints

- Preserve landscape orientation.
- Preserve camera zoom `1.55`.
- Preserve player gravity `-1700`, jump `610`, jump release `285`, run `315`, ground acceleration `1900`, air acceleration `1050`, ground deceleration `2400`, max fall `-900`.
- Preserve the custom kinematic player controller; do not add `SKPhysicsBody` to the player.
- Horizontal movement must never zero vertical velocity.
- Preserve V18 player i-frame semantics and V19 full-scene death/respawn.
- Preserve V20 local room coordinates and `worldOrigin` mapping.
- Ordinary enemy melee hits are interruptible by accepted player melee hits; boss committed attacks are not.
- Projectiles are consumed on player contact even when player i-frames reject damage.
- Use temporary SpriteKit shapes only; final art is out of scope.

---

## File Structure

### New production files

- `Sources/EnemyArchetype.swift` — data-only stats/config for Grunt, Runner, Heavy, Ranged, and Boss hit-reaction tuning.
- `Sources/EnemyRuntimeModel.swift` — pure per-instance HP, player-attack dedup, hit-stun, interrupt state, and knockback contract.
- `Sources/PlayerDamageInbox.swift` — shared scene-local queue of damage events from enemy melee/projectile/boss sources.
- `Sources/ProjectileController.swift` — pure projectile position/lifetime/contact lifecycle.
- `Sources/BossController.swift` — pure Ash Warden phase/pattern/commitment timing state.
- `Sources/MultiEnemyRuntimeInstaller.swift` — SpriteKit normal-enemy spawn/update/player-hit/enemy-melee/projectile integration.
- `Sources/BossRuntimeInstaller.swift` — SpriteKit boss node, patterns, boss HUD, damage events, phase presentation.

### Modified production files

- `Sources/EnemyAIController.swift` — replace fixed AI constants with injected `EnemyAIProfile`, preserving V17 behavior for the default profile.
- `Sources/RoomController.swift` — expand room IDs to six rooms, add `[EnemySpawn]`, combat-gated/final exits, ordered room access, and V21 layout.
- `Sources/RoomRuntimeInstaller.swift` — install six-room geometry, spawn/despawn room combat, gate exits, publish active room bounds, and show level completion.
- `Sources/GameScene.swift` — add narrow internal hooks for player melee snapshot, player/attack reset on room transition, and data-driven platform/world geometry; do not rewrite movement/collision algorithms.
- `Sources/PlayerDamageInstaller.swift` — remove dependency on `testEnemy`; consume `PlayerDamageInbox`; keep `PlayerHealth` as the only acceptance/i-frame authority and preserve death/respawn.
- `Sources/GameView.swift` — install V21 room/combat/damage systems in deterministic order; stop installing legacy single-enemy AI.
- `.github/workflows/build-ipa.yml` — add standalone tests for V21 pure models while keeping all existing regression tests.

### New tests

- `Tests/EnemyArchetypeTests.swift`
- `Tests/EnemyRuntimeModelTests.swift`
- `Tests/ProjectileControllerTests.swift`
- `Tests/BossControllerTests.swift`
- update `Tests/EnemyAIControllerTests.swift`
- update `Tests/RoomControllerTests.swift`

---

### Task 1: Enemy archetypes and independent hit reaction model

**Files:**
- Create: `Sources/EnemyArchetype.swift`
- Create: `Sources/EnemyRuntimeModel.swift`
- Create: `Tests/EnemyArchetypeTests.swift`
- Create: `Tests/EnemyRuntimeModelTests.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces `EnemyArchetype`, `EnemyStats`, `EnemyRuntimeModel`, `EnemyHitResult`.
- Later SpriteKit runtimes use `EnemyArchetype.stats` and one `EnemyRuntimeModel` per live enemy.

- [ ] **Step 1: Write RED archetype tests**

```swift
let grunt = EnemyArchetype.grunt.stats
expect(grunt.maxHP == 3, "grunt HP")
expect(grunt.contactDamage == 1, "grunt damage")

let runner = EnemyArchetype.runner.stats
expect(runner.maxHP == 2, "runner HP")
expect(runner.chaseSpeed > grunt.chaseSpeed, "runner faster than grunt")
expect(runner.knockbackSpeed > grunt.knockbackSpeed, "runner reacts more strongly")

let heavy = EnemyArchetype.heavy.stats
expect(heavy.maxHP == 6, "heavy HP")
expect(heavy.contactDamage == 2, "heavy damage")
expect(heavy.knockbackSpeed < grunt.knockbackSpeed, "heavy has more poise")

let ranged = EnemyArchetype.ranged.stats
expect(ranged.maxHP == 3, "ranged HP")
expect(ranged.attackKind == .projectile, "ranged uses projectiles")
```

- [ ] **Step 2: Write RED independent runtime tests**

```swift
var a = EnemyRuntimeModel(archetype: .grunt)
var b = EnemyRuntimeModel(archetype: .grunt)

expect(a.applyPlayerHit(damage: 1, playerAttackID: 7, playerX: 0, enemyX: 10), "A accepts first hit")
expect(!a.applyPlayerHit(damage: 1, playerAttackID: 7, playerX: 0, enemyX: 10), "A rejects duplicate swing")
expect(b.applyPlayerHit(damage: 1, playerAttackID: 7, playerX: 0, enemyX: 20), "B independently accepts same swing")
expect(a.hp == 2 && b.hp == 2, "separate HP")
expect(a.hitStunRemaining > 0, "hit starts stun")
expect(a.knockbackVelocity > 0, "enemy to right is knocked right")
```

Add an interruption assertion:

```swift
a.markAttackDamageWindowActive(true)
_ = a.applyPlayerHit(damage: 1, playerAttackID: 8, playerX: 0, enemyX: 10)
expect(!a.isAttackDamageWindowActive, "normal hit cancels active enemy damage window")
```

- [ ] **Step 3: Add workflow steps and run CI to verify RED**

Commands added to workflow:

```bash
xcrun swiftc Tests/EnemyArchetypeTests.swift Sources/EnemyArchetype.swift -o build/EnemyArchetypeTests
./build/EnemyArchetypeTests
xcrun swiftc Tests/EnemyRuntimeModelTests.swift Sources/EnemyArchetype.swift Sources/EnemyRuntimeModel.swift -o build/EnemyRuntimeModelTests
./build/EnemyRuntimeModelTests
```

Expected RED: missing production files/types, while all V20 regression tests pass.

- [ ] **Step 4: Implement minimal archetype stats and runtime model**

Use initial tuning:

```swift
enum EnemyAttackKind { case melee, projectile, boss }
enum EnemyArchetype { case grunt, runner, heavy, ranged, boss }

struct EnemyStats {
    let maxHP: Int
    let contactDamage: Int
    let patrolSpeed: Double
    let chaseSpeed: Double
    let detectionRange: Double
    let attackRange: Double
    let attackCooldown: TimeInterval
    let attackDuration: TimeInterval
    let hitStunDuration: TimeInterval
    let knockbackSpeed: Double
    let attackKind: EnemyAttackKind
}
```

Initial relative tuning must preserve spec ordering; exact values may be adjusted during device acceptance.

`EnemyRuntimeModel.applyPlayerHit(...)` must:
- reject dead/duplicate player attack IDs;
- decrement HP;
- set hit-stun and knockback direction/speed;
- cancel normal enemy active melee damage window;
- keep boss interruption semantics configurable through archetype.

- [ ] **Step 5: Run new tests and all existing pure tests; commit**

Expected: all standalone tests pass.

Commit: `feat: add V21 enemy archetypes and hit reaction model`

---

### Task 2: Parameterized normal-enemy AI

**Files:**
- Modify: `Sources/EnemyAIController.swift`
- Modify: `Tests/EnemyAIControllerTests.swift`

**Interfaces:**
- Consumes `EnemyStats`.
- Produces `EnemyAIProfile` and `EnemyAIController(spawnX:profile:)`.
- Keeps `EnemyAIController(spawnX:)` as a compatibility initializer using Grunt-equivalent V17 defaults until legacy callers are removed.

- [ ] **Step 1: Add RED tests for profile behavior**

```swift
let gruntProfile = EnemyAIProfile.from(stats: EnemyArchetype.grunt.stats)
let runnerProfile = EnemyAIProfile.from(stats: EnemyArchetype.runner.stats)
expect(runnerProfile.detectionRange > gruntProfile.detectionRange, "runner detects farther")
expect(runnerProfile.chaseSpeed > gruntProfile.chaseSpeed, "runner chase profile faster")
```

Test hit-stun gating at runtime layer rather than embedding hit-stun in AI: AI receives updates only when the instance runtime is not stunned.

- [ ] **Step 2: Run RED**

Expected: profile types/initializer absent.

- [ ] **Step 3: Parameterize fixed constants**

`EnemyAIProfile` contains patrol half-width, detection range, attack range, idle durations, attack duration/cooldown, patrol speed, chase speed.

`EnemyAIOutput` stays compatible; SpriteKit runtime reads profile speed rather than hard-coded `72/138`.

- [ ] **Step 4: Run `EnemyAIControllerTests` and Task 1 tests; commit**

Commit: `refactor: parameterize V21 enemy AI profiles`

---

### Task 3: Projectile lifecycle and player damage inbox

**Files:**
- Create: `Sources/ProjectileController.swift`
- Create: `Sources/PlayerDamageInbox.swift`
- Create: `Tests/ProjectileControllerTests.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- `PlayerDamageEvent { token: Int, damage: Int, sourceX: Double }`
- `PlayerDamageInbox.enqueue(damage:sourceX:) -> PlayerDamageEvent`
- `PlayerDamageInbox.drain() -> [PlayerDamageEvent]`
- `ProjectileController.update(dt:)`
- `ProjectileController.consumeOnPlayerContact() -> Bool`

- [ ] **Step 1: Write RED projectile tests**

```swift
var projectile = ProjectileController(x: 10, velocityX: 100, damage: 1, lifetime: 1.0)
projectile.update(dt: 0.25)
expect(projectile.x == 35, "projectile moves horizontally")
projectile.update(dt: 0.80)
expect(!projectile.isActive, "projectile expires")
```

Contact consumption test:

```swift
var contact = ProjectileController(x: 0, velocityX: 100, damage: 1, lifetime: 2)
expect(contact.consumeOnPlayerContact(), "first contact consumes projectile")
expect(!contact.isActive, "consumed even before damage acceptance is known")
expect(!contact.consumeOnPlayerContact(), "cannot contact twice")
```

- [ ] **Step 2: Run RED**

Expected missing `ProjectileController.swift`.

- [ ] **Step 3: Implement projectile and inbox pure contracts**

Inbox tokens must be globally unique within one scene/inbox lifetime so `PlayerHealth.applyHit(...attackID:)` can reuse the existing dedup contract without collisions between enemy instances.

- [ ] **Step 4: Run tests; commit**

Commit: `feat: add V21 projectile and player damage inbox contracts`

---

### Task 4: Ash Warden pure boss state machine

**Files:**
- Create: `Sources/BossController.swift`
- Create: `Tests/BossControllerTests.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- `BossPhase { case one, two, defeated }`
- `BossPattern { case slash, charge, volley }`
- `BossController` owns HP=20, phase threshold=10, current pattern timing, commitment and recovery.
- `applyPlayerHit(damage:)` changes HP/phase but does not cancel committed patterns.

- [ ] **Step 1: Write RED phase tests**

```swift
var boss = BossController()
expect(boss.hp == 20 && boss.phase == .one, "boss starts phase one")
boss.applyPlayerHit(damage: 10)
expect(boss.hp == 10 && boss.phase == .two, "phase two at 50 percent")
boss.applyPlayerHit(damage: 10)
expect(boss.phase == .defeated, "boss defeat")
```

- [ ] **Step 2: Write RED commitment test**

```swift
var boss = BossController()
boss.begin(pattern: .charge)
boss.advanceToCommittedForTest()
let before = boss.currentPattern
boss.applyPlayerHit(damage: 1)
expect(boss.currentPattern == before && boss.isCommitted, "player hit does not cancel committed boss attack")
```

Use a deterministic test helper or explicit `update(dt:)` durations rather than random pattern selection in tests.

- [ ] **Step 3: Run RED**

Expected missing boss production file.

- [ ] **Step 4: Implement deterministic boss timing model**

Pattern controller must expose telegraph/committed/recovery windows for SpriteKit integration. Phase 2 shortens recovery and makes Volley request more projectiles; no HP restoration.

- [ ] **Step 5: Run tests; commit**

Commit: `feat: add Ash Warden boss controller`

---

### Task 5: Six-room V21 level data and combat gating

**Files:**
- Modify: `Sources/RoomController.swift`
- Modify: `Tests/RoomControllerTests.swift`

**Interfaces:**
- Expand `RoomID` to `.approach`, `.lowerHall`, `.brokenGallery`, `.furnacePassage`, `.watcherHall`, `.wardenChamber`.
- Add `EnemySpawn { id: Int, archetype: EnemyArchetype, position: RoomPoint }`.
- `RoomDefinition.enemySpawns: [EnemySpawn]` replaces one optional `enemySpawn`.
- Add `requiresCombatClear: Bool`, `isFinalRoom: Bool` or equivalent explicit exit metadata.
- Add `orderedRoomIDs` / ordered definitions for world geometry creation.
- `RoomController.makeV21Level()` becomes the runtime layout factory.

- [ ] **Step 1: Rewrite room tests RED around V21 composition**

Required composition assertions:

```swift
expect(room(.approach).enemySpawns.isEmpty, "Room 1 no enemies")
expect(room(.lowerHall).enemySpawns.map(\.archetype) == [.grunt, .grunt], "Room 2 two grunts")
expect(Set(room(.brokenGallery).enemySpawns.map(\.archetype)) == Set([.grunt, .runner]), "Room 3 mix")
expect(Set(room(.furnacePassage).enemySpawns.map(\.archetype)) == Set([.heavy, .grunt]), "Room 4 mix")
expect(room(.watcherHall).enemySpawns.count == 3, "Room 5 three enemies")
expect(room(.wardenChamber).enemySpawns.map(\.archetype) == [.boss], "Room 6 boss")
```

Also test contiguous `worldOrigin.x` values, local→world conversion, camera clamp, sequential exits, and combat gate policy.

- [ ] **Step 2: Run RED**

Expected compile/test failure because V20 room model lacks new IDs/spawn arrays.

- [ ] **Step 3: Implement six-room data model**

Use six 1200-point-wide segments for a total temporary world width of 7200. Each room has a floor plus 1–3 raised platforms; room 5 gives Ranged a clear firing lane; room 6 is a flatter boss arena.

- [ ] **Step 4: Run room + archetype tests; commit**

Commit: `feat: define V21 six-room level composition`

---

### Task 6: GameScene bridge and data-driven world geometry

**Files:**
- Modify: `Sources/GameScene.swift`

**Interfaces:**
- Add internal read-only `PlayerMeleeSnapshot`/method returning:
  - `attackID`
  - `hitbox: CGRect?`
  - player center/facing.
- Add `resetPlayerForRoomTransition(to:)` that clears velocity, active touch controls, jump buffer, coyote/buffer state as needed, and attack state without altering controller constants.
- Add `configureLevelGeometry(worldWidth:platforms:)` that replaces `platformRects` and corresponding platform visuals while keeping the existing collision solver untouched.
- Add a narrow method/property for player damage rectangle if needed by V21 runtime.
- Add `disableLegacyTestEnemyForV21()` to hide/move/disable the old single enemy path while retaining source compatibility during migration.

- [ ] **Step 1: Add compile-only usage from a temporary/new pure-adjacent bridge consumer**

Because `GameScene` requires iOS frameworks, the red/green gate for this task is the full arm64 compile. Do not create brittle UI unit tests.

- [ ] **Step 2: Implement hooks without changing movement constants or collision algorithms**

When replacing geometry, name/remove only platform visuals; do not remove backdrop/player/camera/HUD nodes.

- [ ] **Step 3: Run all pure tests plus full iOS compile**

Expected: compile succeeds and all previous tests remain green.

- [ ] **Step 4: Commit**

Commit: `refactor: expose narrow V21 combat and level hooks`

---

### Task 7: Multi-enemy runtime, normal melee damage, ranged projectiles, and hit knockback

**Files:**
- Create: `Sources/MultiEnemyRuntimeInstaller.swift`
- Modify: `Sources/RoomRuntimeInstaller.swift`

**Interfaces:**
- `MultiEnemyRuntimeInstaller.spawn(room:on:damageInbox:)`
- `MultiEnemyRuntimeInstaller.clear(from:)`
- Shared scene/container state publishes `v21RequiredEnemiesAlive` or a typed `RoomCombatStatus` object for exit gating.
- Each enemy instance owns `EnemyRuntimeModel` + parameterized `EnemyAIController`.

- [ ] **Step 1: Spawn enemies from room data**

Create `enemyRoot`; each node gets a stable instance name such as `enemy-<room>-<spawnID>`. Give each archetype visibly distinct temporary dimensions/colors and individual HP bars.

- [ ] **Step 2: Integrate player melee snapshot**

Each frame, if `GameScene` exposes an active melee hitbox, intersect every living enemy hurtbox. Call its `EnemyRuntimeModel.applyPlayerHit(...)`. On accepted hit:
- update HP UI;
- flash/pulse;
- cancel normal active damage window through model state;
- enter hit-stun;
- apply kinematic horizontal knockback clamped to room bounds;
- start death presentation/removal at 0 HP.

- [ ] **Step 3: Integrate normal melee AI**

When not stunned/dead:
- Grunt/Runner/Heavy use parameterized AI;
- each active attack window emits at most one `PlayerDamageInbox` event token for that enemy attack ID after intersection with player hurtbox;
- Heavy event damage is 2, Grunt/Runner is 1.

- [ ] **Step 4: Integrate Ranged**

Ranged maintains preferred distance, telegraphs, and spawns horizontal projectile nodes/controllers. On player contact:
1. consume/remove projectile immediately;
2. enqueue 1 damage event;
3. let `PlayerDamageInstaller` decide whether i-frames accept damage.

- [ ] **Step 5: Publish combat clear state**

Required enemy count reaches zero only after all room `EnemySpawn`s are dead. Clear enemies/projectiles on room transition.

- [ ] **Step 6: Full iOS compile and regression tests; commit**

Commit: `feat: add V21 multi-enemy combat runtime`

---

### Task 8: Boss runtime, boss HUD, final exit and LEVEL COMPLETE

**Files:**
- Create: `Sources/BossRuntimeInstaller.swift`
- Modify: `Sources/RoomRuntimeInstaller.swift`

**Interfaces:**
- Boss runtime owns one `BossController` and uses the common damage inbox/projectile helpers.
- Publishes boss alive/defeated through the same combat status used by normal rooms.

- [ ] **Step 1: Spawn Ash Warden and boss HP HUD**

Boss node is substantially larger than normal enemies. HUD shows `ASH WARDEN` and 20/20-derived fill ratio at camera top.

- [ ] **Step 2: Implement Slash**

Telegraph → committed wide melee window → 2-damage inbox event on intersection → recovery. Accepted player hits during committed phase reduce HP and cause weak visual/kinematic reaction but do not cancel the committed window.

- [ ] **Step 3: Implement Charge**

Telegraph locks direction → committed horizontal kinematic charge clamped to boss room → contact damage token → recovery. Player hits do not reverse/cancel committed charge.

- [ ] **Step 4: Implement Volley**

Telegraph → spawn multiple shared-style horizontal projectiles → recovery. Phase 2 requests a denser but readable volley.

- [ ] **Step 5: Implement phase 2 presentation**

At HP <= 10, update glow/color and use shorter recovery/cadence from pure `BossController` without restoring HP.

- [ ] **Step 6: Defeat and level completion**

At 0 HP:
- cancel boss damage sources;
- remove/fade boss;
- mark final combat clear;
- unlock/show final exit;
- when player intersects final exit, freeze progression input as needed and show camera-HUD `LEVEL COMPLETE`.

- [ ] **Step 7: Full compile/tests; commit**

Commit: `feat: add Ash Warden boss and level completion`

---

### Task 9: Central player damage integration, V19 respawn compatibility, and installer order

**Files:**
- Modify: `Sources/PlayerDamageInstaller.swift`
- Modify: `Sources/GameView.swift`
- Modify: `Sources/RoomRuntimeInstaller.swift`

**Interfaces:**
- `PlayerDamageInstaller.install(on:inbox:)` or scene-shared inbox lookup.
- Room runtime publishes current room world min/max X for player knockback clamping.

- [ ] **Step 1: Refactor PlayerDamageInstaller away from `testEnemy`**

Drain `PlayerDamageInbox` each frame. For each event:

```swift
if runtime.health.applyHit(damage: event.damage, attackID: event.token) {
    refreshHUD()
    apply existing 34-point player knockback away from event.sourceX,
    clamped to active room bounds
    run existing i-frame blink
}
```

Continue processing events safely; once i-frames begin, later same-frame events are rejected by `PlayerHealth`.

- [ ] **Step 2: Preserve V19 death flow**

On 0 HP, use the existing pause/blackout/new `GameScene` replacement. Replacement installation order must be deterministic:
1. create/obtain `PlayerDamageInbox`;
2. install `PlayerDamageInstaller`;
3. install V21 `RoomRuntimeInstaller` which configures geometry and spawns room content;
4. do not install legacy `EnemyAIInstaller`.

- [ ] **Step 3: Update GameView with the same installation order**

Both `makeUIView` and fallback `updateUIView` use the identical V21 bootstrap.

- [ ] **Step 4: Full compile/tests and manual code review for regressions; commit**

Commit: `refactor: route V21 enemy damage through player health inbox`

---

### Task 10: Final CI verification and acceptance IPA

**Files:**
- Modify only if verification exposes an actual defect.

**Interfaces:**
- Exact final Git commit SHA.
- Exact GitHub Actions run for that SHA.
- Exact artifact whose `workflow_run.head_sha` equals final SHA.

- [ ] **Step 1: Run final GitHub Actions on final HEAD**

Require success for:
- AttackControllerTests
- EnemyHealthTests
- EnemyAIControllerTests
- PlayerHealthTests
- PlayerRespawnSequenceTests
- RoomControllerTests
- EnemyArchetypeTests
- EnemyRuntimeModelTests
- ProjectileControllerTests
- BossControllerTests
- arm64 iOS compile
- IPA package/upload.

- [ ] **Step 2: Verify exact SHA/run association**

Query workflow runs by `head_sha=<FINAL_SHA>` and confirm run `head_sha` exactly matches.

- [ ] **Step 3: Download exact artifact**

Confirm artifact `workflow_run.head_sha == FINAL_SHA` before download.

- [ ] **Step 4: Verify IPA locally**

Run ZIP integrity and assert:
- `Payload/AshenHollow.app/AshenHollow`
- `Payload/AshenHollow.app/Info.plist`

Compute local SHA-256.

- [ ] **Step 5: Device acceptance checklist**

Ask the user to test:
- Room 1 platforming and exit;
- Room 2 two Grunts independently taking damage;
- player-first melee interrupts/knocks ordinary enemies back so every hit is not a forced trade;
- Runner is visibly faster/lighter;
- Heavy survives 6 hits, hits for 2, and reacts weakly to knockback;
- Ranged shoots and projectiles disappear on contact even during player i-frames;
- mixed Room 5 fight;
- exits stay locked until required enemies die;
- Ash Warden 20 HP, boss HUD, Slash/Charge/Volley, Phase 2 at half HP;
- boss cannot be stun-locked by repeated player melee;
- boss death unlocks final exit and `LEVEL COMPLETE`;
- player death anywhere restarts at Room 1 with 5/5;
- old run/jump/melee/camera behavior still feels unchanged.

Do not mark V21 stable until device acceptance passes.

---

## Plan Self-Review

- Spec coverage: multi-enemy instances, four normal archetypes, repeated room compositions, projectiles, hit-stun/knockback, boss commitment/phase 2, boss HUD, six rooms, combat-gated exits, level completion, and V19/V20 compatibility all have explicit tasks.
- Placeholder scan: no TBD/TODO implementation gaps remain; initial tuning values intentionally stay adjustable only where the approved spec explicitly allows device tuning.
- Type consistency: room data uses `EnemySpawn`/`EnemyArchetype`; enemy runtime uses `EnemyRuntimeModel`; damage sources use one `PlayerDamageInbox`; boss and Ranged share projectile lifecycle semantics; `PlayerDamageInstaller` remains the sole owner of `PlayerHealth` acceptance/i-frames.
