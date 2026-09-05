# Large World + Cinematic Camera v1.2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the small arena with one continuous multi-screen blockout and add a cinematic dead-zone camera matching the supplied reference video behavior.

**Architecture:** `LargeWorldLayout.swift` owns world dimensions and architectural collision rectangles. `CinematicCameraController.swift` is a pure CoreGraphics camera-target solver with dead zones, smooth look-ahead and world clamping. `GameScene.swift` renders the layout, preserves the existing player movement/combat stack, and feeds the camera solver each frame.

**Tech Stack:** Swift 6-compatible syntax, SpriteKit, UIKit, SwiftUI, CoreGraphics, GitHub Actions macOS/iOS toolchains.

**Spec:** `docs/superpowers/specs/2026-09-05-large-world-camera-design.md`

## Global Constraints

- Release version: `CFBundleShortVersionString = 1.2`.
- Visible label: `v1.2 • LARGE WORLD • CINEMATIC CAMERA`.
- Preserve `CFBundleIdentifier = app.ashenhollow.prototype` and `CFBundleVersion = 2`.
- Preserve landscape-left/right only and the minimal IPA package contract.
- Preserve all nine Little Axion animation resources and existing movement/combat controllers.
- Keep the physical collider unchanged; player visual remains 480×480 for this iteration unless compilation/integration forces a correction.

---

### Task 1: Pure blockout and camera logic tests

**Files:**
- Create: `Tests/BlockoutLogicTests.swift`
- Create: `Tests/run-blockout-tests.sh`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Consumes: none.
- Produces: executable assertions for `LargeWorldLayout` and `CinematicCameraController`.

- [ ] **Step 1: Write failing camera/layout assertions**

Assert that the world spans at least 8 reference screens in X and 4 in Y, that collision geometry includes a multi-screen vertical shaft, that a player inside the dead zone does not shift the camera target materially, that leaving the dead zone does, and that camera output clamps to world bounds.

- [ ] **Step 2: Run CI and verify RED**

Expected: test step fails because `LargeWorldLayout.swift` and `CinematicCameraController.swift` do not exist yet.

### Task 2: Implement pure world and camera models

**Files:**
- Create: `Sources/LargeWorldLayout.swift`
- Create: `Sources/CinematicCameraController.swift`

**Interfaces:**
- Produces: `LargeWorldLayout.blockout`, `CinematicCameraController.reset(...)`, `CinematicCameraController.update(...)`.

- [ ] **Step 1: Implement minimal world geometry**

Use rectangle-based architecture for a starting cavern, long traversal, open chamber, tall shaft, upper route and descending continuation in one coordinate system.

- [ ] **Step 2: Implement camera target solver**

Use horizontal/vertical dead zones, smoothed direction-aware look-ahead, slower vertical follow, and clamp to world bounds using the visible camera size.

- [ ] **Step 3: Run blockout tests and verify GREEN**

Expected: all blockout logic assertions pass.

### Task 3: Integrate blockout into `GameScene`

**Files:**
- Modify: `Sources/GameScene.swift`

**Interfaces:**
- Consumes: `LargeWorldLayout.blockout` and `CinematicCameraController`.
- Produces: continuous traversable blockout rendered in SpriteKit.

- [ ] **Step 1: Replace the old 2200-wide arena builder**

Render all architectural collision rectangles from `LargeWorldLayout`; add far/background architecture and foreground silhouettes as non-colliding shapes.

- [ ] **Step 2: Preserve existing movement stack**

Keep run/jump/coyote/buffer/dash/wall-slide/wall-jump/attack/heal logic and current rectangle collision code.

- [ ] **Step 3: Replace direct camera follow**

Feed player position/velocity/facing and scene visible size to the camera controller every frame; assign the returned position to `SKCameraNode` through smoothing only.

- [ ] **Step 4: Compile the iOS app**

Expected: `xcrun swiftc` succeeds and all nine animation resources remain packaged.

### Task 4: Release metadata and verification

**Files:**
- Modify: `Info.plist`
- Modify: `Sources/GameView.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces: installable unsigned `v1.2` IPA artifact.

- [ ] **Step 1: Set release metadata**

Set version to `1.2` and visible label to `v1.2 • LARGE WORLD • CINEMATIC CAMERA`.

- [ ] **Step 2: Keep the v1.1 visual-scale transform**

Continue applying the 480×480 Little Axion visual at build time or bake the same size directly into `GameScene.swift`, but do not change the collider.

- [ ] **Step 3: Run GitHub Actions**

Expected: logic tests, asset validation, iOS compile, packaging and artifact upload all succeed.

- [ ] **Step 4: Verify artifact contents**

Confirm `CFBundleShortVersionString = 1.2`, bundle ID unchanged, build number 2, landscape orientations unchanged, and all nine `PlayerAnimations/*.png` files present.
