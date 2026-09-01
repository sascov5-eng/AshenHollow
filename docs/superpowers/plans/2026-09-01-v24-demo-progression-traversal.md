# Ashen Hollow V24 — Demo Progression & Traversal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current Ashen Hollow prototype into a persistent vertical-slice demo with Dash, Wall Cling/Wall Jump, ability shrines, checkpoints, Continue/New Game, a spatial 10-room route, and at least 10 minutes of real gameplay before Ash Warden completion.

**Architecture:** Preserve the existing custom kinematic AABB/substep controller and keep the player free of `SKPhysicsBody`. Add isolated pure/stateful controllers for durable demo progression, Dash, and wall traversal; `GameScene` integrates those outputs with existing velocity/collision/input; `RoomController` owns V24 room data; `RoomRuntimeInstaller` loads one room's geometry, exits, enemies, shrines, and checkpoints into the scene. Durable state is JSON-encoded into `UserDefaults`, so death and app relaunch restore the latest checkpoint without losing unlocked abilities.

**Tech Stack:** Swift, SwiftUI, SpriteKit, UIKit, Foundation, GitHub Actions `macos-15`, arm64 iOS 15 build target.

**Spec:** `docs/superpowers/specs/2026-09-01-v24-demo-progression-traversal-design.md`

## Global Constraints

- Landscape only.
- No `SKPhysicsBody` on the player.
- Preserve player visual 42×64 and collider 36×60.
- Preserve gravity -1700, jump 610, jump release 285, run 315, ground acceleration 1900, air acceleration 1050, ground deceleration 2400, max fall -900.
- Preserve coyote time, jump buffering, melee/pogo, HP/i-frames, Essence/Focus, enemy damage, room combat clear logic, camera zoom 1.55, and Ash Warden state machine unless a task explicitly adds a V24 integration hook.
- Horizontal movement must never zero vertical velocity except where Dash explicitly suppresses vertical motion during its active window.
- Dash is free, has no i-frames, target cooldown 0.6 s, and one airborne use until restored.
- Wall Cling/Wall Jump is passive and has no separate HUD button.
- Dash and Wall Traversal survive death and relaunch; New Game clears them.
- Four checkpoints: Approach start, immediately after Dash acquisition, immediately after Wall Traversal acquisition, immediately before Ash Warden.
- Required progression: Approach → Lower Hall → Broken Gallery → Dash Shrine → Furnace Passage → Watcher Hall → Hollow Shaft → Ashen Ascent → Warden Gate → Warden Chamber.
- Perceived travel directions must include down, left, up, and down; the demo must not remain a horizontal-only chain.
- Normal first playthrough target: 12–15 minutes. Fast legitimate first playthrough: at least about 10 minutes.
- Do not inflate runtime with waits, slow movement, empty corridors, or inflated enemy HP.
- HUD drawing and hit testing must share the same geometry; the current fixed top HP/Essence/room overlay layout must remain intact.
- Every behavior change follows RED → GREEN → full regression verification before commit.

## File Structure Map

**Create**

- `Sources/DemoProgression.swift` — ability, shrine, checkpoint, and durable progress model.
- `Sources/DemoSaveStore.swift` — injected `UserDefaults` persistence and launch mode.
- `Sources/DashController.swift` — Dash cooldown/active/air-use state.
- `Sources/WallTraversalController.swift` — Wall Cling/Wall Jump state and same-wall lockout.
- `Tests/DemoProgressionTests.swift`
- `Tests/DemoSaveStoreTests.swift`
- `Tests/DashControllerTests.swift`
- `Tests/WallTraversalControllerTests.swift`
- `Tests/DemoRoomTopologyTests.swift`

**Modify**

- `Sources/RoomController.swift`
- `Sources/V21RuntimeContext.swift`
- `Sources/AppRoot.swift`
- `Sources/GameView.swift`
- `Sources/GameScene.swift`
- `Sources/HUDControlLayout.swift`
- `Tests/HUDControlLayoutTests.swift`
- `Sources/RoomRuntimeInstaller.swift`
- `Sources/PlayerDamageInstaller.swift`
- `Sources/BossRuntimeInstaller.swift` only if arena clearance is required.
- `.github/workflows/build-ipa.yml`

---

### Task 1: Durable Progression, Save Store, Continue, and New Game

**Files:**
- Create: `Sources/DemoProgression.swift`
- Create: `Sources/DemoSaveStore.swift`
- Create: `Tests/DemoProgressionTests.swift`
- Create: `Tests/DemoSaveStoreTests.swift`
- Modify: `Sources/RoomController.swift`
- Modify: `Sources/V21RuntimeContext.swift`
- Modify: `Sources/AppRoot.swift`
- Modify: `Sources/GameView.swift`
- Modify: `Sources/PlayerDamageInstaller.swift`
- Modify: `Sources/RoomRuntimeInstaller.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces `PlayerAbility`, `ShrineID`, `CheckpointID`, `CheckpointSnapshot`, `DemoProgressionState`.
- Produces `DemoLaunchMode`, `DemoSaveStore`, `DemoProgressionRuntime`.
- `V21RuntimeContext` gains `let progression: DemoProgressionRuntime`.
- `V21RuntimeBootstrap.install(on:launchMode:)` becomes the only scene bootstrap entry point.

- [ ] **Step 1: Write failing progression tests**

Create `Tests/DemoProgressionTests.swift`:

```swift
import Foundation

@inline(__always)
func expectProgression(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct DemoProgressionTestsMain {
    static func main() {
        var state = DemoProgressionState.fresh
        expectProgression(!state.has(.dash), "fresh state starts without Dash")
        expectProgression(!state.has(.wallTraversal), "fresh state starts without Wall Traversal")
        expectProgression(state.checkpoint.id == .approach, "fresh state uses Approach checkpoint")

        let accepted = state.claimShrine(
            .dash,
            ability: .dash,
            checkpoint: CheckpointSnapshot(
                id: .postDash,
                roomID: .dashShrine,
                spawn: RoomPoint(x: 760, y: 130)
            )
        )
        expectProgression(accepted, "first Dash shrine activation succeeds")
        expectProgression(state.has(.dash), "Dash is unlocked")
        expectProgression(state.consumedShrines.contains(.dash), "Dash shrine is consumed")
        expectProgression(state.checkpoint.id == .postDash, "Dash checkpoint activates atomically")

        let checkpointBeforeDuplicate = state.checkpoint
        let duplicate = state.claimShrine(
            .dash,
            ability: .dash,
            checkpoint: CheckpointSnapshot(
                id: .approach,
                roomID: .approach,
                spawn: RoomPoint(x: 120, y: 130)
            )
        )
        expectProgression(!duplicate, "consumed shrine cannot activate twice")
        expectProgression(state.checkpoint == checkpointBeforeDuplicate, "duplicate shrine cannot move checkpoint backward")

        state = .fresh
        expectProgression(state.unlockedAbilities.isEmpty, "New Game reset clears abilities")
        expectProgression(state.consumedShrines.isEmpty, "New Game reset clears shrine state")
        expectProgression(state.checkpoint.id == .approach, "New Game reset restores Approach")

        print("DemoProgressionTests: PASS")
    }
}
```

- [ ] **Step 2: Write failing persistence tests**

Create `Tests/DemoSaveStoreTests.swift`:

```swift
import Foundation

@inline(__always)
func expectSave(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct DemoSaveStoreTestsMain {
    static func main() {
        let suite = "AshenHollow.DemoSaveStoreTests"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = DemoSaveStore(defaults: defaults)

        expectSave(!store.hasSave, "empty store has no Continue state")

        var state = DemoProgressionState.fresh
        _ = state.claimShrine(
            .dash,
            ability: .dash,
            checkpoint: CheckpointSnapshot(
                id: .postDash,
                roomID: .dashShrine,
                spawn: RoomPoint(x: 760, y: 130)
            )
        )
        store.save(state)

        expectSave(store.hasSave, "save enables Continue")
        expectSave(store.load() == state, "save round trip preserves exact state")

        store.clear()
        expectSave(!store.hasSave, "clear removes Continue state")
        expectSave(store.load() == nil, "clear removes decodable state")
        print("DemoSaveStoreTests: PASS")
    }
}
```

- [ ] **Step 3: Add CI steps and verify RED**

Add to `.github/workflows/build-ipa.yml` before arm64 compilation:

```yaml
      - name: Test demo progression
        shell: bash
        run: |
          set -euo pipefail
          xcrun swiftc Tests/DemoProgressionTests.swift Sources/DemoProgression.swift Sources/RoomController.swift Sources/EnemyArchetype.swift -o build/DemoProgressionTests
          ./build/DemoProgressionTests
      - name: Test demo save store
        shell: bash
        run: |
          set -euo pipefail
          xcrun swiftc Tests/DemoSaveStoreTests.swift Sources/DemoSaveStore.swift Sources/DemoProgression.swift Sources/RoomController.swift Sources/EnemyArchetype.swift -o build/DemoSaveStoreTests
          ./build/DemoSaveStoreTests
```

Expected RED: missing `DemoProgression.swift` / `DemoSaveStore.swift` symbols.

- [ ] **Step 4: Make room/save primitives codable and add V24 room IDs**

In `Sources/RoomController.swift`:

```swift
enum RoomID: String, Equatable, Hashable, Codable {
    case approach
    case lowerHall
    case brokenGallery
    case dashShrine
    case furnacePassage
    case watcherHall
    case hollowShaft
    case ashenAscent
    case wardenGate
    case wardenChamber
}

struct RoomPoint: Equatable, Codable {
    let x: Double
    let y: Double
}
```

Keep compatibility aliases only if current tests/installers still need them during this task.

- [ ] **Step 5: Implement durable progression model**

Create `Sources/DemoProgression.swift`:

```swift
import Foundation

enum PlayerAbility: String, Codable, CaseIterable, Hashable {
    case dash
    case wallTraversal
}

enum ShrineID: String, Codable, CaseIterable, Hashable {
    case dash
    case wallTraversal
}

enum CheckpointID: String, Codable, CaseIterable, Hashable {
    case approach
    case postDash
    case postWallTraversal
    case preWarden
}

struct CheckpointSnapshot: Codable, Equatable {
    let id: CheckpointID
    let roomID: RoomID
    let spawn: RoomPoint
}

struct DemoProgressionState: Codable, Equatable {
    var unlockedAbilities: Set<PlayerAbility>
    var consumedShrines: Set<ShrineID>
    var checkpoint: CheckpointSnapshot

    static let fresh = DemoProgressionState(
        unlockedAbilities: [],
        consumedShrines: [],
        checkpoint: CheckpointSnapshot(
            id: .approach,
            roomID: .approach,
            spawn: RoomPoint(x: 120, y: 130)
        )
    )

    func has(_ ability: PlayerAbility) -> Bool {
        unlockedAbilities.contains(ability)
    }

    @discardableResult
    mutating func claimShrine(
        _ shrine: ShrineID,
        ability: PlayerAbility,
        checkpoint: CheckpointSnapshot
    ) -> Bool {
        guard !consumedShrines.contains(shrine) else { return false }
        consumedShrines.insert(shrine)
        unlockedAbilities.insert(ability)
        self.checkpoint = checkpoint
        return true
    }

    mutating func activateCheckpoint(_ checkpoint: CheckpointSnapshot) {
        self.checkpoint = checkpoint
    }
}
```

- [ ] **Step 6: Implement save store and runtime wrapper**

Create `Sources/DemoSaveStore.swift`:

```swift
import Foundation

enum DemoLaunchMode {
    case newGame
    case continueGame
}

struct DemoSaveStore {
    private let defaults: UserDefaults
    private let key = "ashenHollow.v24.demoProgression"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasSave: Bool {
        defaults.data(forKey: key) != nil
    }

    func load() -> DemoProgressionState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DemoProgressionState.self, from: data)
    }

    func save(_ state: DemoProgressionState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

final class DemoProgressionRuntime: NSObject {
    private let store: DemoSaveStore
    private(set) var state: DemoProgressionState

    init(store: DemoSaveStore = DemoSaveStore(), launchMode: DemoLaunchMode) {
        self.store = store
        switch launchMode {
        case .newGame:
            store.clear()
            state = .fresh
            store.save(state)
        case .continueGame:
            state = store.load() ?? .fresh
            if !store.hasSave { store.save(state) }
        }
    }

    @discardableResult
    func claimShrine(
        _ shrine: ShrineID,
        ability: PlayerAbility,
        checkpoint: CheckpointSnapshot
    ) -> Bool {
        guard state.claimShrine(shrine, ability: ability, checkpoint: checkpoint) else { return false }
        store.save(state)
        return true
    }

    func activateCheckpoint(_ checkpoint: CheckpointSnapshot) {
        state.activateCheckpoint(checkpoint)
        store.save(state)
    }
}
```

- [ ] **Step 7: Thread progression through runtime bootstrap**

Change `V21RuntimeContext` to require progression:

```swift
final class V21RuntimeContext: NSObject {
    let progression: DemoProgressionRuntime
    // keep all existing V21/V23 properties

    init(progression: DemoProgressionRuntime) {
        self.progression = progression
        super.init()
    }
}
```

Change bootstrap:

```swift
static func install(on scene: SKScene, launchMode: DemoLaunchMode = .continueGame) {
    scene.userData = scene.userData ?? NSMutableDictionary()
    let progression = DemoProgressionRuntime(launchMode: launchMode)
    let context = V21RuntimeContext(progression: progression)
    context.attach(to: scene)
    scene.userData?["v21RuntimeContext"] = context
    PlayerDamageInstaller.install(on: scene, context: context)
    RoomRuntimeInstaller.install(on: scene, context: context)
}
```

Update the fallback context creation in `PlayerDamageInstaller.install(on:)` and `RoomRuntimeInstaller.install(on:)` to:

```swift
let context = V21RuntimeContext(
    progression: DemoProgressionRuntime(launchMode: .continueGame)
)
```

- [ ] **Step 8: Add minimal launcher**

`AppRoot.swift` must render a SwiftUI launcher rather than always constructing `GameView` immediately. The launcher reads `DemoSaveStore().hasSave`; it shows `CONTINUE` only when a save exists and always shows `NEW GAME`. Selecting a button creates `GameView(launchMode: .continueGame)` or `GameView(launchMode: .newGame)`.

Change `GameView` signature:

```swift
struct GameView: UIViewRepresentable {
    let launchMode: DemoLaunchMode

    func makeUIView(context: Context) -> SKView {
        let skView = SKView(frame: .zero)
        skView.backgroundColor = .black
        skView.ignoresSiblingOrder = true
        skView.shouldCullNonVisibleNodes = false
        skView.isMultipleTouchEnabled = true
        skView.preferredFramesPerSecond = 60

        let scene = GameScene(size: CGSize(width: 844, height: 390))
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
        V21RuntimeBootstrap.install(on: scene, launchMode: launchMode)
        return skView
    }
}
```

Preserve the existing `updateUIView` behavior but use the same `launchMode` when a replacement scene is required.

- [ ] **Step 9: Verify GREEN and arm64 compile**

Run the two new tests plus existing RoomController, PlayerHealth, Respawn, and full arm64 compile. Expected: all tests print `PASS`, compile exits 0.

- [ ] **Step 10: Commit**

```bash
git add Sources/DemoProgression.swift Sources/DemoSaveStore.swift Sources/RoomController.swift Sources/V21RuntimeContext.swift Sources/AppRoot.swift Sources/GameView.swift Sources/PlayerDamageInstaller.swift Sources/RoomRuntimeInstaller.swift Tests/DemoProgressionTests.swift Tests/DemoSaveStoreTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: persist V24 demo progression"
```

---

### Task 2: Unlockable Kinematic Dash and DASH HUD Button

**Files:**
- Create: `Sources/DashController.swift`
- Create: `Tests/DashControllerTests.swift`
- Modify: `Sources/HUDControlLayout.swift`
- Modify: `Tests/HUDControlLayoutTests.swift`
- Modify: `Sources/GameScene.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces `DashController.tryStart(unlocked:isGrounded:inputX:facing:) -> Double?`.
- Produces `DashController.update(dt:)`, `restoreAirDash()`, `cancelActiveDash()`.
- `HUDControlKind` and `GameScene.Control` gain `.dash`.

- [ ] **Step 1: Write failing Dash tests**

Create `Tests/DashControllerTests.swift`:

```swift
import Foundation

@inline(__always)
func expectDash(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct DashControllerTestsMain {
    static func main() {
        var dash = DashController()
        expectDash(dash.tryStart(unlocked: false, isGrounded: true, inputX: 1, facing: 1) == nil, "locked Dash cannot start")

        expectDash(dash.tryStart(unlocked: true, isGrounded: true, inputX: -1, facing: 1) == -1, "input chooses Dash direction")
        expectDash(dash.isDashing, "Dash enters active window")
        dash.update(dt: 0.20)
        expectDash(!dash.isDashing, "active window ends")
        expectDash(dash.tryStart(unlocked: true, isGrounded: true, inputX: 1, facing: 1) == nil, "cooldown blocks immediate reuse")

        dash.update(dt: 0.50)
        expectDash(dash.tryStart(unlocked: true, isGrounded: false, inputX: 0, facing: 1) == 1, "neutral input uses facing")
        dash.update(dt: 0.70)
        expectDash(dash.tryStart(unlocked: true, isGrounded: false, inputX: 1, facing: 1) == nil, "second air Dash is blocked")
        dash.restoreAirDash()
        expectDash(dash.tryStart(unlocked: true, isGrounded: false, inputX: 1, facing: 1) == 1, "restore event grants air Dash")

        print("DashControllerTests: PASS")
    }
}
```

- [ ] **Step 2: Add CI test and verify RED**

```yaml
      - name: Test dash controller
        shell: bash
        run: |
          set -euo pipefail
          xcrun swiftc Tests/DashControllerTests.swift Sources/DashController.swift -o build/DashControllerTests
          ./build/DashControllerTests
```

Expected RED: `DashController` missing.

- [ ] **Step 3: Implement `DashController`**

Create `Sources/DashController.swift`:

```swift
import Foundation

struct DashController {
    let cooldown: TimeInterval = 0.60
    let duration: TimeInterval = 0.16
    private(set) var cooldownRemaining: TimeInterval = 0
    private(set) var dashRemaining: TimeInterval = 0
    private(set) var direction: Double = 1
    private(set) var airDashAvailable = true

    var isDashing: Bool { dashRemaining > 0 }

    mutating func tryStart(
        unlocked: Bool,
        isGrounded: Bool,
        inputX: Double,
        facing: Double
    ) -> Double? {
        guard unlocked, cooldownRemaining <= 0, !isDashing else { return nil }
        if !isGrounded && !airDashAvailable { return nil }
        direction = inputX == 0 ? (facing >= 0 ? 1 : -1) : (inputX > 0 ? 1 : -1)
        dashRemaining = duration
        cooldownRemaining = cooldown
        if !isGrounded { airDashAvailable = false }
        return direction
    }

    mutating func update(dt: TimeInterval) {
        guard dt > 0 else { return }
        cooldownRemaining = max(0, cooldownRemaining - dt)
        dashRemaining = max(0, dashRemaining - dt)
    }

    mutating func restoreAirDash() {
        airDashAvailable = true
    }

    mutating func cancelActiveDash() {
        dashRemaining = 0
    }
}
```

- [ ] **Step 4: Write RED HUD assertions for DASH**

Extend `Tests/HUDControlLayoutTests.swift` so `.dash` must exist, its visible center resolves to `.dash`, its circle stays onscreen/above bottom safe area, and its visual circle does not overlap Attack or Jump.

The target center for the known 667×375 layout is intentionally above the Attack/Jump row:

```swift
let dash = layout.target(for: .dash)
expectHUD(layout.resolve(x: dash.center.x, y: dash.center.y) == .dash, "visible Dash center resolves to Dash")
expectHUD(dash.center.y + dash.visualRadius <= height - safeBottom, "Dash stays above bottom safe area")
```

Expected RED: `.dash` missing.

- [ ] **Step 5: Add DASH to shared HUD geometry**

In `HUDControlLayout.swift` add `.dash` and:

```swift
case .dash:
    return target(
        x: viewWidth - 137,
        y: baselineY - 90,
        visualRadius: 42,
        hitRadius: 52
    )
```

Do not change the already device-confirmed centers of left/right/up/down/focus/attack/jump or the `HUDOverlayLayout` top status geometry.

- [ ] **Step 6: Integrate Dash into `GameScene`**

Add `dashButton`, `dashLabel`, `.dash` control, and `private var dashController = DashController()`.

On press:

```swift
private func tryDash() {
    cancelFocus()
    guard let context = V21RuntimeBootstrap.context(from: self),
          let direction = dashController.tryStart(
              unlocked: context.progression.state.has(.dash),
              isGrounded: isGrounded,
              inputX: Double(moveInput),
              facing: Double(facing)
          ) else { return }
    facing = direction > 0 ? 1 : -1
}
```

At frame start:

```swift
dashController.update(dt: dt)
```

In horizontal velocity update, before ordinary acceleration:

```swift
if dashController.isDashing {
    velocity.dx = CGFloat(dashController.direction) * 720
    velocity.dy = 0
    return
}
```

Skip gravity while `dashController.isDashing`; resume the existing gravity expression as soon as the active window ends. If `moveHorizontally` resolves a solid collision during a Dash, snap outside the platform as today and call `dashController.cancelActiveDash()`.

On a landing transition and successful pogo bounce, call `dashController.restoreAirDash()`.

- [ ] **Step 7: Verify GREEN and regressions**

Run Dash, HUD, CombatImpulse, AttackController, PlayerAttackDirection, PlayerVitalState, EssenceFocus tests and full arm64 compile. Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/DashController.swift Sources/HUDControlLayout.swift Sources/GameScene.swift Tests/DashControllerTests.swift Tests/HUDControlLayoutTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: add unlockable kinematic dash"
```

---

### Task 3: Passive Wall Cling and Wall Jump

**Files:**
- Create: `Sources/WallTraversalController.swift`
- Create: `Tests/WallTraversalControllerTests.swift`
- Modify: `Sources/GameScene.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces `WallSide`, `WallJumpImpulse`, `WallTraversalController`.
- `GameScene` supplies AABB wall contact and applies the returned slide/jump outputs.

- [ ] **Step 1: Write failing wall traversal tests**

Create `Tests/WallTraversalControllerTests.swift` with these required assertions:

```swift
import Foundation

@inline(__always)
func expectWall(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct WallTraversalControllerTestsMain {
    static func main() {
        var wall = WallTraversalController()
        expectWall(wall.clingSide(unlocked: false, isGrounded: false, heldDirectionX: 1, contactSide: .right) == nil, "locked traversal cannot cling")
        expectWall(wall.clingSide(unlocked: true, isGrounded: true, heldDirectionX: 1, contactSide: .right) == nil, "ground contact wins over wall cling")
        expectWall(wall.clingSide(unlocked: true, isGrounded: false, heldDirectionX: -1, contactSide: .right) == nil, "holding away does not cling")
        expectWall(wall.clingSide(unlocked: true, isGrounded: false, heldDirectionX: 1, contactSide: .right) == .right, "holding into contacted wall clings")

        let jump = wall.wallJump(from: .right)
        expectWall(jump.velocityX < 0, "right-wall jump pushes left")
        expectWall(jump.velocityY > 0, "wall jump pushes upward")
        expectWall(wall.clingSide(unlocked: true, isGrounded: false, heldDirectionX: 1, contactSide: .right) == nil, "same-wall lock blocks instant reattachment")
        expectWall(wall.clingSide(unlocked: true, isGrounded: false, heldDirectionX: -1, contactSide: .left) == .left, "opposite wall remains usable")
        wall.update(dt: 0.13)
        expectWall(wall.clingSide(unlocked: true, isGrounded: false, heldDirectionX: 1, contactSide: .right) == .right, "same wall unlocks after lock duration")

        print("WallTraversalControllerTests: PASS")
    }
}
```

- [ ] **Step 2: Add CI step and verify RED**

```yaml
      - name: Test wall traversal controller
        shell: bash
        run: |
          set -euo pipefail
          xcrun swiftc Tests/WallTraversalControllerTests.swift Sources/WallTraversalController.swift -o build/WallTraversalControllerTests
          ./build/WallTraversalControllerTests
```

Expected RED: controller missing.

- [ ] **Step 3: Implement wall traversal controller**

Create `Sources/WallTraversalController.swift`:

```swift
import Foundation

enum WallSide: Equatable {
    case left
    case right
}

struct WallJumpImpulse: Equatable {
    let velocityX: Double
    let velocityY: Double
}

struct WallTraversalController {
    let slideSpeed: Double = -180
    let jumpHorizontalSpeed: Double = 360
    let jumpVerticalSpeed: Double = 560
    let sameWallLockDuration: TimeInterval = 0.12

    private(set) var lockedWall: WallSide?
    private var lockRemaining: TimeInterval = 0

    mutating func update(dt: TimeInterval) {
        guard dt > 0 else { return }
        lockRemaining = max(0, lockRemaining - dt)
        if lockRemaining == 0 { lockedWall = nil }
    }

    func clingSide(
        unlocked: Bool,
        isGrounded: Bool,
        heldDirectionX: Double,
        contactSide: WallSide?
    ) -> WallSide? {
        guard unlocked, !isGrounded, let contactSide else { return nil }
        if lockedWall == contactSide && lockRemaining > 0 { return nil }
        switch contactSide {
        case .left where heldDirectionX < 0: return .left
        case .right where heldDirectionX > 0: return .right
        default: return nil
        }
    }

    mutating func wallJump(from side: WallSide) -> WallJumpImpulse {
        lockedWall = side
        lockRemaining = sameWallLockDuration
        return WallJumpImpulse(
            velocityX: side == .left ? jumpHorizontalSpeed : -jumpHorizontalSpeed,
            velocityY: jumpVerticalSpeed
        )
    }
}
```

- [ ] **Step 4: Add robust wall-contact probing to `GameScene`**

A player held against a wall has `velocity.dx == 0` after collision resolution, so contact cannot be inferred from velocity. Add a one-point AABB probe:

```swift
private func detectedWallContact() -> WallSide? {
    let probe: CGFloat = 1
    let verticalInset: CGFloat = 2
    let base = playerRect.insetBy(dx: 0, dy: verticalInset)
    let leftProbe = base.offsetBy(dx: -probe, dy: 0)
    let rightProbe = base.offsetBy(dx: probe, dy: 0)

    let left = platformRects.contains { leftProbe.intersects($0) && !base.intersects($0) }
    let right = platformRects.contains { rightProbe.intersects($0) && !base.intersects($0) }
    if left { return .left }
    if right { return .right }
    return nil
}
```

- [ ] **Step 5: Integrate cling/slide/jump**

Call `wallTraversalController.update(dt:)` each frame. After ordinary gravity and before kinematic integration, ask for a cling side using the current progression unlock, ground state, `moveInput`, and probe result. While clinging:

```swift
velocity.dy = max(velocity.dy, CGFloat(wallTraversalController.slideSpeed))
```

When JUMP is pressed during a valid cling, apply:

```swift
let impulse = wallTraversalController.wallJump(from: side)
velocity.dx = CGFloat(impulse.velocityX)
velocity.dy = CGFloat(impulse.velocityY)
isGrounded = false
coyoteRemaining = 0
jumpBufferRemaining = 0
dashController.restoreAirDash()
```

Track previous cling side so entering a valid cling restores the aerial Dash once on the transition into cling rather than once per frame.

- [ ] **Step 6: Verify GREEN and regressions**

Run WallTraversal, Dash, HUD, CombatImpulse, PlayerVitalState, RoomController tests and arm64 compile. Confirm no player physics body exists.

- [ ] **Step 7: Commit**

```bash
git add Sources/WallTraversalController.swift Sources/GameScene.swift Tests/WallTraversalControllerTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: add passive wall traversal"
```

---

### Task 4: Ten-Room Topology and Active-Room Geometry

**Files:**
- Create: `Tests/DemoRoomTopologyTests.swift`
- Modify: `Sources/RoomController.swift`
- Modify: `Sources/GameScene.swift`
- Modify: `Sources/RoomRuntimeInstaller.swift`
- Modify: `Sources/V21RuntimeContext.swift`
- Modify: `Tests/RoomControllerTests.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces `AbilityShrinePlacement`, `CheckpointTrigger`, ability-gated `RoomExit`, and `RoomController.makeV24Demo()`.
- `GameScene.replaceRoomGeometry(platforms:roomWidth:roomHeight:)` becomes the only way the room runtime changes collision geometry.
- `RoomRuntimeInstaller` loads the current saved checkpoint room/spawn and uses room-local physical coordinates.

- [ ] **Step 1: Write failing topology tests**

Create `Tests/DemoRoomTopologyTests.swift` and assert this exact order:

```swift
let expected: [RoomID] = [
    .approach,
    .lowerHall,
    .brokenGallery,
    .dashShrine,
    .furnacePassage,
    .watcherHall,
    .hollowShaft,
    .ashenAscent,
    .wardenGate,
    .wardenChamber
]
expectTopology(level.orderedRoomIDs == expected, "V24 room order is stable")
```

The test must also assert:

```swift
expectTopology(level.room(.dashShrine)?.shrine?.ability == .dash, "Dash Shrine grants Dash")
expectTopology(level.room(.hollowShaft)?.shrine?.ability == .wallTraversal, "Hollow Shaft grants Wall Traversal")
expectTopology(level.room(.wardenGate)?.checkpointTriggers.contains(where: { $0.checkpoint.id == .preWarden }) == true, "Warden Gate contains pre-boss checkpoint")
expectTopology(level.room(.wardenChamber)?.enemySpawns.contains(where: { $0.archetype == .boss }) == true, "Warden Chamber contains Ash Warden")
```

For every room, verify every exit trigger lies within 1200×560 local bounds and every destination spawn lies within the destination room bounds.

- [ ] **Step 2: Add CI topology test and verify RED**

```yaml
      - name: Test V24 room topology
        shell: bash
        run: |
          set -euo pipefail
          xcrun swiftc Tests/DemoRoomTopologyTests.swift Sources/RoomController.swift Sources/EnemyArchetype.swift Sources/DemoProgression.swift -o build/DemoRoomTopologyTests
          ./build/DemoRoomTopologyTests
```

Expected RED: `makeV24Demo`, V24 metadata, or new room IDs missing.

- [ ] **Step 3: Add room metadata and ability-gated exits**

In `RoomController.swift` add:

```swift
struct AbilityShrinePlacement: Equatable {
    let id: ShrineID
    let ability: PlayerAbility
    let position: RoomPoint
    let checkpoint: CheckpointSnapshot
}

struct CheckpointTrigger: Equatable {
    let checkpoint: CheckpointSnapshot
    let trigger: RoomRect
}
```

Extend `RoomExit` with:

```swift
let requiredAbility: PlayerAbility?
```

Extend `RoomDefinition` with:

```swift
let shrine: AbilityShrinePlacement?
let checkpointTriggers: [CheckpointTrigger]
```

Give initializer defaults of `nil` / `[]` so existing V21 tests can migrate safely.

Change exit resolution to:

```swift
func exitIfNeeded(
    playerCenter: RoomPoint,
    playerSize: RoomSize,
    in roomID: RoomID,
    combatCleared: Bool,
    unlockedAbilities: Set<PlayerAbility> = []
) -> RoomExitActivation?
```

Ignore an exit when its `requiredAbility` is non-nil and absent from `unlockedAbilities`.

- [ ] **Step 4: Define initial V24 room geometry with explicit roles**

All rooms use local bounds `RoomRect(x: 0, y: 0, width: 1200, height: 560)`. Use these initial platform patterns; values may later be tuned only for play feel/pacing, not to change progression order:

```text
Approach:
  floor 0...1200 at top y=100
  platforms: (330,185,220×28), (690,250,200×28), (990,190,160×28)
  Grunt at x=720
  DOWN shaft/exit near x=1040

Lower Hall:
  floor 0...1200 top y=100
  platforms: (430,205,240×28), (820,175,210×28)
  two Grunts
  LEFT exit

Broken Gallery:
  floor top y=100
  platforms: (300,190,190×28), (590,275,180×28), (890,215,220×28)
  Grunt + Runner
  DOWN exit
  optional Wall-Traversal-gated shortcut exit to Ashen Ascent

Dash Shrine:
  split floor with safe shrine area around x=300
  shrine at (300,130)
  post-Dash checkpoint spawn (360,130)
  teaching gap starts after x=520 and cannot be crossed by ordinary jump alone
  LEFT exit after teaching section

Furnace Passage:
  floor plus three separated ledges requiring useful Dash repositioning
  Grunt + Runner
  UP exit

Watcher Hall:
  floor plus two firing-height platforms
  Ranged + Grunt
  LEFT exit

Hollow Shaft:
  lower shrine floor around y=100
  opposing climb walls/platform faces through y=500
  wallTraversal shrine at (600,130)
  post-Wall checkpoint spawn (600,150)
  UP exit

Ashen Ascent:
  alternating left/right ledges at y=150, 250, 350, 455
  Runner/Ranged on selected safe ledges
  LEFT exit

Warden Gate:
  floor plus two combat ledges
  Heavy + Ranged
  pre-Warden checkpoint trigger after combat near the DOWN exit

Warden Chamber:
  broad floor and side wall surfaces
  one Boss spawn
  completion state/exit after boss clear
```

Implement required travel using trigger placement, not a hard-coded sequence in runtime:

- Approach DOWN → Lower Hall.
- Lower Hall LEFT → Broken Gallery.
- Broken Gallery DOWN → Dash Shrine.
- Dash Shrine LEFT → Furnace Passage.
- Furnace Passage UP → Watcher Hall.
- Watcher Hall LEFT → Hollow Shaft.
- Hollow Shaft UP → Ashen Ascent.
- Ashen Ascent LEFT → Warden Gate.
- Warden Gate DOWN → Warden Chamber.

Down transitions use a visible shaft/opening plus a trigger below the walkable floor segment; up transitions use a top trigger reached by platforms/walls; left transitions use a trigger at the left edge and spawn the player near the destination's right edge.

- [ ] **Step 5: Put active room platforms under one replaceable geometry node**

In `GameScene`, keep the existing collision algorithm, but make platform visuals/colliders replaceable. Add:

```swift
func replaceRoomGeometry(
    platforms: [RoomPlatform],
    roomWidth: CGFloat,
    roomHeight: CGFloat
) {
    platformRects.removeAll(keepingCapacity: true)

    let geometry: SKNode
    if let existing = worldRoot.childNode(withName: "roomGeometry") {
        geometry = existing
        geometry.removeAllChildren()
    } else {
        geometry = SKNode()
        geometry.name = "roomGeometry"
        worldRoot.addChild(geometry)
    }

    for platform in platforms {
        let center = CGPoint(
            x: CGFloat(platform.center.x),
            y: CGFloat(platform.center.y)
        )
        let size = CGSize(
            width: CGFloat(platform.size.width),
            height: CGFloat(platform.size.height)
        )
        platformRects.append(CGRect(
            x: center.x - size.width * 0.5,
            y: center.y - size.height * 0.5,
            width: size.width,
            height: size.height
        ))

        let visual = SKShapeNode(rectOf: size, cornerRadius: 7)
        visual.fillColor = UIColor(red: 0.15, green: 0.17, blue: 0.21, alpha: 1)
        visual.strokeColor = UIColor(white: 0.42, alpha: 0.35)
        visual.lineWidth = 2
        visual.position = center
        visual.zPosition = 1
        geometry.addChild(visual)
    }

    worldWidth = roomWidth
}
```

Refactor startup `addPlatform` visuals under the same `roomGeometry` node so the first runtime replacement removes every old visual and collider consistently.

- [ ] **Step 6: Replace V21 even/odd physical segment recycling**

In `RoomRuntimeInstaller`, delete `physicalOriginX(for:)`. For each applied room:

```swift
let roomWidth = CGFloat(room.bounds.width)
context.physicalRoomMinX = 0
context.physicalRoomMaxX = roomWidth

guard let gameScene = scene as? GameScene else { return }
gameScene.replaceRoomGeometry(
    platforms: room.platforms,
    roomWidth: roomWidth,
    roomHeight: CGFloat(room.bounds.height)
)

let spawn = destinationSpawn ?? room.playerSpawn
player.position = CGPoint(x: CGFloat(spawn.x), y: CGFloat(spawn.y))
```

Enemy installers receive `physicalOriginX: 0`. Exit checks use:

```swift
state.controller.exitIfNeeded(
    playerCenter: RoomPoint(x: Double(player.position.x), y: Double(player.position.y)),
    playerSize: RoomSize(width: 36, height: 60),
    in: state.activeRoomID,
    combatCleared: context.combatStatus.isCleared,
    unlockedAbilities: context.progression.state.unlockedAbilities
)
```

- [ ] **Step 7: Start the room runtime from the durable checkpoint**

Initialize with:

```swift
let checkpoint = context.progression.state.checkpoint
state.activeRoomID = checkpoint.roomID
applyRoom(checkpoint.roomID, destinationSpawn: checkpoint.spawn)
```

New Game therefore starts in Approach; Continue and death start at the stored checkpoint.

- [ ] **Step 8: Verify GREEN and full regressions**

Run topology, RoomController, Dash, WallTraversal, enemy runtime, projectile, boss controller, HP/respawn tests and arm64 compile/package. Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add Sources/RoomController.swift Sources/GameScene.swift Sources/RoomRuntimeInstaller.swift Sources/V21RuntimeContext.swift Tests/DemoRoomTopologyTests.swift Tests/RoomControllerTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: add V24 ten-room spatial runtime"
```

---

### Task 5: Ability Shrines, Checkpoints, Acquisition Lock, and Death Respawn

**Files:**
- Modify: `Sources/RoomRuntimeInstaller.swift`
- Modify: `Sources/GameScene.swift`
- Modify: `Sources/PlayerDamageInstaller.swift`
- Modify: `Tests/DemoProgressionTests.swift`

**Interfaces:**
- Shrine acquisition calls `context.progression.claimShrine(...)` exactly once.
- Pre-boss checkpoint calls `context.progression.activateCheckpoint(...)`.
- `GameScene` exposes a narrow input lock used only for short acquisition presentation.
- Death replacement scene bootstraps `.continueGame`.

- [ ] **Step 1: Extend progression RED test for shrine atomicity**

The existing test already verifies first claim + duplicate rejection. Add a second Wall Traversal claim and assert its checkpoint becomes `.postWallTraversal` while Dash remains unlocked. This test protects multi-ability cumulative progress.

- [ ] **Step 2: Add a narrow acquisition input lock to `GameScene`**

Add:

```swift
private(set) var externalInputLocked = false

func setExternalInputLocked(_ locked: Bool) {
    externalInputLocked = locked
    if locked {
        activeControls.removeAll(keepingCapacity: true)
        moveInput = 0
        smoothedMoveInput = 0
        cancelFocus()
    }
    refreshButtonVisuals()
}
```

At the top of touch handling, ignore new presses when locked. Do not pause the scene and do not alter collision/gravity.

- [ ] **Step 3: Create shrine presentation from room metadata**

When applying a room, remove any old `v24AbilityShrine`, then if `room.shrine` exists create a pedestal/artifact node at `placement.position`. If the shrine ID is already in `context.progression.state.consumedShrines`, render it dormant and skip activation.

Use a deterministic activation rectangle centered on the shrine, 96×120 points.

- [ ] **Step 4: Activate shrine and persist before teaching section**

When the player rect first intersects an unconsumed shrine:

```swift
let accepted = context.progression.claimShrine(
    placement.id,
    ability: placement.ability,
    checkpoint: placement.checkpoint
)
```

If `accepted` is true:

1. call `gameScene.setExternalInputLocked(true)`;
2. show `DASH ACQUIRED` or `WALL TRAVERSAL ACQUIRED` on a camera child label;
3. keep the presentation approximately 0.45 s;
4. fade/remove the label;
5. call `gameScene.setExternalInputLocked(false)`.

The save and linked checkpoint happen before control returns, so death during the teaching challenge never replays the shrine.

- [ ] **Step 5: Activate standalone checkpoint triggers**

For every `CheckpointTrigger` in the active room, intersect its `RoomRect` with the player's 36×60 rect. If the trigger checkpoint differs from the currently stored checkpoint, call:

```swift
context.progression.activateCheckpoint(trigger.checkpoint)
```

Warden Gate must activate `.preWarden` before the player can enter Warden Chamber.

- [ ] **Step 6: Make death reload latest checkpoint**

In `PlayerDamageInstaller.startRespawnTransition`, use:

```swift
let replacement = GameScene(size: scene.size)
replacement.scaleMode = scene.scaleMode
skView.presentScene(replacement)
V21RuntimeBootstrap.install(on: replacement, launchMode: .continueGame)
```

Keep the existing fade timings and fresh HP state. The replacement room runtime reads the persisted checkpoint.

- [ ] **Step 7: Verify persistence/respawn regression set**

Run DemoProgression, DemoSaveStore, PlayerHealth, PlayerVitalState, RespawnSequence, RoomTopology, Dash, WallTraversal tests and arm64 compile. Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Sources/RoomRuntimeInstaller.swift Sources/GameScene.swift Sources/PlayerDamageInstaller.swift Tests/DemoProgressionTests.swift
git commit -m "feat: add ability shrines and persistent checkpoints"
```

---

### Task 6: Gameplay Pacing, Teaching Sections, Shortcuts, and Ash Warden Integration

**Files:**
- Modify: `Sources/RoomController.swift`
- Modify: `Sources/RoomRuntimeInstaller.swift`
- Modify: `Sources/BossRuntimeInstaller.swift` only when arena clearance requires it.
- Modify: `Tests/DemoRoomTopologyTests.swift`

**Interfaces:**
- Consumes all V24 mechanics from Tasks 1–5.
- Produces the complete 10-room playable route with one traversal-enabled shortcut and room pacing suitable for a 12–15 minute normal first run.

- [ ] **Step 1: Lock the room-by-room pacing roles in topology tests**

Add structural assertions that:

- Dash Shrine has no mandatory enemy encounter and contains Dash shrine metadata.
- Hollow Shaft contains Wall Traversal shrine metadata and an UP exit.
- Watcher Hall contains at least one `.ranged` enemy plus one support enemy.
- Warden Gate contains `.heavy` and `.ranged` enemies.
- Broken Gallery contains at least one ability-gated optional exit.
- Warden Chamber contains exactly one boss archetype spawn.

These tests do not measure minutes; they prevent content-role regressions while device timing handles pacing.

- [ ] **Step 2: Tune Dash teaching geometry**

Use Dash speed 720 pt/s and active duration 0.16 s, giving roughly 115 points of burst distance before ordinary air movement continues. Make the first mandatory Dash gap clearly wider than a standing ordinary jump can clear from the teaching ledge while still giving at least 20–30 points of landing margin with Dash. Follow it with two safer ledges so the player practices cooldown timing without enemies.

- [ ] **Step 3: Tune Hollow Shaft and Ashen Ascent**

Use wall slide cap -180, wall jump horizontal 360, wall jump vertical 560. Hollow Shaft must teach repeated opposing-wall jumps with broad wall faces and no pixel-perfect corner requirement. Ashen Ascent then combines wall jump and Dash with recovery ledges between harder chains. Place enemies only on ledges where combat does not invalidate the traversal lesson.

- [ ] **Step 4: Implement one meaningful shortcut**

Use Broken Gallery's optional `requiredAbility: .wallTraversal` exit as the connected-world payoff. It should be visible during the early pass but unreachable/disabled; after Wall Traversal unlock, returning to Broken Gallery allows a faster connection into the later vertical route. This shortcut must not be required for the first-run progression order.

- [ ] **Step 5: Tune encounters without HP padding**

Keep current archetype HP/stats unless a separately observed balance defect requires a bounded rebalance. Runtime is added through traversal, enemy composition, positioning, and the boss—not by multiplying HP. Preserve Watcher Hall as Ranged + Grunt pressure.

- [ ] **Step 6: Check Ash Warden arena compatibility**

The Warden Chamber must have enough horizontal distance for Dash to reposition without crossing the entire arena in one press. Side wall surfaces may allow optional Wall Jump recovery. Do not require Wall Jump to avoid a mandatory boss attack. If existing `BossRuntimeInstaller` behavior already works inside the V24 room geometry, leave that file unchanged.

- [ ] **Step 7: Run full CI**

Run every old and new test, then arm64 compile, IPA package, artifact upload. Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add Sources/RoomController.swift Sources/RoomRuntimeInstaller.swift Tests/DemoRoomTopologyTests.swift
git add Sources/BossRuntimeInstaller.swift 2>/dev/null || true
git commit -m "feat: complete V24 demo gameplay route"
```

Before committing, verify `git diff --cached --name-only`; if `BossRuntimeInstaller.swift` has no change, it must not appear in the staged set.

---

### Task 7: Final CI, IPA Provenance, and Device Acceptance

**Files:**
- No production file unless verification reveals a defect.
- Create `docs/superpowers/verification/2026-09-01-v24-device-playtest.md` only after actual device measurements exist.

**Interfaces:**
- Produces exact final Git SHA, GitHub Actions run ID, artifact ID/digest, local IPA SHA-256, and the device acceptance result.

- [ ] **Step 1: Run final workflow on final HEAD**

The final run must include successful steps for all existing V21/V23 tests plus DemoProgression, DemoSaveStore, DashController, WallTraversalController, HUDControlLayout with DASH, V24 room topology, arm64 compile, IPA package, and artifact upload.

Do not use an earlier task run as final evidence.

- [ ] **Step 2: Verify artifact provenance**

Confirm the artifact's `workflow_run.head_sha` exactly equals current `main` HEAD. Record the exact run ID, artifact ID, artifact digest, and commit SHA from GitHub.

- [ ] **Step 3: Download and validate IPA locally**

Run:

```bash
unzip -t AshenHollow-unsigned.ipa
unzip -l AshenHollow-unsigned.ipa | grep 'Payload/AshenHollow.app/AshenHollow'
unzip -l AshenHollow-unsigned.ipa | grep 'Payload/AshenHollow.app/Info.plist'
shasum -a 256 AshenHollow-unsigned.ipa
```

Every command must succeed before the IPA is shared.

- [ ] **Step 4: Device-test controls and persistence**

Verify on the user's iPhone:

1. top HP/Essence/room overlays remain correctly placed;
2. DASH does not overlap Attack/Jump and its visible button responds at its visible center;
3. Dash shrine unlocks once and survives death;
4. relaunch → Continue restores post-Dash checkpoint and ability;
5. Wall Traversal shrine unlocks once and survives death/relaunch;
6. wall cling requires holding into the wall and JUMP pushes away;
7. New Game clears abilities/shrines/checkpoint and starts at Approach;
8. boss death respawns at pre-Warden checkpoint.

Any failed item means V24 is not device-stable.

- [ ] **Step 5: Measure clean playthrough duration**

Measure from first player control in Approach to Ash Warden defeat/demo-complete state. Acceptance is a normal first run around 12–15 minutes and a fast legitimate run of at least about 10 minutes. Death/retry time is not required to satisfy the minimum.

If a competent clean run is below 10 minutes, add meaningful traversal complexity, another purposeful combat beat, or additional connected-room traversal in the rooms that are under target, then rerun CI and repeat the timing test. Do not add waits, slow the player, inflate HP, or insert empty corridor distance.

- [ ] **Step 6: Record measured acceptance data**

Only after the actual run, create `docs/superpowers/verification/2026-09-01-v24-device-playtest.md` containing the verified build SHA, workflow run ID, IPA SHA-256, each device checklist result, measured clean playthrough duration, and whether V24 is device-stable. Every field must contain a real measured/verified value; do not commit an unfilled template.

- [ ] **Step 7: Re-verify if any code changes are made during device tuning**

Any tuning/fix creates a new final HEAD. Repeat final workflow, artifact provenance check, IPA integrity check, and device test before making a completion claim.
