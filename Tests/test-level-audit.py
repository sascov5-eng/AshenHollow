#!/usr/bin/env python3
"""Static reachability audit for Ashen Hollow level geometry.

Parses the real tuning numbers and level data out of
Sources/PlayerMovementTuning.swift, Sources/TestLocationLayout.swift and
Sources/KingdomMap.swift, then verifies:

1. Every TraversalSpec satisfies the same jump physics the Swift
   TraversalReachabilityValidator enforces (jump height / running range /
   dash bonus derived from tuning, not hardcoded).
2. No dead ends on the critical ground route 240 -> 25880:
   - every lever sits BEFORE its door and at ground level,
   - every ground gap is plain-jumpable (except the one sanctioned
     void-pit dash gap),
   - every spike strip is plain-jumpable,
   - no death zone reaches up into jumper/standable space,
   - every door stands on walkable ground,
   - no tall wall or low ceiling seals the ground route,
   - every raised platform is boardable from below or via jump-down.
3. Checkpoint/hazard separation, tutorial coverage, moving-platform axes.

Stage-independent: no patch script rewrites the layout files, so this can
run at any point of the build chain.
"""

import math
import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
failures = []


def check(name, ok, detail=""):
    if not ok:
        failures.append(f"{name}" + (f": {detail}" if detail else ""))


# ---------------------------------------------------------------- tuning --
tuning_src = (root / "Sources/PlayerMovementTuning.swift").read_text()


def tnum(field):
    m = re.search(rf"{field}: ([\d.]+)", tuning_src)
    assert m, f"tuning field missing: {field}"
    return float(m.group(1))


collider_w = tnum("colliderWidth")
collider_h = tnum("colliderHeight")
gravity = tnum("gravity")
jump_v = tnum("jumpVelocity")
run_speed = tnum("runSpeed")
dash_bonus = tnum("dashSpeed") * tnum("dashDuration")
wall_h = tnum("wallJumpHorizontalSpeed")

max_jump_h = jump_v * jump_v / (2 * gravity)
air_time = 2 * jump_v / gravity
run_range = run_speed * air_time


def jump_reach_up(rise):
    """Horizontal range of a full running jump landing `rise` px higher."""
    disc = jump_v * jump_v - 4 * (gravity / 2) * rise
    if disc < 0:
        return 0.0
    t2 = (jump_v + math.sqrt(disc)) / gravity
    return run_speed * t2


def jump_reach_down(drop):
    """Horizontal range jumping from a perch and landing `drop` px lower."""
    t_up = jump_v / gravity
    t_down = math.sqrt(2 * (max_jump_h + drop) / gravity)
    return run_speed * (t_up + t_down)


# -------------------------------------------------------------- geometry --
layout_src = (root / "Sources/TestLocationLayout.swift").read_text()
kingdom_src = (root / "Sources/KingdomMap.swift").read_text()
model_src = (root / "Sources/TestLocationModel.swift").read_text()


def rect_tuple(m):
    return (float(m[0]), float(m[1]), float(m[2]), float(m[3]))


def rect_min_x(r): return r[0]
def rect_min_y(r): return r[1]
def rect_max_x(r): return r[0] + r[2]
def rect_max_y(r): return r[1] + r[3]


# -- solids --
m = re.search(r"let solids: \[CGRect\] = \[(.*?)\n        \]", layout_src, re.DOTALL)
assert m, "solids block not found"
solids = [rect_tuple(x) for x in re.findall(
    r"CGRect\(x: ([\d.]+), y: ([\d.]+), width: ([\d.]+), height: ([\d.]+)\)", m.group(1))]

static_kingdom = [rect_tuple(x) for x in re.findall(
    r"r\.append\(CGRect\(x: ([\d.]+), y: ([\d.]+), width: ([\d.]+), height: ([\d.]+)\)\)", kingdom_src)]

def loop_expr_value(expr, i):
    """Evaluate the tiny loop-index expressions used in KingdomMap."""
    expr = expr.strip()
    m = re.fullmatch(r"([\d.]+)", expr)
    if m:
        return float(m.group(1))
    m = re.fullmatch(r"([\d.]+) \+ CGFloat\(i(?: % (\d+))?\) \* ([\d.]+)", expr)
    assert m, f"unsupported loop expression: {expr!r}; update the audit"
    base, mod, step = float(m.group(1)), m.group(2), float(m.group(3))
    return base + (i % int(mod) if mod else i) * step


moss_loop = re.search(
    r"for i in 0\.\.<(\d+) \{\s*let x = ([^\n]+?)\s*"
    r"r\.append\(CGRect\(x: x, y: ([^,]+?), width: ([\d.]+), height: ([\d.]+)\)\)",
    kingdom_src)
assert moss_loop, "moss platform loop shape changed; update the audit"
terrace_loop = re.search(
    r"for i in 0\.\.<(\d+) \{\s*"
    r"r\.append\(CGRect\(x: ([^,]+?), y: ([^,]+?), width: ([\d.]+), height: ([\d.]+)\)\)",
    kingdom_src)
assert terrace_loop, "terrace loop shape changed; update the audit"

loop_rects = []
for count, x_expr, y_expr, w, h in (moss_loop.groups(), terrace_loop.groups()):
    for i in range(int(count)):
        loop_rects.append((loop_expr_value(x_expr, i), loop_expr_value(y_expr, i),
                           float(w), float(h)))

solids += static_kingdom + loop_rects

# -- hazards / checkpoints / moving / interactions / tutorials / traversals --
def specs(pattern, *sources):
    out = []
    for src in sources:
        out += re.findall(pattern, src)
    return out


hazards = specs(
    r"HazardSpec\(id: \"([^\"]+)\", kind: \.(\w+), rect: CGRect\(x: ([\d.]+), y: ([\d.]+), width: ([\d.]+), height: ([\d.]+)\)\)",
    layout_src, kingdom_src)
checkpoints = specs(
    r"TestCheckpointSpec\(id: \"([^\"]+)\", position: CGPoint\(x: ([\d.]+), y: ([\d.]+)\)\)",
    layout_src, kingdom_src)
movings = specs(
    r"MovingPlatformSpec\(id: \"([^\"]+)\", axis: (\.\w+), start: CGPoint\(x: ([\d.]+), y: ([\d.]+)\), "
    r"end: CGPoint\(x: ([\d.]+), y: ([\d.]+)\), size: CGSize\(width: ([\d.]+), height: ([\d.]+)\), speed: ([\d.]+)\)",
    layout_src)
interactions = specs(
    r"InteractionSpec\(id: \"([^\"]+)\", kind: (\.\w+), rect: CGRect\(x: ([\d.]+), y: ([\d.]+), width: ([\d.]+), "
    r"height: ([\d.]+)\), linkedID: (?:\"([^\"]+)\"|nil)\)",
    layout_src, kingdom_src)
traversals = specs(
    r"TraversalSpec\(id: \"([^\"]+)\", kind: (\.\w+), from: CGPoint\(x: ([\d.]+), y: ([\d.]+)\), "
    r"to: CGPoint\(x: ([\d.]+), y: ([\d.]+)\), landingWidth: ([\d.]+), headClearance: ([\d.]+)\)",
    layout_src)
tutorial_mechanics = set(re.findall(r"tutorial\(\.(\w+),", layout_src))
m = re.search(r"requiredTutorialMechanics: Set<TestMechanicID> = \[(.*?)\]", model_src, re.DOTALL)
assert m, "requiredTutorialMechanics not found"
required_mechanics = set(re.findall(r"\.(\w+)", m.group(1)))

# parse-count sanity guards (catch silent regex drift)
check("parsed solids", len(solids) > 40, f"got {len(solids)}")
check("parsed hazards", len(hazards) == 8, f"got {len(hazards)}")
check("parsed checkpoints", len(checkpoints) == 8, f"got {len(checkpoints)}")
check("parsed movings", len(movings) == 3, f"got {len(movings)}")
check("parsed interactions", len(interactions) == 11, f"got {len(interactions)}")
check("parsed traversals", len(traversals) == 9, f"got {len(traversals)}")

# --------------------------------------- 1. traversal specs vs jump physics --
for tid, kind, fx, fy, tx, ty, land_w, head in traversals:
    fx, fy, tx, ty, land_w, head = map(float, (fx, fy, tx, ty, land_w, head))
    dx, dy = abs(tx - fx), ty - fy
    check(f"traversal {tid} landing", land_w >= collider_w * 2.0, f"width {land_w}")
    check(f"traversal {tid} headroom", head >= collider_h + 20, f"clearance {head}")
    if kind == ".walk":
        check(f"traversal {tid}", dy <= 24, f"rises {dy}")
    elif kind == ".ordinaryJump":
        check(f"traversal {tid} height", dy <= max_jump_h * 0.98, f"rises {dy:.1f} vs {max_jump_h:.1f}")
        check(f"traversal {tid} width", dx <= run_range * 0.72, f"spans {dx:.1f} vs {run_range:.1f}")
    elif kind == ".runningJump":
        check(f"traversal {tid} height", dy <= max_jump_h * 0.95, f"rises {dy:.1f} vs {max_jump_h:.1f}")
        check(f"traversal {tid} width", dx <= run_range * 0.98, f"spans {dx:.1f} vs {run_range:.1f}")
    elif kind == ".jumpDash":
        check(f"traversal {tid} height", dy <= max_jump_h * 0.9, f"rises {dy:.1f}")
        check(f"traversal {tid} width", dx <= run_range + dash_bonus * 1.05, f"spans {dx:.1f}")
    elif kind == ".wallJump":
        check(f"traversal {tid} shaft", abs(tx - fx) <= wall_h * 1.5, f"width {abs(tx - fx):.1f}")
    elif kind == ".movingPlatformTransfer":
        check(f"traversal {tid}", dx <= run_range * 0.9 and abs(dy) <= max_jump_h * 1.15,
              f"dx {dx:.1f} dy {dy:.1f}")
    else:
        check(f"traversal {tid}", False, f"unknown kind {kind}")

# ------------------------------------------------- standable ground cover --
standable = sorted(
    [r for r in solids if 88 <= rect_max_y(r) <= 92], key=rect_min_x)
merged = []
for r in standable:
    if merged and rect_min_x(r) <= merged[-1][1]:
        merged[-1][1] = max(merged[-1][1], rect_max_x(r))
    else:
        merged.append([rect_min_x(r), rect_max_x(r)])


def covered(x0, x1):
    return any(a <= x0 and x1 <= b for a, b in merged)


ROUTE_START, ROUTE_END = 240.0, 25880.0

# ------------------------------------------------- 2a. levers before doors --
by_id = {i[0]: i for i in interactions}
for iid, kind, x, y, w, h, linked in interactions:
    if kind in (".lever", ".shortcutLever") and linked:
        lever_cx = float(x) + float(w) / 2
        door = by_id.get(linked)
        check(f"lever {iid} links", door is not None, f"missing {linked}")
        if door:
            check(f"lever {iid} before door", lever_cx < float(door[2]),
                  f"lever x {lever_cx:.0f} vs door x {door[2]}")
        check(f"lever {iid} at ground", float(y) < 300, f"y {y}")

# ------------------------------------------------- 2b. doors on walk ground --
for iid, kind, x, y, w, h, _linked in interactions:
    if kind in (".door", ".shortcutDoor", ".breakableWall"):
        check(f"{iid} stands on ground",
              covered(float(x) + 2, float(x) + float(w) - 2),
              f"x {x}..{float(x) + float(w):.0f}")

# ------------------------------------------------- 2c. ground gaps jumpable --
VOID_GAP = (23840.0, 24100.0)
for (a0, a1), (b0, _b1) in zip(merged, merged[1:]):
    if b0 < ROUTE_START or a1 > ROUTE_END:
        continue
    width = b0 - a1
    if width <= 0:
        continue
    travel = width + collider_w
    if a1 <= VOID_GAP[1] and b0 >= VOID_GAP[0]:
        check(f"void gap {a1:.0f}..{b0:.0f} dashable",
              travel <= run_range + dash_bonus * 1.05, f"travel {travel:.0f}")
    else:
        check(f"gap {a1:.0f}..{b0:.0f} jumpable",
              travel <= run_range * 0.98, f"travel {travel:.0f} vs {run_range:.0f}")

# ------------------------------------------------- 2d. spikes / death zones --
for hid, kind, x, y, w, h in hazards:
    x, y, w, h = map(float, (x, y, w, h))
    if kind == "spikes":
        check(f"spikes {hid} jumpable", w + collider_w <= run_range * 0.98,
              f"width {w:.0f}")
    elif kind == "deathZone":
        check(f"deathzone {hid} below feet", y + h <= 88, f"top {y + h:.0f}")
    else:
        check(f"hazard {hid}", False, f"unknown kind {kind}")

# ------------------------------------------------- 2e. no wall / ceiling block --
for r in solids:
    tall_wall = (rect_min_y(r) <= 92 and rect_max_y(r) > 300
                 and 0 <= rect_min_x(r) <= ROUTE_END)
    check(f"solid ({rect_min_x(r):.0f},{rect_min_y(r):.0f}) not a route wall",
          not tall_wall, f"spans y ..{rect_max_y(r):.0f}")
    low_ceiling = (92 < rect_min_y(r) < 92 + collider_h
                   and rect_min_x(r) < ROUTE_END and rect_max_x(r) > ROUTE_START)
    check(f"solid ({rect_min_x(r):.0f},{rect_min_y(r):.0f}) walk-under clearance",
          not low_ceiling, f"ceiling at {rect_min_y(r):.0f}")

# ------------------------------------------------- 2f. platforms boardable --
DASH_TOP_GAP = (6656.0, 6860.0)
targets = [r for r in solids
           if rect_max_y(r) > 92 and r[3] <= 40 and rect_min_y(r) >= 40 and rect_min_x(r) >= 0]
sources = [(rect_min_x(r), rect_max_x(r), rect_max_y(r)) for r in solids]
for _mid, _axis, sx, sy, ex, ey, sw, sh, _sp in movings:
    sx, sy, ex, ey, sw, sh = map(float, (sx, sy, ex, ey, sw, sh))
    sources.append((sx - sw / 2, sx + sw / 2, sy + sh / 2))
    sources.append((ex - sw / 2, ex + sw / 2, ey + sh / 2))


def edge_gap(t0, t1, s0, s1):
    if t1 < s0:
        return s0 - t1
    if t0 > s1:
        return t0 - s1
    return 0.0


for t in targets:
    t0, t1, top = rect_min_x(t), rect_max_x(t), rect_max_y(t)
    feasible = False
    for s0, s1, stop in sources:
        travel = edge_gap(t0, t1, s0, s1) + collider_w
        if stop <= top:
            rise = top - stop
            if rise <= 100 and travel <= jump_reach_up(rise) * 0.95:
                feasible = True
                break
        else:
            drop = stop - top
            if travel <= jump_reach_down(drop) * 0.9:
                feasible = True
                break
    if not feasible:
        for s0, s1, stop in sources:
            travel = edge_gap(t0, t1, s0, s1) + collider_w
            rise = top - stop
            gap_left, gap_right = (t1, s0) if t1 < s0 else (s1, t0)
            if (rise <= max_jump_h * 0.9
                    and travel <= run_range + dash_bonus * 1.05
                    and gap_left >= DASH_TOP_GAP[0] - 1 and gap_right <= DASH_TOP_GAP[1] + 1):
                feasible = True
                break
    check(f"platform ({t0:.0f},{rect_min_y(t):.0f}) boardable", feasible, f"top {top:.0f}")

# ------------------------------------------------- 3. hazards / tutorials --
for cid, cx, cy in checkpoints:
    cx, cy = float(cx), float(cy)
    frame = (cx - collider_w / 2, cy - collider_h / 2, collider_w, collider_h)
    for hid, _k, x, y, w, h in hazards:
        x, y, w, h = map(float, (x, y, w, h))
        overlap = (frame[0] < x + w and frame[0] + frame[2] > x
                   and frame[1] < y + h and frame[1] + frame[3] > y)
        check(f"checkpoint {cid} vs {hid}", not overlap, "intersects hazard")

check("tutorial coverage", required_mechanics <= tutorial_mechanics,
      f"missing {sorted(required_mechanics - tutorial_mechanics)}")
check("checkpoint count", len(checkpoints) >= 4, f"got {len(checkpoints)}")
check("moving axes", {m[1] for m in movings} == {".horizontal", ".vertical"},
      f"got {sorted(m[1] for m in movings)}")

if failures:
    print("LEVEL AUDIT FAILURES:")
    for f in failures:
        print(" -", f)
    sys.exit(1)
print(f"Level audit PASS: jump {max_jump_h:.1f}px, range {run_range:.1f}px, "
      f"{len(solids)} solids, {len(traversals)} traversals, {len(targets)} platforms boardable")
