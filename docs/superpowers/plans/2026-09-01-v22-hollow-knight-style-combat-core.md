# V22 Hollow Knight-Style Combat Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the V21 prototype combat feel with a directional, spacing-driven combat core featuring recoil, pogo, Essence/Focus healing, boss stagger, readable Ash Warden patterns, and hit feedback while preserving the stable kinematic movement/collision solver.

**Architecture:** Keep `GameScene` as the authoritative owner of player input and kinematic velocity, but expose only narrow combat-facing hooks through named state/userData and explicit methods rather than reintroducing SpriteKit physics. Pure Swift models own directional attack state, Essence/Focus state, and boss stagger/damage responses; SpriteKit runtimes translate accepted-hit events into recoil, pogo, visuals, room combat status, and player-damage events.

**Tech Stack:** Swift, SpriteKit, UIKit, custom kinematic AABB controller, GitHub Actions macOS 15 arm64 iOS 15 compile/package pipeline.

**Spec:** `docs/superpowers/specs/2026-09-01-v22-hollow-knight-style-combat-core-design.md`

## Global Constraints

- Landscape only.
- Preserve the existing custom kinematic player controller; do not add `SKPhysicsBody` to the player.
- Keep gravity `-1700`, jump `610`, jump release `285`, run speed `315`, ground acceleration `1900`, air acceleration `1050`, ground deceleration `2400`, max fall speed `-900`.
- Keep camera zoom `1.55`.
- Preserve V21 six-room level architecture and all four normal enemy archetypes plus Ash Warden.
- PlayerHealth remains the single authority for accepted player damage and healing.
- Death still performs the V19 full scene replacement and restarts the level at 5/5 HP.
- All feature work follows RED -> GREEN TDD and exact-SHA GitHub Actions verification.

---

## File Structure

### New pure-model files

- `Sources/PlayerAttackDirection.swift` — `PlayerAttackDirection` and directional hitbox geometry contract.
- `Sources/CombatImpulse.swift` — pure result model describing player recoil or pogo requested by an accepted hit.
- `Sources/EssenceFocusController.swift` — Essence economy and Focus channel state machine.
- `Sources/PlayerVitalState.swift` — shared PlayerHealth owner/bridge used by damage and Focus systems.

### Modified pure-model files

- `Sources/AttackController.swift` — stores the attack direction selected at start and exposes the current direction for the entire swing.
- `Sources/BossController.swift` — adds hit-count stagger and explicit boss hit responses while keeping default damageability outside explicit guard.

### Modified SpriteKit integration files

- `Sources/GameScene.swift` — adds attack-direction touch gesture state, `FOCUS` control, a narrow kinematic combat impulse queue, directional attack hitbox placement, and focus movement gating. Existing collision integration functions remain the only path that moves the player through geometry.
- `Sources/V21RuntimeContext.swift` — carries shared `PlayerVitalState`, `EssenceFocusController`, and combat impulse/event bridge.
- `Sources/PlayerDamageInstaller.swift` — uses shared `PlayerVitalState`, emits accepted-damage sequence so Focus cancels, and no longer teleports the player for damage knockback.
- `Sources/MultiEnemyRuntimeInstaller.swift` — emits accepted-hit effects: Essence gain, player recoil/pogo, enemy hit reaction, and contact damage.
- `Sources/BossRuntimeInstaller.swift` — rebuilds Ash Warden runtime around readable pattern states, stagger, accepted-hit effects, and recovery as safe punish rather than exclusive vulnerability.
- `.github/workflows/build-ipa.yml` — compiles/runs new pure tests.

### New tests

- `Tests/PlayerAttackDirectionTests.swift`
- `Tests/CombatImpulseTests.swift`
- `Tests/EssenceFocusControllerTests.swift`
- `Tests/PlayerVitalStateTests.swift`
- extend `Tests/AttackControllerTests.swift`
- extend `Tests/BossControllerTests.swift`

---

### Task 1: Directional Attack Pure Contract

**Files:**
- Create: `Sources/PlayerAttackDirection.swift`
- Modify: `Sources/AttackController.swift`
- Create: `Tests/PlayerAttackDirectionTests.swift`
- Modify: `Tests/AttackControllerTests.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces:
  - `enum PlayerAttackDirection: Equatable { case horizontal, up, down }`
  - `struct AttackHitboxSpec: Equatable { let offsetX: Double; let offsetY: Double; let width: Double; let height: Double }`
  - `func hitboxSpec(facing: Double) -> AttackHitboxSpec`
  - `AttackController.currentDirection: PlayerAttackDirection`
  - `AttackController.tryStart(direction: PlayerAttackDirection) -> Bool`
- Compatibility: existing `tryStart()` remains and delegates to `.horizontal`.

- [ ] **Step 1: Write failing directional attack tests**

```swift
let horizontal = PlayerAttackDirection.horizontal.hitboxSpec(facing: 1)
expect(horizontal.offsetX > 0 && horizontal.width == 62, "horizontal hitbox faces right")
let up = PlayerAttackDirection.up.hitboxSpec(facing: -1)
expect(up.offsetY > 0 && up.height > up.width, "up attack extends vertically")
let down = PlayerAttackDirection.down.hitboxSpec(facing: 1)
expect(down.offsetY < 0 && down.height > down.width, "down attack extends below player")
```

Extend `AttackControllerTests`:

```swift
var controller = AttackController()
expect(controller.tryStart(direction: .up), "up attack starts")
expect(controller.currentDirection == .up, "direction locks for swing")
controller.update(controller.attackDuration)
expect(controller.currentDirection == .up, "completed swing preserves last direction until next start")
controller.update(controller.cooldownDuration)
expect(controller.tryStart(direction: .down), "down attack starts after cooldown")
expect(controller.currentDirection == .down, "new swing replaces direction")
```

- [ ] **Step 2: Run RED in Actions**

Add workflow commands:

```bash
xcrun swiftc Tests/PlayerAttackDirectionTests.swift Sources/PlayerAttackDirection.swift -o build/PlayerAttackDirectionTests
./build/PlayerAttackDirectionTests
xcrun swiftc Tests/AttackControllerTests.swift Sources/AttackController.swift Sources/PlayerAttackDirection.swift -o build/AttackControllerTests
./build/AttackControllerTests
```

Expected: FAIL because `PlayerAttackDirection.swift` / directional APIs do not exist.

- [ ] **Step 3: Implement minimal pure contract**

Use these initial hitbox specs:

```swift
enum PlayerAttackDirection: Equatable {
    case horizontal
    case up
    case down

    func hitboxSpec(facing: Double) -> AttackHitboxSpec {
        switch self {
        case .horizontal:
            return AttackHitboxSpec(offsetX: 50 * facing, offsetY: 2, width: 62, height: 42)
        case .up:
            return AttackHitboxSpec(offsetX: 8 * facing, offsetY: 48, width: 42, height: 64)
        case .down:
            return AttackHitboxSpec(offsetX: 6 * facing, offsetY: -50, width: 42, height: 64)
        }
    }
}
```

Modify `AttackController` so `tryStart(direction:)` stores `currentDirection` and the old `tryStart()` calls `tryStart(direction: .horizontal)`.

- [ ] **Step 4: Run GREEN**

Expected: both directional tests PASS plus all existing pure tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/PlayerAttackDirection.swift Sources/AttackController.swift Tests/PlayerAttackDirectionTests.swift Tests/AttackControllerTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: add directional melee contract"
```

---

### Task 2: Kinematic Combat Impulses

**Files:**
- Create: `Sources/CombatImpulse.swift`
- Create: `Tests/CombatImpulseTests.swift`
- Modify: `Sources/GameScene.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces:
  - `enum CombatImpulseKind: Equatable { case recoil, pogo }`
  - `struct CombatImpulse: Equatable { let kind: CombatImpulseKind; let velocityX: Double?; let velocityY: Double? }`
  - `GameScene.enqueueCombatImpulse(_:)`
- `GameScene` applies queued impulse values to its existing private `velocity` before gravity/integration; it never changes `player.position` directly for V22 attacker recoil/pogo.

- [ ] **Step 1: Write failing pure tests**

```swift
let recoil = CombatImpulse.recoil(direction: -1, speed: 240)
expect(recoil.kind == .recoil, "recoil kind")
expect(recoil.velocityX == -240, "recoil points away from target")
expect(recoil.velocityY == nil, "horizontal recoil preserves vertical velocity")

let pogo = CombatImpulse.pogo(verticalSpeed: 465)
expect(pogo.kind == .pogo, "pogo kind")
expect(pogo.velocityY == 465, "pogo sets upward velocity")
expect(pogo.velocityX == nil, "pogo preserves horizontal velocity")
```

- [ ] **Step 2: Run RED**

Expected: missing `CombatImpulse.swift`.

- [ ] **Step 3: Implement pure model and narrow GameScene hook**

```swift
struct CombatImpulse: Equatable {
    let kind: CombatImpulseKind
    let velocityX: Double?
    let velocityY: Double?

    static func recoil(direction: Double, speed: Double = 240) -> CombatImpulse {
        CombatImpulse(kind: .recoil, velocityX: direction >= 0 ? speed : -speed, velocityY: nil)
    }

    static func pogo(verticalSpeed: Double = 465) -> CombatImpulse {
        CombatImpulse(kind: .pogo, velocityX: nil, velocityY: verticalSpeed)
    }
}
```

In `GameScene`, add `private var pendingCombatImpulses: [CombatImpulse] = []` and an internal method:

```swift
func enqueueCombatImpulse(_ impulse: CombatImpulse) {
    pendingCombatImpulses.append(impulse)
}
```

At the beginning of `update`, before gravity:

```swift
for impulse in pendingCombatImpulses {
    if let x = impulse.velocityX { velocity.dx = CGFloat(x) }
    if let y = impulse.velocityY {
        velocity.dy = CGFloat(y)
        isGrounded = false
        coyoteRemaining = 0
    }
}
pendingCombatImpulses.removeAll(keepingCapacity: true)
```

- [ ] **Step 4: Run GREEN + arm64 app compile**

Expected: pure tests PASS and full app compile PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/CombatImpulse.swift Sources/GameScene.swift Tests/CombatImpulseTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: add kinematic combat impulses"
```

---

### Task 3: Shared Player Vital Authority + Essence/Focus Pure State

**Files:**
- Create: `Sources/PlayerVitalState.swift`
- Create: `Sources/EssenceFocusController.swift`
- Create: `Tests/PlayerVitalStateTests.swift`
- Create: `Tests/EssenceFocusControllerTests.swift`
- Modify: `Sources/V21RuntimeContext.swift`
- Modify: `Sources/PlayerDamageInstaller.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces:
  - `final class PlayerVitalState` containing the single `PlayerHealth` instance and `acceptedDamageSequence`.
  - `EssenceFocusController(maxEssence: 100, essencePerHit: 34, healCost: 100, focusDuration: 1.0)`.
  - `gainFromAcceptedMeleeHit()`, `beginFocus(currentHP:maxHP:)`, `updateFocus(dt:)`, `cancelFocus()`, `consumeCompletedHeal() -> Bool`.
- `V21RuntimeContext` owns `vitals` and `focus`.
- `PlayerDamageInstaller` mutates `context.vitals.health` instead of a private health copy and increments `acceptedDamageSequence` only when `PlayerHealth.applyHit` returns true.

- [ ] **Step 1: Write failing PlayerVitalState test**

```swift
let vitals = PlayerVitalState(maxHP: 5, invulnerabilityDuration: 0.65)
expect(vitals.health.hp == 5, "starts full")
expect(vitals.applyDamage(damage: 1, attackID: 7), "first damage accepted")
expect(vitals.health.hp == 4, "shared HP changes")
expect(vitals.acceptedDamageSequence == 1, "accepted damage emits sequence")
expect(!vitals.applyDamage(damage: 1, attackID: 8), "i-frames reject immediate damage")
expect(vitals.acceptedDamageSequence == 1, "rejected damage does not emit sequence")
```

- [ ] **Step 2: Write failing Essence/Focus tests**

```swift
var focus = EssenceFocusController()
focus.gainFromAcceptedMeleeHit()
focus.gainFromAcceptedMeleeHit()
expect(focus.essence == 68, "two hits grant 68 Essence")
focus.gainFromAcceptedMeleeHit()
expect(focus.essence == 100, "Essence caps at 100")
expect(focus.beginFocus(currentHP: 4, maxHP: 5), "focus starts with full resource and missing HP")
focus.updateFocus(dt: 0.50)
expect(!focus.consumeCompletedHeal(), "half channel does not heal")
focus.updateFocus(dt: 0.50)
expect(focus.consumeCompletedHeal(), "full channel completes one heal")
expect(focus.essence == 0, "completed heal spends Essence")
```

Add interruption test:

```swift
focus.gainFromAcceptedMeleeHit(); focus.gainFromAcceptedMeleeHit(); focus.gainFromAcceptedMeleeHit()
expect(focus.beginFocus(currentHP: 4, maxHP: 5), "second focus starts")
focus.cancelFocus()
expect(!focus.consumeCompletedHeal(), "cancelled focus does not heal")
expect(focus.essence == 100, "cancelled focus does not spend Essence")
```

- [ ] **Step 3: Run RED**

Expected: missing new files.

- [ ] **Step 4: Implement minimal models and migrate damage authority**

`PlayerVitalState.applyDamage` calls `health.applyHit`; on true increments `acceptedDamageSequence`.

`EssenceFocusController` uses exact initial values `100 / 34 / 100 / 1.0 s` and only spends resource when the channel completes successfully.

- [ ] **Step 5: Run GREEN + all player-health regression tests**

Expected: new tests PASS, `PlayerHealthTests` PASS, full app compile PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/PlayerVitalState.swift Sources/EssenceFocusController.swift Sources/V21RuntimeContext.swift Sources/PlayerDamageInstaller.swift Tests/PlayerVitalStateTests.swift Tests/EssenceFocusControllerTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: add shared vitals and focus resource"
```

---

### Task 4: Mobile Directional Attack + FOCUS Input

**Files:**
- Modify: `Sources/GameScene.swift`
- Modify: `Sources/V21RuntimeContext.swift`

**Interfaces:**
- Consumes: `PlayerAttackDirection`, `EssenceFocusController`, `PlayerVitalState`.
- Produces scene runtime state through player `userData`:
  - `attackDirection` as `"horizontal" | "up" | "down"`.
  - `attackSequenceID` as `NSNumber`.
- FOCUS button drives `context.focus`; attack/jump cancel Focus.

- [ ] **Step 1: Add deterministic attack-direction resolver helper in `GameScene`**

Use ATTACK touch start point and current/moved point in SKView coordinates. Initial thresholds:

```swift
let dx = current.x - start.x
let dy = current.y - start.y
if abs(dy) < 28 { return .horizontal }
if dy < -28 { return .up }
if dy > 28 && !isGrounded { return .down }
return .horizontal
```

UIKit y increases downward, so upward flick is negative `dy`.

- [ ] **Step 2: Change ATTACK activation contract**

ATTACK should no longer start immediately in `touchesBegan`. Store the ATTACK touch origin; start on touch release or once directional threshold is crossed. Ensure a simple tap still starts `.horizontal`.

When an attack starts:

```swift
attackController.tryStart(direction: direction)
attackFacing = facing
attackSequenceID += 1
player.userData?["attackDirection"] = direction.rawValue
player.userData?["attackSequenceID"] = NSNumber(value: attackSequenceID)
```

- [ ] **Step 3: Update attack hitbox node placement per direction**

Use `attackController.currentDirection.hitboxSpec(facing: Double(attackFacing))` to set node position and path/size. The authoritative damage rectangle consumed by runtimes must match this spec rather than assuming 62x42 horizontal geometry.

- [ ] **Step 4: Add FOCUS control**

Add `case focus` to `Control`, a circular button and `FOCUS` label. Put FOCUS between ATTACK and JUMP without overlapping hit radii; acceptance target positions around 66%, 78%, 90% of width for FOCUS/ATTACK/JUMP can be tuned to fit.

While FOCUS is held:

```swift
if !context.focus.isFocusing {
    _ = context.focus.beginFocus(currentHP: context.vitals.health.hp, maxHP: context.vitals.health.maxHP)
}
```

Each frame update Focus. On completion, call `context.vitals.heal(1)` and refresh HUD through the shared vital state. Attack/jump cancel Focus. Accepted player damage cancels Focus by detecting a changed `acceptedDamageSequence`.

- [ ] **Step 5: Compile iOS app**

Expected: arm64 iOS compile succeeds; existing movement constants are unchanged.

- [ ] **Step 6: Commit**

```bash
git add Sources/GameScene.swift Sources/V21RuntimeContext.swift
git commit -m "feat: add directional attack and focus input"
```

---

### Task 5: Normal Enemy Recoil, Pogo, Essence, and Contact Danger

**Files:**
- Modify: `Sources/MultiEnemyRuntimeInstaller.swift`
- Modify: `Sources/EnemyRuntimeModel.swift` only if contact-harmless/dead state needs a pure flag.
- Extend: `Tests/EnemyRuntimeModelTests.swift` if model changes.

**Interfaces:**
- Consumes player `attackDirection`, per-swing ID, `GameScene.enqueueCombatImpulse`, `context.focus.gainFromAcceptedMeleeHit()`.
- Produces accepted-hit flow:
  - horizontal/up accepted hit -> target reaction + Essence + horizontal player recoil.
  - down accepted hit while airborne -> target reaction + Essence + pogo impulse.

- [ ] **Step 1: Replace hard-coded 62x42 attack rectangle with direction-aware rectangle**

Read current attack direction from `player.userData` or `AttackController` bridge and use the exact `AttackHitboxSpec` geometry.

- [ ] **Step 2: On accepted normal-enemy hit, emit one combat impulse**

```swift
switch direction {
case .down:
    sceneAsGameScene.enqueueCombatImpulse(.pogo(verticalSpeed: 465))
case .horizontal, .up:
    let away: Double = player.position.x >= enemy.node.position.x ? 1 : -1
    sceneAsGameScene.enqueueCombatImpulse(.recoil(direction: away, speed: 240))
}
context.focus.gainFromAcceptedMeleeHit()
```

Do not grant Essence or recoil on duplicate/rejected hits.

- [ ] **Step 3: Add contact damage for living non-stunned normal enemies**

Use a body rectangle per archetype. Contact damage enters `context.damageInbox` and relies on PlayerHealth i-frames. Do not emit contact damage while enemy is dead or in hit-stun.

- [ ] **Step 4: Add local impact feedback**

For accepted hits: 35–55 ms local combat presentation freeze effect (do not pause the full scene), target flash, short camera impulse action, and existing enemy knockback.

- [ ] **Step 5: Full compile/regression run**

Expected: all pure tests and arm64 compile PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/MultiEnemyRuntimeInstaller.swift Sources/EnemyRuntimeModel.swift Tests/EnemyRuntimeModelTests.swift
git commit -m "feat: add recoil pogo and contact combat"
```

---

### Task 6: Ash Warden Stagger and Explicit Hit Response

**Files:**
- Modify: `Sources/BossController.swift`
- Modify: `Tests/BossControllerTests.swift`

**Interfaces:**
- Produces:
  - `enum BossHitResponse: Equatable { case accepted, blocked, staggered, defeated }`
  - `BossPatternStage` gains `.staggered`.
  - `BossController.applyPlayerHit(damage:) -> BossHitResponse`.
  - `staggerHitCount`, phase-specific threshold `6` in phase one / `7` in phase two.
  - stagger duration `1.45 s` initial target.
- Default damageability remains active during idle/telegraph/committed/recovery/stagger; only explicit guard returns `.blocked` if guard is later added.

- [ ] **Step 1: Write RED boss tests**

```swift
var boss = BossController()
expect(boss.applyPlayerHit(damage: 1) == .accepted, "idle boss takes damage")
_ = boss.begin(pattern: .slash)
expect(boss.stage == .telegraph, "slash telegraphs")
expect(boss.applyPlayerHit(damage: 1) == .accepted, "telegraph boss remains damageable")
boss.update(dt: boss.telegraphDuration(for: .slash))
expect(boss.stage == .committed, "slash commits")
expect(boss.applyPlayerHit(damage: 1) == .accepted, "committed boss remains damageable")
```

Stagger test:

```swift
var staggerBoss = BossController()
for _ in 0..<5 { expect(staggerBoss.applyPlayerHit(damage: 1) == .accepted, "pre-stagger hit") }
expect(staggerBoss.applyPlayerHit(damage: 1) == .staggered, "sixth phase-one hit staggers")
expect(staggerBoss.stage == .staggered, "boss enters stagger stage")
staggerBoss.update(dt: 1.44)
expect(staggerBoss.stage == .staggered, "stagger persists for target duration")
staggerBoss.update(dt: 0.02)
expect(staggerBoss.stage == .idle, "stagger ends cleanly")
```

- [ ] **Step 2: Run RED**

Expected: missing `BossHitResponse` / stagger behavior.

- [ ] **Step 3: Implement minimal stagger state**

Normal hits never cancel a committed pattern unless the hit crosses the stagger threshold. A stagger-triggering hit explicitly sets stage to `.staggered`, clears current pattern, and starts 1.45 s stagger timer.

Phase transition to phase two re-bases `staggerHitCount = 0`.

- [ ] **Step 4: Run GREEN**

Expected: extended BossController tests PASS and all previous pure tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/BossController.swift Tests/BossControllerTests.swift
git commit -m "feat: add Ash Warden stagger contract"
```

---

### Task 7: Rebuild Ash Warden Runtime Around Read-Dodge-Punish

**Files:**
- Modify: `Sources/BossRuntimeInstaller.swift`

**Interfaces:**
- Consumes `BossHitResponse`, directional hitbox spec, combat impulses, Essence/Focus.
- Keeps three patterns: Slash, Charge, Ash Volley.

- [ ] **Step 1: Make player hits direction-aware and always legal outside explicit block**

Remove any concept of recovery-only vulnerability. For every accepted hit response:

- decrement HP via `BossController`;
- grant 34 Essence;
- horizontal/up hit -> weak attacker recoil (boss displacement remains negligible);
- down hit -> pogo 465;
- flash boss and issue local hit-stop/camera impulse;
- `.staggered` -> cancel active boss damage source/projectile spawning for the current pattern and show `STAGGERED`;
- `.defeated` -> existing combatStatus clear/death flow.

- [ ] **Step 2: Rewrite Slash timing contract**

Keep readable stages:

```text
telegraph ~0.38 s -> active slash ~0.18 s -> recovery ~0.76 s
```

Only active slash rect can enqueue 2 damage. Boss remains damageable in all three stages.

- [ ] **Step 3: Rewrite Charge timing contract**

Direction locks when entering committed state. Charge collision can damage once per commit. On end, movement stops for ~0.98 s phase-one recovery. Pogo over the boss remains possible because down-hit detection uses attack rectangle rather than forcing body overlap.

- [ ] **Step 4: Rewrite Volley timing contract**

Projectile spawn occurs exactly once on commit. Phase I spawns 3 readable lanes; Phase II 5 lanes. Recovery target ~1.10 s phase one. Projectiles still disappear on player contact even if i-frames reject HP loss.

- [ ] **Step 5: Present stagger and recovery clearly**

- recovery: core bright/open and label `RECOVER`;
- stagger: stronger pulse, label `STAGGERED`, no attack damage sources;
- phase II: existing visual phase change retained.

- [ ] **Step 6: Compile and run all tests**

Expected: all pure tests PASS, arm64 app compile/package PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/BossRuntimeInstaller.swift
git commit -m "feat: rebuild Ash Warden combat loop"
```

---

### Task 8: Focus HUD, Healing Integration, and Final Combat Feedback

**Files:**
- Modify: `Sources/PlayerDamageInstaller.swift`
- Modify: `Sources/GameScene.swift`
- Modify: `Sources/V21RuntimeContext.swift`

**Interfaces:**
- Player HP HUD reads `context.vitals.health` every refresh.
- Essence meter shows `0...100`.
- Focus channel progress is visible while holding FOCUS.

- [ ] **Step 1: Add `PlayerVitalState.heal(_:)`**

Test first if not already covered:

```swift
vitals.update(0.65)
expect(vitals.heal(1), "missing HP can heal")
expect(vitals.health.hp == 5, "heal restores exactly one HP")
expect(!vitals.heal(1), "cannot heal above max HP")
```

- [ ] **Step 2: Add Essence/Focus HUD**

Under/near Player HP, show:

```text
ESSENCE  68/100
FOCUS [progress bar while channeling]
```

Update from `context.focus` each frame without creating duplicate actions/HUD nodes on room transitions.

- [ ] **Step 3: Complete Focus heal only through shared vitals**

When `consumeCompletedHeal()` returns true, call `context.vitals.heal(1)` and refresh HP HUD. If acceptedDamageSequence changes while focusing, call `cancelFocus()` before completion.

- [ ] **Step 4: Verify death/respawn resets V22 state**

Fresh scene bootstrap must produce 5/5 HP, 0 Essence, no active Focus, no queued combat impulse, room 1.

- [ ] **Step 5: Full regression run**

Required test stages:

```text
AttackController
EnemyHealth
EnemyAIController
PlayerHealth
PlayerRespawnSequence
RoomController
EnemyArchetype
EnemyRuntimeModel
ProjectileController
PlayerDamageInbox
BossController
PlayerAttackDirection
CombatImpulse
PlayerVitalState
EssenceFocusController
```

Then arm64 iOS compile, package unsigned IPA, upload artifact.

- [ ] **Step 6: Commit**

```bash
git add Sources/PlayerDamageInstaller.swift Sources/GameScene.swift Sources/V21RuntimeContext.swift Sources/PlayerVitalState.swift Tests/PlayerVitalStateTests.swift
git commit -m "feat: finish V22 focus and combat feedback"
```

---

### Task 9: Exact-SHA Verification and Acceptance IPA

**Files:** none unless verification reveals a defect.

- [ ] **Step 1: Verify final main SHA**

Fetch repository/commit and record exact HEAD SHA.

- [ ] **Step 2: Verify the GitHub Actions run whose `head_sha` equals final HEAD**

Require every test step, arm64 compile, package, and artifact upload to be `success`.

- [ ] **Step 3: Verify artifact belongs to exact final SHA**

Artifact metadata `workflow_run.head_sha` must equal final HEAD.

- [ ] **Step 4: Download and inspect IPA**

Extract artifact ZIP, locate `.ipa`, run ZIP integrity test, verify:

```text
Payload/AshenHollow.app/AshenHollow
Payload/AshenHollow.app/Info.plist
```

Calculate IPA SHA-256.

- [ ] **Step 5: Device acceptance checklist**

Ask user to verify on iPhone:

1. tap ATTACK = horizontal;
2. up flick = upward attack;
3. airborne down flick = down attack and successful pogo;
4. normal hit causes separation/recoil instead of mandatory trade;
5. Heavy remains hard to knock back;
6. contact danger obeys i-frames;
7. Essence gains once per accepted hit;
8. Focus heals one HP after full channel and cancels on damage/attack/jump;
9. Ash Warden can be damaged during telegraph/attack/recovery if reachable;
10. Slash/Charge/Volley damage only during readable active windows;
11. stagger triggers predictably and creates a large opening;
12. Phase II remains playable;
13. death restarts at Room 1 with 5/5 HP and 0 Essence;
14. run/jump/collision/camera remain stable.

V22 becomes stable only after device acceptance.
