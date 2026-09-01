# Ashen Hollow V24 Level Rebuild v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current V24 room geometry and encounter placement with a coherent 10-room route that is physically forgiving on iPhone and validated end-to-end from spawn to exit.

**Architecture:** Keep the existing progression/runtime systems. Move the new V24 blockout into a dedicated builder, add an ordered mandatory-route manifest plus validator, and keep enemy placement as a second pass after traversal safety is green. Camera framing is adjusted independently so gameplay stays above the mobile HUD.

**Tech Stack:** Swift, SpriteKit, custom kinematic AABB movement, GitHub Actions, unsigned IPA packaging.

**Spec:** `docs/superpowers/specs/2026-09-01-v24-level-rebuild-v2-design.md`

## Global Constraints

- Preserve the approved 10-room V24 progression order.
- Preserve Dash, Wall Traversal, save/checkpoint, boss and tutorial systems.
- Use `PlayerMovementTuning.current` as the movement source of truth.
- Mandatory traversal targets 20–25% first-play margin.
- No `SKPhysicsBody` migration.
- No temporary patchers may remain in the final exact-SHA build.

---

### Task 1: Full-route manifest and validator

**Files:**
- Create: `Sources/V24MandatoryRoute.swift`
- Create: `Sources/V24RouteValidator.swift`
- Create: `Tests/V24FullRouteValidationTests.swift`
- Modify: `.github/workflows/build-ipa.yml`

**Interfaces:**
- Produces `V24MandatoryRoute.manifest(for:)` and `V24RouteValidator.validate(level:)`.
- Uses `TraversalSafetyValidator` and `PlayerMovementTuning.current`.

- [ ] **Step 1: Write failing test** asserting every mandatory room has an ordered route from spawn support to the exit, and that the current Furnace route is rejected as an overlong shelf chain.
- [ ] **Step 2: Run test in CI and verify RED** for missing route/validator types.
- [ ] **Step 3: Implement route-step types** (`ordinary`, `dash`, `wallJump`, `drop`, `exit`) and validation of platform indices, transfer safety, spawn support, continuation and exit reachability.
- [ ] **Step 4: Run route test and verify GREEN** on the new builder once Task 2 lands.

### Task 2: Rebuild all 10 rooms from scratch

**Files:**
- Create: `Sources/V24LevelRebuildV2.swift`
- Modify: `Sources/RoomController.swift` (rename old V24 builder to legacy and delegate `makeV24Demo()` to v2)
- Modify: `Tests/V24MandatoryTraversalTests.swift`
- Modify: `Tests/DemoRoomTopologyTests.swift`

**Interfaces:**
- Produces `RoomController.makeV24Demo()` with the v2 geometry.
- Consumed by runtime and all existing tests without call-site changes.

- [ ] **Step 1: Add failing topology assertions** for broad terraces, one Dash lesson, no Furnace zigzag staircase, clean Hollow Shaft and clean boss arena.
- [ ] **Step 2: Verify RED** against current V24 geometry.
- [ ] **Step 3: Implement new 10-room blockout** using broad surfaces and explicit route indices matching the manifest.
- [ ] **Step 4: Verify traversal/topology tests GREEN** and run the full-route validator.

### Task 3: Encounter placement safety pass

**Files:**
- Create: `Sources/V24EncounterSafetyValidator.swift`
- Modify: `Tests/V24EncounterPlacementTests.swift`
- Modify: `Sources/V24LevelRebuildV2.swift`

**Interfaces:**
- Validates enemy spawns against player spawn safety radius and mandatory landing rectangles.

- [ ] **Step 1: Add failing tests** rejecting enemies on mandatory landing zones, immediate ranged line-of-fire at spawn, and Runner lanes that are too short.
- [ ] **Step 2: Verify RED** on current placements.
- [ ] **Step 3: Place Grunt/Runner/Ranged/Heavy enemies only after blockout is green** with quiet traversal rooms preserved.
- [ ] **Step 4: Verify encounter tests GREEN**.

### Task 4: Mobile gameplay framing

**Files:**
- Create: `Sources/GameplayFraming.swift`
- Create: `Tests/GameplayFramingTests.swift`
- Modify: `Sources/GameScene.swift`

**Interfaces:**
- Produces a camera vertical target/offset derived from visible scene height and a reserved lower HUD band.

- [ ] **Step 1: Add failing framing tests** for 910x512-class landscape layout so ground combat and landing bands resolve above the lower control cluster.
- [ ] **Step 2: Verify RED** because current fixed `cameraVerticalOffset = 12` does not reserve the HUD band.
- [ ] **Step 3: Implement gameplay framing helper** and use it in `updateCamera` without moving HUD buttons.
- [ ] **Step 4: Verify framing and HUD tests GREEN**.

### Task 5: Regression, clean CI and IPA

**Files:**
- Modify only regression/workflow files if required.

- [ ] **Step 1: Run all V24 progression, route, topology, encounter, tutorial, Dash, Wall Traversal, combat, boss and HUD tests.**
- [ ] **Step 2: Run arm64 iOS typecheck and full compile.**
- [ ] **Step 3: Confirm workflow contains no staging/patch scripts.**
- [ ] **Step 4: Build unsigned IPA, verify ZIP integrity, executable and `Info.plist`, and record SHA-256.**
- [ ] **Step 5: Hand off IPA for physical-device acceptance.**
