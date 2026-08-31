# V20 Room / Level Architecture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single long test strip with a reusable two-room level flow while preserving the user-confirmed V19 controller, combat, health, AI, and death/respawn behavior.

**Architecture:** Keep one `GameScene` and make room structure data-driven. A pure Swift `RoomController` owns room definitions, exit lookup, and camera clamp math; `GameScene` remains the runtime owner of nodes, kinematic collision, player combat, the current test enemy, camera, and HUD. Normal room transitions rebuild only room-local geometry and reposition/reset the existing gameplay objects; V19 death still replaces the whole scene and returns to Room A.

**Tech Stack:** Swift 5.x, SpriteKit, UIKit, SwiftUI, GitHub Actions on macOS 15, arm64 iOS 15 target.

**Spec:** `docs/superpowers/specs/2026-08-31-v20-room-level-architecture-design.md`

## Global Constraints

- Preserve the confirmed kinematic player controller constants and collision algorithm.
- Preserve camera zoom `1.55` and existing smoothing/look-ahead behavior; only change horizontal clamp source.
- Preserve V15 melee attack, V16 enemy HP, V17 AI, V18 player damage/i-frames, and V19 scene-replacement death/respawn.
- V20 supports one active `testEnemy` only; multi-enemy support is deferred.
- First acceptance path is Room A → Room B.
- No external JSON/plist room loading in V20.
- All production behavior must be covered by a RED → GREEN unit-test cycle where practical.

---

### Task 1: Pure Room Model and Controller

**Files:**
- Create: `Tests/RoomControllerTests.swift`
- Create: `Sources/RoomController.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces: `RoomID`, `RoomPoint`, `RoomSize`, `RoomRect`, `RoomPlatform`, `RoomExit`, `RoomDefinition`, `RoomTransition`, `RoomController`.
- `RoomController.initialRoomID -> RoomID`
- `RoomController.room(_ id: RoomID) -> RoomDefinition?`
- `RoomController.transitionIfNeeded(playerCenter: RoomPoint, playerSize: RoomSize, in roomID: RoomID) -> RoomTransition?`
- `RoomController.clampedCameraX(targetX: Double, visibleHalfWidth: Double, in roomID: RoomID) -> Double`

- [ ] **Step 1: Write the failing room test**

```swift
import Foundation

@inline(__always)
func expectRoom(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct RoomControllerTestsMain {
    static func main() {
        let controller = RoomController.makeV20TestLayout()
        expectRoom(controller.initialRoomID == .entry, "Room A is initial")

        let roomA = controller.room(.entry)
        let roomB = controller.room(.combat)
        expectRoom(roomA != nil, "Room A exists")
        expectRoom(roomB != nil, "Room B exists")
        expectRoom(roomA!.bounds.width == 1200, "Room A width is 1200")
        expectRoom(roomB!.platforms.count != roomA!.platforms.count, "rooms use different geometry")

        let noTransition = controller.transitionIfNeeded(
            playerCenter: RoomPoint(x: 500, y: 130),
            playerSize: RoomSize(width: 36, height: 60),
            in: .entry
        )
        expectRoom(noTransition == nil, "middle of room does not transition")

        let transition = controller.transitionIfNeeded(
            playerCenter: RoomPoint(x: 1152, y: 130),
            playerSize: RoomSize(width: 36, height: 60),
            in: .entry
        )
        expectRoom(transition?.destinationRoomID == .combat, "Room A exit targets Room B")
        expectRoom(transition?.destinationSpawn == RoomPoint(x: 110, y: 130), "Room B spawn matches design")

        let leftClamp = controller.clampedCameraX(targetX: -500, visibleHalfWidth: 300, in: .entry)
        let rightClamp = controller.clampedCameraX(targetX: 5000, visibleHalfWidth: 300, in: .entry)
        expectRoom(leftClamp == 300, "camera clamps to Room A left edge")
        expectRoom(rightClamp == 900, "camera clamps to Room A right edge")

        print("RoomControllerTests: PASS")
    }
}
```

- [ ] **Step 2: Add CI step and verify RED**

Add before `Compile Ashen Hollow`:

```yaml
      - name: Test room controller
        shell: bash
        run: |
          set -euo pipefail
          xcrun swiftc Tests/RoomControllerTests.swift Sources/RoomController.swift -o build/RoomControllerTests
          ./build/RoomControllerTests
```

Expected: existing tests PASS; `Test room controller` FAILS because `Sources/RoomController.swift` does not exist.

- [ ] **Step 3: Implement the minimal pure room model/controller**

`Sources/RoomController.swift` must define the interfaces above and `makeV20TestLayout()` with:
- Room A / `.entry`: bounds `(0,0,1200,560)`, spawn `(120,130)`, floor + two raised platforms, enemy spawn around `(760,130)`, exit trigger near the right edge.
- Room B / `.combat`: bounds `(0,0,1380,560)`, spawn `(110,130)`, floor + a distinct raised-platform arrangement, enemy spawn around `(860,130)`, no required forward exit in V20.
- Room A exit destination spawn exactly `(110,130)`.

`RoomRect.intersects(_:)` must provide deterministic AABB overlap for tests and runtime conversion.

- [ ] **Step 4: Run CI and verify GREEN**

Expected: `RoomControllerTests: PASS`; all prior tests still PASS; iOS compile/package still succeeds because the new file is Foundation-only.

- [ ] **Step 5: Commit**

Commit message: `feat: add V20 room model and controller`.

---

### Task 2: Integrate Room Loading into GameScene Without Rewriting the Controller

**Files:**
- Modify: `Sources/GameScene.swift`
- Modify: `Sources/EnemyAIInstaller.swift`

**Interfaces:**
- Consumes: `RoomController.makeV20TestLayout()`, room definitions and transitions from Task 1.
- Produces in `GameScene`: `activeRoomID`, `loadRoom(_:playerSpawn:)`, `resolveRoomTransitionIfNeeded()`, room-local platform rebuild and room-local camera clamp.

- [ ] **Step 1: Add room runtime state to GameScene**

Add:
```swift
private let roomController = RoomController.makeV20TestLayout()
private var activeRoomID: RoomID = .entry
private let roomGeometryRoot = SKNode()
private var roomTransitionCooldown: CGFloat = 0
```

Keep all player acceleration/gravity/jump/run/collision constants unchanged.

- [ ] **Step 2: Replace the long-strip `buildWorld()` layout with room-local loading**

`buildWorld()` must:
- add persistent `worldRoot`;
- add `roomGeometryRoot` beneath it;
- call `loadRoom(.entry, playerSpawn: nil)` only after player/enemy nodes exist, or split initial world decoration from initial room loading so room loading occurs after `buildPlayer()` and `buildTestEnemy()`.

`loadRoom` must:
- clear `roomGeometryRoot` only;
- clear and rebuild `platformRects` from the active room definition;
- set `worldWidth` to active room width only as a compatibility value;
- draw a room-specific backdrop/floor/platforms;
- reset enemy HP/presentation and place/hide the existing enemy according to `enemySpawn`;
- place the player at explicit destination spawn or room default spawn;
- set `velocity = .zero`, `isGrounded = true`, clear jump/attack buffers, active touches, and transient attack visual/state;
- update `activeRoomID`;
- snap camera into valid active-room bounds;
- rerun `EnemyAIInstaller.install(on:)` after enemy position is final.

- [ ] **Step 3: Make EnemyAIInstaller respect the room-provided enemy position**

Remove the hard-coded line that forces `enemy.position.x = 520`.

Keep:
```swift
let runtime = EnemyAIRuntime(spawnX: enemy.position.x)
```
so patrol origin comes from the active room spawn.

- [ ] **Step 4: Add transition detection after kinematic motion**

After `integrateKinematicMotion(...)`, call `resolveRoomTransitionIfNeeded()`.

`resolveRoomTransitionIfNeeded()` must:
- ignore transition while a short transition cooldown is active;
- ask `RoomController.transitionIfNeeded(...)` using the logical player collider;
- call `loadRoom(destinationRoomID, playerSpawn: destinationSpawn)` once;
- apply a short cooldown (~0.20 s) to prevent immediate retrigger.

- [ ] **Step 5: Change only the horizontal world/camera clamps**

Player horizontal clamp must use the active room `bounds.minX/maxX` instead of the old global strip width.

`updateCamera` keeps the same look-ahead/smoothing constants but obtains min/max camera X via:
```swift
roomController.clampedCameraX(
    targetX: Double(targetXUnclamped),
    visibleHalfWidth: Double(visibleHalfWidth),
    in: activeRoomID
)
```

- [ ] **Step 6: Compile and fix only V20 integration errors**

Run full GitHub Actions workflow. Expected: all pure tests PASS and arm64 iOS compile succeeds. Do not change V13–V19 mechanics to fix room integration.

- [ ] **Step 7: Commit**

Commit message: `feat: integrate V20 room loading and transitions`.

---

### Task 3: Preserve Player Damage and V19 Respawn Across Normal Room Transitions

**Files:**
- Modify: `Sources/PlayerDamageInstaller.swift` only if integration requires reinstalling references after room transition.
- Modify: `Sources/GameScene.swift` only for a narrow room-transition hook if needed.

**Interfaces:**
- Normal room transition must not replace `GameScene`, so player damage HUD/runtime remains alive.
- V19 death must still replace the scene and therefore restart at Room A with 5/5 HP.

- [ ] **Step 1: Verify room transition does not recreate PlayerDamageInstaller**

Normal A → B transition must keep the same player node and player damage runtime action. No HP reset is allowed during a normal room transition.

- [ ] **Step 2: Ensure enemy references remain valid**

Because the existing `testEnemy` node is reused, `PlayerDamageInstaller` continues referencing the same node. Reinstall only `EnemyAIInstaller` after room load; do not create a second player damage runtime or duplicate HUD.

- [ ] **Step 3: Verify V19 scene replacement still starts in Room A**

Fresh `GameScene` initialization must set `activeRoomID = .entry`, load Room A, then install Enemy AI and Player Damage as before.

- [ ] **Step 4: Full regression build**

Expected CI order:
`AttackControllerTests PASS`, `EnemyHealthTests PASS`, `EnemyAIControllerTests PASS`, `PlayerHealthTests PASS`, `PlayerRespawnSequenceTests PASS`, `RoomControllerTests PASS`, iOS compile PASS, IPA package/upload PASS.

- [ ] **Step 5: Commit any compatibility fix only if needed**

Commit message: `fix: preserve V19 systems across room transitions`.

---

### Task 4: Artifact Verification and Device Acceptance Build

**Files:**
- No source changes unless verification exposes a concrete V20 defect.

**Interfaces:**
- Final output: exact-head unsigned IPA from GitHub Actions.

- [ ] **Step 1: Verify exact workflow head SHA**

Fetch the latest run and require `head_sha` to equal the final V20 source commit.

- [ ] **Step 2: Verify every CI step**

Require all six unit-test steps plus compile/package/upload to conclude `success`.

- [ ] **Step 3: Verify artifact provenance**

Require artifact `workflow_run.head_sha` to equal the exact V20 source commit.

- [ ] **Step 4: Download and validate IPA**

Extract the workflow ZIP and run ZIP integrity verification. Require:
- `Payload/AshenHollow.app/AshenHollow`
- `Payload/AshenHollow.app/Info.plist`
- no corrupt entries.

- [ ] **Step 5: Device acceptance checklist**

User verifies:
1. Room A uses a visibly bounded layout and camera does not reveal beyond its horizontal bounds.
2. Right-side Room A exit transitions into visibly different Room B geometry.
3. Player movement/jump/attack feel unchanged.
4. Room B enemy patrol/chase/attack/damage/death works.
5. Player HP remains consistent across A → B transition.
6. Death in Room B still runs V19 death/blackout/respawn and returns to Room A at 5/5 HP.
