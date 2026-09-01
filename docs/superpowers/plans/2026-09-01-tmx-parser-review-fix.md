# TMX Parser Review Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the TMX loader against malformed numeric attributes, unsupported object geometries, and XMLParser parse-error edge cases identified in PR #1 review.

**Architecture:** Preserve the existing `TMXLevelLoader -> RoomDefinition` boundary. Reject malformed or unsupported TMX during parsing/building before any invalid coordinate can enter gameplay. No runtime, progression, combat, movement, or level-layout behavior changes.

**Tech Stack:** Swift 6, Foundation, FoundationXML/XMLParser, existing standalone swiftc tests and GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-09-01-tmx-level-loader-design.md`

## Global Constraints

- No third-party dependencies.
- Keep finite orthogonal rectangle/point TMX subset only.
- Unsupported geometry must fail explicitly rather than degrade to a bounding rectangle.
- Existing valid `Resources/Maps/approach.tmx` behavior must remain unchanged.
- Full V24 validation and IPA build must remain green.

---

### Task 1: Regression tests

**Files:**
- Modify: `Tests/TMXLevelLoaderTests.swift`

**Interfaces:**
- Consumes: `TMXLevelLoader.loadRoom(data:sourceName:)`
- Produces: regression coverage for invalid numeric object attributes, unsupported geometry, and truncated XML.

- [x] Add failing tests for nonnumeric object `x` and `rotation` attributes.
- [x] Add failing tests for ellipse, polygon, and tile-object geometry.
- [x] Add a malformed-document test where all gameplay objects are complete but the root map is truncated.
- [ ] Run CI and verify the regression tests fail on the current parser for the expected reasons.

### Task 2: Parser hardening

**Files:**
- Modify: `Sources/TMXLevelLoader.swift`

**Interfaces:**
- Consumes: raw XML attributes and XMLParser callbacks.
- Produces: only finite numeric object data and explicitly supported point/rectangle geometry.

- [ ] Validate object x/y/width/height/rotation as finite numbers before constructing runtime geometry.
- [ ] Reject ellipse, polygon, polyline and tile objects with `invalidObjectGeometry`.
- [ ] Check `parserFailure` and `parser.parserError` after every `parse()` call, regardless of the returned Boolean.
- [ ] Run TMX parser tests and confirm all regressions pass.

### Task 3: Full verification

**Files:**
- No additional production files expected.

**Interfaces:**
- Consumes: hardened parser.
- Produces: verified V24 build.

- [ ] Run TMX Approach parity tests.
- [ ] Run V24 Full Route Validation.
- [ ] Run full Build Ashen Hollow IPA workflow.
- [ ] Verify arm64 compile, IPA packaging, and artifact upload succeed.
