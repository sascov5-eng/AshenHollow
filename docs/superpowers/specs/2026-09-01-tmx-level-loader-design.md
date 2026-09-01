# Ashen Hollow TMX Level Loader Design

## Goal

Introduce Tiled/TMX as the authoring format for Ashen Hollow room geometry and placement data without replacing the existing V24 runtime model, progression, combat, movement, save/checkpoint logic, boss logic, route validators, or custom kinematic controller.

The first implementation phase migrates only the Approach room end-to-end. The remaining nine V24 rooms stay on the existing Swift-authored definitions until the loader is proven on CI and a physical iPhone.

## Baseline

The design targets the current V24 codebase on `main` at commit `3602934df8bde78b81bd0dde8fd66aaa52bcca39`.

Existing systems remain authoritative:

- `RoomController.swift` defines `RoomID`, `RoomDefinition`, `RoomPlatform`, `EnemySpawn`, `RoomExit`, `CheckpointTrigger`, shrine placement, room bounds, and transition behavior.
- `V24LevelRebuildV2.swift` currently provides the 10-room V24 data set.
- `V24MandatoryRoute.swift`, `V24RouteValidator.swift`, `TraversalSafetyValidator.swift`, and `V24EncounterSafetyValidator.swift` validate the same `RoomDefinition` model used by gameplay.
- `RoomRuntimeInstaller.swift` and `GameScene.swift` consume room definitions and install the SpriteKit runtime.
- Dash, Wall Traversal, combat, boss, health, respawn, progression, save, checkpoint, tutorial, and world-reaction systems must remain behaviorally unchanged.
- The project compiles directly with `swiftc`; no Xcode project, CocoaPods, or package manager is required by the current CI pipeline.

## Core Architecture

TMX is an input format only. It must not become the gameplay model.

Data flow:

`Resources/Maps/*.tmx -> TMXLevelLoader -> RoomDefinition -> existing validators/runtime`

The loader parses a finite TMX map into the exact existing domain types used by V24. This keeps gameplay code independent of XML/Tiled and preserves all existing validation and runtime interfaces.

### New files

- `Sources/TMXLevelLoader.swift` — Foundation `XMLParser` implementation and TMX-specific parsing errors.
- `Sources/TMXRoomSchema.swift` — constants and small parsing helpers for accepted layer/object/property names.
- `Tests/TMXLevelLoaderTests.swift` — parser and coordinate-conversion coverage.
- `Tests/TMXApproachParityTests.swift` — verifies the TMX-authored Approach room preserves the required V24 route, encounters, exits, and metadata.
- `Resources/Maps/approach.tmx` — first production TMX room.

No third-party TMX library will be introduced in this phase.

## Runtime Integration

`V24LevelRebuildV2.makeController()` remains the public entry point for constructing the demo controller.

During phase 1 it will:

1. construct the existing Swift-authored 10-room definitions;
2. attempt to load `Resources/Maps/approach.tmx`;
3. replace only `.approach` with the parsed `RoomDefinition`;
4. keep the remaining nine rooms unchanged;
5. fail deterministically in tests when the TMX fixture is invalid;
6. in the app bundle, surface a clear assertion/log and fall back to the Swift Approach definition only if the bundled resource cannot be read.

The fallback is temporary migration protection, not a permanent dual-source architecture. Once all 10 rooms are migrated and validated, the Swift geometry source can be removed in a later task.

## Supported TMX Subset

Phase 1 supports only the features Ashen Hollow needs now:

- finite orthogonal TMX maps;
- XML map files stored directly in the app bundle;
- object groups;
- rectangle objects;
- point objects;
- string, integer, float, and boolean custom properties;
- map width/height and tile width/height metadata when present;
- unrotated objects only.

Explicitly unsupported in phase 1:

- infinite maps;
- rotated objects;
- polygon/polyline collision;
- base64 or compressed tile data;
- external TSX dependencies;
- image-layer rendering;
- animated tiles;
- terrain sets;
- Wang sets;
- custom scripting.

Unsupported required constructs must produce a descriptive parser error instead of being silently ignored.

## Tiled Layer Contract

The production TMX map uses these object layers.

### `Collision`

Rectangle objects become `RoomPlatform` entries.

Accepted object type/class:

- `platform`

Each platform uses the Tiled rectangle's width and height. Tiled top-left object coordinates are converted to SpriteKit/room-local center coordinates.

### `Entities`

Point or rectangle objects describe gameplay placements.

Accepted types/classes:

- `player_spawn`
- `enemy`
- `checkpoint`
- `shrine`

`enemy` properties:

- `id`: Int, required
- `archetype`: String, required, mapped to an existing `EnemyArchetype`

`checkpoint` properties encode the existing checkpoint/progression data needed to construct `CheckpointSnapshot`; no new save model is introduced.

`shrine` properties:

- `id`: existing `ShrineID` raw value
- `ability`: existing `PlayerAbility` raw value
- checkpoint-related properties required by the existing `AbilityShrinePlacement`

### `Triggers`

Rectangle objects describe transitions and non-visual trigger volumes.

Accepted types/classes:

- `room_exit`

`room_exit` properties:

- `destinationRoom`: `RoomID` raw value when the exit enters another room
- `destinationSpawnX`: Double when entering another room
- `destinationSpawnY`: Double when entering another room
- `completesLevel`: Bool, default false
- `requiredAbility`: optional `PlayerAbility` raw value

Exactly the existing `RoomExit` semantics are preserved.

## Map-Level Properties

Each TMX room requires:

- `roomID`: existing `RoomID` raw value
- `worldOriginX`: Double
- `worldOriginY`: Double
- `requiresCombatClear`: Bool

Room bounds are derived from explicit map properties when supplied:

- `boundsX`
- `boundsY`
- `boundsWidth`
- `boundsHeight`

If these are absent, a finite map may derive width/height from `map.width * tilewidth` and `map.height * tileheight`, with local origin `(0, 0)`.

## Coordinate Conversion

Tiled object coordinates use a top-left origin with positive Y downward. Ashen Hollow room-local coordinates use a bottom-left style coordinate space with positive Y upward.

Given a finite map height `H`:

For a rectangle object `(x, y, width, height)`:

- centerX = `x + width / 2`
- centerY = `H - y - height / 2`

For a point object `(x, y)`:

- pointX = `x`
- pointY = `H - y`

All conversion happens inside `TMXLevelLoader`. No SpriteKit/runtime consumer performs Tiled coordinate conversion.

## Approach Migration Contract

The first production TMX map is `Resources/Maps/approach.tmx`.

It must preserve the current approved Approach design from V24 level rebuild v2:

- long safe starting floor;
- MOVE tutorial before hazards;
- one low broad ledge for JUMP teaching;
- one stable combat area with a single Grunt for ATTACK;
- no precision traversal;
- optional inaccessible high geometry may tease later traversal;
- combat clear remains required before exit;
- exit continues to Lower Hall with the currently approved destination spawn;
- existing mandatory-route and encounter-safety validators remain green.

The TMX file becomes the source of geometry and placement for Approach, but tutorial state logic stays in existing controllers.

## Error Handling

`TMXLevelLoader` returns `RoomDefinition` or throws a typed error.

Errors must distinguish at minimum:

- missing resource;
- malformed XML;
- unsupported map orientation/infinite map;
- missing required map property;
- unknown `RoomID`;
- missing player spawn;
- duplicate player spawn;
- unknown object layer/type;
- invalid number/property type;
- unknown enemy archetype;
- invalid exit destination or incomplete destination spawn;
- unsupported rotated object.

Tests assert specific error cases so malformed maps cannot silently enter production.

## Bundle / CI Changes

The existing GitHub Actions compile step creates `build/Payload/AshenHollow.app` manually. TMX resources therefore must be copied explicitly.

The build workflow will:

1. create `build/Payload/AshenHollow.app/Resources/Maps`;
2. copy `Resources/Maps/*.tmx` into that directory;
3. verify `approach.tmx` exists in the app bundle before packaging;
4. compile loader tests with Foundation and the required domain source files;
5. run `TMXApproachParityTests` before the existing V24 route/encounter validation suite;
6. keep the existing arm64 typecheck, app compile, IPA packaging, and archive checks.

Runtime resource lookup must work with the actual unsigned app-bundle layout produced by this workflow rather than assuming an Xcode asset catalog.

## Testing Strategy

### Parser tests

Cover:

- finite map metadata;
- rectangle coordinate conversion;
- point coordinate conversion;
- map properties;
- collision platforms;
- enemy mapping;
- exits;
- required ability mapping;
- duplicate/missing spawn rejection;
- rotation rejection;
- malformed property rejection.

Tests should use small inline XML strings through a loader API that accepts `Data`, so unit tests do not depend on app-bundle lookup.

### Approach parity tests

Load the real `Resources/Maps/approach.tmx` and assert:

- room ID and world origin;
- bounds;
- player spawn;
- platform count/key geometry contract;
- one Grunt encounter with expected ID;
- combat-clear requirement;
- Lower Hall exit and destination spawn;
- route validator success;
- encounter safety success.

The parity test should verify design invariants rather than freezing every pixel coordinate unnecessarily.

### Regression suite

All existing tests for:

- movement tuning;
- Dash;
- Wall Traversal;
- combat;
- enemies;
- player damage/health/respawn;
- save/progression;
- room transitions;
- tutorial behavior;
- V24 mandatory route;
- V24 encounter safety;
- boss behavior;
- HUD/framing;

must remain green.

## Physical iPhone Acceptance

After CI passes, Approach must be checked on a real iPhone for:

- player spawn correctness;
- no collision gaps or inverted Y placement;
- unchanged jump/Dash/wall behavior;
- tutorial prompts still trigger correctly;
- Grunt placement and combat-clear exit behavior;
- death/respawn behavior;
- transition to Lower Hall;
- camera framing and HUD-safe composition.

TMX migration is not considered proven solely by parser unit tests.

## Migration Sequence After Phase 1

Once Approach passes CI and device acceptance, migrate rooms one at a time in progression order:

1. Lower Hall
2. Broken Gallery
3. Dash Shrine
4. Furnace Passage
5. Watcher Hall
6. Hollow Shaft
7. Ashen Ascent
8. Warden Gate
9. Warden Chamber

Each room must pass its existing route/encounter/progression contracts before the next room becomes TMX-authored.

## Out of Scope

- changing the 10-room progression order;
- redesigning Dash or Wall Traversal;
- changing combat controls;
- changing save/checkpoint semantics;
- changing Ash Warden mechanics;
- replacing the custom kinematic controller with `SKPhysicsBody`;
- adding a rendering tileset/art pipeline;
- migrating all 10 rooms in one commit;
- adding third-party dependencies.
