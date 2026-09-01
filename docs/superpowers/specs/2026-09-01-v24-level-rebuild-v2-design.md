# Ashen Hollow V24 Level Rebuild v2 Design

## Goal

Rebuild the full 10-room V24 demo layout from scratch while preserving the approved progression, abilities, boss, save/checkpoint model, and 10–15 minute target. The rebuilt level must feel like one coherent Hollow Knight-inspired world slice rather than a sequence of test platforms, and mandatory traversal must be forgiving on a physical iPhone.

## Scope

The following remain unchanged in concept:

- 10 zones: Approach, Lower Hall, Broken Gallery, Dash Shrine, Furnace Passage, Watcher Hall, Hollow Shaft, Ashen Ascent, Warden Gate, Warden Chamber.
- Unlock order: Dash first, Wall Traversal second.
- Dash remains free, no invulnerability, about 0.6 s cooldown, one air dash until refresh.
- Wall Cling / Wall Jump remain passive after acquisition.
- New Game resets progression; Continue restores the last valid checkpoint.
- Abilities persist after death and app relaunch.
- Ash Warden remains the final boss.
- Demo pacing target remains approximately 12–15 minutes first playthrough and about 10–11 minutes for a fast player.

This rebuild replaces the current V24 geometry and encounter placement. Existing platform coordinates are not preserved for compatibility.

## Root problems to eliminate

1. Rooms currently read as stacked test shelves instead of natural spaces.
2. Individual traversal checks can pass while the complete player path is still awkward or unreadable.
3. Several mandatory jumps are too close to the movement envelope, causing side-collider impacts and falls.
4. Some combat happens visually under the virtual control HUD on a phone.
5. Enemy placement sometimes conflicts with landing zones, entry direction, and camera framing.
6. Vertical routes can become long staircase chains rather than clear environmental teaching.
7. Exit gates can be mechanically valid but visually disconnected from the route the player naturally follows.

## Movement baseline

All level calculations use `PlayerMovementTuning.current` as the single source of truth:

- collider: 36 x 60 pt
- gravity: 1700 pt/s²
- jump velocity: 610 pt/s
- run speed: 315 pt/s
- air acceleration: 1050 pt/s²
- Dash: 720 pt/s for 0.16 s
- Wall Jump: 360 pt/s horizontal, 560 pt/s vertical
- movement substep limit: 5 pt

Mandatory routes are designed with approximately 20–25% first-play margin instead of theoretical maximum reach.

## Global geometry rules

### Ordinary mandatory movement

- Typical upward top-to-top rise: 45–70 pt.
- Hard mandatory rise ceiling: 80 pt.
- Comfortable ordinary horizontal clear gap: normally no more than 150–165 pt.
- Mandatory landing surface width: normally at least 220 pt; never below 180 pt.
- A mandatory jump must still work without a perfect full-speed run-up.
- A platform is invalid if the player's collider reaches its vertical face before the feet clear the platform top.

### Dash teaching / application

- The first Dash lesson contains one obvious Dash-required gap.
- Dash teaching takeoff and landing surfaces are equal-height or near equal-height.
- First Dash receiving surface is at least 320 pt wide.
- The first Dash lesson does not immediately chain into precision jumping.
- Later Dash applications may combine with ordinary jumps, but each combination ends on a large recovery surface.

### Wall traversal teaching

- The Wall Traversal shrine is reachable without already owning Wall Traversal.
- The first opposing-wall gap is approximately 170–200 pt.
- Hollow Shaft contains no enemies.
- The first climb ends on a broad recovery ledge.
- Ashen Ascent may combine Wall Jump and Dash only after both have already been taught separately.

### HUD-safe gameplay band

- Mandatory combat and landing zones must not sit visually behind the primary mobile control cluster.
- Camera framing is adjusted so the player and active combat space remain above the lower control band on a 910x512-class landscape display.
- HUD button positions remain unchanged; gameplay composition adapts around them.

## Full-route validation

A new room-route validation layer must model mandatory traversal as an ordered route:

`spawn -> surface/segment -> surface/segment -> ... -> exit`

For every route edge it verifies:

- source and target exist;
- ordinary jump / Dash / Wall Jump mode matches the intended ability state;
- vertical rise is within the safe envelope;
- horizontal gap is within the safe envelope;
- landing width is sufficient;
- collider-side interception cannot occur before top clearance;
- the target is not a dead-end with no valid continuation;
- player spawn is supported by or safely above the first route surface;
- exit trigger is reachable from the final route surface;
- enemy spawn does not overlap mandatory landing or spawn safety zones;
- critical combat is not placed in the HUD-obscured lower-screen band.

The validator is a regression guard, not a substitute for physical-device testing.

## World structure

The 10 rooms remain a single spatially coherent route rather than a linear menu. World origins and directional transitions should visually make sense on a map. The player may revisit Broken Gallery through the Wall Traversal shortcut payoff.

## Room designs

### 1. Approach

Purpose: first 30–60 seconds of onboarding.

Structure:

- One long safe starting floor.
- MOVE tutorial occurs before any hazard.
- One low, broad ledge teaches JUMP.
- A large stable combat platform contains a single Grunt for ATTACK.
- FOCUS is contextual only when HP is missing and enough Essence is available.
- No precision jumps.
- High inaccessible geometry may tease later traversal, but it is clearly optional.

### 2. Lower Hall

Purpose: readable descent and basic spatial combat.

Structure:

- Three large terraces form a descending route.
- No shelf staircase.
- Two Grunts are encountered sequentially, not as an immediate pile-on.
- Each terrace has enough room to fight without standing on an edge.
- Exit direction continues naturally from the descent.

### 3. Broken Gallery

Purpose: route identity, Runner introduction, visible future shortcut.

Structure:

- Large horizontal gallery lane.
- Runner has enough uninterrupted distance to accelerate and telegraph behavior.
- One high Wall Traversal-only shortcut is clearly visible but not mandatory yet.
- Main route to Dash Shrine remains obvious.
- Combat does not block the player on a narrow landing.

### 4. Dash Shrine

Purpose: acquire and understand Dash.

Structure:

- Shrine is accessible from the entry floor.
- After acquisition, one obvious equal-height Dash gap must be crossed.
- Receiving platform is at least 320 pt wide.
- A recovery floor exists below the gap so failed first attempts do not create excessive punishment.
- After the landing, the route exits via ordinary movement; no long post-Dash platform ladder.
- No enemies.

### 5. Furnace Passage

Purpose: first real Dash application plus combat.

Structure:

- Current eight-platform zigzag staircase is removed completely.
- A large entry arena establishes safe combat space.
- One Dash-relevant gap separates two broad banks.
- A short climb uses only two large terraces with forgiving 45–70 pt rises.
- Grunt and Runner are positioned away from the mandatory landing rectangles.
- The player can always visually read where the upper exit is before beginning the climb.
- The route stays above the lower HUD control band.

### 6. Watcher Hall

Purpose: teach spatial response to a Ranged enemy.

Structure:

- One broad combat floor plus one deliberate elevated firing position.
- Entry-side cover breaks the first projectile lane.
- Ranged enemy cannot fire directly into the player at spawn.
- Grunt pressures the ground route while the Ranged enemy controls distance.
- Exit lies beyond the encounter in the direction the player naturally advances.

### 7. Hollow Shaft

Purpose: pure Wall Traversal tutorial.

Structure:

- Shrine is walk-accessible on the lower floor.
- No enemies.
- One clean opposing-wall climb.
- Inner wall gap approximately 170–200 pt.
- Walls begin above the shrine floor so acquisition never requires the ability beforehand.
- The climb terminates on a large upper recovery platform.
- Exit follows directly from that recovery platform.

### 8. Ashen Ascent

Purpose: combined traversal exam without precision chaining.

Structure:

Three distinct challenges separated by recovery zones:

1. Wall Jump section -> broad recovery.
2. Dash section -> broad recovery.
3. Short Wall Jump + Dash combination -> broad exit approach.

Enemy placement occurs only on recovery platforms. No enemy occupies the first landing of a traversal combination. Runner and Ranged enemies may be used, but their arenas must remain separate from the actual airborne tutorial transfer.

### 9. Warden Gate

Purpose: final combat test and pre-boss reset.

Structure:

- One broad combat floor.
- Heavy physically guards the route.
- Ranged enemy occupies a deliberate distant/elevated position.
- Optional positional platform may exist but cannot be required for progression.
- Checkpoint activates in a calm space after the encounter and before the boss transition.

### 10. Warden Chamber

Purpose: clean boss fight.

Structure:

- Broad uninterrupted floor.
- Side walls may support Wall Jump as an optional tactical tool.
- No small mid-air catch platforms.
- Boss spawn has adequate separation from player spawn.
- Level-complete exit changes state only after Ash Warden defeat.

## Enemy placement rules

Enemy placement is a separate pass after traversal blockout validates.

- No enemy may overlap the player spawn safety radius.
- No enemy may occupy a mandatory landing rectangle.
- Runner requires a readable horizontal lane.
- Ranged requires a deliberate line-of-sight role and cannot immediately shoot the spawn point.
- Heavy guards rewards/routes instead of being dropped randomly into traversal.
- Hollow Shaft contains no enemies.
- Quiet rooms and traversal-only rooms are intentional pacing tools.

## World reactions

Preserve and use existing V24 reactions:

- claimed shrines become dormant;
- activated checkpoints visibly change state;
- combat gates change from locked to open;
- Broken Gallery shortcut presentation changes when Wall Traversal is owned;
- traversal teaching prompts appear contextually after acquisition;
- Ash Warden defeat changes the chamber completion state.

## Tutorial behavior

Approach onboarding remains:

- MOVE: highlight left/right controls until meaningful movement occurs.
- JUMP: highlight JUMP until a successful landing after jumping.
- ATTACK: highlight ATTACK until an accepted melee hit occurs.
- FOCUS: only display when the player has missing HP and enough Essence to heal.

Traversal teaching remains contextual:

- Dash prompt begins after a fresh Dash shrine claim and clears after a successful Dash.
- Wall Traversal prompt begins after a fresh Wall shrine claim and clears after a successful Wall Jump.

Tutorial progression must not restart merely because the player dies and respawns during the same run.

## Camera / presentation requirement

The camera must frame the active world so the player's lower-body, mandatory landing surfaces, nearby enemies, and immediate route remain visible above the mobile controls. This may be achieved through camera vertical offset / composition adjustments, but HUD positions themselves are not redesigned in this task.

## Testing requirements

Before device handoff:

1. Existing combat, Dash, Wall Traversal, save, checkpoint, boss, and HUD tests remain green.
2. Full-route validation covers all mandatory rooms.
3. Regression tests verify the old Furnace zigzag layout is gone.
4. Encounter-placement tests reject enemy overlap with mandatory landing/spawn safety zones.
5. HUD-safe composition tests cover key combat/landing zones.
6. `GameScene` arm64 iOS typecheck passes.
7. Full arm64 app compile passes.
8. Unsigned IPA packages successfully and archive integrity is verified.
9. Temporary CI patchers must not remain in the final exact-SHA build.

Physical iPhone acceptance is still required for visual framing and game feel.

## Out of scope

- New abilities.
- New boss mechanics.
- New enemy archetypes.
- New art pipeline.
- New map UI.
- Fast travel.
- Changing the approved 10-room V24 progression order.
- Replacing the custom kinematic controller with `SKPhysicsBody`.
