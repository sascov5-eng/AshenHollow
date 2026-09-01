# V23 Combat Controls + Focus Reliability + Ranged Rebalance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace V22 swipe-based attack input with immediate D-pad-directed melee, make Focus completion atomic and reliable, and rebalance the Ranged enemy around readable aim/fire/recovery/retreat windows.

**Architecture:** Keep `GameScene` as the owner of touch input and the existing kinematic player controller, but move attack-direction selection and Ranged combat timing into small pure Swift models. `EssenceFocusController` remains the pure Focus state machine and `PlayerVitalState` remains the HP authority. SpriteKit runtimes consume those pure contracts without changing gravity, movement, collision, camera, or player physics architecture.

**Tech Stack:** Swift, SpriteKit, UIKit, custom kinematic AABB controller, GitHub Actions on macOS 15, arm64 iOS 15 compile/package pipeline.

**Spec:** `docs/superpowers/specs/2026-09-01-v23-combat-controls-ranged-rebalance-design.md`

## Global Constraints

- Landscape only.
- No `SKPhysicsBody` on the player.
- Gravity remains `-1700`.
- Jump velocity remains `610`.
- Jump release velocity remains `285`.
- Run speed remains `315`.
- Ground acceleration remains `1900`.
- Air acceleration remains `1050`.
- Ground deceleration remains `2400`.
- Max fall speed remains `-900`.
- Camera zoom remains `1.55`.
- Keep V21 six-room level architecture and V22 boss combat/stagger unless a regression is discovered.
- Player damage still uses `PlayerVitalState` / `PlayerHealth` as the single HP authority.
- Death still replaces the scene and restarts at Room 1 with `5/5 HP`, `0 Essence`, and no active Focus.
- All behavior changes use RED -> GREEN TDD before production code.

---

## File Structure

### New pure-model files

- `Sources/DPadAttackDirectionResolver.swift` — resolves `.horizontal`, `.up`, or `.down` from held vertical D-pad state and grounded state.
- `Sources/RangedCombatController.swift` — deterministic Ranged state machine for aim, fire, recovery, retreat burst, and retreat cooldown.
- `Sources/TouchRetentionPolicy.swift` — pure distance-based policy for keeping an already-owned Focus touch despite small finger drift.

### New tests

- `Tests/DPadAttackDirectionResolverTests.swift`
- `Tests/RangedCombatControllerTests.swift`
- `Tests/TouchRetentionPolicyTests.swift`

### Modified files

- `Sources/GameScene.swift` — four-direction D-pad HUD/input, immediate ATTACK on touch-down, held-direction attack selection, Focus touch ownership.
- `Sources/EssenceFocusController.swift` — atomic Focus completion; remove confirmation-frame race.
- `Tests/EssenceFocusControllerTests.swift` — regression coverage for release-after-completion and pre-completion cancellation.
- `Sources/EnemyArchetype.swift` — V23 Ranged balance values.
- `Sources/MultiEnemyRuntimeInstaller.swift` — integrate `RangedCombatController`, stronger AIM presentation, finite retreat behavior.
- `Sources/RoomController.swift` — Watcher Hall composition becomes Ranged + Grunt.
- `Tests/RoomControllerTests.swift` — verify V23 Watcher Hall composition.
- `.github/workflows/build-ipa.yml` — run new pure test executables.

---

### Task 1: Pure D-pad Attack Direction Contract

**Files:**
- Create: `Sources/DPadAttackDirectionResolver.swift`
- Create: `Tests/DPadAttackDirectionResolverTests.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Consumes: existing `PlayerAttackDirection`.
- Produces:
  - `struct DPadAttackDirectionResolver`
  - `static func resolve(upHeld: Bool, downHeld: Bool, isGrounded: Bool) -> PlayerAttackDirection`

- [ ] **Step 1: Write the failing test**

Create `Tests/DPadAttackDirectionResolverTests.swift`:

```swift
import Foundation

@inline(__always)
func expectDPad(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct DPadAttackDirectionResolverTestsMain {
    static func main() {
        expectDPad(
            DPadAttackDirectionResolver.resolve(
                upHeld: false,
                downHeld: false,
                isGrounded: true
            ) == .horizontal,
            "no vertical modifier gives horizontal attack"
        )
        expectDPad(
            DPadAttackDirectionResolver.resolve(
                upHeld: true,
                downHeld: false,
                isGrounded: true
            ) == .up,
            "UP gives up-slash"
        )
        expectDPad(
            DPadAttackDirectionResolver.resolve(
                upHeld: false,
                downHeld: true,
                isGrounded: false
            ) == .down,
            "airborne DOWN gives down-slash"
        )
        expectDPad(
            DPadAttackDirectionResolver.resolve(
                upHeld: false,
                downHeld: true,
                isGrounded: true
            ) == .horizontal,
            "grounded DOWN falls back to horizontal"
        )
        expectDPad(
            DPadAttackDirectionResolver.resolve(
                upHeld: true,
                downHeld: true,
                isGrounded: false
            ) == .up,
            "UP wins deterministic conflict"
        )
        print("DPadAttackDirectionResolverTests: PASS")
    }
}
```

- [ ] **Step 2: Add the workflow test command and run RED**

Add:

```bash
xcrun swiftc \
  Tests/DPadAttackDirectionResolverTests.swift \
  Sources/DPadAttackDirectionResolver.swift \
  Sources/PlayerAttackDirection.swift \
  -o build/DPadAttackDirectionResolverTests
./build/DPadAttackDirectionResolverTests
```

Expected: FAIL because `Sources/DPadAttackDirectionResolver.swift` does not exist.

- [ ] **Step 3: Implement the minimal resolver**

Create `Sources/DPadAttackDirectionResolver.swift`:

```swift
import Foundation

struct DPadAttackDirectionResolver {
    static func resolve(
        upHeld: Bool,
        downHeld: Bool,
        isGrounded: Bool
    ) -> PlayerAttackDirection {
        if upHeld { return .up }
        if downHeld && !isGrounded { return .down }
        return .horizontal
    }
}
```

- [ ] **Step 4: Run GREEN**

Expected: `DPadAttackDirectionResolverTests: PASS` plus all existing pure tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/DPadAttackDirectionResolver.swift Tests/DPadAttackDirectionResolverTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: add dpad attack direction resolver"
```

---

### Task 2: Immediate ATTACK + Four-Direction D-pad Integration

**Files:**
- Modify: `Sources/GameScene.swift`
- Optional cleanup after GREEN: remove `Sources/AttackGestureResolver.swift` and `Tests/AttackGestureResolverTests.swift` only if nothing else references them.
- Modify: `.github/workflows/build-ipa.yml` only if the gesture test is removed.

**Interfaces:**
- Consumes: `DPadAttackDirectionResolver.resolve(upHeld:downHeld:isGrounded:)`.
- Produces no new cross-file API.
- Existing `tryAttack(direction:)` remains the single attack-start path.

- [ ] **Step 1: Replace left-side control enum and held-state interpretation**

Change `Control` to include:

```swift
case left
case right
case up
case down
case focus
case attack
case jump
```

Do not make UP/DOWN alter `moveInput`. `recalculateMoveInput()` continues to derive horizontal input only from LEFT/RIGHT.

- [ ] **Step 2: Build a four-direction D-pad HUD**

Add `upButton`, `downButton`, `upArrow`, and `downArrow` beside the existing LEFT/RIGHT nodes. Use a compact cross-shaped arrangement on the left side. Keep the right-side order `FOCUS`, `ATTACK`, `JUMP`.

Initial layout targets in camera coordinates:

```swift
let dpadCenterX = -halfW + 145
let dpadCenterY = -halfH + bottomPadding
leftButton.position  = CGPoint(x: dpadCenterX - 55, y: dpadCenterY)
rightButton.position = CGPoint(x: dpadCenterX + 55, y: dpadCenterY)
upButton.position    = CGPoint(x: dpadCenterX, y: dpadCenterY + 55)
downButton.position  = CGPoint(x: dpadCenterX, y: dpadCenterY - 55)

focusButton.position  = CGPoint(x: halfW - 318, y: -halfH + bottomPadding + 2)
attackButton.position = CGPoint(x: halfW - 205, y: -halfH + bottomPadding + 2)
jumpButton.position   = CGPoint(x: halfW - 88,  y: -halfH + bottomPadding + 4)
```

- [ ] **Step 3: Make ATTACK fire on touch-down**

In `touchesBegan`, when control is `.attack`, do not store a swipe origin. Resolve attack direction immediately from held controls:

```swift
let upHeld = activeControls.values.contains(.up)
let downHeld = activeControls.values.contains(.down)
let direction = DPadAttackDirectionResolver.resolve(
    upHeld: upHeld,
    downHeld: downHeld,
    isGrounded: isGrounded
)
tryAttack(direction: direction)
```

The ATTACK touch itself remains in `activeControls` only for button presentation; releasing it must not start a second attack.

- [ ] **Step 4: Remove swipe-driven attack startup**

Delete `attackTouchOrigins`, `triggeredAttackTouches`, and the ATTACK-specific `touchesMoved` / `touchesEnded` logic. `touchesEnded` for ATTACK only removes the active touch.

- [ ] **Step 5: Update touch classification**

Use four left-side hit centers matching the D-pad layout. Suggested UIKit-space centers:

```swift
let dpadX = width * 0.17
let dpadY = height * 0.80
let dpadStep = min(width, height) * 0.075

(.left,  CGPoint(x: dpadX - dpadStep, y: dpadY), 54)
(.right, CGPoint(x: dpadX + dpadStep, y: dpadY), 54)
(.up,    CGPoint(x: dpadX, y: dpadY - dpadStep), 54)
(.down,  CGPoint(x: dpadX, y: dpadY + dpadStep), 54)
```

UIKit y increases downward, so UP uses `dpadY - dpadStep`.

- [ ] **Step 6: Verify app compile and regressions**

Run the complete Actions workflow. Required checks:
- D-pad resolver PASS;
- AttackController PASS;
- PlayerAttackDirection PASS;
- full arm64 iOS compile PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/GameScene.swift Sources/AttackGestureResolver.swift Tests/AttackGestureResolverTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: switch combat input to immediate dpad attacks"
```

If gesture files remain for compatibility, omit them from `git add` and leave their workflow step intact.

---

### Task 3: Focus Completion Race Regression + Atomic Completion

**Files:**
- Modify: `Tests/EssenceFocusControllerTests.swift`
- Modify: `Sources/EssenceFocusController.swift`

**Interfaces:**
- Existing public API remains:
  - `beginFocus(currentHP:maxHP:) -> Bool`
  - `updateFocus(dt:)`
  - `cancelFocus()`
  - `consumeCompletedHeal() -> Bool`
- Behavioral change: completed Focus spends Essence at completion and produces exactly one pending heal event; `cancelFocus()` cannot erase an already-completed heal.

- [ ] **Step 1: Replace V22 confirmation-frame expectations with failing V23 regression tests**

Use:

```swift
var focus = EssenceFocusController()
focus.gainFromAcceptedMeleeHit()
focus.gainFromAcceptedMeleeHit()
focus.gainFromAcceptedMeleeHit()

expectFocus(
    focus.beginFocus(currentHP: 4, maxHP: 5),
    "focus starts with enough Essence"
)
focus.updateFocus(dt: 1.0)
expectFocus(focus.essence == 0, "completion spends Essence atomically")

focus.cancelFocus() // simulates finger release immediately after completion
expectFocus(
    focus.consumeCompletedHeal(),
    "release after completion cannot erase completed heal"
)
expectFocus(
    !focus.consumeCompletedHeal(),
    "completed heal emits exactly once"
)
```

Add cancellation-before-completion:

```swift
focus.gainFromAcceptedMeleeHit()
focus.gainFromAcceptedMeleeHit()
focus.gainFromAcceptedMeleeHit()
expectFocus(focus.beginFocus(currentHP: 4, maxHP: 5), "second focus starts")
focus.updateFocus(dt: 0.70)
focus.cancelFocus()
expectFocus(!focus.consumeCompletedHeal(), "early release cancels heal")
expectFocus(focus.essence == 100, "early cancel spends no Essence")
```

- [ ] **Step 2: Run RED**

Expected: current V22 logic fails because completion does not spend Essence immediately and `cancelFocus()` clears pending completion.

- [ ] **Step 3: Implement atomic completion**

Replace confirmation-frame state with one pending event flag:

```swift
private var completedHealPending = false
```

Update:

```swift
mutating func updateFocus(dt: TimeInterval) {
    guard isFocusing, dt > 0 else { return }

    focusRemaining = max(0, focusRemaining - dt)
    if focusRemaining == 0 {
        isFocusing = false
        essence = max(0, essence - healCost)
        completedHealPending = true
    }
}
```

Change cancellation so it cannot erase an already-completed event:

```swift
mutating func cancelFocus() {
    guard isFocusing else { return }
    isFocusing = false
    focusRemaining = 0
}
```

And consume exactly once:

```swift
mutating func consumeCompletedHeal() -> Bool {
    guard completedHealPending else { return false }
    completedHealPending = false
    return true
}
```

`beginFocus(...)` must clear any stale pending event only when starting a genuinely new channel after the prior event has already been consumed. Do not permit a new Focus while `completedHealPending == true`.

- [ ] **Step 4: Run GREEN**

Expected: EssenceFocusController tests PASS and PlayerVitalState / PlayerHealth tests remain PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/EssenceFocusController.swift Tests/EssenceFocusControllerTests.swift
git commit -m "fix: make focus completion atomic"
```

---

### Task 4: Focus Touch Ownership / Finger Drift

**Files:**
- Create: `Sources/TouchRetentionPolicy.swift`
- Create: `Tests/TouchRetentionPolicyTests.swift`
- Modify: `Sources/GameScene.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces:
  - `struct TouchRetentionPolicy`
  - `static func shouldRetain(distanceFromCenter: Double, baseRadius: Double, toleranceMultiplier: Double = 1.45) -> Bool`

- [ ] **Step 1: Write the failing pure test**

```swift
import Foundation

@inline(__always)
func expectRetention(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct TouchRetentionPolicyTestsMain {
    static func main() {
        expectRetention(
            TouchRetentionPolicy.shouldRetain(
                distanceFromCenter: 55,
                baseRadius: 56
            ),
            "touch inside base radius is retained"
        )
        expectRetention(
            TouchRetentionPolicy.shouldRetain(
                distanceFromCenter: 76,
                baseRadius: 56
            ),
            "small finger drift outside visible control is retained"
        )
        expectRetention(
            !TouchRetentionPolicy.shouldRetain(
                distanceFromCenter: 90,
                baseRadius: 56
            ),
            "large drift releases focus ownership"
        )
        print("TouchRetentionPolicyTests: PASS")
    }
}
```

- [ ] **Step 2: Run RED**

Expected: missing `TouchRetentionPolicy.swift`.

- [ ] **Step 3: Implement the pure policy**

```swift
import Foundation

struct TouchRetentionPolicy {
    static func shouldRetain(
        distanceFromCenter: Double,
        baseRadius: Double,
        toleranceMultiplier: Double = 1.45
    ) -> Bool {
        guard baseRadius > 0, toleranceMultiplier >= 1 else { return false }
        return distanceFromCenter <= baseRadius * toleranceMultiplier
    }
}
```

- [ ] **Step 4: Integrate stable FOCUS touch ownership in `GameScene`**

In `touchesMoved`, handle an existing `.focus` touch before generic reclassification:

```swift
if oldControl == .focus {
    let point = touch.location(in: skView)
    let center = CGPoint(x: skView.bounds.width * 0.62, y: skView.bounds.height * 0.80)
    let distance = hypot(point.x - center.x, point.y - center.y)

    if TouchRetentionPolicy.shouldRetain(
        distanceFromCenter: Double(distance),
        baseRadius: 56
    ) {
        activeControls[id] = .focus
        continue
    }

    cancelFocus()
    activeControls.removeValue(forKey: id)
    continue
}
```

This touch must not silently become ATTACK/JUMP after drifting out of FOCUS; it is released instead.

- [ ] **Step 5: Run GREEN + app compile**

Expected: retention test PASS and full arm64 compile PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/TouchRetentionPolicy.swift Tests/TouchRetentionPolicyTests.swift Sources/GameScene.swift .github/workflows/build-ipa.yml
git commit -m "fix: retain focus touch through finger drift"
```

---

### Task 5: Pure Ranged Combat State Machine

**Files:**
- Create: `Sources/RangedCombatController.swift`
- Create: `Tests/RangedCombatControllerTests.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces:

```swift
enum RangedCombatState: Equatable {
    case tracking
    case aiming
    case recovery
    case retreating
}

struct RangedCombatOutput: Equatable {
    let state: RangedCombatState
    let shouldFire: Bool
    let movementDirection: Double
}
```

- `RangedCombatController` initial V23 values:
  - aimDuration `0.42`
  - recoveryDuration `0.72`
  - retreatDistanceTrigger `105`
  - retreatDuration `0.28`
  - retreatCooldown `0.85`

- [ ] **Step 1: Write RED tests for aim -> one fire -> recovery**

```swift
var ranged = RangedCombatController()

var output = ranged.update(dt: 0.01, distanceToPlayer: 220, directionToPlayer: 1)
expectRanged(output.state == .aiming, "valid range enters aim")
expectRanged(!output.shouldFire, "aim does not fire immediately")

output = ranged.update(dt: 0.40, distanceToPlayer: 220, directionToPlayer: 1)
expectRanged(!output.shouldFire, "aim remains readable before threshold")

output = ranged.update(dt: 0.02, distanceToPlayer: 220, directionToPlayer: 1)
expectRanged(output.shouldFire, "aim completion fires once")
expectRanged(output.state == .recovery, "shot enters recovery")

output = ranged.update(dt: 0.20, distanceToPlayer: 220, directionToPlayer: 1)
expectRanged(!output.shouldFire, "recovery blocks immediate second shot")
```

- [ ] **Step 2: Add RED finite-retreat tests**

```swift
var retreat = RangedCombatController()
var output = retreat.update(dt: 0.01, distanceToPlayer: 80, directionToPlayer: 1)
expectRanged(output.state == .retreating, "close player triggers retreat burst")
expectRanged(output.movementDirection == -1, "retreat moves away")

output = retreat.update(dt: 0.30, distanceToPlayer: 80, directionToPlayer: 1)
expectRanged(output.state != .retreating, "retreat burst is finite")

output = retreat.update(dt: 0.10, distanceToPlayer: 80, directionToPlayer: 1)
expectRanged(output.state != .retreating, "retreat cooldown prevents permanent kiting")
```

- [ ] **Step 3: Run RED**

Expected: missing `RangedCombatController.swift`.

- [ ] **Step 4: Implement the minimal deterministic state machine**

Use explicit timers:

```swift
struct RangedCombatController {
    let aimDuration: TimeInterval = 0.42
    let recoveryDuration: TimeInterval = 0.72
    let retreatDistanceTrigger: Double = 105
    let retreatDuration: TimeInterval = 0.28
    let retreatCooldownDuration: TimeInterval = 0.85
    let attackDistance: Double = 270

    private(set) var state: RangedCombatState = .tracking
    private var stateRemaining: TimeInterval = 0
    private var retreatCooldownRemaining: TimeInterval = 0

    mutating func update(
        dt: TimeInterval,
        distanceToPlayer: Double,
        directionToPlayer: Double
    ) -> RangedCombatOutput {
        let safeDT = max(0, dt)
        retreatCooldownRemaining = max(0, retreatCooldownRemaining - safeDT)

        switch state {
        case .aiming:
            stateRemaining = max(0, stateRemaining - safeDT)
            if stateRemaining == 0 {
                state = .recovery
                stateRemaining = recoveryDuration
                return RangedCombatOutput(state: .recovery, shouldFire: true, movementDirection: 0)
            }
            return RangedCombatOutput(state: .aiming, shouldFire: false, movementDirection: 0)

        case .recovery:
            stateRemaining = max(0, stateRemaining - safeDT)
            if stateRemaining == 0 { state = .tracking }
            return RangedCombatOutput(state: state, shouldFire: false, movementDirection: 0)

        case .retreating:
            stateRemaining = max(0, stateRemaining - safeDT)
            if stateRemaining == 0 {
                state = .tracking
                retreatCooldownRemaining = retreatCooldownDuration
                return RangedCombatOutput(state: .tracking, shouldFire: false, movementDirection: 0)
            }
            let away = directionToPlayer >= 0 ? -1.0 : 1.0
            return RangedCombatOutput(state: .retreating, shouldFire: false, movementDirection: away)

        case .tracking:
            if distanceToPlayer < retreatDistanceTrigger,
               retreatCooldownRemaining == 0 {
                state = .retreating
                stateRemaining = retreatDuration
                let away = directionToPlayer >= 0 ? -1.0 : 1.0
                return RangedCombatOutput(state: .retreating, shouldFire: false, movementDirection: away)
            }
            if distanceToPlayer <= attackDistance {
                state = .aiming
                stateRemaining = aimDuration
                return RangedCombatOutput(state: .aiming, shouldFire: false, movementDirection: 0)
            }
            return RangedCombatOutput(
                state: .tracking,
                shouldFire: false,
                movementDirection: directionToPlayer >= 0 ? 1 : -1
            )
        }
    }
}
```

- [ ] **Step 5: Run GREEN**

Expected: RangedCombatController tests PASS and existing EnemyAI tests remain PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/RangedCombatController.swift Tests/RangedCombatControllerTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: add ranged combat state machine"
```

---

### Task 6: V23 Ranged Stats + Runtime Integration

**Files:**
- Modify: `Sources/EnemyArchetype.swift`
- Modify: `Sources/MultiEnemyRuntimeInstaller.swift`

**Interfaces:**
- Consumes: `RangedCombatController`.
- Existing normal melee enemies continue using `EnemyAIController` unchanged.

- [ ] **Step 1: Update only Ranged data values**

Set Ranged stats to:

```swift
maxHP: 3,
contactDamage: 1,
patrolSpeed: 58,
chaseSpeed: 92,
detectionRange: 340,
attackRange: 270,
attackCooldown: 1.45,
attackDuration: 0.42,
hitStunDuration: 0.16,
knockbackSpeed: 320,
attackKind: .projectile
```

Projectile velocity in runtime becomes `285` instead of `325`.

- [ ] **Step 2: Give each live Ranged enemy its own controller**

Add to `V21LiveEnemy`:

```swift
var rangedCombat = RangedCombatController()
```

This controller is ignored for non-Ranged archetypes.

- [ ] **Step 3: Replace V22 Ranged branch with pure-controller output**

For Ranged enemies, calculate:

```swift
let delta = player.position.x - enemy.node.position.x
let directionToPlayer: Double = delta >= 0 ? 1 : -1
let distance = abs(Double(delta))
let rangedOutput = enemy.rangedCombat.update(
    dt: Double(dt),
    distanceToPlayer: distance,
    directionToPlayer: directionToPlayer
)
```

Presentation/movement contract:

```swift
switch rangedOutput.state {
case .aiming:
    enemy.stateLabel.text = "AIM"
    enemy.attackVisual.alpha = 0.70
case .recovery:
    enemy.stateLabel.text = "RECOVER"
    enemy.attackVisual.alpha = 0.16
case .retreating:
    enemy.stateLabel.text = "EVADE"
    enemy.attackVisual.alpha = 0
    enemy.node.position.x += CGFloat(rangedOutput.movementDirection) * CGFloat(enemy.stats.chaseSpeed * 0.72) * dt
case .tracking:
    enemy.stateLabel.text = "TRACK"
    enemy.attackVisual.alpha = 0
    enemy.node.position.x += CGFloat(rangedOutput.movementDirection) * CGFloat(enemy.stats.patrolSpeed) * dt
}
```

When `rangedOutput.shouldFire == true`, spawn exactly one projectile toward the player's current side at the fire moment. Do not use the old `pendingShotRemaining` path for Ranged.

- [ ] **Step 4: Preserve hit reaction cancellation**

When a player melee hit is accepted on Ranged:
- keep existing HP/knockback/hit-stun;
- cancel any current AIM by resetting `enemy.rangedCombat = RangedCombatController()`;
- do not spawn a projectile from a cancelled AIM.

- [ ] **Step 5: Run full workflow**

Expected:
- all Ranged pure tests PASS;
- existing EnemyRuntimeModel / ProjectileController tests PASS;
- arm64 iOS compile PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/EnemyArchetype.swift Sources/MultiEnemyRuntimeInstaller.swift
git commit -m "feat: rebalance ranged enemy combat loop"
```

---

### Task 7: Watcher Hall Pressure Reduction

**Files:**
- Modify: `Tests/RoomControllerTests.swift`
- Modify: `Sources/RoomController.swift`

**Interfaces:** none new.

- [ ] **Step 1: Write RED room-composition assertion**

Add to RoomController tests:

```swift
let controller = RoomController.makeV21Level()
let watcher = controller.definition(for: .watcherHall)
expectRoom(watcher != nil, "Watcher Hall exists")
expectRoom(watcher?.enemySpawns.count == 2, "Watcher Hall has two enemies in V23")
expectRoom(
    watcher?.enemySpawns.map(\.archetype) == [.ranged, .grunt],
    "Watcher Hall is Ranged plus Grunt"
)
```

If the existing `definition(for:)` accessor has a different name, use that existing public accessor rather than adding a duplicate API.

- [ ] **Step 2: Run RED**

Expected: current layout returns three enemies including Runner.

- [ ] **Step 3: Change Watcher Hall spawns**

Use:

```swift
enemySpawns: [
    EnemySpawn(id: 1, archetype: .ranged, position: RoomPoint(x: 900, y: 130)),
    EnemySpawn(id: 2, archetype: .grunt, position: RoomPoint(x: 620, y: 130))
]
```

- [ ] **Step 4: Run GREEN**

Expected: RoomController tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/RoomController.swift Tests/RoomControllerTests.swift
git commit -m "balance: reduce Watcher Hall pressure"
```

---

### Task 8: Full V23 Regression, Exact-SHA Verification, and IPA

**Files:** none unless verification reveals a defect.

- [ ] **Step 1: Verify final repository HEAD**

Fetch `main` and record the exact final SHA.

- [ ] **Step 2: Verify the exact-SHA GitHub Actions run**

Require these test stages to succeed:

```text
AttackController
PlayerAttackDirection
DPadAttackDirectionResolver
CombatImpulse
CombatHitStopController
PlayerVitalState
EssenceFocusController
TouchRetentionPolicy
EnemyHealth
EnemyAIController
EnemyRuntimeModel
ProjectileController
PlayerDamageInbox
RangedCombatController
RoomController
BossController
```

Then require:

```text
Compile Ashen Hollow: success
Package unsigned IPA: success
Upload IPA artifact: success
```

- [ ] **Step 3: Verify artifact provenance**

Artifact `workflow_run.head_sha` must equal the exact final HEAD SHA.

- [ ] **Step 4: Download and inspect IPA**

Verify ZIP integrity and required paths:

```text
Payload/AshenHollow.app/AshenHollow
Payload/AshenHollow.app/Info.plist
```

Calculate SHA-256 of the `.ipa`.

- [ ] **Step 5: Device acceptance checklist**

Ask the user to verify on iPhone:

1. ATTACK fires immediately on press.
2. UP + ATTACK reliably gives up-slash.
3. Airborne DOWN + ATTACK reliably gives down-slash/pogo.
4. No swipe is needed to attack.
5. LEFT/RIGHT movement feels unchanged.
6. Focus starts reliably.
7. Completing Focus and releasing immediately never loses the heal.
8. Releasing Focus early heals nothing and spends no Essence.
9. Ranged AIM is visibly readable.
10. One shot is followed by a real recovery period.
11. Ranged cannot retreat forever.
12. Watcher Hall no longer drains most HP by default.
13. Boss stagger/combat remains unchanged from V22.
14. Death still resets to Room 1 with 5/5 HP and 0 Essence.

V23 becomes stable only after device acceptance.
