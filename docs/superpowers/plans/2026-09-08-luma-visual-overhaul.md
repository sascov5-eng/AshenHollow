# Luma Visual Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace AshenHollow placeholder visuals with production-ready Luma environment, interaction, hazard, and three-enemy art without changing gameplay.

**Architecture:** Keep the existing Swift gameplay model and resource lookup contracts. Introduce/replace only render resources and narrowly scoped art-selection helpers where multiple visual states are required. Preserve existing IDs and geometry.

**Tech Stack:** Swift, SpriteKit/CoreGraphics, PNG resources, existing repository scripts/tests.

**Spec:** `docs/superpowers/specs/2026-09-08-luma-visual-overhaul-design.md`

## Global Constraints
- No gameplay-number, collision, traversal, enemy-AI, reward, or progression changes.
- No sheet-label/background crops may ship as production sprites.
- Preserve existing resource filenames where runtime code already depends on them.
- Three parallax depths: far, middle, near.

---

### Task 1: Inventory runtime art contracts
**Files:** inspect `Sources/`, `Resources/`, `Tests/`; modify only documentation if no runtime change is needed.

- [ ] Search all `SKTexture`, image-name, `EnvArt`, door, lever, enemy and background references.
- [ ] Record exact filenames, state names, and fallback behavior.
- [ ] Run existing tests/build to establish baseline.
- [ ] Commit the inventory if documentation changes are required.

### Task 2: Production environment asset set
**Files:** modify/create PNGs under `Resources/EnvArt/` using the approved Luma art direction.

- [ ] Prepare isolated far-background artwork with no labels or baked UI.
- [ ] Prepare isolated middle-layer ruins/vegetation artwork.
- [ ] Prepare isolated near-foreground silhouettes/foliage artwork.
- [ ] Replace terrain/platform/decor resources while retaining expected dimensions/anchors where required by renderer contracts.
- [ ] Verify alpha edges and mobile readability.
- [ ] Commit environment assets.

### Task 3: Interactive props and hazards
**Files:** `Resources/EnvArt/` plus existing Swift art selectors such as `Sources/LeverArt.swift` when required.

- [ ] Supply lever OFF and ON isolated sprites.
- [ ] Supply door closed/open state sprites and shortcut-door compatible art.
- [ ] Supply checkpoint sprite.
- [ ] Supply breakable-wall/hidden-passage visual states.
- [ ] Supply spikes/platform/hazard visuals.
- [ ] Update state-to-texture mapping only where the existing runtime needs explicit state selection.
- [ ] Run interaction tests and commit.

### Task 4: Three core enemies
**Files:** replace `Resources/EnvArt/enemy_grub.png`, `enemy_fly.png`, `enemy_husk.png`; update render-state mapping only if existing runtime supports animation frames.

- [ ] Produce grub/groundPatrol isolated art matching its low ground silhouette.
- [ ] Produce fly/flying isolated art with a clear airborne silhouette.
- [ ] Produce husk/aggressive isolated art with a larger threatening silhouette.
- [ ] Preserve gameplay kinds and controller logic unchanged.
- [ ] Verify hit/death visibility and commit.

### Task 5: Parallax integration
**Files:** existing SpriteKit scene/render support discovered in Task 1.

- [ ] Add far layer with the smallest camera displacement factor.
- [ ] Add middle layer with intermediate displacement.
- [ ] Add near foreground with the strongest displacement while keeping gameplay readable.
- [ ] Ensure layers do not affect collision or touch input.
- [ ] Test across representative viewport sizes and commit.

### Task 6: Regression verification
**Files:** tests only if coverage gaps are found.

- [ ] Run complete existing test suite.
- [ ] Verify ground/flying/aggressive enemies retain HP, movement and patrol behavior.
- [ ] Verify lever-door and shortcut links still work.
- [ ] Verify checkpoint, spikes, moving platforms, secret wall and hidden path still function.
- [ ] Verify no missing texture fallbacks appear.
- [ ] Commit any test-only corrections.