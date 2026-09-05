#!/usr/bin/env python3
from pathlib import Path

runtime_path = Path("Sources/V15RuntimeSupport.swift")
runtime = runtime_path.read_text(encoding="utf-8")
start = "        case .lever, .shortcutLever:" + chr(10)
end = "        case .door, .shortcutDoor:"
a = runtime.find(start)
b = runtime.find(end, a)
if a < 0 or b < 0:
    raise SystemExit("lever case missing in V15RuntimeSupport")
runtime = runtime[:a] + start + "            root.addChild(LeverArt.node())" + chr(10) + runtime[b:]
if "LeverArt.node()" not in runtime:
    raise SystemExit("failed to insert LeverArt.node()")
runtime_path.write_text(runtime, encoding="utf-8")

scene_path = Path("Sources/GameSceneV14.swift")
scene = scene_path.read_text(encoding="utf-8")
old_visual = '''    private func setLeverVisual(id: String, active: Bool) {
        guard let handle = worldNodes[id]?.childNode(withName: "//leverHandle") else { return }
        let target: CGFloat = active ? 0.58 : -0.55
        if abs(handle.zRotation - target) > 0.02 {
            handle.run(.rotate(toAngle: target, duration: 0.16, shortestUnitArc: true), withKey: "leverState")
        }
    }'''
new_visual = '''    private func setLeverVisual(id: String, active: Bool) {
        guard let root = worldNodes[id] else { return }
        if let handle = root.childNode(withName: "//leverHandle") {
            let target: CGFloat = active ? 0.58 : -0.55
            if abs(handle.zRotation - target) > 0.02 {
                handle.run(.rotate(toAngle: target, duration: 0.16, shortestUnitArc: true), withKey: "leverState")
            }
        }
        if let glow = root.childNode(withName: "//leverGlow") as? SKShapeNode {
            glow.fillColor = UIColor(red: 0.28, green: 0.92, blue: 0.86, alpha: active ? 0.55 : 0)
        }
    }'''
if old_visual in scene:
    scene = scene.replace(old_visual, new_visual, 1)
    scene_path.write_text(scene, encoding="utf-8")
elif "leverGlow" not in scene:
    raise SystemExit("setLeverVisual missing and glow not present")

print("Applied cave lever sprite")
