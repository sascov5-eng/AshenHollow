# V20 — Room / Level Architecture

## Status
Design for the first reusable room system on top of the user-confirmed V19 gameplay baseline.

## Goal
Replace the single long test strip with a small room-driven level structure without rewriting the stable player controller, combat, health, AI, or V19 death/respawn flow.

V20 must prove:
- room-specific world bounds;
- room-specific player spawn;
- room-specific platforms;
- room-specific enemy spawn;
- room exit/transition;
- camera clamp to the active room;
- safe reset of room-local enemy state on transition.

## Chosen architecture
Use one persistent `GameScene` and describe rooms as data.

Rejected alternatives:
1. Hard-code room checks directly throughout `GameScene`: fastest initially, but creates conditionals in camera, collision, spawn, and transition code and becomes difficult to extend.
2. Use one SpriteKit scene per room: clean isolation, but would repeatedly recreate/install the V13–V19 gameplay systems and make persistent player state harder.
3. Data-driven rooms inside one `GameScene` — chosen: stable gameplay objects stay alive, while only room-local geometry and enemy placement are rebuilt.

## Data model
Add a pure room-definition layer, independent from SpriteKit presentation where practical.

Initial model:
- `RoomID`
- `RoomDefinition`
  - `id`
  - `bounds`
  - `playerSpawn`
  - `platforms`
  - optional `enemySpawn`
  - `exits`
- `RoomPlatform`
  - center
  - size
- `RoomExit`
  - trigger rectangle
  - destination room ID
  - destination spawn

The first implementation keeps one active enemy node because V16–V19 currently use a single `testEnemy`. Multi-enemy architecture is intentionally deferred; V20 must not silently expand into a combat-system rewrite.

## Runtime ownership
`GameScene` remains the owner of:
- player node and kinematic velocity;
- collision rectangles;
- combat state;
- test enemy node and HP;
- camera/HUD.

A new room controller owns:
- active room ID;
- room lookup;
- transition lookup;
- room-specific camera clamp math.

`GameScene.loadRoom(...)` will:
1. clear only room-local geometry from `worldRoot`;
2. rebuild the active room backdrop/platforms;
3. replace `platformRects` with active-room collision rectangles;
4. move the player to the destination spawn and zero movement state required for a clean room entry;
5. reset/reposition the single current enemy;
6. reinstall enemy AI so its patrol origin matches the new enemy spawn;
7. leave player HP/damage runtime and HUD intact during normal room transitions.

## First playable V20 layout
Create two test rooms so the architecture is exercised rather than only compiled.

### Room A — Entry
- approximately 1200 world units wide;
- floor plus two elevated platforms;
- player starts near the left side;
- one enemy farther right;
- visible exit zone at the right edge leading to Room B.

### Room B — Combat test
- different platform arrangement;
- player enters near the left side;
- one enemy at a different patrol origin;
- no required backtracking in V20; the architecture supports destination exits, but the first acceptance path only needs A → B.

## Transition behavior
When the player intersects an active room exit trigger:
- input for the old room is neutralized;
- attack/jump buffers and velocity are cleared for deterministic entry;
- active room switches;
- player is placed at the exit's destination spawn;
- camera snaps/clamps inside the destination room before normal follow resumes;
- enemy HP/state is reset for the new room;
- enemy AI is reinstalled at the new spawn.

No scene replacement is used for normal room transitions.

## Camera
Keep the confirmed V14/V19 zoom and smoothing constants.

Only the clamp source changes:
- current: global `worldWidth`;
- V20: active `RoomDefinition.bounds`.

For each frame, camera target still uses existing look-ahead and vertical follow, but horizontal position is clamped so the viewport cannot reveal outside the active room.

## Player collision boundaries
Do not modify acceleration, gravity, jump, substep collision, or platform resolution.

The final horizontal world clamp changes from the global strip to the active room's min/max X. Exit triggers are placed inside those bounds, so the player transitions before the room wall clamp becomes an obstacle.

## Enemy compatibility
V20 preserves the existing single-enemy combat contract:
- same `testEnemy` node;
- same 3 HP;
- same player melee hit detection;
- same enemy AI/damage system.

On room load, enemy health/presentation is reset and `EnemyAIInstaller.install(on:)` is rerun so the patrol center is based on the new spawn.

## Death / respawn compatibility
V19 behavior remains unchanged in V20: death creates a fresh scene and therefore returns the player to Room A at full HP.

Current-room checkpoints/persistent room progress are explicitly deferred.

## Test strategy
Add a pure `RoomController`/`RoomLayout` unit test before production code.

The test must verify at least:
- Room A is the initial room;
- Room A exit resolves to Room B and the expected destination spawn;
- room-specific camera clamp returns values inside active-room bounds;
- unknown/non-intersecting exits do not transition.

Then run all existing V15–V19 tests plus the new room test and the full arm64 iOS compile/package workflow.

## Acceptance criteria
V20 is accepted only after real-device confirmation that:
1. V19 movement/jump/attack still feel unchanged;
2. Room A camera never reveals outside Room A;
3. entering Room A's exit moves the player into Room B;
4. Room B has different geometry and enemy spawn;
5. Room B enemy still patrols/chases/attacks/takes damage/dies;
6. player HP/damage still works after a room transition;
7. player death still performs the V19 respawn cycle and returns to Room A.

## Deferred
- multiple simultaneous enemies;
- bidirectional map/backtracking UI;
- checkpoints/current-room death respawn;
- room persistence after enemy death;
- doors/keys/locked exits;
- room streaming from external JSON/plist;
- final level art.