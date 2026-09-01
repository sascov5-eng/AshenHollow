# Ashen Hollow V24 — Demo Progression & Traversal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current Ashen Hollow combat/platforming prototype into a persistent 10+ minute vertical-slice demo with Dash, Wall Cling/Wall Jump, ability shrines, checkpoints, Continue/New Game, 10 spatially varied rooms, and the existing Ash Warden as the climax.

**Architecture:** Keep the existing custom kinematic controller and collision algorithm intact, but move new behavior into focused pure/stateful controllers: durable demo progression/save state, Dash state, and wall-traversal state. `GameScene` remains the integration point for velocity/collision/HUD, while `RoomController` owns the 10-room topology and `RoomRuntimeInstaller` owns active-room geometry, exits, shrines, checkpoints, enemies, and room transitions. Durable progress is serialized through `UserDefaults`; death and relaunch reload the latest checkpoint rather than rebuilding progression from transient scene state.

**Tech Stack:** Swift 6-style source compiled with `swiftc`, SwiftUI, SpriteKit, UIKit, Foundation, GitHub Actions on `macos-15`, arm64 iOS 15 target.

**Spec:** `docs/superpowers/specs/2026-09-01-v24-demo-progression-traversal-design.md`

## Global Constraints

- Landscape only.
- Player must remain free of `SKPhysicsBody`.
- Preserve player visual 42×64 and collider 36×60.
- Preserve gravity -1700, jump 610, jump release 285, run 315, ground acceleration 1900, air acceleration 1050, ground deceleration 2400, max fall -900.
- Preserve coyote time, jump buffering, existing melee/pogo, player HP/i-frames, Essence/Focus, enemy damage, room combat clearing, camera behavior, and Ash Warden state machine unless a task explicitly adds a V24 integration hook.
- Camera zoom remains 1.55.
- Horizontal movement must never zero vertical velocity.
- Dash is free, has no i-frames, target cooldown 0.6 s, and only one airborne use until restored.
- Wall Cling/Wall Jump is passive and has no separate button.
- Ability unlocks and consumed shrines survive death and app relaunch; only New Game clears them.
- Four persistent checkpoints: Approach start, immediately post-Dash, immediately post-Wall Traversal, pre-Ash-Warden.
- Demo progression order is Approach → Lower Hall → Broken Gallery → Dash Shrine → Furnace Passage → Watcher Hall → Hollow Shaft → Ashen Ascent → Warden Gate → Warden Chamber.
- Perceived room travel must include down, left, up, and down transitions rather than a horizontal-only chain.
- Normal first playthrough target 12–15 minutes; fast legitimate first playthrough must remain at least about 10 minutes without relying on deaths, waits, inflated HP, or empty corridors.
- HUD drawing and hit testing must share geometry; the fixed top overlay layout must not regress.
- Every behavior task follows RED → GREEN → regression verification before commit.

---

## File Structure Map

**Create**

- `Sources/DemoProgression.swift` — ability/shrine/checkpoint enums, durable progression snapshot, atomic progression mutations.
- `Sources/DemoSaveStore.swift` — JSON encode/decode/clear/has-save using injected `UserDefaults`.
- `Sources/DashController.swift` — pure Dash cooldown, active-window, direction, and air-use state.
- `Sources/WallTraversalController.swift` — pure wall-cling/wall-jump decision state and same-wall reattachment lockout.
- `Tests/DemoProgressionTests.swift`
- `Tests/DemoSaveStoreTests.swift`
- `Tests/DashControllerTests.swift`
- `Tests/WallTraversalControllerTests.swift`
- `Tests/DemoRoomTopologyTests.swift`

**Modify**

- `Sources/RoomController.swift` — make room/save primitives codable, add four V24 room IDs, optional ability-gated exits, shrine/checkpoint metadata, and the 10-room level definition.
- `Sources/V21RuntimeContext.swift` — attach durable progression/save runtime plus launch mode to the existing runtime context.
- `Sources/AppRoot.swift` — show minimal New Game / Continue launcher instead of always entering a fresh scene.
- `Sources/GameView.swift` — accept launch mode and bootstrap the scene with new/continued durable state.
- `Sources/GameScene.swift` — integrate Dash button, Dash movement, wall contact/wall movement, and active-room geometry replacement without changing the core AABB/substep algorithm.
- `Sources/HUDControlLayout.swift` — add shared DASH target geometry while preserving the fixed status overlay layout.
- `Tests/HUDControlLayoutTests.swift` — verify DASH does not overlap controls, stays onscreen, and resolves from its visible center.
- `Sources/RoomRuntimeInstaller.swift` — load checkpoint room/spawn, rebuild active room geometry, directional transitions, shrine/checkpoint runtime, and V24 room presentation.
- `Sources/PlayerDamageInstaller.swift` — respawn by reloading Continue/latest checkpoint instead of implicitly starting at Approach.
- `Sources/BossRuntimeInstaller.swift` — only if needed, expose/adjust arena geometry so Dash and optional Wall Jump have safe room to operate; do not rewrite boss states.
- `.github/workflows/build-ipa.yml` — compile/run each new pure test before arm64 packaging.

---

### Task 1: Durable Demo Progression Domain

**Files:**
- Create: `Sources/DemoProgression.swift`
- Modify: `Sources/RoomController.swift`
- Test: `Tests/DemoProgressionTests.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces: `enum PlayerAbility: String, Codable, CaseIterable, Hashable { case dash, wallTraversal }`
- Produces: `enum ShrineID: String, Codable, CaseIterable, Hashable { case dash, wallTraversal }`
- Produces: `enum CheckpointID: String, Codable, CaseIterable, Hashable { case approach, postDash, postWallTraversal, preWarden }`
- Produces: `struct CheckpointSnapshot: Codable, Equatable`
- Produces: `struct DemoProgressionState: Codable, Equatable`
- Consumes later: `RoomID` and `RoomPoint`, which become `Codable` in this task.

- [ ] **Step 1: Write the failing progression test**

Create `Tests/DemoProgressionTests.swift` with a tiny executable test harness. Cover fresh state, atomic shrine claim, checkpoint advancement, duplicate shrine rejection, and New Game reset:

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
        expectProgression(!state.has(.dash), "fresh state starts without dash")
        expectProgression(state.checkpoint.id == .approach, "fresh state starts at Approach checkpoint")

        let claimed = state.claimShrine(
            .dash,
            ability: .dash,
            checkpoint: CheckpointSnapshot(
                id: .postDash,
                roomID: .dashShrine,
                spawn: RoomPoint(x: 760, y: 130)
            )
        )
        expectProgression(claimed, "first dash shrine activation is accepted")
        expectProgression(state.has(.dash), "dash unlock is recorded")
        expectProgression(state.consumedShrines.contains(.dash), "dash shrine is consumed")
        expectProgression(state.checkpoint.id == .postDash, "post-Dash checkpoint is activated atomically")

        let duplicate = state.claimShrine(
            .dash,
            ability: .dash,
            checkpoint: state.checkpoint
        )
        expectProgression(!duplicate, "consumed shrine cannot activate twice")

        state = .fresh
        expectProgression(!state.has(.dash), "New Game-style reset removes dash")
        expectProgression(state.consumedShrines.isEmpty, "New Game-style reset clears shrine consumption")
        expectProgression(state.checkpoint.id == .approach, "New Game-style reset restores Approach checkpoint")

        print("DemoProgressionTests: PASS")
    }
}
```

- [ ] **Step 2: Add the CI test step and verify RED**

Add before the existing HUD/enemy tests in `.github/workflows/build-ipa.yml`:

```yaml
      - name: Test demo progression
        shell: bash
        run: |
          set -euo pipefail
          xcrun swiftc Tests/DemoProgressionTests.swift Sources/DemoProgression.swift Sources/RoomController.swift Sources/EnemyArchetype.swift -o build/DemoProgressionTests
          ./build/DemoProgressionTests
```

Push only the test/workflow change. Expected CI result: **FAIL** because `Sources/DemoProgression.swift` and V24 room/checkpoint symbols do not exist yet.

- [ ] **Step 3: Implement the minimal progression types**

In `Sources/RoomController.swift`, change:

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

- [ ] **Step 4: Verify GREEN and existing RoomController tests**

Run through CI or local macOS Swift:

```bash
xcrun swiftc Tests/DemoProgressionTests.swift Sources/DemoProgression.swift Sources/RoomController.swift Sources/EnemyArchetype.swift -o /tmp/DemoProgressionTests && /tmp/DemoProgressionTests
xcrun swiftc Tests/RoomControllerTests.swift Sources/RoomController.swift Sources/EnemyArchetype.swift Sources/DemoProgression.swift -o /tmp/RoomControllerTests && /tmp/RoomControllerTests
```

Expected: both print `PASS`.

- [ ] **Step 5: Commit**

```bash
git add Sources/DemoProgression.swift Sources/RoomController.swift Tests/DemoProgressionTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: add durable demo progression model"
```

---

### Task 2: Save Store, Continue/New Game, and Runtime Bootstrap

**Files:**
- Create: `Sources/DemoSaveStore.swift`
- Create: `Tests/DemoSaveStoreTests.swift`
- Modify: `Sources/V21RuntimeContext.swift`
- Modify: `Sources/AppRoot.swift`
- Modify: `Sources/GameView.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces: `enum DemoLaunchMode { case newGame, continueGame }`
- Produces: `struct DemoSaveStore` with `load()`, `save(_:)`, `clear()`, `hasSave`.
- Produces: `final class DemoProgressionRuntime` with durable `state`, `newGame()`, `reload()`, `claimShrine(...)`, `activateCheckpoint(...)`.
- `V21RuntimeContext` gains `let progression: DemoProgressionRuntime`.
- `V21RuntimeBootstrap.install(on:launchMode:)` becomes the scene entry point.

- [ ] **Step 1: Write the failing persistence round-trip test**

Create `Tests/DemoSaveStoreTests.swift` using an isolated defaults suite:

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

        expectSave(!store.hasSave, "empty defaults has no save")

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

        expectSave(store.hasSave, "saving creates a Continue state")
        expectSave(store.load() == state, "save round trip preserves progression")

        store.clear()
        expectSave(!store.hasSave, "clear removes Continue state")
        expectSave(store.load() == nil, "cleared save does not decode stale state")

        print("DemoSaveStoreTests: PASS")
    }
}
```

- [ ] **Step 2: Add CI step and verify RED**

```yaml
      - name: Test demo save store
        shell: bash
        run: |
          set -euo pipefail
          xcrun swiftc Tests/DemoSaveStoreTests.swift Sources/DemoSaveStore.swift Sources/DemoProgression.swift Sources/RoomController.swift Sources/EnemyArchetype.swift -o build/DemoSaveStoreTests
          ./build/DemoSaveStoreTests
```

Expected: **FAIL** with `cannot find 'DemoSaveStore' in scope`.

- [ ] **Step 3: Implement `DemoSaveStore` and runtime wrapper**

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

- [ ] **Step 4: Thread launch mode through runtime/bootstrap**

Modify `V21RuntimeContext` initializer so it receives a progression runtime:

```swift
final class V21RuntimeContext: NSObject {
    let progression: DemoProgressionRuntime
    // existing properties remain

    init(progression: DemoProgressionRuntime) {
        self.progression = progression
        super.init()
    }
}
```

Change bootstrap entry point:

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

Update any fallback `V21RuntimeContext()` construction sites to construct with `DemoProgressionRuntime(launchMode: .continueGame)`.

- [ ] **Step 5: Add minimal New Game / Continue launcher**

Replace direct `GameView()` in `AppRoot.swift` with a SwiftUI launcher that reads `DemoSaveStore().hasSave` and creates `GameView(launchMode:)`. Keep the UI deliberately minimal: title, `CONTINUE` when a save exists, and `NEW GAME`.

Update `GameView`:

```swift
struct GameView: UIViewRepresentable {
    let launchMode: DemoLaunchMode

    func makeUIView(context: Context) -> SKView {
        let skView = SKView(frame: .zero)
        // preserve current SKView configuration
        let scene = GameScene(size: CGSize(width: 844, height: 390))
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
        V21RuntimeBootstrap.install(on: scene, launchMode: launchMode)
        return skView
    }
}
```

The launcher does not add save slots or settings; those remain out of scope.

- [ ] **Step 6: Verify tests and arm64 compile**

Run `DemoSaveStoreTests`, `DemoProgressionTests`, and the workflow arm64 compile command. Expected: tests print `PASS`; `swiftc -target arm64-apple-ios15.0 ... Sources/*.swift` exits 0.

- [ ] **Step 7: Commit**

```bash
git add Sources/DemoSaveStore.swift Sources/V21RuntimeContext.swift Sources/AppRoot.swift Sources/GameView.swift Tests/DemoSaveStoreTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: persist demo progress and add continue flow"
```

---

### Task 3: Dash State Machine and HUD Button

**Files:**
- Create: `Sources/DashController.swift`
- Create: `Tests/DashControllerTests.swift`
- Modify: `Sources/HUDControlLayout.swift`
- Modify: `Tests/HUDControlLayoutTests.swift`
- Modify: `Sources/GameScene.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces: `struct DashController` with `tryStart(...) -> Double?`, `update(dt:)`, `restoreAirDash()`, `cancelActiveDash()`.
- `GameScene.Control` gains `.dash`.
- `HUDControlKind` gains `.dash`.
- `GameScene` reads `context.progression.state.has(.dash)` before starting.

- [ ] **Step 1: Write RED tests for Dash rules**

Create `Tests/DashControllerTests.swift` covering locked ability, ground dash, 0.6 s cooldown, one air dash, landing restore, wall/pogo restore, and active dash duration:

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
        expectDash(dash.tryStart(unlocked: false, isGrounded: true, inputX: 1, facing: 1) == nil, "locked dash cannot start")

        let groundDirection = dash.tryStart(unlocked: true, isGrounded: true, inputX: -1, facing: 1)
        expectDash(groundDirection == -1, "held horizontal input chooses dash direction")
        expectDash(dash.isDashing, "dash enters active window")
        dash.update(dt: 0.20)
        expectDash(!dash.isDashing, "dash active window ends")
        expectDash(dash.tryStart(unlocked: true, isGrounded: true, inputX: 0, facing: 1) == nil, "cooldown blocks immediate reuse")
        dash.update(dt: 0.50)
        expectDash(dash.tryStart(unlocked: true, isGrounded: false, inputX: 0, facing: 1) == 1, "facing is used when input is neutral")
        dash.update(dt: 0.70)
        expectDash(dash.tryStart(unlocked: true, isGrounded: false, inputX: 1, facing: 1) == nil, "second air dash is blocked")
        dash.restoreAirDash()
        expectDash(dash.tryStart(unlocked: true, isGrounded: false, inputX: 1, facing: 1) == 1, "restore event grants air dash again")

        print("DashControllerTests: PASS")
    }
}
```

- [ ] **Step 2: Verify RED in CI**

Add:

```yaml
      - name: Test dash controller
        shell: bash
        run: |
          set -euo pipefail
          xcrun swiftc Tests/DashControllerTests.swift Sources/DashController.swift -o build/DashControllerTests
          ./build/DashControllerTests
```

Expected: **FAIL** because `DashController` does not exist.

- [ ] **Step 3: Implement minimal Dash controller**

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

- [ ] **Step 4: Add shared DASH HUD geometry test first**

Extend `HUDControlKind` test expectations before production change. The visible DASH center must resolve to `.dash`, remain above the bottom safe area, stay within the right edge, and not visually overlap Attack or Jump.

Use a target around:

```swift
let dash = layout.target(for: .dash)
expectHUD(layout.resolve(x: dash.center.x, y: dash.center.y) == .dash, "visible dash center resolves to dash")
expectHUD(dash.center.y + dash.visualRadius <= height - safeBottom, "dash stays above bottom safe area")
```

Expected RED: `.dash` does not exist.

- [ ] **Step 5: Add DASH target without regressing current controls**

In `HUDControlLayout.swift` add `.dash` and return:

```swift
case .dash:
    return target(
        x: viewWidth - 137,
        y: baselineY - 90,
        visualRadius: 42,
        hitRadius: 52
    )
```

Keep current left/right/up/down/focus/attack/jump centers unchanged. Run `HUDControlLayoutTests` to prove the new button fits the known 667×375 case and all visible centers resolve correctly.

- [ ] **Step 6: Integrate Dash into `GameScene`**

Add `dashButton`, `dashLabel`, `.dash` control mapping, and `private var dashController = DashController()`.

In frame update:

```swift
dashController.update(dt: dt)
```

When `.dash` is pressed:

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

During horizontal velocity update, Dash takes precedence only while active:

```swift
if dashController.isDashing {
    velocity.dx = CGFloat(dashController.direction) * 720
    velocity.dy = 0
    return
}
```

Skip gravity application while `isDashing`; resume existing gravity immediately afterward. If `moveHorizontally` resolves a solid collision during an active dash, call `dashController.cancelActiveDash()` after snapping outside the platform. Do not bypass the existing `maxMotionPerSubstep = 5` integration.

On landing transition and successful pogo integration points, call `dashController.restoreAirDash()`.

- [ ] **Step 7: Verify Dash regression set**

Run Dash tests, HUD tests, CombatImpulse tests, AttackController tests, and full arm64 compile. Expected: all pass; no existing control enum switch remains non-exhaustive.

- [ ] **Step 8: Commit**

```bash
git add Sources/DashController.swift Sources/HUDControlLayout.swift Sources/GameScene.swift Tests/DashControllerTests.swift Tests/HUDControlLayoutTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: add unlockable kinematic dash"
```

---

### Task 4: Passive Wall Cling / Wall Jump

**Files:**
- Create: `Sources/WallTraversalController.swift`
- Create: `Tests/WallTraversalControllerTests.swift`
- Modify: `Sources/GameScene.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces: `enum WallSide { case left, right }`
- Produces: `struct WallTraversalController` with `clingSide(...)`, `wallJump(...)`, `update(dt:)`.
- `GameScene` supplies actual wall contact from the current AABB geometry and applies returned impulses.

- [ ] **Step 1: Write RED tests for cling/jump rules**

Test: locked ability cannot cling; grounded player cannot cling; holding away cannot cling; valid wall contact caps slide; wall jump pushes away/up; same wall is temporarily suppressed; opposing wall can be used; wall jump is an air-dash restore event.

Use constants in the expected contract:

```swift
let slideCap = -180.0
let jump = controller.wallJump(from: .right)
expectWall(jump.velocityX < 0, "right-wall jump pushes left")
expectWall(jump.velocityY > 0, "wall jump pushes upward")
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

Expected: **FAIL** because the controller is missing.

- [ ] **Step 3: Implement pure wall traversal state**

Create `Sources/WallTraversalController.swift` with these fixed initial tuning values:

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

- [ ] **Step 4: Add reliable wall-contact probing to `GameScene`**

Do not depend only on `velocity.dx != 0`, because a player pressed into a wall has horizontal velocity zero after collision resolution. Add a 1-point side probe using `playerRect` and `platformRects`:

```swift
private func detectedWallContact() -> WallSide? {
    let probe: CGFloat = 1.0
    let leftProbe = playerRect.offsetBy(dx: -probe, dy: 0)
    let rightProbe = playerRect.offsetBy(dx: probe, dy: 0)
    let hitsLeft = platformRects.contains { leftProbe.intersects($0) && !playerRect.intersects($0) }
    let hitsRight = platformRects.contains { rightProbe.intersects($0) && !playerRect.intersects($0) }
    if hitsLeft { return .left }
    if hitsRight { return .right }
    return nil
}
```

If the strict `!playerRect.intersects` guard proves too sensitive at exact floating-point edges, use a narrowed vertical probe (`insetBy(dx: 0, dy: 2)`) rather than increasing probe distance.

- [ ] **Step 5: Integrate wall slide and wall jump**

Each frame, call `wallTraversalController.update(dt:)`. After ordinary gravity but before integration, if progression has `.wallTraversal` and `clingSide(...)` returns a side, cap:

```swift
velocity.dy = max(velocity.dy, CGFloat(wallTraversalController.slideSpeed))
```

When JUMP is pressed during a valid cling, bypass the ordinary coyote jump and apply the wall-jump impulse. Clear jump buffer/coyote state, mark airborne, and call `dashController.restoreAirDash()`.

Entering valid wall cling also restores the aerial Dash once per cling contact; avoid repeated side effects by tracking the previous cling side and only restoring on the transition from no cling → cling.

- [ ] **Step 6: Verify movement regressions**

Run WallTraversal tests, Dash tests, CombatImpulse tests, PlayerAttackDirection tests, and arm64 compile. Verify no `SKPhysicsBody` was added to the player.

- [ ] **Step 7: Commit**

```bash
git add Sources/WallTraversalController.swift Sources/GameScene.swift Tests/WallTraversalControllerTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: add passive wall traversal"
```

---

### Task 5: V24 Room Topology, Shrines, Checkpoints, and Ability-Gated Exits

**Files:**
- Modify: `Sources/RoomController.swift`
- Create: `Tests/DemoRoomTopologyTests.swift`
- Modify: `Tests/RoomControllerTests.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces: `struct AbilityShrinePlacement` and `struct CheckpointTrigger` metadata in room definitions.
- Extends: `RoomExit` with `requiredAbility: PlayerAbility?`.
- Extends: `exitIfNeeded(... unlockedAbilities: Set<PlayerAbility>)` while keeping a compatibility default `[]` for old tests/callers during the migration.
- Produces: `RoomController.makeV24Demo()`.

- [ ] **Step 1: Write the topology test before editing rooms**

Create `Tests/DemoRoomTopologyTests.swift` asserting exact required order:

```swift
let level = RoomController.makeV24Demo()
expectTopology(level.orderedRoomIDs == [
    .approach, .lowerHall, .brokenGallery, .dashShrine,
    .furnacePassage, .watcherHall, .hollowShaft,
    .ashenAscent, .wardenGate, .wardenChamber
], "V24 progression order is stable")
```

Also assert:
- Dash Shrine contains `.dash` shrine metadata and post-Dash checkpoint.
- Hollow Shaft contains `.wallTraversal` shrine metadata and post-Wall checkpoint.
- Warden Gate has pre-Warden checkpoint trigger.
- At least one optional exit has a non-nil `requiredAbility` and does not activate when the ability is absent.
- Warden Chamber contains the boss and a completing exit/state.

- [ ] **Step 2: Add CI step and verify RED**

```yaml
      - name: Test V24 room topology
        shell: bash
        run: |
          set -euo pipefail
          xcrun swiftc Tests/DemoRoomTopologyTests.swift Sources/RoomController.swift Sources/EnemyArchetype.swift Sources/DemoProgression.swift -o build/DemoRoomTopologyTests
          ./build/DemoRoomTopologyTests
```

Expected: **FAIL** because `makeV24Demo`, new room IDs/metadata, and ability-gated exits are not yet complete.

- [ ] **Step 3: Add room metadata types**

In `RoomController.swift`:

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

Add to `RoomDefinition`:

```swift
let shrine: AbilityShrinePlacement?
let checkpointTriggers: [CheckpointTrigger]
```

Add to `RoomExit`:

```swift
let requiredAbility: PlayerAbility?
```

Default all new initializer parameters to nil/empty so existing room tests can migrate incrementally.

- [ ] **Step 4: Extend exit resolution with ability gating**

Change exit selection so it ignores an exit whose `requiredAbility` is not unlocked. Preserve existing `requiresCombatClear` behavior. Add a compatibility default:

```swift
func exitIfNeeded(
    playerCenter: RoomPoint,
    playerSize: RoomSize,
    in roomID: RoomID,
    combatCleared: Bool,
    unlockedAbilities: Set<PlayerAbility> = []
) -> RoomExitActivation?
```

- [ ] **Step 5: Define the 10-room demo**

Implement `makeV24Demo()` with 1200×560 room-local bounds and exits placed on the intended screen edge:

- Approach `DOWN` → Lower Hall.
- Lower Hall `LEFT` → Broken Gallery.
- Broken Gallery `DOWN` → Dash Shrine.
- Dash Shrine `LEFT` → Furnace Passage.
- Furnace Passage `UP` → Watcher Hall.
- Watcher Hall `LEFT` → Hollow Shaft.
- Hollow Shaft `UP` → Ashen Ascent.
- Ashen Ascent `LEFT` → Warden Gate.
- Warden Gate `DOWN` → Warden Chamber.
- Warden Chamber completion after Ash Warden clear.

Use destination spawns on the opposite edge: downward exit spawns near destination top, upward exit near destination bottom, left exit near destination right.

Preserve current enemy archetype intent and use these minimum encounter roles:
- Approach: one Grunt.
- Lower Hall: two Grunts.
- Broken Gallery: Grunt + Runner.
- Dash Shrine: no combat in the teaching subsection.
- Furnace Passage: Grunt + Runner.
- Watcher Hall: Ranged + Grunt.
- Hollow Shaft: no mandatory combat at the shrine floor; optional ledge enemy is allowed only if it does not block learning.
- Ashen Ascent: Runner/Ranged on selected ledges.
- Warden Gate: Heavy + Ranged.
- Warden Chamber: Boss.

Add one optional Wall Traversal-gated shortcut from Broken Gallery into a later connected room so the world has at least one traversal payoff without changing the required first-run order.

- [ ] **Step 6: Verify topology and legacy room tests**

Run both topology and room controller test executables. Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/RoomController.swift Tests/DemoRoomTopologyTests.swift Tests/RoomControllerTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: define V24 demo room topology"
```

---

### Task 6: Active-Room Geometry and Directional Runtime

**Files:**
- Modify: `Sources/GameScene.swift`
- Modify: `Sources/RoomRuntimeInstaller.swift`
- Modify: `Sources/V21RuntimeContext.swift`
- Test: `Tests/DemoRoomTopologyTests.swift`

**Interfaces:**
- `GameScene` produces `func replaceRoomGeometry(platforms: [RoomPlatform], roomWidth: CGFloat, roomHeight: CGFloat)` for the runtime installer.
- `RoomRuntimeInstaller` uses `context.progression.state.checkpoint` as initial room/spawn.
- Current room collision is rebuilt from the active `RoomDefinition.platforms`; the controller algorithm remains unchanged.

- [ ] **Step 1: Add a failing geometry/topology assertion**

Extend `DemoRoomTopologyTests` so every required room has a floor or traversable platform set, every directional exit trigger lies inside room bounds, and destination spawns lie inside destination bounds. This catches malformed room data before SpriteKit runtime integration.

Expected RED until all V24 platform/trigger definitions satisfy the assertions.

- [ ] **Step 2: Add a dedicated room geometry node and replacement API**

In `GameScene`, stop treating startup demo platforms as permanent collision truth. Keep `buildWorld()` for backdrop creation, but name a child `roomGeometry` and route visual platforms through it.

Add:

```swift
func replaceRoomGeometry(
    platforms: [RoomPlatform],
    roomWidth: CGFloat,
    roomHeight: CGFloat
) {
    platformRects.removeAll(keepingCapacity: true)
    let geometry = worldRoot.childNode(withName: "roomGeometry") ?? SKNode()
    geometry.name = "roomGeometry"
    geometry.removeAllChildren()
    if geometry.parent == nil { worldRoot.addChild(geometry) }

    for platform in platforms {
        let center = CGPoint(x: platform.center.x, y: platform.center.y)
        let size = CGSize(width: platform.size.width, height: platform.size.height)
        platformRects.append(CGRect(
            x: center.x - size.width * 0.5,
            y: center.y - size.height * 0.5,
            width: size.width,
            height: size.height
        ))
        // create the same simple platform visual under roomGeometry
    }

    worldWidth = roomWidth
}
```

Use explicit `CGFloat(...)` conversions as needed. Do **not** change `integrateKinematicMotion`, `moveHorizontally`, `moveVertically`, or `maxMotionPerSubstep` beyond the already-planned Dash collision cancellation and wall probes.

- [ ] **Step 3: Replace V21 two-segment recycling in `RoomRuntimeInstaller`**

Remove `physicalOriginX(for:)` and the dependency on even/odd 0/1200 collision segments. Apply each room in the same room-local physical frame:

```swift
let originX: CGFloat = 0
let roomWidth = CGFloat(room.bounds.width)
context.physicalRoomMinX = 0
context.physicalRoomMaxX = roomWidth
(gameScene as? GameScene)?.replaceRoomGeometry(
    platforms: room.platforms,
    roomWidth: roomWidth,
    roomHeight: CGFloat(room.bounds.height)
)
```

Set player spawn directly from room-local coordinates. Existing enemy installers receive `physicalOriginX: 0`.

- [ ] **Step 4: Start from the saved checkpoint**

Initialize runtime with:

```swift
let checkpoint = context.progression.state.checkpoint
state.activeRoomID = checkpoint.roomID
applyRoom(checkpoint.roomID, destinationSpawn: checkpoint.spawn)
```

For a New Game this resolves to Approach; for Continue/death it resolves to the latest persisted checkpoint.

- [ ] **Step 5: Pass abilities into exit resolution and support all edge triggers**

Call:

```swift
state.controller.exitIfNeeded(
    playerCenter: localPlayer,
    playerSize: RoomSize(width: 36, height: 60),
    in: state.activeRoomID,
    combatCleared: context.combatStatus.isCleared,
    unlockedAbilities: context.progression.state.unlockedAbilities
)
```

The trigger rectangles, not hard-coded x assumptions, determine whether an exit is left/right/up/down.

- [ ] **Step 6: Verify full CI before commit**

All pure tests plus arm64 compile/package must pass. This is the first task that replaces the old physical-room geometry strategy, so do not proceed if any movement/combat test regresses.

- [ ] **Step 7: Commit**

```bash
git add Sources/GameScene.swift Sources/RoomRuntimeInstaller.swift Sources/V21RuntimeContext.swift Tests/DemoRoomTopologyTests.swift
git commit -m "refactor: load collision geometry per active room"
```

---

### Task 7: Shrine Acquisition Runtime and Persistent Checkpoints

**Files:**
- Modify: `Sources/RoomRuntimeInstaller.swift`
- Modify: `Sources/PlayerDamageInstaller.swift`
- Modify: `Sources/DemoProgression.swift`
- Test: `Tests/DemoProgressionTests.swift`

**Interfaces:**
- Shrine activation calls `context.progression.claimShrine(...)` exactly once and persists ability + consumed shrine + linked checkpoint atomically.
- Pre-Warden trigger calls `context.progression.activateCheckpoint(...)`.
- Death replacement scene always bootstraps with `.continueGame`.

- [ ] **Step 1: Extend progression test for atomic shrine checkpoint semantics**

Assert that after `claimShrine`, all three durable facts are simultaneously true: ability unlocked, shrine consumed, linked checkpoint active. Also assert a duplicate call cannot move the checkpoint backward or replay the claim.

- [ ] **Step 2: Build shrine nodes from room metadata**

When applying a room with `room.shrine`, create one named node such as `v24AbilityShrine` at `placement.position`. Give it a visible but simple artifact/pedestal shape. If `context.progression.state.consumedShrines` already contains the shrine ID, render it dormant and do not attach activation behavior.

- [ ] **Step 3: Add activation detection and short acquisition presentation**

During room runtime update, when the player's 36×60 rect intersects a small shrine activation rect and the shrine is not consumed:

1. set a runtime `acquisitionActive` flag;
2. prevent room transition and combat input for about 0.45 s;
3. call `context.progression.claimShrine(...)` once;
4. show `DASH ACQUIRED` or `WALL TRAVERSAL ACQUIRED` centered above the player/HUD for the short presentation;
5. after the presentation, clear the flag and return control.

Do not use a long cutscene or artificial wait. The linked checkpoint is already persisted before the teaching section begins.

Expose a simple `GameScene` input-lock property/method rather than pausing the whole scene, so the scene can finish the acquisition presentation deterministically.

- [ ] **Step 4: Activate standalone checkpoint triggers**

For each `CheckpointTrigger` in the current room, if player intersects it and it is newer/different from the current checkpoint, call `context.progression.activateCheckpoint(...)`. Warden Gate's trigger must store `.preWarden` before the boss transition.

- [ ] **Step 5: Make death use latest durable checkpoint**

In `PlayerDamageInstaller.startRespawnTransition`, replace:

```swift
V21RuntimeBootstrap.install(on: replacement)
```

with:

```swift
V21RuntimeBootstrap.install(on: replacement, launchMode: .continueGame)
```

The replacement RoomRuntime then uses the saved checkpoint room/spawn. HP/reset semantics remain owned by the existing fresh `PlayerVitalState` created for the replacement scene.

- [ ] **Step 6: Verify death/save-related tests and compile**

Run progression, save-store, respawn-sequence, player-health, room-topology tests and arm64 compile. Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/RoomRuntimeInstaller.swift Sources/PlayerDamageInstaller.swift Sources/DemoProgression.swift Tests/DemoProgressionTests.swift
git commit -m "feat: add persistent shrines and checkpoints"
```

---

### Task 8: Build the 10+ Minute Gameplay Route

**Files:**
- Modify: `Sources/RoomController.swift`
- Modify: `Sources/RoomRuntimeInstaller.swift`
- Modify: `Sources/BossRuntimeInstaller.swift` only if arena clearance is required
- Test: `Tests/DemoRoomTopologyTests.swift`

**Interfaces:**
- Consumes the V24 room order, active-room geometry replacement, Dash, Wall Traversal, shrines, and checkpoints from Tasks 1–7.
- Produces a first-play route whose geometry and encounters match the spec's pacing roles.

- [ ] **Step 1: Encode traversal teaching gates in room geometry**

Adjust platform sets so:

- Dash Shrine has at least one gap that ordinary jump cannot clear but Dash can, followed by a safe multi-dash sequence.
- Hollow Shaft's shrine is at the lower portion and its mandatory exit is upward through opposing wall surfaces usable for wall jumps.
- Ashen Ascent contains forgiving sequences of wall jump → dash → wall cling → jump → dash, with landing ledges between harder chains.
- Warden Gate combines movement and Heavy/Ranged pressure but ends with a calm approach before the checkpoint/boss.

Do not use moving platforms in V24 unless a separate design is approved; static collision keeps the scope controlled.

- [ ] **Step 2: Verify ability gating mathematically against baseline movement**

Use the known jump/run constants when sizing gaps. Dash-required horizontal gaps must exceed ordinary full-jump horizontal reach at normal intended approach but remain comfortably inside Dash-assisted reach. Wall sections must be wider than the 36-point player collider and leave enough wall height for multiple 560-upward wall jumps without pixel-perfect timing.

Record chosen dimensions directly in `RoomController.makeV24Demo()`; do not introduce unexplained runtime randomization.

- [ ] **Step 3: Tune encounters for pacing, not HP padding**

Use existing archetype stats. Increase runtime through room traversal, mixed enemy positioning, and the need to use unlocked movement—not by multiplying enemy HP. Keep Watcher Hall on the already-rebalanced Ranged + Grunt concept.

- [ ] **Step 4: Adapt Warden Chamber only as needed**

Ensure the boss arena has enough horizontal space for the 720-point/s Dash to be useful without instantly crossing the entire arena and enough wall geometry that Wall Jump is optional mobility, not required survival. If the existing `BossRuntimeInstaller` arena already satisfies this, make no boss-code change.

- [ ] **Step 5: Verify topology test and full CI**

Run the complete workflow. Expected: all tests, arm64 compile, IPA package, and artifact upload succeed.

- [ ] **Step 6: Commit**

```bash
git add Sources/RoomController.swift Sources/RoomRuntimeInstaller.swift Sources/BossRuntimeInstaller.swift Tests/DemoRoomTopologyTests.swift
git commit -m "feat: build V24 ten-room demo route"
```

If `BossRuntimeInstaller.swift` was not changed, omit it from `git add`.

---

### Task 9: Full Regression, IPA, and Device Acceptance Gate

**Files:**
- No production file is required unless verification reveals a defect.
- Optional create after measured device run: `docs/superpowers/verification/2026-09-01-v24-device-playtest.md`

**Interfaces:**
- Produces the exact tested Git SHA, GitHub Actions run ID, artifact ID/digest, local IPA SHA-256, and device acceptance result.

- [ ] **Step 1: Run the complete GitHub Actions workflow on final HEAD**

Required successful steps include every existing V21/V23 regression test plus:

- Demo progression
- Demo save store
- Dash controller
- Wall traversal controller
- HUD control layout with DASH
- V24 room topology
- arm64 iOS compile
- IPA package
- artifact upload

Do not infer success from earlier task runs; use the final HEAD run.

- [ ] **Step 2: Verify artifact provenance**

Confirm artifact `workflow_run.head_sha` exactly equals final `main` HEAD. Record run ID, artifact ID, artifact digest, and commit SHA.

- [ ] **Step 3: Download and verify IPA locally**

Extract the workflow artifact, then verify:

```bash
unzip -t AshenHollow-unsigned.ipa
unzip -l AshenHollow-unsigned.ipa | grep 'Payload/AshenHollow.app/AshenHollow'
unzip -l AshenHollow-unsigned.ipa | grep 'Payload/AshenHollow.app/Info.plist'
shasum -a 256 AshenHollow-unsigned.ipa
```

All commands must succeed before sharing the IPA.

- [ ] **Step 4: Device test controls and persistence**

On the user's iPhone, verify in this order:

1. HUD top overlays remain correctly placed and DASH does not overlap Attack/Jump.
2. Dash shrine unlocks Dash once; death keeps it.
3. App relaunch → Continue keeps Dash and checkpoint.
4. Hollow Shaft unlocks Wall Traversal once; death keeps it.
5. Wall cling requires holding toward the wall; JUMP pushes away; no separate wall button exists.
6. New Game clears both abilities and restarts at Approach.
7. Boss death respawns at pre-Warden checkpoint.

Any failed item means V24 is not device-stable.

- [ ] **Step 5: Measure clean first-run duration**

Measure from gaining control in Approach to Ash Warden defeat/demo completion. Acceptance:

- normal first-time run: target 12–15 minutes;
- fast legitimate run: at least approximately 10 minutes;
- do not count required deaths as pacing;
- if under 10 minutes, add meaningful traversal/combat density in specific rooms and repeat the timing run;
- never fix runtime by adding idle waits, lowering player speed, inflating HP, or adding empty corridor distance.

- [ ] **Step 6: Record device acceptance**

If a verification document is created, use this exact shape:

```markdown
# V24 Device Playtest

- Build SHA: <exact verified SHA>
- GitHub Actions run: <exact verified run ID>
- IPA SHA-256: <exact verified hash>
- Device: user-tested iPhone
- HUD/control result: PASS or FAIL with note
- Save/Continue/New Game result: PASS or FAIL with note
- Dash result: PASS or FAIL with note
- Wall Traversal result: PASS or FAIL with note
- Boss/checkpoint result: PASS or FAIL with note
- Clean playthrough duration: <measured duration>
- V24 device-stable: YES only when every item passes and runtime requirement is met
```

Replace angle-bracket fields only with measured/verified values; do not commit a template containing unresolved placeholders.

- [ ] **Step 7: Final commit only if verification required code/content changes**

If no changes are needed, do not create an empty commit. If pacing or defects required changes, repeat final CI/artifact verification from the new HEAD before making any completion claim.
