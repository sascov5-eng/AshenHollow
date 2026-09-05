# Ashen Hollow Large World + Cinematic Camera Design

## Goal
Replace the current small test arena with one continuous, multi-screen platforming space and refactor the camera so movement reads like the supplied reference video: player motion inside a large world, soft camera follow, dead zones, look-ahead, vertical restraint, and camera bounds.

## Scope
This iteration is a gameplay blockout, not final art. It should validate spatial scale, traversal flow, camera behavior, and the relationship between player movement and room geometry.

## World Layout
Build one continuous world approximately 8–10 screen widths by 4–5 screen heights at the current 844×390 scene reference scale.

The route is continuous and contains:
- a broad starting cavern;
- a long horizontal traversal with changing floor/ceiling height;
- a larger open chamber;
- a tall vertical shaft with climbable ledges and wall-jump opportunities;
- an upper route that reconnects into the wider space;
- a descending continuation leading toward the far side of the map.

There are no teleports or room loads inside this prototype. All geometry exists in one coordinate space.

The route must be formed primarily by cave architecture itself: floors, walls, ceilings, ledges, shafts, choke points, drops, and tunnels. Avoid the current visual of isolated floating rectangles on a small flat floor.

## Collision and Traversal
Preserve the existing kinematic movement stack unless a change is required for the new world:
- running and acceleration/deceleration;
- jump with coyote time and jump buffering;
- variable jump height;
- dash and one-air-dash behavior;
- wall slide and wall jump;
- attack and heal controls.

Collision remains rectangle-based for this blockout. Geometry can be composed from larger architectural rectangles rather than introducing tilemaps or polygon collision in this iteration.

## Camera Behavior
Use the existing `SKCameraNode`, but replace direct/simple follow with a camera target system.

### Horizontal follow
- Define a horizontal dead zone around the visual center.
- While the player stays inside the dead zone, the camera should move little or not at all.
- When the player exits the dead zone, move the camera target just enough to bring the player back toward the allowed zone.
- Add direction-aware look-ahead so the player has more visible space in front of movement than behind.
- Smooth the look-ahead when reversing direction; it must not snap instantly from one side to the other.

### Vertical follow
- Use a smaller, more conservative vertical response than horizontal follow.
- Ordinary jumps should happen mostly inside the camera frame without the camera tracing the full jump arc.
- Sustained climbs, large drops, and movement through a vertical shaft should move the camera vertically.
- Use a vertical dead zone and smooth target movement rather than mapping camera Y directly to player Y.

### Dash behavior
A dash should move the player first. The camera follows through the same smoothing system and must not teleport or hard-snap.

### Bounds
The camera must be clamped to world/camera-region bounds so it never reveals empty space outside the intended environment.

For v1.2, one global camera region covering the whole blockout is acceptable if it produces correct framing. The architecture should leave room to support multiple camera regions later without redesigning player movement.

## Visual Scale
Keep the Little Axion animation system. Do not finalize player visual size independently of the new camera. The desired result is that the player remains clearly readable while enough environment is visible to preview traversal and architecture.

Start with the current v1.1 sprite visual size and adjust only if the new camera makes it obviously wrong. Do not change the physical collider merely to match the sprite artwork.

## Background / Depth
For the blockout, use simple layered shapes to establish depth:
- far background;
- background architecture;
- gameplay/collision layer;
- optional dark foreground silhouettes.

Introduce restrained parallax for background layers if it can be done without complicating collision or camera logic. Final environment art is out of scope.

## Code Structure
Refactor responsibilities so the large-world work does not further overload `GameScene.swift`.

Recommended units:
- `LargeWorldLayout.swift`: defines world dimensions and blockout collision/decorative geometry.
- `CinematicCameraController.swift`: owns dead-zone logic, look-ahead smoothing, camera target, and clamping.
- `GameScene.swift`: coordinates player, world, camera controller, HUD, and input.

Keep existing movement/combat controller files unchanged unless integration proves a concrete need.

## v1.2 Release Contract
The next assembled test build is `CFBundleShortVersionString = 1.2`.

Visible top label:
`v1.2 • LARGE WORLD • CINEMATIC CAMERA`

Preserve:
- `CFBundleIdentifier = app.ashenhollow.prototype`
- `CFBundleVersion = 2`
- landscape left/right only;
- existing minimal IPA packaging contract;
- all nine Little Axion animation resources.

## Acceptance Criteria
The v1.2 build is successful when:
- the player can traverse a single continuous space much larger than one screen in both X and Y;
- there are no room-load transitions within the blockout;
- the map includes a meaningful horizontal section and a multi-screen vertical shaft;
- camera motion is noticeably softer than direct player lock;
- small jumps do not drag the camera through their entire vertical arc;
- sustained vertical traversal does move the camera;
- reversing direction does not make look-ahead snap across the screen;
- dash does not hard-snap the camera;
- camera never reveals empty world outside intended bounds;
- existing movement, dash, wall traversal, attack, HUD, and animation state selection still compile and remain usable;
- the top label visibly identifies v1.2 and the camera/large-world change.

## Non-goals
- final environment art;
- enemies or boss logic;
- save/checkpoint systems;
- map UI;
- loading-zone architecture;
- tilemap migration;
- final parallax art tuning;
- damage/death wiring for Hurt/Death animations.
