# Ashen Hollow V24 Level Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the existing ten-room V24 demo into a connected, first-play mobile-friendly metroidvania slice with contextual onboarding, mathematically validated traversal, deliberate enemy placement, visible world reactions, and the existing Ash Warden climax.

**Architecture:** Move movement constants into a shared pure tuning type consumed by `GameScene` and tests. Add a pure traversal validator that checks mandatory transfers using collider dimensions and conservative safety margins. Rebuild room blockout first, then add onboarding/runtime reactions and finally rebalance enemy placement and boss approach, preserving the current kinematic controller, progression order, abilities, saves, checkpoints, and boss state machine.

**Tech Stack:** Swift, SpriteKit, UIKit, Foundation, custom kinematic AABB collision, GitHub Actions/macOS arm64 iOS build.

**Spec:** `docs/superpowers/specs/2026-09-01-v24-level-rebuild-design.md`

## Global Constraints

- Exactly ten required V24 rooms; keep the approved progression order and directional intent.
- Keep Dash and Wall Traversal as the only traversal unlocks.
- Keep four checkpoint stages: start, post-Dash, post-Wall Traversal, pre-Warden.
- Keep the existing Ash Warden state-machine architecture.
- Keep the custom kinematic controller; do not introduce `SKPhysicsBody`.
- Mandatory traversal targets roughly 20–25% execution margin; optional shortcut traversal may be tighter.
- Player collider remains 36×60 pt unless a separate design changes it.
- Dash remains 720 pt/s for 0.16 s with 0.60 s cooldown and no i-frames.
- Wall Jump remains 360 pt/s horizontal, 560 pt/s vertical; wall slide cap remains -180 pt/s.
- First-use traversal teaching remains combat-free.
- Clean legitimate playthrough target remains 12–15 minutes; fast legitimate run should remain about 10+ minutes.

---

### Task 1: Shared movement tuning source of truth

**Files:**
- Create: `Sources/PlayerMovementTuning.swift`
- Modify: `Sources/GameScene.swift`
- Create: `Tests/PlayerMovementTuningTests.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces: `struct PlayerMovementTuning` with `static let current` and properties for collider, gravity, jump, run, acceleration, fall speed, coyote/buffer, substep, Dash, and Wall values.
- `GameScene` consumes `PlayerMovementTuning.current` rather than duplicated numeric movement constants.

- [ ] **Step 1: Write the failing test**

```swift
import Foundation

@main
struct PlayerMovementTuningTestsMain {
    static func main() {
        let t = PlayerMovementTuning.current
        precondition(t.colliderWidth == 36)
        precondition(t.colliderHeight == 60)
        precondition(t.gravity == 1700)
        precondition(t.jumpVelocity == 610)
        precondition(t.runSpeed == 315)
        precondition(t.dashSpeed == 720)
        precondition(t.dashDuration == 0.16)
        precondition(t.wallJumpHorizontalSpeed == 360)
        precondition(t.wallJumpVerticalSpeed == 560)
        print("PlayerMovementTuningTests: PASS")
    }
}
```

- [ ] **Step 2: Run test to verify RED**

Run in CI:

```bash
xcrun swiftc Tests/PlayerMovementTuningTests.swift Sources/PlayerMovementTuning.swift -o build/PlayerMovementTuningTests
./build/PlayerMovementTuningTests
```

Expected before implementation: compile failure because `PlayerMovementTuning.swift` does not exist.

- [ ] **Step 3: Implement shared tuning and wire `GameScene`**

Create:

```swift
struct PlayerMovementTuning: Equatable {
    let colliderWidth: Double
    let colliderHeight: Double
    let gravity: Double
    let jumpVelocity: Double
    let jumpReleaseVelocity: Double
    let maxFallSpeed: Double
    let runSpeed: Double
    let groundAcceleration: Double
    let airAcceleration: Double
    let groundDeceleration: Double
    let coyoteDuration: Double
    let jumpBufferDuration: Double
    let maxMotionPerSubstep: Double
    let dashSpeed: Double
    let dashDuration: Double
    let dashCooldown: Double
    let wallSlideSpeed: Double
    let wallJumpHorizontalSpeed: Double
    let wallJumpVerticalSpeed: Double
    let sameWallLockDuration: Double

    static let current = PlayerMovementTuning(
        colliderWidth: 36,
        colliderHeight: 60,
        gravity: 1700,
        jumpVelocity: 610,
        jumpReleaseVelocity: 285,
        maxFallSpeed: 900,
        runSpeed: 315,
        groundAcceleration: 1900,
        airAcceleration: 1050,
        groundDeceleration: 2400,
        coyoteDuration: 0.12,
        jumpBufferDuration: 0.12,
        maxMotionPerSubstep: 5,
        dashSpeed: 720,
        dashDuration: 0.16,
        dashCooldown: 0.60,
        wallSlideSpeed: -180,
        wallJumpHorizontalSpeed: 360,
        wallJumpVerticalSpeed: 560,
        sameWallLockDuration: 0.12
    )
}
```

Replace `GameScene` movement literals with `PlayerMovementTuning.current` conversions to `CGFloat`/`TimeInterval` as needed without changing behavior.

- [ ] **Step 4: Run tuning test plus full movement/combat regression suite**

Expected: all existing tests remain GREEN and arm64 typecheck succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sources/PlayerMovementTuning.swift Sources/GameScene.swift Tests/PlayerMovementTuningTests.swift .github/workflows/build-ipa.yml
git commit -m "refactor: centralize player movement tuning"
```

---

### Task 2: Pure traversal safety validator

**Files:**
- Create: `Sources/TraversalSafetyValidator.swift`
- Create: `Tests/TraversalSafetyValidatorTests.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Consumes: `PlayerMovementTuning.current`, `RoomPlatform`.
- Produces:

```swift
struct TraversalSafetyValidator {
    let tuning: PlayerMovementTuning
    func validateOrdinaryTransfer(from: RoomPlatform, to: RoomPlatform) -> TraversalTransferResult
    func validateDashTeachingTransfer(from: RoomPlatform, to: RoomPlatform) -> TraversalTransferResult
    func validateVerticalStep(from: RoomPlatform, to: RoomPlatform) -> TraversalTransferResult
}

enum TraversalTransferResult: Equatable {
    case safe
    case unsafe(String)
}
```

- [ ] **Step 1: Write RED tests**

Cover at minimum:

```swift
// +95 pt rise must be rejected for an ordinary mandatory step.
// +70 pt rise with broad receiving platform must be safe.
// 230–255 pt Dash teaching gap with >=260 pt receiving platform must be safe.
// receiving platform <180 pt must be rejected for mandatory ordinary transfer.
// a transfer whose horizontal arrival intersects the platform side below top-clearance must be rejected.
```

Use real `RoomPlatform` values and the 36×60 collider.

- [ ] **Step 2: Run RED**

Expected: compile failure because validator types do not exist.

- [ ] **Step 3: Implement validator**

Use conservative design envelopes rather than a perfect-player simulation:

```swift
let mandatoryRiseLimit = 80.0
let preferredMandatoryHorizontalGap = 170.0
let minimumMandatoryLandingWidth = 180.0
let minimumTutorialLandingWidth = 260.0
let dashTeachingGap = 230.0...255.0
```

For collision-side safety, compare source top, target top, target near edge, collider half-width/half-height, and a conservative trajectory-height estimate. Reject transfers whose horizontal arrival would put the collider into the target vertical face before its feet can clear `targetTop`.

- [ ] **Step 4: Run GREEN and regressions**

Expected: validator tests PASS; existing room/movement tests unchanged.

- [ ] **Step 5: Commit**

```bash
git add Sources/TraversalSafetyValidator.swift Tests/TraversalSafetyValidatorTests.swift .github/workflows/build-ipa.yml
git commit -m "test: add traversal safety validator"
```

---

### Task 3: Rebuild all ten room blockouts before enemy tuning

**Files:**
- Modify: `Sources/RoomController.swift`
- Modify: `Tests/DemoRoomTopologyTests.swift`
- Create: `Tests/V24MandatoryTraversalTests.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Consumes: `TraversalSafetyValidator`, existing `RoomDefinition`, existing progression/exit types.
- Produces: rebuilt `RoomController.makeV24Demo()` geometry with the same ten `RoomID`s, same shrines/checkpoints, and same required progression order.

- [ ] **Step 1: Write RED geometry-contract tests**

Tests must assert the room roles from the spec rather than exact decoration coordinates. Required assertions include:

```swift
// Approach has a broad start floor and one low tutorial ledge.
// Broken Gallery contains the wallTraversal-gated shortcut.
// Dash Shrine has one 230–255 pt teaching gap and >=260 pt receiving platform.
// Dash Shrine mandatory ascent steps are all <=80 pt rise and validator-safe.
// Hollow Shaft shrine remains walk-accessible before unlock.
// Hollow Shaft opposing wall inner gap is 170–200 pt.
// Hollow Shaft top recovery platform >=220 pt.
// Ashen Ascent mandatory transfers are validator-safe and separated by recovery platforms.
// Warden Chamber has broad floor and side walls, with no small mandatory catch platforms.
```

- [ ] **Step 2: Run RED against current geometry**

Expected: current V24 blockout fails multiple new contracts.

- [ ] **Step 3: Replace `makeV24Demo()` blockout**

Rebuild room geometry according to the approved functions:

- Approach: wide floor, low safe tutorial ledge, high Wall teaser.
- Lower Hall: two broad floor elevations + central ledge.
- Broken Gallery: clear main route + visible high Wall shortcut.
- Dash Shrine: walk-accessible shrine, one safe Dash gap, broad landing/recovery, 55–75 pt ascent steps.
- Furnace Passage: ordinary jumps + Dash-favored transfers, broad landings.
- Watcher Hall: cover/interruption before ranged lane.
- Hollow Shaft: walk-accessible shrine, 170–200 pt wall gap, broad upper landing.
- Ashen Ascent: recovery-separated combined traversal.
- Warden Gate: broad combat floor + optional height.
- Warden Chamber: broad arena floor + side walls only as meaningful traversal surfaces.

Keep all exits spatially consistent with the approved directional route.

- [ ] **Step 4: Run traversal/topology tests GREEN**

Run:

```bash
xcrun swiftc Tests/DemoRoomTopologyTests.swift Sources/RoomController.swift Sources/EnemyArchetype.swift Sources/DemoProgression.swift -o build/DemoRoomTopologyTests
./build/DemoRoomTopologyTests

xcrun swiftc Tests/V24MandatoryTraversalTests.swift Sources/TraversalSafetyValidator.swift Sources/PlayerMovementTuning.swift Sources/RoomController.swift Sources/EnemyArchetype.swift Sources/DemoProgression.swift -o build/V24MandatoryTraversalTests
./build/V24MandatoryTraversalTests
```

Expected: both PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/RoomController.swift Tests/DemoRoomTopologyTests.swift Tests/V24MandatoryTraversalTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: rebuild V24 room blockouts"
```

---

### Task 4: Contextual onboarding tutorial in Approach

**Files:**
- Create: `Sources/OnboardingTutorialController.swift`
- Create: `Tests/OnboardingTutorialControllerTests.swift`
- Modify: `Sources/GameScene.swift`
- Modify: `Sources/HUDControlLayout.swift` only if an existing highlight API cannot reuse current control geometry.
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces:

```swift
enum OnboardingStep: Equatable { case move, jump, attack, focusOpportunity, complete }

struct OnboardingTutorialController {
    private(set) var step: OnboardingStep
    mutating func recordHorizontalTravel(_ distance: Double)
    mutating func recordSuccessfulLandingAfterJump()
    mutating func recordSuccessfulAttackHit()
    mutating func updateFocusEligibility(missingHP: Bool, canAffordFocus: Bool)
    mutating func recordSuccessfulHeal()
}
```

- [ ] **Step 1: Write RED controller tests**

Required sequence:

```swift
move -> jump -> attack -> complete
```

Focus is opportunistic: if `missingHP && canAffordFocus`, expose a Focus hint; successful heal dismisses it. Focus never blocks room progression.

- [ ] **Step 2: Run RED**

Expected: compile failure because controller does not exist.

- [ ] **Step 3: Implement pure controller and scene presentation**

`GameScene` must:

- highlight the real HUD targets through existing layout geometry;
- show short labels: `MOVE`, `JUMP`, `ATTACK`, `HOLD FOCUS TO HEAL`;
- advance on successful gameplay events, not raw taps where the spec requires success;
- never show Dash/Wall tutorial at game start;
- avoid resetting tutorial completion on ordinary death/checkpoint reload.

- [ ] **Step 4: Run GREEN plus arm64 typecheck**

Expected: onboarding tests PASS; HUD/movement regressions remain PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/OnboardingTutorialController.swift Tests/OnboardingTutorialControllerTests.swift Sources/GameScene.swift Sources/HUDControlLayout.swift .github/workflows/build-ipa.yml
git commit -m "feat: add contextual onboarding tutorial"
```

---

### Task 5: Enemy placement pass after traversal is stable

**Files:**
- Modify: `Sources/RoomController.swift`
- Modify/Create: `Tests/V24EncounterPlacementTests.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Consumes: rebuilt room geometry and existing `EnemyArchetype` stats.
- Produces: deliberate enemy spawns that do not overlap player spawn, required landing surfaces, or first-use traversal tutorials.

- [ ] **Step 1: Write RED encounter-placement tests**

Assert:

```swift
// Approach contains exactly one Grunt and no other enemy.
// Dash Shrine and Hollow Shaft contain no enemies.
// Broken Gallery Runner has a sufficiently long horizontal lane.
// Watcher Hall has exactly Ranged + Grunt and Ranged is not on player spawn/first landing.
// Ashen Ascent enemies appear only after first recovery-safe traversal segment.
// Warden Gate has Heavy + Ranged separated into ground-guard and firing roles.
// No hostile spawn intersects any room's player spawn safety radius.
```

- [ ] **Step 2: Run RED**

Expected: one or more current spawn-layout contracts fail.

- [ ] **Step 3: Reposition existing archetypes only**

Do not add new enemy types. Preserve approved compositions while moving spawns to match room function.

- [ ] **Step 4: Run GREEN and all AI/combat tests**

Expected: encounter placement tests and existing enemy AI/runtime tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/RoomController.swift Tests/V24EncounterPlacementTests.swift .github/workflows/build-ipa.yml
git commit -m "feat: rebalance V24 enemy placement"
```

---

### Task 6: Visible world reactions and traversal teaching prompts

**Files:**
- Modify: `Sources/RoomRuntimeInstaller.swift` and/or current room presentation installer confirmed from repository state.
- Modify: `Sources/GameScene.swift` only for presentation hooks not already exposed.
- Modify: `Sources/DemoRoomProgressionResolver.swift` if state resolution needs a presentation contract.
- Create: `Tests/V24WorldReactionTests.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Consumes: existing progression state, consumed shrines, checkpoints, combat clear state, shortcut presentation resolver.
- Produces visible states for active/consumed shrines, inactive/active checkpoints, closed/open combat gates, locked/open shortcut, post-boss exit.

- [ ] **Step 1: Write RED state-resolution tests**

Required state assertions:

```swift
// Unconsumed Dash shrine => active; consumed => dormant.
// Post-Dash checkpoint => active after acquisition.
// Broken Gallery high route => locked before Wall Traversal, shortcut after unlock.
// Combat gate => closed before clear, open after clear.
// Ash Warden defeated => completion exit exposed.
```

- [ ] **Step 2: Run RED**

Expected: missing presentation cases fail.

- [ ] **Step 3: Implement minimal persistent presentation hooks**

Keep logic in pure resolvers where possible; SpriteKit nodes only render the resolved state.

Add contextual Dash teaching prompt after Dash acquisition and Wall teaching prompt after Wall acquisition. Prompts disappear after demonstrated success and do not replay for consumed shrines on Continue.

- [ ] **Step 4: Run GREEN and persistence/room regressions**

Expected: progression, save, room resolver, and world reaction tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources Tests .github/workflows/build-ipa.yml
git commit -m "feat: add V24 world reaction states"
```

---

### Task 7: Final boss-approach geometry and complete acceptance build

**Files:**
- Modify: `Sources/RoomController.swift` only if device-independent tests expose final arena/approach geometry issues.
- Modify: `Tests/V24MandatoryTraversalTests.swift`
- Modify: `Tests/V24EncounterPlacementTests.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces: exact-SHA clean V24 rebuild with no temporary CI patch steps and an unsigned IPA artifact.

- [ ] **Step 1: Add final acceptance assertions**

Assert all ten rooms exist, mandatory route is traversal-safe, one shortcut exists, four checkpoint stages exist, first-use Dash/Wall rooms are combat-free, Warden Gate has pre-boss checkpoint, Warden Chamber has exactly one boss and broad arena geometry.

- [ ] **Step 2: Run complete test suite**

Expected: every unit/regression test PASS.

- [ ] **Step 3: Run clean arm64 iOS compile**

```bash
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun swiftc -parse-as-library -target arm64-apple-ios15.0 -sdk "$SDK" -O -framework Foundation -framework SwiftUI -framework UIKit -framework SpriteKit Sources/*.swift -o build/Payload/AshenHollow.app/AshenHollow
```

Expected: exit code 0.

- [ ] **Step 4: Package and verify IPA**

```bash
cd build
zip -qry AshenHollow-unsigned.ipa Payload
unzip -t AshenHollow-unsigned.ipa
test -f Payload/AshenHollow.app/AshenHollow
test -f Payload/AshenHollow.app/Info.plist
```

Expected: archive integrity PASS and required app entries exist.

- [ ] **Step 5: Commit clean workflow state and record exact HEAD**

No temporary source-patching workflow step may remain in final `main`.

- [ ] **Step 6: Device acceptance**

Verify on physical iPhone:

- Approach tutorial is readable and non-blocking;
- every mandatory platform transfer is consistently reachable with touch controls;
- player does not collide with platform sides on intended arcs;
- Dash Shrine and Hollow Shaft teach safely;
- enemy placement reads correctly;
- shortcut/world reactions persist;
- boss approach/checkpoint work;
- clean first playthrough remains approximately 10+ minutes, target 12–15.
