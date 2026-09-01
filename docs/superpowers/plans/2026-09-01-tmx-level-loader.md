# TMX Level Loader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dependency-free Tiled/TMX authoring path for Ashen Hollow and migrate only the V24 Approach room to TMX while preserving the existing `RoomDefinition` runtime model and all V24 gameplay behavior.

**Architecture:** `TMXLevelLoader` parses a deliberately small finite orthogonal TMX subset into the existing `RoomDefinition` domain model. `RoomController.makeV24DemoV2()` continues to build the existing Swift definitions, then replaces only `.approach` with `Resources/Maps/approach.tmx` when that resource can be loaded; all validators and runtime code keep consuming the same domain types. The production resource loader searches the manually assembled app bundle first and a repository-relative path only for CLI tests/development.

**Tech Stack:** Swift 5.x, Foundation `XMLParser`, SpriteKit runtime unchanged, GitHub Actions `swiftc`, XML/TMX object layers, no third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-09-01-tmx-level-loader-design.md`

## Global Constraints

- Preserve the approved 10-room V24 progression order and existing gameplay systems.
- Migrate only Approach in this phase; the other nine rooms remain Swift-authored.
- Keep the custom kinematic player controller; do not introduce `SKPhysicsBody` player movement.
- No CocoaPods, SPM, SKTiled, or other third-party TMX dependency.
- TMX is an authoring/input format only; `RoomDefinition` remains the gameplay model.
- Supported TMX phase-1 subset is finite orthogonal maps, object groups, unrotated rectangles/points, and scalar custom properties.
- Preserve Approach's current mandatory route platform order: platform 0 -> platform 1 -> platform 0.
- Existing V24 movement, route, encounter, combat, save, checkpoint, boss, HUD, and typecheck tests must remain green.

---

### Task 1: Define the TMX schema and parser contract

**Files:**
- Create: `Sources/TMXRoomSchema.swift`
- Create: `Tests/TMXLevelLoaderTests.swift`

**Interfaces:**
- Produces: `TMXRoomSchema` constants/helpers used by `TMXLevelLoader`.
- Produces test contract for `TMXLevelLoader.loadRoom(data:sourceName:) -> RoomDefinition`.

- [ ] **Step 1: Add schema constants**

Define accepted layer names `Collision`, `Entities`, `Triggers`; accepted object classes `platform`, `player_spawn`, `enemy`, `checkpoint`, `shrine`, `room_exit`; and property keys including `roomID`, `worldOriginX`, `worldOriginY`, `requiresCombatClear`, bounds keys, enemy `id`/`archetype`, exit destination keys, ability keys, and checkpoint keys.

- [ ] **Step 2: Write parser tests before implementation**

Add inline XML tests covering:

```swift
let room = try TMXLevelLoader.loadRoom(data: Data(xml.utf8), sourceName: "inline.tmx")
assert(room.id == .approach)
assert(room.worldOrigin == RoomPoint(x: 4800, y: 1120))
assert(room.playerSpawn == RoomPoint(x: 120, y: 130))
```

Include tests for rectangle Y conversion, point Y conversion, platform ordering, Grunt mapping, exit destination, required ability, missing/duplicate spawn, unknown archetype, malformed scalar property, unsupported rotation, non-orthogonal map, and infinite map.

- [ ] **Step 3: Run the new tests and verify they fail because the loader is absent**

Run on macOS CI/tooling:

```bash
xcrun swiftc Tests/TMXLevelLoaderTests.swift Sources/TMXRoomSchema.swift Sources/RoomController.swift Sources/EnemyArchetype.swift Sources/DemoProgression.swift Sources/TMXLevelLoader.swift -o build/TMXLevelLoaderTests
./build/TMXLevelLoaderTests
```

Expected before Task 2: compile failure because `Sources/TMXLevelLoader.swift` does not exist.

- [ ] **Step 4: Commit the contract**

```bash
git add Sources/TMXRoomSchema.swift Tests/TMXLevelLoaderTests.swift
git commit -m "test: define TMX room loader contract"
```

### Task 2: Implement dependency-free TMX parsing

**Files:**
- Create: `Sources/TMXLevelLoader.swift`
- Test: `Tests/TMXLevelLoaderTests.swift`

**Interfaces:**
- Produces: `enum TMXLevelLoaderError: Error, Equatable, CustomStringConvertible`.
- Produces: `struct TMXLevelLoader`.
- Produces: `static func loadRoom(data: Data, sourceName: String = "<memory>") throws -> RoomDefinition`.
- Produces: `static func loadRoom(at url: URL) throws -> RoomDefinition`.
- Produces: `static func productionURL(named: String, bundle: Bundle = .main, fileManager: FileManager = .default) -> URL?`.
- Produces: `static func loadProductionRoom(named: String, bundle: Bundle = .main, fileManager: FileManager = .default) throws -> RoomDefinition`.

- [ ] **Step 1: Add typed parser errors**

Errors must distinguish missing resource, malformed XML, unsupported orientation/infinite/rotation, missing required property, unknown room/object/layer/archetype, invalid scalar property, missing/duplicate player spawn, and invalid exit destination/spawn.

- [ ] **Step 2: Parse XML into small intermediate objects**

Use `XMLParserDelegate` with `#if canImport(FoundationXML) import FoundationXML #endif`. Capture map attributes/properties, object-group name, object coordinates/class (`class` with `type` compatibility), point marker, rotation, and object properties.

- [ ] **Step 3: Convert finite Tiled coordinates centrally**

For map pixel height `H`:

```swift
rectangleCenterX = x + width * 0.5
rectangleCenterY = H - y - height * 0.5
pointX = x
pointY = H - y
```

Do not leak Tiled coordinates beyond the loader.

- [ ] **Step 4: Build existing domain types**

Map `Collision/platform` objects to `RoomPlatform` in source order. Map `Entities` into one `playerSpawn`, `EnemySpawn`, `CheckpointTrigger`, and `AbilityShrinePlacement`. Map `Triggers/room_exit` into `RoomExit`. Construct exactly one `RoomDefinition`.

Checkpoint property contract:

```text
checkpointID
checkpointRoom
checkpointSpawnX
checkpointSpawnY
```

Shrine additionally requires:

```text
id
ability
```

Enemy requires `id` and `archetype`. Exit uses `destinationRoom`, `destinationSpawnX`, `destinationSpawnY`, optional `completesLevel`, and optional `requiredAbility`.

- [ ] **Step 5: Implement production resource lookup**

Lookup order:

1. `<Bundle.main.bundleURL>/Resources/Maps/<name>.tmx`
2. `<Bundle.main.resourceURL>/Resources/Maps/<name>.tmx` when distinct
3. `<current working directory>/Resources/Maps/<name>.tmx` only as CLI/test fallback

- [ ] **Step 6: Run parser tests**

```bash
xcrun swiftc Tests/TMXLevelLoaderTests.swift Sources/TMXRoomSchema.swift Sources/TMXLevelLoader.swift Sources/RoomController.swift Sources/EnemyArchetype.swift Sources/DemoProgression.swift -o build/TMXLevelLoaderTests
./build/TMXLevelLoaderTests
```

Expected: all TMX parser tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sources/TMXLevelLoader.swift Sources/TMXRoomSchema.swift Tests/TMXLevelLoaderTests.swift
git commit -m "feat: add dependency-free TMX room parser"
```

### Task 3: Author the production Approach TMX and parity test

**Files:**
- Create: `Resources/Maps/approach.tmx`
- Create: `Tests/TMXApproachParityTests.swift`

**Interfaces:**
- Consumes: `TMXLevelLoader.loadRoom(at:)`.
- Produces: TMX-authored `.approach` definition matching the approved V24 Approach invariants.

- [ ] **Step 1: Write `approach.tmx` with a 1200 x 560 pixel map**

Use `tilewidth="40" tileheight="40" width="30" height="14"`, map properties `roomID=approach`, `worldOriginX=4800`, `worldOriginY=1120`, and `requiresCombatClear=true`.

`Collision` object order must be:

1. floor: Tiled rectangle `x=0 y=460 width=860 height=80` -> room center `(430, 60)`
2. tutorial block: `x=290 y=396 width=320 height=64` -> room center `(450, 132)`

`Entities`:

- `player_spawn`: point `(120, 430)` -> room `(120, 130)`
- `enemy`: point `(790, 430)`, properties `id=1`, `archetype=grunt` -> room `(790, 130)`

`Triggers`:

- `room_exit`: rectangle `x=900 y=340 width=300 height=220`, properties `destinationRoom=lowerHall`, `destinationSpawnX=1040`, `destinationSpawnY=420`

- [ ] **Step 2: Write parity/invariant tests**

Load the real TMX file from repository path and assert:

```swift
assert(room.id == .approach)
assert(room.platforms.count == 2)
assert(room.platforms[0] == RoomPlatform(center: RoomPoint(x: 430, y: 60), size: RoomSize(width: 860, height: 80)))
assert(room.platforms[1] == RoomPlatform(center: RoomPoint(x: 450, y: 132), size: RoomSize(width: 320, height: 64)))
assert(room.enemySpawns == [EnemySpawn(id: 1, archetype: .grunt, position: RoomPoint(x: 790, y: 130))])
```

Also assert combat clear, Lower Hall destination/spawn, `V24RouteValidator` success for the Approach mandatory route, and `V24EncounterSafetyValidator` success.

- [ ] **Step 3: Run parity test**

```bash
xcrun swiftc Tests/TMXApproachParityTests.swift Sources/TMXRoomSchema.swift Sources/TMXLevelLoader.swift Sources/RoomController.swift Sources/EnemyArchetype.swift Sources/DemoProgression.swift Sources/PlayerMovementTuning.swift Sources/TraversalSafetyValidator.swift Sources/V24MandatoryRoute.swift Sources/V24RouteValidator.swift Sources/V24EncounterSafetyValidator.swift -o build/TMXApproachParityTests
./build/TMXApproachParityTests
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Resources/Maps/approach.tmx Tests/TMXApproachParityTests.swift
git commit -m "feat: author Approach room in TMX"
```

### Task 4: Integrate TMX Approach into V24 construction with safe fallback

**Files:**
- Modify: `Sources/V24LevelRebuildV2.swift`
- Modify tests only where compile source lists require the new loader files.

**Interfaces:**
- Consumes: `TMXLevelLoader.loadProductionRoom(named: "approach")`.
- Preserves: `RoomController.makeV24Demo()` and `RoomController.makeV24DemoV2()` signatures.

- [ ] **Step 1: Keep a Swift fallback definition**

Rename only the local variable conceptually to `swiftApproach` inside `makeV24DemoV2()`; do not alter its existing coordinates or semantics.

- [ ] **Step 2: Load and validate the TMX replacement**

At construction time:

```swift
let approach: RoomDefinition
do {
    let loaded = try TMXLevelLoader.loadProductionRoom(named: "approach")
    guard loaded.id == .approach else {
        throw TMXLevelLoaderError.unexpectedRoomID(expected: .approach, actual: loaded.id)
    }
    approach = loaded
} catch {
    print("Ashen Hollow TMX fallback for Approach: \(error)")
    approach = swiftApproach
}
```

The fallback is migration protection only. Tests specifically exercise the real TMX separately, so malformed production TMX cannot hide behind the fallback in CI.

- [ ] **Step 3: Run existing topology/progression/route tests with loader sources included**

Update workflow compile commands that include `V24LevelRebuildV2.swift` to also include `Sources/TMXRoomSchema.swift Sources/TMXLevelLoader.swift`.

- [ ] **Step 4: Commit**

```bash
git add Sources/V24LevelRebuildV2.swift
git commit -m "feat: load Approach from TMX at runtime"
```

### Task 5: Package TMX resources and execute full CI regression

**Files:**
- Modify: `.github/workflows/build-ipa.yml`
- Modify: `.github/workflows/v24-route-validation.yml` if it independently compiles V24 level sources.

**Interfaces:**
- Produces app bundle path: `build/Payload/AshenHollow.app/Resources/Maps/approach.tmx`.

- [ ] **Step 1: Add TMX unit/parity tests to CI**

Before the existing V24 suite, compile and run `TMXLevelLoaderTests` and `TMXApproachParityTests` with the exact source lists from Tasks 2 and 3.

- [ ] **Step 2: Copy resources into the manually assembled app bundle**

Add before app compile/package verification:

```bash
mkdir -p "$APP/Resources/Maps"
cp Resources/Maps/*.tmx "$APP/Resources/Maps/"
test -f "$APP/Resources/Maps/approach.tmx"
```

Ensure `APP="build/Payload/AshenHollow.app"` is defined in that step.

- [ ] **Step 3: Extend compile source lists**

Every standalone test command that compiles `Sources/V24LevelRebuildV2.swift` must also compile `Sources/TMXRoomSchema.swift` and `Sources/TMXLevelLoader.swift` because `makeV24DemoV2()` now references them.

- [ ] **Step 4: Run full regression**

Expected green gates:

- TMX parser tests
- TMX Approach parity/route/encounter tests
- existing V24 level/progression tests
- combat/control tests
- arm64 iOS `GameScene` typecheck
- full arm64 app compile
- unsigned IPA package
- archive contains `Payload/AshenHollow.app/Resources/Maps/approach.tmx`

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/build-ipa.yml .github/workflows/v24-route-validation.yml
git commit -m "ci: validate and package TMX room resources"
```

### Task 6: Review, verify branch, and prepare merge

**Files:**
- Review all changed files.

**Interfaces:**
- Produces a feature branch whose diff contains only TMX phase-1 work and documentation.

- [ ] **Step 1: Compare against `main`**

Verify no unrelated gameplay values, HUD layout, combat tuning, movement tuning, boss logic, save format, or non-Approach room geometry changed.

- [ ] **Step 2: Verify CI evidence**

Confirm the feature branch/PR CI run is green. If branch push triggers are unavailable, open a PR to `main` and use pull-request checks; do not merge on assumptions.

- [ ] **Step 3: Inspect IPA artifact**

Confirm the generated archive includes the executable, `Info.plist`, and `Resources/Maps/approach.tmx`.

- [ ] **Step 4: Prepare merge handoff**

Do not modify `main` until the verified branch is reviewed. Physical iPhone acceptance remains required after merge/build for spawn, collision orientation, tutorial flow, Grunt placement, death/respawn, Lower Hall transition, camera framing, and HUD-safe composition.
